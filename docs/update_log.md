# 项目更新日志

## 2026-08-28 +08:00

### 28 nm DC 全核基线与 CoreMark 板级验收入口
- 在真实 28 nm standard-cell max/min library、`riscv_cpu_core`、5.000 ns 时钟和 pre-layout 约束下完成 DC 全核综合；QoR 为 setup/hold `WNS=0.00 ns`、`TNS=0.00 ns`、无 timing violation。最差 setup path 为 `u_id_ex/reg2_rdata_reg[0]` 到 `u_id_ex/reg2_rdata_reg[31]`，81 logic levels、4.87 ns，说明 200 MHz 仅刚好收敛且后续优化应集中在 ID/EX operand-selection cone。
- 本轮 `Macro Count=0`，I/D Cache 仍以行为数组综合；`467031.597320` 为 standard-cell library area units，不能当作最终含 SRAM macro 的芯片面积或 physical sign-off PPA。下一步应以匹配 PVT 的 SRAM macro wrapper 重跑同一约束，再比较面积和时序。
- 新增 `build_zu15eg_coremark.ps1`、`capture_zu15eg_coremark.ps1` 与 `docs/validation/coremark_board.md`：固定 50 MHz CPU、2000 iterations、32 KiB ROM，禁止 `SIMULATION_FAST_EXIT`，以 UART CRC/10 秒条件和 `CoreMark 1.0` 输出验收并计算 CoreMark/MHz。release bitstream 已完成 post-route（WNS `+8.941 ns`、TNS `0`、WHS `+0.005 ns`、THS `0`，22,667 LUT / 16,615 registers / 16 BRAM / 4 DSP，DRC 0 errors），但本机 JTAG 尚无 target，未烧写和验收；当前没有正式可声明的 CoreMark/MHz 数字。
- 板卡随后重新枚举为 `xczu15_0`，经 USB-JTAG 易失烧写同一 release image；FTDI `COM10` 收到 CoreMark UART 原文，包含 `Correct operation validated.`、17 秒、2000 iterations 与 `Iterations/Sec=117`。固定 50 MHz 下的板级结果为 `2.34 CoreMark/MHz`。采集脚本同时兼容 `CoreMark 1.0` 和此 port 使用的 `Iterations/Sec` 输出格式；本结果为 CoreMark performance run，不是 EEMBC certified score。
- 更新 `docs/RESUME.md`：简历表述仅保留五级 RV32IM RTL、Cache-to-AXI 数据路径、定向 UVM 验证基础、USER2 JTAG/DMI CDC 板测与 28 nm pre-layout DC/STA 的可追溯证据。明确区分上述可复现板测与历史 `SIMULATION_FAST_EXIT` 短窗口估算值；历史 `3.1906` 不作为当前性能声明。当前 full-core DC 尚未绑定匹配 PVT/端口语义的 SRAM macro，因此不得宣称 cache-inclusive ASIC PPA 或后端 sign-off。

## 2026-08-27 +08:00

