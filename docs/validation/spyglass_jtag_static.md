# SpyGlass JTAG-DMI 静态检查记录

## 目的与范围

`jtag_dmi_static_top` 是用于 SpyGlass 的结构分析 top，不是 FPGA 或功能仿真 top。它实例化真实的 `jtag_top`、`jtag_driver`、`jtag_dm`、`full_handshake_tx/rx` 和 `jtag_cdc_reset_sync`，并将 CPU 寄存器和 memory debug target 绑为常量。

该 profile 的目的，是快速检查 raw-JTAG DMI transport 中 `jtag_TCK` 与 `clk` 的双向 four-phase handshake、2FF synchronizer 和 reset-release 结构。它不覆盖：

- `USE_BSCAN_USER2=1` 的 BSCANE2/USER2 hierarchy；
- CPU、cache、AXI fabric、DMA 和外设的 full-SoC CDC/RDC；
- 功能协议正确性、板级验收或 ASIC sign-off。

full-SoC `cdc`/`rdc` 仍保留为独立、较慢的 profile；其中行为级 `axi4_mem_model` 在 CDC/RDC 中被 port-compatible static stub 替换，避免 64K-word simulation memory 拖慢结构检查。该 stub 不参与仿真、综合或 FPGA/ASIC implementation。

## 可复跑命令

在已经加载 SpyGlass 环境的 Rocky/WSL shell 中执行：

```bash
cd /mnt/e/workspace/chip/cpu/lumen-rv32
bash tools/spyglass/run_cpu_static_checks.sh jtag-cdc
bash tools/spyglass/run_cpu_static_checks.sh jtag-rdc
bash tools/spyglass/run_cpu_static_checks.sh jtag-lint
```

报告位于 `build/spyglass_cpu/jtag-cdc/` 和 `build/spyglass_cpu/jtag-rdc/`；`build/` 已被 Git ignore。

## 2026-08-31 结果

| Goal | 结果 | 说明 |
| --- | --- | --- |
| `jtag-rdc` | 0 fatal / 0 error / 0 warning | 修复 `jtag_driver` 中 `shift_reg`、`ir_reg`、`jtag_TDO` 缺少 reset 分支后获得。`Ar_resetcross_matrix01` 报告 0 reset-domain crossings。 |
| `jtag-cdc` | 0 fatal / 0 error / 3 warning | `Unsynchronized clock domain crossings = 0`；两条 2FF req/ack 同步链和 40-bit stable-bundle/enable-based transfer 被工具识别。 |
| `jtag-lint` | 0 fatal / 0 error / 0 warning | focused raw-JTAG transport lint；无 waiver。 |

CDC 的 3 条 warning 不能直接忽略：

1. `Ac_conv01`：`jtag_dm.resp_pending` 同时受 request receive 与 response acknowledge 两条同步链影响。设计通过 one-entry mailbox 和四相协议限制 single outstanding transaction；需要配合专项 TB/SVA 审阅后再决定是否写 waiver。
2. 两条 `Reset_sync04`：同一异步 reset 被 TCK/CPU 域中的 request 与 acknowledge synchronizer 使用。它们属于 shared reset topology 提示；`jtag_cdc_reset_sync` 已实现 async assert、各域两拍 sync deassert。仍需在 full-SoC reset architecture 中复核，不能将 focused 结果写成全芯片 RDC sign-off。

## 本轮 RTL 修复

`rtl/debug/jtag_driver.v` 的 `shift_reg`、`ir_reg` 和 `jtag_TDO` 先前没有 reset 分支，却依赖带 reset 的 TAP state/response 寄存器。现已为它们加入 `rst_n` 的 asynchronous assertion，并分别设为已定义的 idle 值（shift register=0、IR=`REG_IDCODE`、TDO=0）。这消除了 focused RDC 的 6 条 `Ar_resetcross01`，不改变正常 TAP capture/shift/update 行为。
