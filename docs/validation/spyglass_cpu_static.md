# CPU profile SpyGlass 静态检查记录

## 范围

本记录覆盖 `cpu_axi_debug_profile_top` 的 full-SoC static profile。它包含
CPU、Cache、AXI fabric、DMA、APB peripheral 和 raw-JTAG debug 路径；CDC/RDC
以 port-compatible `axi4_mem_model` stub 代替 64K-word 行为级 memory model。
该 stub 仅服务静态结构分析，不用于功能仿真、综合或 FPGA 实现。

## 可复跑命令

```bash
cd /mnt/e/workspace/chip/cpu/lumen-rv32
bash tools/spyglass/run_cpu_static_checks.sh lint
bash tools/spyglass/run_cpu_static_checks.sh cdc
bash tools/spyglass/run_cpu_static_checks.sh rdc
```

三个 goal 必须串行执行。`build/spyglass_cpu/` 内报告为生成物，不进入 Git。

## 2026-09-01 结果

| Goal | 结果 | 结论 |
| --- | --- | --- |
| `lint` | 0 fatal / 0 reported error / 403 warning / 1 local waiver | error-level 已关闭；warning 仍须按规则、模块和设计意图审阅，不能称为 lint clean。 |
| `cdc` | 0 fatal / 0 error / 3 warning | `Unsynchronized clock domain crossings = 0`，`Convergences = 1`。三条 warning 为 JTAG-DMI mailbox convergence 与两条 shared-reset topology review。 |
| `rdc` | 257 `Ar_resetcross01` errors（基线） | 未签收。所有 error 源于 async-assert/sync-deassert 的 raw-JTAG CPU-domain transport 与同步 reset CPU state 的 reset-style mismatch；不是 257 个独立 RTL bug。 |

## 本轮处理

- full-SoC Lint/CDC/RDC 都使用 static memory stub；此前 Lint 会展开行为级 memory model，造成长时间高内存运行。
- Lint 仅对大数组规则启用 `handle_large_bus`；CDC/RDC 不再产生该参数的无效命令 warning。
- CPU profile 中未引出的 I2C open-drain net 使用内部 weak pull-up；未连接 GPIO inout 使用局部、带理由的 `UndrivenInTerm-ML` waiver，避免为静态 profile 增加虚假的强驱动。
- full-SoC RDC 的下一步是完成 reset-style review：明确 CPU-domain transport 是否统一使用 synchronous reset，或建立有设计依据、按层级限制的 `Ar_resetcross01` waiver。禁止将当前结果写成 RDC sign-off。