### Pipeline hazard UVM 定向回归
- 新增 `pipeline_hazard_test`，在独立受控程序中覆盖 EX/MEM/WB forwarding、load-use interlock、JAL/JALR redirect；scoreboard 检查 x1/x2/x3/x5/x7/x8/x9/x11、data-memory signature、`Hold_Load` 和 redirect 事件。
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_cpu_uvm_smoke.ps1 -TestName pipeline_hazard_test -Snapshot cpu_uvm_pipeline_hazard` 新鲜 PASS：`CPU_UVM_PIPELINE_HAZARD_SCOREBOARD_PASS hold_load=2 redirect=92 data=12` 与 `CPU_UVM_PIPELINE_HAZARD_PASS`，UVM `0 error / 0 fatal`。
- `bash tools/run_cpu_uvm_smoke.sh pipeline_hazard_test` 在 Rocky-8.10 / VCS V-2023.12-SP1 新鲜 PASS，得到相同 scoreboard token 和 UVM `0 error / 0 fatal`。
- XSim 2024.1 不接受带 `=` 的 `--testplusarg` value form，因此 testbench 使用布尔 `PIPELINE_HAZARD` harness plusarg 选择此用例；VCS 同样使用该布尔 plusarg，以保持两端运行语义一致。

### 简历项目表述收口
- 更新 `docs/RESUME.md`，将公开、可复核的 CPU RTL、cache-to-AXI 集成、UVM 定向验证、USER2 DMI 板测、28 nm DC timing-cone 和 ZU15EG post-route 证据拆分为独立 bullet；明确不将定向验证、timing cone、custom DMI 或 FPGA profile 扩大表述为 sign-off、完整 Debug Spec、完整 SoC DDR4 或 OoO AXI 能力。
- 简历 FPGA 数字统一到最终 USER2 closeout image 的 routed report：100 MHz、WNS `+1.527 ns`、TNS `0`、WHS `+0.015 ns`、`20,587` CLB LUT、`16,006` registers、`16` BRAM tiles 与 `4` DSP；不再混用较早 CPU-only profile 的资源数字或未归档的中间 WNS。

### UVM 目录分层与 Linux VCS 入口
- 新增 `docs/validation/test_matrix.md` 作为唯一测试索引，区分 `FRESH PASS`、`RECORDED PASS`、`BLOCKED` 与 `NOT_RUN`；后续每轮只从“当前只推进的下一项”取一个小任务，避免并行扩展造成状态混乱。
- 将 `verify/uvm_cpu/` 重构为 `agent/`、`common/`、`env/`、`formal/`、`sim/`、`tb/` 和 `tests/`；第一层只保留 `cpu_smoke_test`，后续将把 hazard、cache backpressure、JTAG halt/resume 和 interrupt 分别实现为独立 test。
- 新增 `formal/cpu_core_properties.sv`，包含 x0 读零与 native instruction/data request 在 backpressure 期间稳定的 SVA。属性已随 XSim smoke 执行；尚未运行 formal proof，因此 formal 状态为 `NOT_RUN`。
- 重构后重新运行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_cpu_uvm_smoke.ps1 -Snapshot cpu_core_uvm_layers`：`CPU_UVM_SCOREBOARD_PASS fetch=24 data=13 redirect=62 ic_miss=2 dc_load_miss=1 dc_store_miss=1`、`CPU_UVM_SMOKE_PASS`，UVM 为 `0 error / 0 fatal`。
- 新增 `tools/run_cpu_uvm_smoke.sh`，使用 Linux VCS 的 UVM-1.2 package 显式编译与 DPI 链接流程；在 Rocky-8.10 + VCS `V-2023.12-SP1` 中完成新鲜 PASS：`CPU_UVM_SCOREBOARD_PASS`、`CPU_UVM_SMOKE_PASS`、`CPU_UVM_VCS_SMOKE_PASS`，UVM 为 `0 error / 0 fatal`。脚本的输出目录 `build/uvm_cpu_vcs.*` 和 VCS `AN.DB/` 已忽略。

### RV32IM CPU UVM 第一层

- 新增 `verify/uvm_cpu/`：以 `riscv_cpu_core` 为 DUT，定义 native instruction/data memory BFM、sequence/driver、monitor、scoreboard 与功能覆盖。
- `cpu_smoke_test` 执行 forwarding、store/load、taken branch/flush 程序，通过 JTAG 组合读端口检查 x3/x4/x5 和 data-memory signature；运行入口为 `tools/run_cpu_uvm_smoke.ps1`。
- 使用 Vivado 2024.1 XSim 内置 UVM-1.2 完成新鲜运行：`CPU_UVM_SCOREBOARD_PASS fetch=24 data=13 redirect=62 ic_miss=2 dc_load_miss=1 dc_store_miss=1`、`CPU_UVM_SMOKE_PASS`，UVM summary 为 `0 error / 0 fatal`。该入口已加入 CPU interview regression 的串行首项。
- 本阶段不宣称随机 instruction generation、ISS/DPI-C differential verification 或 coverage closure；既有 JALR、branch、D-Cache 和 AXI 专项 TB 继续保留并由 CPU interview regression 串行调用。

## 2026-08-26 +08:00

### CPU 面试边界 DV 入口与静态检查准备

