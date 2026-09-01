#!/usr/bin/env bash
set -euo pipefail

mode="${1:-lint}"
case "$mode" in lint|cdc|rdc|jtag-lint|jtag-cdc|jtag-rdc) ;; *) echo "usage: $0 {lint|cdc|rdc|jtag-lint|jtag-cdc|jtag-rdc}" >&2; exit 2;; esac
case "$mode" in
    lint) goal='lint/lint_rtl' ;;
    cdc)  goal='cdc/cdc_verify_struct' ;;
    rdc)  goal='rdc/rdc_verify_struct' ;;
    jtag-lint) goal='lint/lint_rtl' ;;
    jtag-cdc) goal='cdc/cdc_verify_struct' ;;
    jtag-rdc) goal='rdc/rdc_verify_struct' ;;
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
# Static Lint/CDC/RDC need the complete SoC connectivity but not the 64K-word
# behavioural AXI memory contents.  Swap only that simulation model for a
# port-compatible static stub so structural checks finish reliably.  Runtime
# simulation continues to use the production memory model.
if [ "$mode" = 'jtag-lint' ] || [ "$mode" = 'jtag-cdc' ] || [ "$mode" = 'jtag-rdc' ]; then
    cat > "$out/cpu_profile.f" <<EOF
$root/rtl/utils/jtag_cdc_reset_sync.v
$root/rtl/utils/full_handshake_tx.v
$root/rtl/utils/full_handshake_rx.v
$root/rtl/debug/jtag_driver.v
$root/rtl/debug/jtag_dm.v
$root/rtl/debug/jtag_top.v
$root/verify/static/jtag_dmi_static_top.v
EOF
elif [ "$mode" = 'lint' ] || [ "$mode" = 'cdc' ] || [ "$mode" = 'rdc' ]; then
    find "$root/rtl" -type f -name '*.v' ! -path "$root/rtl/perips/axi4_mem_model.v" -print | sort > "$out/cpu_profile.f"
    printf '%s\n' "$root/tools/spyglass/static_models/axi4_mem_model_stub.v" >> "$out/cpu_profile.f"
else
    find "$root/rtl" -type f -name '*.v' -print | sort > "$out/cpu_profile.f"
fi

if [ "$mode" = 'jtag-lint' ] || [ "$mode" = 'jtag-cdc' ] || [ "$mode" = 'jtag-rdc' ]; then
    top='jtag_dmi_static_top'
else
    top='cpu_axi_debug_profile_top'
fi

cat > "$out/run.tcl" <<EOF
set_option top $top
set_option language_mode mixed
set_option enableSV yes
set_option mthresh 1048576
EOF

if [ "$mode" = 'lint' ]; then
    # W123 needs this rule parameter for the cache/ROM/RAM array accesses.
    # CDC/RDC do not enable W123 and report it as an unused command-line option.
    printf 'set_parameter handle_large_bus yes\n' >> "$out/run.tcl"
fi

if [ "$mode" = 'cdc' ] || [ "$mode" = 'rdc' ]; then
    # Keep the ROM mux evaluation above the default depth threshold so CDC/RDC
    # does not leave a partial-logic-analysis warning for the 4K-word ROM.
    printf 'set_option define_cell_sim_depth 12\n' >> "$out/run.tcl"
fi

if [ "$mode" != 'jtag-lint' ] && [ "$mode" != 'jtag-cdc' ] && [ "$mode" != 'jtag-rdc' ]; then
    # This profile intentionally disables legacy hierarchical GPR probes and
    # allows SpyGlass to elaborate the synthesizable large SRAM/BRAM models.
    printf 'set_option define ASIC_DC\n' >> "$out/run.tcl"
fi

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

if [ "$mode" = 'cdc' ] || [ "$mode" = 'rdc' ]; then
    # CDC/RDC need clock intent; lint intentionally starts without it so SGDC
    # syntax cannot hide parser or RTL-rule findings.
    sed -i "s|^current_goal |read_file -type sgdc {$root/tools/spyglass/cpu_profile.sgdc}\\ncurrent_goal |" "$out/run.tcl"
elif [ "$mode" = 'jtag-cdc' ] || [ "$mode" = 'jtag-rdc' ]; then
    sed -i "s|^current_goal |read_file -type sgdc {$root/tools/spyglass/jtag_dmi_static.sgdc}\\ncurrent_goal |" "$out/run.tcl"
fi

cd "$out"
TERM=dumb spyglass -shell -tcl run.tcl | tee spyglass_${mode}.log
