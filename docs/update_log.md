# 项目更新日志

## 2026-08-25 +08:00

### ZU15EG USER2 DMI 板级最终验收

- 以 bitstream SHA-256 `36CC8A3DD3BB3A92664E21D6953BA314D1D1230FA9AFC216F481BA00189C6BAA` 易失下载至 `xczu15` 后，真实板测完成并通过：`DMSTATUS=0x00430C82`（running）→ `DMCONTROL halt=0x80010001` → `DMSTATUS=0x00430382`（halted）→ abstract 只读 `x5=0x00000000` → `DMCONTROL resume=0x40010001` → `DMSTATUS=0x00430C82`（running），host 输出 `USER2_HALT_GPR_READ_RESUME_PASS`。
- host client 发现 XSDB sequence object 边界可能恢复外层 TAP instruction；每笔独立请求前需重新选择 ZynqMP USER2 instruction `0x903`，或将完整验收保持在单一连续 USER2 session。最终 `full` 模式采用后一方式，且提前排入 resume，避免中途响应解析异常使 CPU 停留在 halt。
- 新版 DMI response path 使用一项保持式 response buffer，不再用单周期 `need_resp` 脉冲；`DMSTATUS` 的 all/any halted/running 状态直接反映 live `dm_halt_req`，并已有 USER2 专项仿真断言覆盖。
- 最终实现结果：`xczu15eg-ffvb1156-2-i`、`FPGA_CPU_CLK_DIV=2`（100 MHz），`ZU15EG_CPU_JTAG_USER2_BUILD=PASS`；本轮板测不发送 CPU reset、DMI memory/system-bus write 或 Flash 操作。

### USER2 DMI host-response closeout correction
- Board-side XSDB analysis confirmed that a USER2 `CAPTURE -> UPDATE` NOP scan was being accepted as a new DMI transaction. `jtag_user2_dmi_transport` now treats `op=NOP` as a response-capture-only scan and does not submit it across the TCK/CPU CDC; the USER2 transport TB now asserts that this NOP does not raise a second debug operation.
- The host client returned to the standard request scan followed by NOP response-capture scans. The alternate DRPAUSE-only proposal was discarded after board evidence: re-entering `DRSHIFT` from `DRPAUSE` does not traverse `CAPTURE_DR`, so it cannot sample a newly arrived asynchronous DMI response.
- A subsequent board run exposed the next single-outstanding corner: accepting a new request as soon as its response reaches TCK can overlap the prior response sender's ack-low phase and lose the second response. The transport now keeps `dm_busy` asserted until that response handshake is fully released; the host adds two ignored-NOP settle scans after a matched response, and the TB checks the transport-idle boundary before a back-to-back halt request.
- Board read-after-read evidence showed that the prior release point was still two CPU-domain synchronizer cycles early: `jtag_dm`'s one-entry response `full_handshake_tx` had not yet returned to `tx_idle`. `jtag_dm` now exports this CPU-domain idle state; USER2 synchronizes it into TCK and releases the next DMI request only after the return ACK is low and the sender is idle. The initial "must observe busy then idle" refinement was removed because its synchronized low pulse can be missed and would hold the single-outstanding gate forever.
- Final board read-after-read diagnosis identified the structural root cause: `jtag_dm` emitted a response with a one-cycle `need_resp` pulse, so a second request received while its response sender was still returning to idle could lose its response. Replaced that pulse with a one-entry response buffer holding the tagged address and data until `full_handshake_tx` samples it. USER2 releases the next request after the TCK-side response ACK is low; the buffer preserves the response safely during the CPU-side sender tail.
- Board evidence then confirmed that `DMCONTROL=0x80010001` was accepted while `DMSTATUS` still returned its old running mirror. `DMSTATUS` all/any halted/running bits now derive directly from the live `dm_halt_req`; this compact DM has no distinct hart-halted acknowledgement input. USER2 TB now requires `DMSTATUS=0x00430382` after halt before issuing the abstract GPR read.

### JTAG USER2 transport 收口（RTL/仿真）