- 新增 `docs/validation/cpu_dv_plan.md`：以 JTAG/DMI CDC、USER2 transport、JALR forwarding、branch predictor、D-Cache store path 和 CPU AXI RAM path 作为可解释的 CPU DV 最小范围；明确 coverage plan、回归规则和未完成边界。
- 新增 `tools/run_cpu_interview_regression.ps1`，以串行方式调用上述专项 TB，避免共享 XSim 工作目录并发污染。本轮新鲜运行已观察到 `JTAG_DMI_CDC_TB_PASS`、`JTAG_USER2_TRANSPORT_TB_PASS`、`ID_JALR_FORWARDING_TB_PASS`、`BRANCH_PREDICTOR_TB_PASS`、`DCACHE_STORE_PATH_TB_PASS` 与 `AXI4_CPU_RAM_PATH_PASS`。
- 新增 `tools/spyglass/` 的 CPU-profile 静态检查入口与 CPU/JTAG 时钟意图。Rocky-8.10 当前 shell 未加载 `spyglass`，所以 CDC/RDC/Lint 尚未运行；不得标记为 sign-off PASS。
- `run_isa_regression.ps1` 仍被 RISC-V GCC 与 `tests/isa/generated` 工件缺失阻塞，明确记为 `BLOCKED`。

### SpyGlass Lint 首轮执行与 JTAG 声明修复

- 在 Rocky-8.10 的交互 shell 中确认 `SpyGlass V-2023.12-SP1` 可用；此前非交互 shell 不读取 `~/.bashrc`，因此错误地表现为 `spyglass` 不在 `PATH`。
- 新增 CPU-profile SpyGlass source/include 生成、SystemVerilog 解析和 `lint/lint_rtl` 目标适配。首轮完整 Lint 已执行，不是 sign-off PASS：`22 errors / 400 warnings`。
- Lint 发现 `jtag_dm.v` 中 `tx_idle` 依赖 Verilog implicit net；已改为显式 `wire tx_idle`，随后 `JTAG_USER2_TRANSPORT_TB_PASS` 重新通过。
- 当前错误需分类处理：大容量 cache/RAM/memory-model 超出默认 `mthresh`、debug 层次寄存器访问不适合静态综合分析、以及 `s2_req_o` 未驱动提示。不得将这些误写为 CDC/RDC/Lint clean；下一轮先完善工具参数，再逐条审查 RTL 或建立有理由的 waiver。

### RISC-V CPU core SpyGlass Lint baseline

- 新增 `tools/spyglass/run_riscv_core_lint.sh`。该 profile 以 `riscv_cpu_core` 为 top，保留真实 I/D Cache RTL，并排除 SoC RAM/ROM/DDR memory model 与板级 primitive，避免仿真数组和 board IP 干扰 CPU 核 static analysis。
- 使用 SpyGlass `V-2023.12-SP1` 运行 `lint/lint_rtl`：Design Read、Blackbox Resolution、SGDC Checks 和 Policy lint 均为 `0 error`；报告有 `58 warnings / 4 infos`。这是 CPU core 的 Lint baseline，不等价于 warning 全部 waiver 或完整 SoC/CDC/RDC sign-off。

### 公开版 provenance 与 AXI 事实校正

- 复核 Apache-2.0 上游归属：保留 `LICENSE`、`NOTICE` 和继承 RTL 中 Blue Liang/TinyRISCV 的版权头；README 明确上游作者为 attribution，不表示其为本仓库 collaborator 或 endorsement。
- 修正 `NOTICE` 和 `axi4_crossbar.v` 的过时 “ID-aware response routing / Stage B/C” 描述。当前公开实现为单个全局 outstanding transaction，不支持 AXI ID、multi-outstanding 或 OoO response。
- 本轮改动的 `jtag_dm.v` 与 `heterogeneous_soc_top.v` 保留上游版权头并增加 LumenRV32 modifications notice，满足派生源文件对修改声明和归属保留的要求。

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
## 2026-08-30 +08:00

### LumenRV32 面试电子笔记编排

