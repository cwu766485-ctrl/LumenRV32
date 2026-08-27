# RV32IM CPU UVM 验证起点

该目录是 CPU 核的可运行 UVM 第一层，不替换既有模块级定向 TB。DUT 为
`riscv_cpu_core`；`tb/cpu_core_if.sv` 的 memory BFM 直接驱动 CPU native
instruction/data port。AXI 协议的 ready/valid、ID 与 arbitration 仍由
`tb/axi4_*` 专项 TB 负责。

```text
agent/   transaction、sequence、driver、monitor
common/  event 与 package 组装
env/     scoreboard、coverage、environment
formal/  可供 simulation/formal 共用的 SVA property
sim/     filelist 与仿真配置
tb/      interface、DUT wrapper、top
tests/   UVM test 与 future virtual sequence
```

`cpu_smoke_test` 执行一段受控 RV32I 程序，检查 RAW forwarding、store/load、
taken branch flush、JTAG 读 x3/x4/x5 以及 memory signature；monitor 与
covergroup 采集 fetch/data/redirect/cache-miss 事件。

`pipeline_hazard_test` 是第二个独立的定向用例：程序分别制造 EX/MEM/WB
forwarding、`lw` 后立即使用的 load-use interlock、`JAL` redirect 和 `JALR`
redirect。scoreboard 检查 x1/x2/x3/x5/x7/x8/x9/x11、data-memory signature、至少
一个 `Hold_Load` 以及至少两次 redirect；它不等价于随机指令生成或 coverage closure。

运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run_cpu_uvm_smoke.ps1
powershell -ExecutionPolicy Bypass -File .\tools\run_cpu_uvm_smoke.ps1 -TestName pipeline_hazard_test -Snapshot cpu_uvm_pipeline_hazard
```

Linux VCS：

```bash
bash tools/run_cpu_uvm_smoke.sh
bash tools/run_cpu_uvm_smoke.sh pipeline_hazard_test
```

验收 token 为 `CPU_UVM_SCOREBOARD_PASS` 与 `CPU_UVM_SMOKE_PASS`。本阶段没有
ISS/DPI-C 差分模型、随机指令生成或 coverage closure；后续扩展必须保留该
directed baseline。
