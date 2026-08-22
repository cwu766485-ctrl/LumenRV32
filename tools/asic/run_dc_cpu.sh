#!/usr/bin/env bash
# Run a local 28 nm DC baseline without recording PDK locations in Git.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
: "${ASIC28_MAX_LIB:?Set ASIC28_MAX_LIB to the local worst setup-corner .db}"

export REPO_ROOT="$repo_root"
export ASIC28_OUT_DIR="${ASIC28_OUT_DIR:-$repo_root/build/asic28_cpu}"
export ASIC28_CLK_NS="${ASIC28_CLK_NS:-5.000}"
export ASIC28_IO_DELAY_NS="${ASIC28_IO_DELAY_NS:-0.200}"
export ASIC28_CLK_UNCERTAINTY_NS="${ASIC28_CLK_UNCERTAINTY_NS:-0.100}"
export ASIC28_CLK_TRANSITION_NS="${ASIC28_CLK_TRANSITION_NS:-0.050}"
export ASIC28_MAX_CORES="${ASIC28_MAX_CORES:-4}"

dc_bin="${DC_BIN:-dc_shell}"
command -v "$dc_bin" >/dev/null 2>&1 || {
    echo "dc_shell is not available; source the local Synopsys environment first." >&2
    exit 127
}

mkdir -p "$ASIC28_OUT_DIR"
"$dc_bin" -f "$repo_root/tools/asic/dc_cpu_synth.tcl" \
    | tee "$ASIC28_OUT_DIR/dc_shell.stdout.log"
