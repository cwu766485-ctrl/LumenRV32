#!/usr/bin/env bash
# Run the portable CPU + AXI + PMU + JTAG/debug profile through local DC.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
: "${ASIC28_MAX_LIB:?Set ASIC28_MAX_LIB to the local worst setup-corner .db}"

export ASIC28_TOP=cpu_axi_debug_profile_top
export ASIC28_CPU_AXI_DEBUG_PROFILE=1
export ASIC28_OUT_DIR="${ASIC28_OUT_DIR:-$repo_root/build/asic28_cpu_axi_debug}"
exec "$repo_root/tools/asic/run_dc_cpu.sh"
