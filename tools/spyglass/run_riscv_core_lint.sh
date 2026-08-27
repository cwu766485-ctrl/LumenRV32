#!/usr/bin/env bash
# CPU-core-only SpyGlass Lint profile. It excludes SoC RAM/ROM models and
# board primitives so simulation storage arrays cannot hide core RTL findings.
set -euo pipefail

if ! command -v spyglass >/dev/null 2>&1 && [ -f "$HOME/.bashrc" ]; then
    # shellcheck disable=SC1090
    source "$HOME/.bashrc"
fi
command -v spyglass >/dev/null || { echo "ERROR: source the local SpyGlass environment first" >&2; exit 127; }

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
out="$root/build/spyglass_riscv_core/lint"
mkdir -p "$out"

find "$root/rtl/core" -maxdepth 1 -type f -name '*.v' -print | sort > "$out/riscv_core.f"
cat > "$out/run.tcl" <<EOF
set_option top riscv_cpu_core
set_option language_mode mixed
set_option enableSV yes
set_option incdir {$root/rtl/core}
# 64 KiB cache arrays are real CPU storage; retain them for this core check.
set_option mthresh 131072
set_parameter handle_large_bus yes
EOF

while IFS= read -r src; do
    printf 'read_file -type verilog {%s}\n' "$src" >> "$out/run.tcl"
done < "$out/riscv_core.f"

cat >> "$out/run.tcl" <<'EOF'
current_goal lint/lint_rtl
run_goal
EOF

cd "$out"
spyglass -shell -tcl run.tcl | tee spyglass_lint.log