- 新增 `BSCANE2` `JTAG_CHAIN=2`（USER2）封装和独立 `jtag_user2_dmi_transport`，可经 ZU15EG 既有配置 JTAG 链路接入 DMI，无需额外 FMC/PMOD 四线 JTAG 引脚。
- transport 仅在同一 USER2 事务出现 `CAPTURE` 后接受 `UPDATE`；无 `CAPTURE` 的 `UPDATE` 不得提交 DMI，避免外层 TAP 指令选择阶段污染 payload。
- 新增 USER2 端到端 TB 和 XSim 启动脚本，实际通过 `JTAG_USER2_TRANSPORT_TB_PASS`：覆盖 capture-less update 拒绝、只读 DMSTATUS、halt、abstract GPR read、resume；测试不发起 reset、DMI memory write 或 Flash 操作。
- 重新执行异步 DMI CDC TB，得到 `JTAG_DMI_CDC_TB_PASS`。
- 新增 ZU15EG USER2 CPU-focused build top/脚本；在 `xczu15eg-ffvb1156-2-i`、`FPGA_CPU_CLK_DIV=2`（100 MHz）完成 post-route 和 bitstream：WNS `+1.711 ns`、TNS `0`、WHS `+0.004 ns`、THS `0`；`20,593` LUT、`16,006` registers、`16` BRAM tiles、`4` DSP。bitstream SHA-256：`670463E784BCEBB18051A025B85D2B506DB910E06D8F0A9BA980D07DCA00FE40`。
- 板级最终验收仍未完成：仓库当前没有 host-side USER2 scan client，USER3 trace 也尚未实现；不得将 RTL/仿真/实现 PASS 写为板测 PASS。
- 板级下载排障发现未配置 `xczu15` 在下载前 `refresh_hw_device` 停滞；下载脚本改为直接设置 `PROGRAM.FILE` 后调用 `program_hw_devices`，配置完成状态由后续只读 probe 确认。
- 新增基于 XSDB raw `jtag sequence` 的 USER2 DMI host client。`dmstatus` 模式仅发起只读 DMSTATUS；`full` 模式限定为 `DMSTATUS → halt → abstract x5 read → resume`，不实现 reset、system-bus/memory write 或 Flash 操作。
- 板测 client 排障确认 `xczu15` 的 USER2 为 ZynqMP 12-bit instruction `0x903`，而不是通用 FPGA USER2 值 `0x003`；依据本机 Vitis `svf.tcl` 的 ZynqMP USER instruction 编码规则修正 host client。此前仅执行的错误 instruction scan 未触发 DMI 控制操作。
- 板测 DMSTATUS 已返回 `0x00430C82`，验证 USER2/DMI transport 可用。首次 halt 尝试确认 host client 在每笔 transaction 前进入 TAP RESET 会复位 `BSCANE2` transport/`jtag_dm`，使后续读取回到默认 running 状态；client 改为仅在会话初始化时 RESET/选择 USER2，后续 DMI 事务保持 USER2，不在操作之间 RESET。

## 2026-08-24 +08:00

### ZU15EG external raw-JTAG profile

- Added `zu15eg_cpu_jtag_raw_top`, which exposes raw TCK/TMS/TDI/TDO through user-selected PL I/O while reusing the hardened DMI CDC. The static-TCK PPA profile remains unchanged.
- Added raw-JTAG build scripts and a 50 MHz asynchronous TCK base constraint. A real FMC/PMOD/GPIO XDC is mandatory; the checked-in example deliberately has no pin assignments.
- No dynamic-TCK bitstream, post-route result, or board acceptance is claimed until an actual connector mapping is supplied. The board USB-JTAG path would require a separate BSCANE3 user-scan adapter.

## 2026-08-23 +08:00

### JTAG DMI CDC hardening

- Marked the existing request and acknowledge two-flop chains in `full_handshake_tx` and `full_handshake_rx` with `ASYNC_REG`; the source data bundle remains stable for the complete four-phase handshake.
- Added independent asynchronous-assert, synchronous-release reset handling for the TCK and CPU domains in `jtag_top`.
- Added `jtag_dmi_cdc_tb.sv` and its XSim launcher. The asynchronous 58.8 MHz TCK / 100 MHz CPU test transfers four 40-bit requests and four responses without loss, duplication, or payload mismatch: `JTAG_DMI_CDC_TB_PASS`.
- Re-ran the public bare-metal `simple` SoC smoke: `TEST_PASS`, 3250 cycles and 2010 instructions.
- This is directed simulation evidence only. No CDC static-tool sign-off, active-TCK FPGA integration, or board validation is claimed.

