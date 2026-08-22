# RV32IM CPU

## 职责

单发射五级流水 RV32IM CPU，提供取指、执行、CSR/异常和中断入口。CPU通过
native-to-AXI master adapter 访问指令与数据系统，不直接连接 APB。

## RTL

- 核心：`rtl/core/riscv_cpu_core.v`
- 流水级：`ifetch.v`、`id.v`、`ex.v`、`mem.v`、`*_id/ex/mem/wb.v`
- 控制/寄存器：`ctrl.v`、`csr_reg.v`、`regs.v`、`clint.v`、`div.v`

## 验证

- ISA、软件用例和 CoreMark 入口：`tools/run_sw_example.ps1`。
- 当前性能证据与边界：[`../project_coremark.md`](../project_coremark.md)。
- 微架构验证：[`../validation/cpu_microarch_validation.md`](../validation/cpu_microarch_validation.md)。

## 已知边界

- 当前为顺序单核；多核、硬件 cache coherence 和乱序执行不在范围内。