- 新增并编排 `docs/LUMENRV32_NOTEBOOK.md`，作为 Lumen 工作区唯一的项目学习主入口；包含目录、阅读路径、CPU 微架构、memory subsystem、AXI/control plane、PMU、directed UVM、CDC/USER2 DMI、DC/STA/PPA、波形阅读和面试边界。
- 按 Part I--VII 重编为可点击目录，并补入 RV32M 实现取舍、USER2 板测与 raw-JTAG static CDC 覆盖边界、外设/控制平面地图、CoreMark/PPA 的可用证据、面试追问矩阵与开源来源表述。
- 文档对每项验证证据显式标出范围：directed UVM 不等于 coverage closure，custom USER2 DMI 不等于完整 RISC-V Debug Spec，CDC 异步仿真不等于 static CDC/RDC sign-off，28 nm DC 不等于 post-layout ASIC sign-off。

## 2026-08-30 +08:00

### SpyGlass CDC/RDC 约束修正

- 将 `tools/spyglass/cpu_profile.sgdc` 从不兼容的 DC/STA `create_clock`、`set_clock_groups` 写法改为 SpyGlass 原生 `clock`、`sg_clock_group`、`reset` 和 `reset_synchronizer` 约束；明确 `clk` 与 BSCAN USER2 的 `jtag_TCK` 为异步时钟域。
- 删除当前 SpyGlass V-2023.12-SP1 不支持的 `handle_large_bus` 参数；保留既有大内存 elaboration 配置，避免用参数掩盖 RTL 规则问题。
- 历史 CDC 尝试曾通过 SGDC 解析并进入完整 RTL elaboration，但因 reset synchronizer 的层级名不匹配而未完成规则检查；当前已改为默认 raw-JTAG profile 的实际层级。2026-08-31 的单次串行重跑在 SpyGlass 规则启动前因 `checker 2023.12` license 无法连接 `27000@localhost` 中止。因此 CDC/RDC 均未签收，不能标记 clean；待许可证恢复后必须串行重跑 CDC，再跑 RDC 并审阅 report/waiver。验证命令和日志保留在被 Git 忽略的 `build/spyglass_cpu/`。
- 随后 CDC 已完成 534 条规则：`0 fatal / 0 error / 5 warning`，其中 `Ac_unsync01/02=0`，并报告一个 `jtag_dm.resp_pending` handshake convergence 待审阅。RDC 首次在大行为 memory elaboration 阶段耗时过长；将 `mthresh` 降至 1024 的试验虽能快速完成 elaboration，却产生了 8 个 memory/cache blackbox synthesis error，因此已撤回，不能作为 RDC 结果。恢复原 `mthresh=1048576` 后再次运行 RDC，确认 `Ar_resetcross01/Ar_resetcross_matrix01` 因缺少 `rdc_adv_checker` license feature 未执行；RDC 未签收，需 CAD 管理员提供该 feature 后重跑并审阅报告。

### 面试笔记：协议、微架构、验证与时序增补

- 扩充 `docs/LUMENRV32_NOTEBOOK.md`：明确 I/D Cache → native-to-AXI4 → AXI4 fabric → memory/control-island 的真实协议边界，区分 AXI4-Lite 专用寄存器窗口与 AXI4-to-APB 低速外设路径，并说明同源 `pclk` 分频不是天然异步 CDC。
- 增补 async-assert/sync-deassert reset synchronizer 的 RTL、静态 CDC/RDC 证据边界、EX-to-JALR hazard 条件和逐周期 interlock/late-forwarding 过程，以及 directed UVM 的刺激、检查与未覆盖边界。

## 2026-08-31 +08:00

### SpyGlass CDC raw-JTAG profile hierarchy correction

- The default `cpu_axi_debug_profile_top` elaboration uses `USE_BSCAN_USER2=0`; its active reset synchronizers are `u_soc/u_jtag_top/u_tck_reset_sync/srst_n` and `u_soc/u_jtag_top/u_cpu_reset_sync/srst_n`. Replaced unsupported wildcard names in `cpu_profile.sgdc` with these concrete hierarchy terminals.
- Kept USER2/BSCANE2 explicitly out of this raw-JTAG profile. A future USER2 static CDC run must elaborate `fpga/zu15eg_cpu_jtag_user2_top.v` (or an equivalent wrapper) with `USE_BSCAN_USER2=1` and use its separate transport hierarchy; this run must not be described as USER2 static CDC coverage.

