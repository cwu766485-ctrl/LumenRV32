#!/usr/bin/env bash
set -euo pipefail

mode="${1:-lint}"
case "$mode" in lint|cdc|rdc) ;; *) echo "usage: $0 {lint|cdc|rdc}" >&2; exit 2;; esac
case "$mode" in
    lint) goal='lint/lint_rtl' ;;
    cdc)  goal='cdc/cdc_verify_struct' ;;
    rdc)  goal='rdc/rdc_verify_struct' ;;
esac
# WSL batch shells are often non-interactive and therefore do not source the
# user's .bashrc, where this workstation loads Synopsys tool paths.
if ! command -v spyglass >/dev/null 2>&1 && [ -f "$HOME/.bashrc" ]; then
    # shellcheck disable=SC1090
    source "$HOME/.bashrc"
fi
command -v spyglass >/dev/null || { echo "ERROR: spyglass is not in PATH; source the local EDA setup first." >&2; exit 127; }

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
out="$root/build/spyglass_cpu/$mode"
mkdir -p "$out"
find "$root/rtl" -type f -name '*.v' -print | sort > "$out/cpu_profile.f"

cat > "$out/run.tcl" <<EOF
set_option top cpu_axi_debug_profile_top
set_option language_mode mixed
set_option enableSV yes
# This profile intentionally disables legacy hierarchical GPR probes and
# allows SpyGlass to elaborate the synthesizable large SRAM/BRAM models.
set_option define ASIC_DC
set_option mthresh 1048576
set_parameter handle_large_bus yes
EOF

find "$root/rtl" -type d -print | sort | while IFS= read -r incdir; do
    printf 'set_option incdir {%s}\n' "$incdir" >> "$out/run.tcl"
done

# This SpyGlass release does not accept a Verilog file list through
# "read_file -f". Emit one escaped Tcl command per source instead.
while IFS= read -r src; do
    printf 'read_file -type verilog {%s}\n' "$src" >> "$out/run.tcl"
done < "$out/cpu_profile.f"

cat >> "$out/run.tcl" <<EOF
current_goal $goal
run_goal
EOF

if [ "$mode" != 'lint' ]; then
    # CDC/RDC need clock intent; lint intentionally starts without it so SGDC
    # syntax cannot hide parser or RTL-rule findings.
    sed -i "s|^current_goal |read_file -type sgdc {$root/tools/spyglass/cpu_profile.sgdc}\\ncurrent_goal |" "$out/run.tcl"
fi

cd "$out"
spyglass -shell -tcl run.tcl | tee spyglass_${mode}.log