## 2026-08-23 +08:00

### Fresh ZU15EG CPU-profile implementation

- Rebuilt the CPU + AXI + PMU + JTAG/debug profile for `xczu15eg-ffvb1156-2-i` with `FPGA_CPU_CLK_DIV=2` (100 MHz from the 200 MHz reference clock).
- Post-route timing: WNS `+1.163 ns`, TNS `0`, WHS `+0.012 ns`, THS `0`. Utilization: `19,183` LUT, `15,324` registers, `16` BRAM tiles, and `4` DSPs. Bitstream generation completed successfully.
- Fixed `tools/build_zu15eg_cpu_profile.tcl` to reopen `impl_1` after `wait_on_run` before generating final reports. The first completed implementation was valid, but the old Tcl incorrectly attempted reporting without an open design.
- This is implementation evidence only. No current-commit board execution was performed, and 125 MHz or higher was not attempted because the measured 8.837 ns setup path does not support a 125 MHz period.

## 2026-08-23 +08:00

### English public documentation refresh

- Reworked the public README, architecture/specification, status, resume notes, and JALR timing case study for an external engineering reader.
- Corrected the public AXI description to the implemented single-global-outstanding limitation and retained explicit pre-layout / timing-cone claim boundaries.
- No generated XSim/DC artifacts, PDK files, board files, or external accelerator sources were added.

## 2026-08-23 +08:00

### JALR forwarding 时序闭环

- 将 JALR base operand 从直接 EX forwarding feedback 改为 MEM/WB late forwarding 或寄存器堆，并在 EX ALU → JALR RAW 时插入一个显式 bubble；普通 ALU/branch 的 EX forwarding 不变。
- 新增 `id_jalr_forwarding_tb.sv` 与 `jalr_forwarding` bare-metal SoC 用例；本次 XSim 分别得到 `ID_JALR_FORWARDING_TB_PASS`、`TEST_PASS`（675 cycles / 161 instructions）和 `simple` smoke `TEST_PASS`（3250 cycles / 2010 instructions）。
- 使用本机授权 28 nm SS setup standard-cell library、同一 5.000 ns 约束，对改动前/后 `jalr_timing_cone_top` 完成 DC A/B：改动前 EX→ID/EX 路径 80 logic levels、4.90 ns、+0.00 ns slack；改动后直接路径被移除，MEM/WB late-value→ID/EX 路径为 0.09 ns、+4.77 ns slack。该数字仅代表定向 timing cone，不代表完整 CPU PPA/Fmax，且本次没有有效 min library 的 hold 结论。
- 修正 DC 脚本在未启用 SRAM profile 时把空 SRAM library 加入 `link_library` 的问题；新增 timing-cone 的可复现报告入口。
- 同步修正文档中历史遗留的 AXI multi-outstanding/OoO 表述：当前公开实现为单个全局 outstanding transaction。

## 2026-08-22 +08:00

### 公开版收敛与隐私清理

- 删除外部参考加速器的 RTL、wrapper、软件用例、专项 TB、工具与模块文档；`reference_project/` 保持本地忽略，不进入 Git。
- 新鲜验证：`run_axi4_control_island_tb.ps1` 通过；`run_sw_example.ps1 -ExampleName simple -Snapshot public_cpu_dma_smoke` 通过（`TEST_PASS`）。
- 公开 SoC 固定为 CPU/DMA 版，保留一个 quiescent reserved accelerator slot 以维持既有 control-island/crossbar 集成边界。
- 删除脚本中硬编码的本机 Python 用户目录，将 DC 文档绝对路径改为 `<repository root>` 占位符。
- 清除项目模板中的工具供应商名称；Apache-2.0 上游文件的版权头、`LICENSE` 与 `NOTICE` 仍保留。
- 本次仅完成公开源树收敛；新的 CPU/DMA SoC XSim、FPGA 和板测验收须在当前 commit 重新执行。