### SpyGlass JTAG-DMI focused CDC/RDC cleanup

- Added `verify/static/jtag_dmi_static_top.v`, `tools/spyglass/jtag_dmi_static.sgdc`, and `jtag-cdc` / `jtag-rdc` runner modes. These focused goals elaborate the real raw-JTAG DMI transport but tie off CPU debug targets; they are a rapid transport-level structural check, not full-SoC or USER2 static sign-off.
- Added a CDC/RDC-only, port-compatible `axi4_mem_model` stub to the full-SoC runner. The functional 64K-word model remains unchanged for simulation and implementation; the stub only avoids unnecessary behavioural-memory elaboration during structural static checks.
- Fixed six focused RDC `Ar_resetcross01` violations by adding asynchronous reset behavior to `jtag_driver` shift register, instruction register, and TDO register. Fresh focused RDC: `0 fatal / 0 error / 0 warning`; fresh focused CDC: `0 fatal / 0 error / 3 warning`, `Unsynchronized clock domain crossings = 0`.
- The three focused CDC warnings (`resp_pending` synchronizer convergence and two shared-reset topology messages) remain unwaived pending protocol/reset review. Full-SoC CDC/RDC and USER2/BSCANE2 static coverage remain open; do not claim static sign-off.

- Refactored the raw JTAG TAP and four-phase handshake FSMs into explicit
  next-state decode plus sequential state registers, removed unused DMI
  response-data state, and made the SoC JTAG debug outputs reset-safe. Fresh focused
  `jtag-lint`: `0 fatal / 0 error / 0 warning`; `jtag-cdc` remains
  `0 fatal / 0 error / 3 reviewed warning`; `jtag-rdc` remains
  `0 fatal / 0 error / 0 warning`. The asynchronous CDC directed testbench
  passed as `JTAG_DMI_CDC_TB_PASS`.

### SpyGlass full-SoC 静态检查收敛（2026-09-01）

- full-SoC `lint`、`cdc` 与 `rdc` 统一改用 port-compatible static
  `axi4_mem_model` stub；功能仿真、综合和 FPGA implementation 继续使用原
  behavioural model。Lint 仅为 W123 启用 `handle_large_bus`，CDC/RDC 不再
  报该参数无效。
- CPU profile 修复内部 I2C open-drain idle pull-up；未引出的 GPIO inout 保留
  为 profile-only 局部 waiver。新鲜 full Lint 为 0 fatal / 0 reported error /
  403 warning / 1 local waiver；full CDC 为 0 fatal / 0 error / 3 reviewed
  warning，`Unsynchronized clock domain crossings = 0`。
- full RDC 已实际运行并 checkout `Advanced_RDC`，但基线仍有 257 条
  `Ar_resetcross01`，均为 raw-JTAG CPU-domain transport 的 async-reset state
  到同步-reset CPU architectural state 的 reset-style mismatch。RDC 未签收；
  后续必须完成统一 reset-style 设计或受控 waiver 审阅，不能写为 clean。

### 面试笔记 UTF-8 恢复（2026-09-01）

- `docs/LUMENRV32_NOTEBOOK.md` 曾被错误按 GBK 读取后再以 UTF-8 保存，导致
  中文出现 mojibake。已从 VS Code local history 恢复最新正常 UTF-8 版本，并
  验证无 replacement character、无 BOM 且 `git diff --check` 通过。

### SpyGlass full-SoC Lint memory abstraction

- Full-SoC `lint` now uses the same port-compatible `axi4_mem_model` static
  stub already used by `cdc` and `rdc`. This avoids elaborating the 64K-word
  behavioural memory model during structural analysis; functional simulation
  and implementation continue to use the production model.
- Replaced a long-running pre-fix full-Lint invocation rather than treating its
  partial output as a result. Full-SoC Lint/CDC/RDC must be run serially after
  this change, and each final report must be reviewed before any clean claim.
