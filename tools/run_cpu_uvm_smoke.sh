#!/usr/bin/env bash
# Run the smallest reusable CPU UVM test on Linux VCS.
# No generated output is written outside build/, which is ignored by Git.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
vcs_home="${VCS_HOME:-/opt/Synopsys/vcs/V-2023.12-SP1}"
test_name="${1:-cpu_smoke_test}"

case "$test_name" in
    cpu_smoke_test)
        pass_tokens=(CPU_UVM_SCOREBOARD_PASS CPU_UVM_SMOKE_PASS)
        ;;
    pipeline_hazard_test)
        pass_tokens=(CPU_UVM_PIPELINE_HAZARD_SCOREBOARD_PASS CPU_UVM_PIPELINE_HAZARD_PASS)
        ;;
    *)
        echo "ERROR: unsupported UVM test: $test_name" >&2
        exit 2
        ;;
esac

if [[ ! -x "$vcs_home/bin/vlogan" || ! -x "$vcs_home/bin/vcs" ]]; then
    echo "ERROR: VCS_HOME is not usable: $vcs_home" >&2
    echo "Set VCS_HOME to the VCS installation root, then rerun this script." >&2
    exit 2
fi

export VCS_HOME="$vcs_home"
export PATH="$VCS_HOME/bin:$PATH"

out="$(mktemp -d "$root/build/uvm_cpu_vcs.XXXXXX")"
core="$root/rtl/core"
uvm="$root/verify/uvm_cpu"

core_sources=(
    defines.v cache_ram_1r1w.v branch_predictor.v clint.v csr_reg.v ctrl.v
    div.v ex.v ex_mem.v dcache.v icache.v id.v id_ex.v ifetch.v if_id.v mem.v
    mem_wb.v pc_reg.v regs.v riscv_cpu_core.v
)

sources=()
for source in "${core_sources[@]}"; do
    sources+=("$core/$source")
done
sources+=(
    "$uvm/tb/cpu_core_if.sv"
    "$uvm/common/cpu_core_uvm_pkg.sv"
    "$uvm/formal/cpu_core_properties.sv"
    "$uvm/tb/cpu_core_uvm_tb.sv"
)

include_opts=(
    "+incdir+$core"
    "+incdir+$uvm/common"
    "+incdir+$uvm/agent"
    "+incdir+$uvm/env"
    "+incdir+$uvm/tests"
    "+incdir+$uvm/tb"
)

echo "[CPU UVM] build directory: $out"
uvm_src="$VCS_HOME/etc/uvm-1.2"
(
    cd "$out"
    vlogan -full64 -sverilog "+incdir+$uvm_src" -l "$out/vlogan.log" "$uvm_src/uvm_pkg.sv"
    vlogan -full64 -sverilog "+incdir+$uvm_src" "${include_opts[@]}" -l "$out/vlogan.log" "${sources[@]}"
    vcs -full64 -sverilog -ntb_opts uvm-1.2 cpu_core_uvm_tb -o "$out/simv" -l "$out/vcs.log"
    if [[ "$test_name" == "pipeline_hazard_test" ]]; then
        "$out/simv" +PIPELINE_HAZARD -l "$out/simv.log"
    else
        "$out/simv" -l "$out/simv.log"
    fi
)

for token in "${pass_tokens[@]}"; do
    if ! grep -q "$token" "$out/simv.log"; then
        echo "ERROR: CPU UVM test '$test_name' did not emit '$token'. Log: $out/simv.log" >&2
        exit 1
    fi
done
if grep -Eqi 'assertion.*failed|UVM_(ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9]' "$out/simv.log"; then
    echo "ERROR: CPU UVM test '$test_name' reported an assertion/UVM error. Log: $out/simv.log" >&2
    exit 1
fi

if [[ "$test_name" == "cpu_smoke_test" ]]; then
    echo "CPU_UVM_VCS_SMOKE_PASS"
else
    echo "CPU_UVM_VCS_PIPELINE_HAZARD_PASS"
fi
echo "Log: $out/simv.log"
