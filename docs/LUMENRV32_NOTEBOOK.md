# LumenRV32 面试复习笔记

> 目标：让具备数字电路基础的读者，在理解本笔记和对应 RTL 后，能清楚说明项目的设计边界、关键取舍、验证证据与已知限制。
>
> 适用边界：`RV32IM` 单发射五级流水 CPU、I/D Cache、native-to-AXI4 memory path、PMU、ZU15EG USER2 JTAG/DMI。它不是完整乱序 CPU、完整 RISC-V Debug Spec 实现，也不是已完成 CDC/LEC sign-off 的芯片项目。

### Part 0：项目总览

- [0. LumenRV32 CPU：定位、边界和成果](#0-lumenrv32-cpu)
- [1. 结构边界与 RTL 文件地图](#1-结构边界与文件地图)

### Part I：CPU 微架构

- [2. 五级流水：IF/ID/EX/MEM/WB](#2-五级流水不是五个-cpu而是五条指令重叠执行)
- [3. RV32IM 指令与软件执行过程](#3-指令软件究竟让硬件做什么)
- [4. Register、Cache、RAM/DDR](#4-registercacheramddr容量越大离-alu-越远)
- [5. Instruction Fetch、I-Cache 与 FENCE.I](#5-fetchi-cacheburst-和-fencei)
- [6. Data/Control Hazard：forwarding、interlock、flush](#6-hazardipc-为什么不总是-1)
- [7. Frontend：BTB、BHT 与 prefetch queue](#7-frontendbtbbht-与-prefetch-queue)

### Part II：Memory Subsystem 与 SoC 互连

- [8. D-Cache 与 2-entry store queue](#8-d-cache-与-2-entry-store-queue)
- [9. Native memory interface、AXI4 与 UVM 边界](#9-native-memoryaxi-与-uvm-到底验证什么)
- [17. AXI4 crossbar、AXI4-Lite/APB control island](#17-axi4-crossbar-与-control-plane-边界)

### Part III：Debug、CDC 与性能观测

- [10. CDC 结构选择](#10-cdc不同跨域场景要用不同工具)
- [11. ZU15EG USER2 JTAG/DMI debug](#11-user2-jtagdmi从电脑到-cpu-halt-的链路)
- [18. PMU：从计数器到性能判断](#18-pmu从计数器到性能判断)

### Part IV：Verification

- [19. Directed UVM foundation：agent、driver、monitor、scoreboard](#19-directed-uvm-foundation)
- [20. 现有验证、覆盖和回归边界](#20-验证状态覆盖与回归边界)
- [21. 波形阅读：normal、bubble、stall、flush](#21-波形阅读normalbubblestallflush)

### Part V：Implementation 与 PPA

- [12. DC、STA 与 EX-to-JALR timing case study](#12-时序dcsta-与-ex-to-jalr-优化故事)
- [13. ZU15EG FPGA 结果、PPA 与限制](#13-fpga-结果ppa-和诚实边界)
- [22. 面试时如何表述 PPA 证据](#22-面试时如何表述-ppa-证据)

### Part VI：实战与面试

- [14. 实际运行与波形学习任务](#14-实际运行与波形学习任务)
- [15. 面试常问问题](#15-面试常问问题简洁且准确的回答)
- [16. 十分钟 / 一小时 / 深入复习路线](#16-三个复习阶段)
- [23. 面试表达模板与已知限制](#23-面试表达模板与已知限制)

## 0. LumenRV32 CPU

LumenRV32 是一颗 **RV32IM、单发射、顺序执行、五级流水** 的 CPU。每拍最多进入一条新指令；不同指令同时分别处在 IF/ID/EX/MEM/WB 五个阶段，因此理想情况接近 IPC=1，而不是一拍做完一条指令。当前可复现的 CoreMark 计数窗口给出约 `0.705 IPC`；它是性能诊断证据，不应被误读为理论峰值。

它的主数据路径是：

```text
CPU pipeline
  ├─ IF → prefetch queue → I-Cache → native instruction port
  └─ MEM → D-Cache + 2-entry store queue → native data port
                 ↓
           native-to-AXI4 adapters → AXI4 fabric → BRAM/RAM/DDR 或外设
```

面试中最值得讲的三段闭环：

1. **微架构**：forwarding、load-use interlock、branch redirect/flush、I/D Cache、BTB/2-bit BHT。
2. **可验证性**：在 CPU native-memory 边界建立 SystemVerilog UVM foundation；已跑定向 smoke 和 pipeline-hazard 测试，包含 monitor、scoreboard、coverage、SVA 和回归入口。
3. **工程证据**：ZU15EG 的 USER2 JTAG/DMI 通过板载 USB-JTAG 打通 `DMSTATUS → halt → GPR read → resume`；再用 DC timing report 驱动 EX-to-JALR 的局部时序重构。

一句话版本：

> 我实现并验证了一颗可综合的五级 RV32IM CPU；将 cache/microarchitecture 与 AXI 协议适配解耦；在 FPGA 上完成 USER2 DMI 调试闭环，并用 pre-layout DC timing cone 定位和重构了 JALR 依赖关键路径。

## 1. 结构边界与文件地图

| 层次 | 主要 RTL | 你要能回答的问题 |
|---|---|---|
| Pipeline | `rtl/core/riscv_cpu_core.v`、`ifetch.v`、`id.v`、`ex.v`、`mem.v` | 一条指令如何流经五级？hazard 如何处理？ |
| 流水寄存器/状态 | `if_id.v`、`id_ex.v`、`ex_mem.v`、`mem_wb.v`、`pc_reg.v` | flush、hold、writeback 分别改变什么？ |
| Register file/控制 | `regs.v`、`ctrl.v`、`csr_reg.v`、`clint.v` | x0 为什么恒为 0？interlock 在哪里产生？ |
| Memory hierarchy | `icache.v`、`dcache.v`、`cache_ram_1r1w.v` | miss 怎么填 line？store 为何有 queue？ |
| Frontend | `branch_predictor.v`、`ifetch.v` | BTB/BHT 预测什么？错了如何恢复？ |
| AXI integration | `rtl/interconnect/native_to_axi4_master.v`、`axi4_crossbar.v` | 为什么 core 不直接写 AXI？本项目 AXI 的边界？ |
| Debug | `rtl/debug/jtag_user2_dmi_transport.v`、`jtag_dm.v`、`jtag_bscan2_user2.v` | USER2、DMI、CDC 和板测闭环是什么？ |
| Verification | `verify/uvm_cpu/` | UVM 的 DUT 边界、scoreboard、覆盖范围？ |

## 2. 五级流水：不是五个 CPU，而是五条指令重叠执行

### 2.1 五级含义

| 阶段 | 做什么 | 主要产物 |
|---|---|---|
| IF (Instruction Fetch) | 用 PC 取指、用预测器给下一 PC | instruction、PC、predicted next PC |
| ID (Instruction Decode) | 译码、读寄存器、检测 dependency | opcode 控制信号、`rs1/rs2` 数据、立即数 |
| EX (Execute) | ALU、比较 branch、计算 load/store 地址 | ALU result、branch taken/target、effective address |
| MEM (Memory) | D-Cache 查找、load/store 与后端握手 | load data 或 store 请求完成 |
| WB (Write Back) | 将计算结果或 load 数据写入 GPR | `rd`、write data、reg_write |

例子：

```asm
addi x1, x0, 5
addi x2, x1, 7
add  x3, x1, x2
```

稳定后可以同时发生：`addi x1` 在 WB、`addi x2` 在 MEM、`add x3` 在 EX、下一条在 ID、再下一条在 IF。它们共用硬件，但通过流水寄存器保存各自的 PC、寄存器号、数据和控制信号。

### 2.2 MEM 和 WB 的区别

- **MEM** 是“访问数据存储层级”的阶段。`lw x5, 12(x1)` 在 EX 得到地址，在 MEM 用该地址查 D-Cache；hit 则得到数据，miss 则发出 line-fill 请求并等待。
- **WB** 是“更新架构寄存器状态”的阶段。对 `lw`，WB 把 MEM 返回的数据写给 `x5`；对 `add`，WB 把 ALU 结果写给 `rd`；`sw`、`beq` 通常不写 GPR，因此经过 WB 时 `reg_we=0`。

注意：一条有效 `beq` 经过 MEM/WB 但没有写寄存器或内存，**不是 bubble**。它的数据/控制仍随流水寄存器流动，只是副作用控制全为 0。真正 bubble 是硬件注入的 NOP；stall/hold 则是某些流水寄存器保持前一拍值不更新。

## 3. 指令：软件究竟让硬件做什么

### 3.1 常见 RV32IM 指令

| 类别 | 示例 | 语义 |
|---|---|---|
| 算术 | `add x3,x1,x2` | `x3 = x1 + x2` |
| 立即数 | `addi x1,x0,5` | `x1 = 0 + 5` |
| 逻辑/移位 | `and/or/xor/sll/srl/sra` | 位运算或移位 |
| 比较 | `slt/sltu` | 比较结果写 0/1 |
| load | `lw x5,12(x1)` | `x5 = Memory[x1 + 12]` |
| store | `sw x5,12(x1)` | `Memory[x1 + 12] = x5` |
| 条件分支 | `beq x1,x2,target` | 相等则 PC 跳到 target，否则顺序执行 |
| 跳转 | `jal rd,target` | 跳转，同时把返回 PC 写 `rd` |
| 间接跳转 | `jalr rd,imm(rs1)` | 跳到寄存器计算出的地址；常用于 return/函数指针 |
| 乘除法 | `mul/div/rem` | RV32M 扩展的乘、除、余数 |
| CSR | `csrrw/csrrs/csrrc` | 读改写控制/状态寄存器 |
| FENCE.I | `fence.i` | 让此前对代码区的写入对之后取指可见 |

软件工程师/编译器把 C 程序翻译成上述二进制指令，链接器把它们放进 ROM/DDR 的地址空间。硬件并不理解 C；它只在每拍按 ISA 译码并执行指令。软件决定“做什么、数据放在哪里”，CPU 硬件决定“如何按时序执行、何时命中 cache、何时 stall”。

### 3.2 `lw` 和 `sw` 逐步例子

假设 `x1=0x8000_1000`：

```asm
lw x5, 12(x1)      # 读地址 0x8000_100C 的 32-bit 数据给 x5
sw x5, 16(x1)      # 将 x5 的 32-bit 数据写到 0x8000_1010
```

`lw`：EX 算 `0x8000_100C` → MEM 查 D-Cache → WB 写 `x5`。
`sw`：EX 算地址并携带写数据/byte mask → MEM 更新 D-Cache，并把 write-through 工作交给 store queue 或后端。

## 4. Register、Cache、RAM/DDR：容量越大，离 ALU 越远

| 存储层 | 本质/位置 | 谁显式使用 | 典型作用 |
|---|---|---|---|
| GPR register file | CPU 内核里，`regs.v` | 指令的 `x0..x31` | ALU 输入、结果暂存；RV32 每个 32 bit，共 32×4 B=128 B，`x0` 固定为 0 |
| I/D Cache | CPU 内核附近的硬件缓存 | 硬件自动管理 | 缓存常用 code/data，降低访问后端延迟 |
| BRAM/RAM | FPGA 片上存储或 SoC memory-mapped RAM | 软件通过地址访问 | 程序映像、数据、stack/heap |
| DDR | 板级外部动态内存 | 软件通过地址访问 | 大容量程序/数据 |

寄存器不是“ALU 本身”，而是 ALU 最近的可编程操作数仓库。`add x3,x1,x2` 会从 register file 读 x1/x2，ALU 相加，再最终写回 x3。

当前配置的可核实数字：I-Cache = `8 words/line × 256 lines × 4 B = 8 KiB`；D-Cache = `8 × 128 × 4 B = 4 KiB`。默认仿真 ROM/RAM 各为 4096 words，即各 16 KiB；CoreMark BRAM build 的 ROM 是 8192 words，即 32 KiB。它们不是“会用满就崩”的固定分区：cache 满时按映射/替换规则腾出 line；软件 RAM 真不够时才是 stack overflow、heap failure 或地址非法等软件/系统问题。

## 5. Fetch、I-Cache、burst 和 FENCE.I

### 5.1 IF 的 instruction 从哪里来

```text
PC → prefetch queue / I-Cache lookup
   ├─ hit：立即给 IF 一条 32-bit instruction
   └─ miss：native instruction request → AXI read burst → BRAM/RAM/DDR
                                            ↓
                                      填入完整 cache line
                                            ↓
                                      将所需 word 给 IF
```

I-Cache 不会因为 IF 用过一条指令就清除该指令。该 line 会一直保留，直到 reset、FENCE.I/invalidate，或另一个地址映射到同一 direct-mapped index 时被替换。

本项目实际 line 是 8 个 32-bit word：一次 miss 发出 `ARLEN=7、ARSIZE=2、INCR` 的 AXI read burst，返回 **8 beats × 4 B = 32 B**，不是 `8×32 B`。因此一条 line 可容纳 8 条 32-bit RV32 指令（若全是标准 32-bit 指令）。

### 5.2 FENCE.I

若 bootloader、DMA 或调试器刚把新机器码写到某段可执行地址，DDR/RAM 内容虽然更新了，I-Cache 仍可能有旧 line。`FENCE.I` 让 CPU invalidate I-Cache，之后 IF 必须重新 fetch 新代码。它与 branch 都会影响 frontend，但本质不同：

- **branch result**：EX 比较后得到 `taken/not-taken` 与正确 target PC；若和预测不同，flush 错路径的前端指令，redirect PC。
- **FENCE.I**：不是改变控制流，而是确保“新写入的程序”不会被旧 instruction cache 内容遮住。

## 6. Hazard：IPC 为什么不总是 1

### 6.1 Data hazard 与 forwarding

```asm
add x1, x2, x3
sub x4, x1, x5
```

`sub` 在 ID/EX 需要 x1 时，`add` 可能还没有 WB。若只等 WB，必须停很多拍。`id.v` 的 forwarding compare `rs1/rs2` 与后级 `rd`：当后级确实会写 GPR、`rd != x0` 且寄存器号相同，就以 EX/MEM/WB 的新结果覆盖 register-file 旧读值。`x0` 必须排除，因为它在架构上永远是 0，绝不能被“旁路写成别的数”。

这就是为什么 `add` 的结果能够给紧跟的 `sub` 使用：不是绕过 MEM/WB“消失”，而是在该时刻从可用的后级结果总线上绕送到消费者操作数 MUX；producer 仍按正常流程经过 MEM/WB。

### 6.2 load-use interlock

```asm
lw   x5, 0(x1)
addi x6, x5, 1
```

load 的真实数据到 MEM 末期才得到；紧随的 `addi` 进 EX 时来不及从 EX 转发。因此 control logic 检测到 `load rd == next rs` 后：冻结 PC/IF-ID、对 ID/EX 注入一个 bubble，等 load 数据可被 MEM/WB forwarding 使用，再让 `addi` 前进。这是正确性需要的一拍损失，不是 bug。

### 6.3 Control hazard

branch predictor 提前猜“跳不跳、跳到哪”。EX 才给出 branch result；若猜错，front end 把错误路径的 IF/ID/prefetch 项清为 invalid/NOP，PC 改到正确 target。flush 不会删除程序存储器里的 instruction，只是禁止已经取到的错误路径 instruction 产生写 GPR/store 等副作用。

### 6.4 IPC 的正确理解

IPC = retired instructions / cycles。当前一次可复现 CoreMark 记录约 `318,138 / 451,235 = 0.705 IPC`；板级完整 CoreMark 为 2.34 CoreMark/MHz。这些数字不能由“cache 或 register 满了”直接解释：

- GPR 不会像队列那样“满”；32 个寄存器不足是编译器 register spilling 增多的问题。
- cache 满是正常状态，影响性能的是 **miss、冲突和 refill latency**，不是容量状态本身。
- CoreMark 还会受到 load-use、branch redirect、乘除法、store wait、I/D miss、AXI/BRAM/DDR backpressure 和测试配置影响。

下一步应以 PMU 分类计数定位占比，再决定是否改 branch predictor、cache、store queue 或编译选项；不能只凭 IPC 盲改结构。

## 7. Frontend：BTB、BHT 与 prefetch queue

**控制流指令**指会改变顺序 PC+4 的指令：conditional branch、`jal`、`jalr`、return 等。

- **BTB (Branch Target Buffer)**：小型按 PC 索引的表，存 valid/tag/target；回答“这条 PC 曾跳过吗？target 是哪里？”
- **BHT (Branch History Table)**：存 2-bit 饱和计数器；回答“这次更可能 taken 还是 not taken？”计数器通常从 strong-not-taken、weak-not-taken、weak-taken、strong-taken 逐步移动，偶然一次结果不立刻翻转预测。
- **prefetch queue**：缓冲 I-Cache/后端返回的指令和 ID 消费之间的节奏差，减少 fetch starvation。

本项目 `branch_predictor.v` 是 16-entry direct-mapped BTB + 对应 2-bit BHT。BTB/BHT 不是魔法：命中和预测正确才省掉 redirect；预测错仍必须 flush。

## 8. D-Cache 与 2-entry store queue

store queue 在 [`rtl/core/dcache.v`](../rtl/core/dcache.v) 的 `store_buffer_*` 寄存器里：`store_buffer_addr[0:1]`、`store_buffer_wdata[0:1]`、`store_buffer_wmask[0:1]`、head/tail/count。它是严格有序的 **2-entry write-through store queue**。

作用：cache-hit store 在 D-Cache 中立即反映其架构可见结果，同时将后端 write-through 写请求排队；CPU 不必每次都等外部 memory handshake。queue 满时后续 store 必须 stall；queue 中的 older store 必须按顺序 drain，不能被新的 store 或 MMIO 越过。load 若读到尚未写回后端的地址，D-Cache 有 store-to-load forwarding，保证读到最新值。

是否扩大到 4-entry 不能拍脑袋决定。正确实验是：PMU 观察 `store_buffer_full_stall` 是否真为热点 → 2-entry/4-entry A/B → 比较 IPC/CoreMark、LUT/FF、时序和功能回归。容量变大可能提高持续 store 吞吐，也可能增加比较/MUX/控制，恶化 PPA。

## 9. Native memory、AXI 与 UVM 到底验证什么

Cache/AXI memory subsystem 是什么
它是 CPU 从“执行一条 lw/取一条指令”到“最终访问 BRAM、DDR 或外设”的整套存储访问系统。
```
取指：
PC → prefetch queue → I-Cache → native instruction port
                               → native-to-AXI4 adapter
                               → AXI4 fabric → ROM / BRAM / DDR

读写数据：
EX 算地址 → D-Cache + store queue → native data port
                                      → native-to-AXI4 adapter
                                      → AXI4 fabric → RAM / DDR / MMIO
```

CPU core 将 IF/DCache 请求抽象成 native memory ports：

```text
request: address, read/write, wdata, byte mask, burst length
response: ready, rdata
```

为什么中间还要有 native interface？
- CPU/Cache 只需表达：地址、读写、写数据、byte mask、burst length、ready。
- native_to_axi4_master.v 再负责处理 AXI 的 AR/AW/W/R/B 五个通道握手。
- 这样 CPU 微架构不会和 AXI 协议细节死绑，Cache TB 也不必先拉起完整 DDR/AXI SoC。

当前 UVM DUT boundary 是：

```text
CPU core + I/D Cache  ↔  native memory BFM
                           ↑
                    driver / monitor / scoreboard
```

Directed UVM verification
directed 就是“人手写清楚要测什么场景”，而不是随机生成几万条指令碰运气。
当前 UVM 的 DUT 边界是：
```
CPU pipeline + I-Cache + D-Cache
              ↕ native instruction/data memory ports
       UVM memory driver / monitor / scoreboard
```
所以它不是单纯验证 “I/D Cache → native-to-AXI4 adapter”。更准确地说：
- 当前 CPU UVM 验证 CPU 与 Cache 对 native-memory 的访问语义；
- 不直接驱动/检查 AXI AR/AW/W/R/B 信号；
- AXI adapter/crossbar 应由独立 AXI VIP 或 AXI 专项 TB 验证。
现有 pipeline_hazard_test 已覆盖：
- EX/MEM/WB forwarding；
- lw 后立刻使用结果的 load-use interlock；
- sw → lw 数据正确性；
- native memory backpressure；
- jal 错路径 flush；
- jalr 错路径 flush；
- GPR 最终值、memory signature、hold 次数、redirect 次数。
面试应说“reusable directed UVM foundation”，不要说“已完成 coverage closure 或 ISS differential verification”。

它**确实在验证接口交互**，但不止看接口信号：driver 加载定向 instruction/data memory，并制造 ready/backpressure；monitor 观察 fetch/data request、miss、redirect；scoreboard 检查 GPR、memory signature、load-use hold 和 branch redirect。现有 `pipeline_hazard_test` 具体跑了：EX/MEM/WB forwarding、`lw→addi` interlock、`jal`/`jalr` wrong-path flush、store/load 与 native-memory backpressure。

目前没有完整 ISA reference model/ISS differential test。严谨说法是“UVM directed verification foundation”，不能说“完整 UVM coverage closure”或“RTL-vs-ISS sign-off”。

## 10. CDC：不同跨域场景要用不同工具

CDC 不是“一律两拍同步”。选择取决于数据宽度、吞吐、是否每个 event 都不能丢失。

| 场景 | 常用结构 | 原因 |
|---|---|---|
| 单 bit level（例如 enable） | 2FF synchronizer | 降低亚稳态传播概率 |
| 单 bit pulse/event，允许低吞吐 | toggle 或 req/ack handshake | pulse 可能被目标时钟错过 |
| 少量 multi-bit 命令/响应 | stable bundle + four-phase req/ack | 数据保持稳定到确认，避免逐 bit 同步撕裂 |
| 高吞吐 multi-bit stream | asynchronous FIFO（Gray pointer） | 两端可独立连续读写 |
| async reset deassertion | 各时钟域 async assert / sync deassert reset synchronizer | 避免不同域释放 reset 造成假事件 |

本项目 USER2 DMI 采用第三种：TCK 域保持 40-bit DMI request payload，发起 req；CPU 域看到同步后的 req 后只执行一次，保持 response payload，再返回 ack；双方完成 req high/ack high/req low/ack low 的 four-phase 协议。多 bit 数据没有逐位打两拍，正是为了避免 data tearing。它已有 RTL/异步仿真与板测证据，但尚未完成 SpyGlass CDC/RDC sign-off。

## 11. USER2 JTAG/DMI：从电脑到 CPU halt 的链路

```text
PC / Vivado hardware manager
  → board USB-JTAG cable
  → FPGA internal TAP
  → USER2 instruction (ZynqMP USER2 IR = 0x903)
  → BSCANE2 USER2 adapter
  → custom DMI transport (TCK ↔ cpu_clk CDC)
  → jtag_dm
  → halt / register access / resume
```

`USER2` 是 FPGA 内置 TAP 留给用户逻辑的一条 user-scan instruction；`0x903` 是该器件配置 TAP 选择 USER2 的 12-bit instruction encoding，不是 RISC-V 指令。这样复用板卡 USB-JTAG，不必额外接四根外部 JTAG pin。

板测验收顺序为：

```text
DMSTATUS = 0x00430C82  (running)
halt
DMSTATUS = 0x00430382  (halted)
abstract read x5 = 0x00000000
resume
DMSTATUS = 0x00430C82  (running)
```

这证明 host transport、CDC、debug module 与 CPU halt/resume 状态连接起来了。边界必须主动说明：它是自定义 USER2/DMI 的最小板测闭环，不是完整 RISC-V Debug Specification，也未做 memory/system-bus write/Flash 操作。

## 12. 时序、DC、STA 与 EX-to-JALR 优化故事

### 12.1 DC/STA 是做什么的

- **Design Compiler (DC)**：读 RTL、standard-cell library 和 SDC 约束，将 RTL 综合成门级网表，同时估算 area、功耗相关信息和时序。
- **STA (Static Timing Analysis)**：不跑测试向量，而是枚举 register-to-register、input/output 等时序路径，检查 setup/hold 是否满足。WNS 是最差 setup slack，TNS 是所有负 slack 总和，WHS 是最差 hold slack。
- 当前结果是 **28 nm pre-layout** DC/STA：没有 placement/routing 寄生，因此不是 ASIC sign-off。完整 ASIC sign-off 还需 post-layout parasitics、多 PVT corners、SI/OCV 等。

### 12.2 关键路径怎么改

原始特殊情形是：EX 阶段刚产生一个寄存器结果，下一条 `jalr` 立即把该寄存器作为跳转 base。直接 EX forwarding + JALR redirect 形成很长的组合 feedback cone。

改法：只在 **EX producer → immediate JALR consumer** 的特定 RAW dependency 时插入一拍 interlock，让 JALR 等到 MEM/WB，再从 `reg1_late_data` 使用 MEM/WB late forwarding。这样用寄存器切断了原先组合路径。

代价是该特殊 JALR dependency 多一拍；收益是较易时序收敛。相同 5 ns timing-cone A/B 下，旧 cone 为约 80 levels/4.90 ns；替换后的 registered path 约 0.09 ns，对应局部 setup slack +4.77 ns。**不要说 CPU 全局 Fmax 提升了 4.77 ns**：这是局部 timing-cone 对比，完整 CPU 的 Fmax 必须以完整 post-route/完整 STA report 为准。

## 13. FPGA 结果、PPA 和诚实边界

USER2 CPU profile 在 ZU15EG 100 MHz post-route 的已签收记录：WNS `+1.527 ns`、TNS `0`、WHS `+0.015 ns`，资源约 `20.6K LUT / 16.0K FF / 16 BRAM / 4 DSP`。这说明该 profile 在这个 FPGA 构建/约束下 setup 和 hold 都收敛。

PPA 是 **Performance / Power / Area**：

- Performance：频率、slack、IPC、benchmark；
- Power：切换活动、时钟、存储访问决定，当前没有 sign-off power；
- Area：FPGA 的 LUT/FF/BRAM/DSP，ASIC 的 cell/macro area。

提升 PPA 不是“把所有 buffer 加大”。例如更大 BTB、store queue、cache 会减少部分 stall，却增大 SRAM/FF/MUX/比较器；应以 PMU 找瓶颈后做 A/B，并同时复跑功能和 post-route/DC。

## 14. 实际运行与波形学习任务

现有 `pipeline_hazard_test` 的程序在 `verify/uvm_cpu/tb/cpu_core_if.sv`，包含：

```text
addi x1, x0, 5
addi x2, x1, 7          # forwarding
add  x3, x2, x1
...
sw   x5, 0(x6)
lw   x7, 0(x6)
addi x8, x7, 1          # load-use interlock
jal  x0, +8             # wrong path must flush
...
jalr x0, 0(x10)         # wrong path must flush
```

在 Windows Vivado/XSim 运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_cpu_uvm_smoke.ps1 -TestName pipeline_hazard_test
```

学习波形时优先加入：`clk`、`rst`、PC、IF/ID instruction、ID/EX instruction、`hold_flag`、`jump/flush`、`mem_ex_req_o`、`mem_ex_ready_i`、`mem_pc_req_o`、`mem_pc_ready_i`、`perf_branch_redirect_o`、`perf_dcache_load_miss_stall_o`、`perf_store_buffer_*`、EX/MEM/WB 的 `reg_we/rd/wdata`。

你应能在波形中分辨：

1. **正常 branch 流过 MEM/WB**：数据仍更新，但 `reg_we=0`/`mem_we=0`；
2. **bubble**：被注入的无副作用 NOP 向后流动；
3. **stall**：PC、IF/ID 等寄存器在若干拍保持不变；
4. **flush**：错误路径前端项变 invalid/NOP，PC 改为正确 target。

## 15. 面试常问问题：简洁且准确的回答

**Q：这是 Harvard 还是 von Neumann？**
CPU 内部有独立 I-Cache 和 D-Cache/native ports，因此前端呈 Harvard-like；下游 AXI fabric/DDR 是共享 memory-mapped 空间，所以不是完全物理分离的 Harvard machine。

**Q：AXI 支持 OoO/multi-outstanding 吗？**
当前 SoC crossbar 是单全局 outstanding，不支持 AXI ID、多 outstanding 或跨 ID OoO。AXI4 标准本身支持 ID 和多个 outstanding；AXI4 移除的是 write-data interleaving 的 WID，不是 ID。当前实现是为可验证性和集成范围做的简化。

**Q：为什么 IPC 小于 1？**
单发射五级顺序核的理想 IPC 才是 1。真实 workload 会因 cache miss、load-use、branch redirect、乘除法和总线 backpressure 消耗 cycle。应从 PMU 分项计数判断，而非仅看一个总 IPC。

**Q：UVM 做到什么程度？**
已经是 core native-memory boundary 的 reusable directed UVM foundation，有 sequence/driver/monitor/scoreboard/coverage/SVA 与 XSim/VCS smoke、hazard 回归。尚未做 constrained-random closure、完整 coverage closure、ISS differential 或静态 sign-off。

**Q：CDC 如何保证 40-bit DMI 不撕裂？**
不用逐位 2FF；源端稳定保持 bundle，用 2FF 同步的 req/ack 四相握手传递 ownership，完成前禁止覆盖 payload；reset 在各域同步释放。

## 16. 三个复习阶段

### 面试前 10 分钟

复习第 0、2、6、11、12、15 节；能画 CPU→Cache→AXI→memory 和 PC→BTB/BHT→IF 的两张图。

### 面试前 1 小时

顺着第 1 节文件地图读 `id.v` forwarding、`ctrl.v` interlock/flush、`dcache.v` store queue、`jtag_user2_dmi_transport.v` handshake；亲自跑一次 UVM hazard test。

### 能深入讨论的程度

回答每项时都按“问题 → RTL 机制 → 验证证据 → 代价/边界”四步说。不要把 directed UVM 说成 closure，不把 DC pre-layout 说成 ASIC sign-off，也不把 custom USER2 DMI 说成完整 RISC-V Debug Spec。

## 17. AXI4 crossbar 与 control-plane 边界

CPU 内部的 native port 不是 AXI；它只表达“地址、读/写、数据、byte mask、burst length、ready”。`native_to_axi4_master.v` 负责把这一简洁接口翻译为 AXI4 的五个 channel：

```text
read : native request → AR → R
write: native request → AW + W → B
```

`axi4_crossbar.v` 再将 CPU I-cache、CPU D-cache、DMA 等 master 的请求路由到 ROM、RAM、external memory/DDR 或 AXI control island。低速寄存器访问不应让 CPU 直接面对 APB：它首先经 AXI4-Lite control path，再由 AXI-to-APB bridge 访问 UART、timer、GPIO、SPI、QSPI、I2C、PMU 等。

当前实现的真实性边界：crossbar 采用单全局 outstanding transaction。它足以解释 cache/AXI 数据流和 backpressure，但没有 AXI ID、多 outstanding、read response interleaving 或 cross-ID OoO。面试时可说“AXI4-compatible integration path”，不要说“高并发 commercial AXI fabric”。

## 18. PMU：从计数器到性能判断

PMU 是 memory-mapped 的观察模块，不参与 PC、译码、Cache 或 AXI 的功能决策。它观察 CPU/Cache/总线发出的 perf_* 信号，并维护一批 64-bit counter。

CPU/Cache 把 `perf_*` 信号导出，SoC 把它们接到 APB PMU register bank；软件读取计数器即可得到性能画像。

64-bit counter 例如：

```text
PMU_CYCLE                  → 总周期
PMU_INST                   → WB 阶段的有效 instruction 计数
PMU_ICACHE_MISS            → instruction cache miss
PMU_DCACHE_LOAD_MISS_STALL → load refill 导致的停顿
PMU_BRANCH_REDIRECT        → branch/JAL/JALR 预测或目标恢复
PMU_STORE_BUFFER_FULL_STALL→ store queue 满导致的停顿
PMU_FETCH/DATA_BUS_WAIT    → 下游 ready/backpressure 等待
```
RTL 数据流
```
riscv_cpu_core
  → perf_icache_miss_o / perf_branch_redirect_o / ...
  → soc_top
  → apb_perips
  → pmu
  → APB memory-mapped registers
```
在 CPU 中，perf_inst_o = wb_inst_o，因此 instruction counter 观察 WB 阶段的非 NOP 指令，是一个较接近 retirement 的粗粒度指标。
PMU 内部就是条件计数：
```
if (icache_miss_i)
    icache_miss_counter <= icache_miss_counter + 64'd1;

if (branch_redirect_i)
    branch_redirect_counter <= branch_redirect_counter + 64'd1;
```
软件通过 APB 映射寄存器读取。PMU 在 APB 的选择号是 4，内部偏移如：
```
0x04  cycle
0x0c  instruction
0x54  I-Cache miss
0x5c  D-Cache load miss
0x68  branch redirect
0x84  D-Cache load-miss stall
0x94  store-buffer-full stall
```
阅读性能时按此顺序：先算粗粒度 `IPC = PMU_INST / PMU_CYCLE`，再看 miss、redirect、load-use hold、store wait、bus wait 的占比。若 D-Cache miss 是主因，应优先研究 cache line/refill/布局；若 redirect 是主因，再研究 predictor；若 store-buffer-full 很少，扩大 store queue 没有依据。
tips:
`sw → lw 数据正确性`：store 先更新 D-Cache，并把 write-through 请求放进 store queue；如果后续 lw 读同一地址、而该 store 还没写到后端，D-Cache 会用 store-to-load forwarding 返回最新数据，保证软件看到的顺序正确。

## 19. Directed UVM foundation

### 19.1 为什么叫 directed

本项目不是“随机生成程序，然后期望随机覆盖所有 hazard”。每个 test 都明确放入一段小程序和预期结果。例如 pipeline hazard sequence 中人为安排：

```asm
addi x1, x0, 5
addi x2, x1, 7          # EX forwarding
add  x3, x2, x1
sw   x5, 0(x6)
lw   x7, 0(x6)
addi x8, x7, 1          # load-use interlock
jal  x0, +8             # wrong path flush
jalr x0, 0(x10)         # indirect redirect + flush
```

这类 test 的优点是：一个失败的波形非常容易定位；它适合 CPU 项目第一阶段建立可信证据。缺点是覆盖范围有限，因此不能用它声称 fully-random 或 full-coverage verification。

### 19.2 UVM 组件分工

```text
sequence → 生成测试意图（program kind、backpressure）
sequencer→ 调度 transaction
driver   → 装载 instruction/data memory，施加 reset 与 ready 延迟
monitor  → 观测 fetch/data request、redirect、Cache miss 等事件
scoreboard → 比对最终 GPR、memory signature 与事件次数
coverage → 记录关键 scenario 是否被触发
SVA      → 约束 native request/response 等不可违反性质
```

当前 DUT boundary 是 **CPU core + I/D Cache ↔ native-memory BFM**。因此 UVM 同时验证了 Cache 的请求、burst、miss/backpressure 下的 CPU 语义，但不直接验证 AXI AR/AW/W/R/B 信号；adapter/crossbar 的 AXI 协议应由独立 AXI VIP/sanity TB 覆盖。

主要位置：`verify/uvm_cpu/agent/`、`env/`、`formal/`、`tb/`、`tests/`。

## 20. 验证状态、覆盖与回归边界

已建立并跑通的验证证据应这样理解：

| 范围 | 当前证据 | 不能推导出的结论 |
|---|---|---|
| CPU UVM smoke | XSim/VCS 定向 smoke，scoreboard PASS | 不是全 ISA 随机验证 |
| Pipeline hazard | forwarding、load-use、JAL/JALR redirect、native backpressure | 不是全组合 hazard coverage closure |
| JTAG DMI | 专项 transport TB + ZU15EG halt/read/resume 板测 | 不是完整 RISC-V Debug Spec |
| CDC | four-phase handshake RTL、异步时钟仿真、reset synchronizer | 不是 SpyGlass CDC/RDC sign-off |
| DC/STA | 28 nm pre-layout timing cone A/B | 不是 post-layout ASIC sign-off |

后续若走 CPU DV 路线，最自然的增长顺序是：增加 cache backpressure test → interrupt test → JTAG halt/resume UVM test → reference ISS/DPI differential test → constrained-random / coverage closure。

## 21. 波形阅读：normal、bubble、stall、flush

阅读波形时，不要只看 `inst`，还要并排看 PC、IF/ID、ID/EX、EX/MEM、MEM/WB、`hold_flag`、`jump/flush`、`reg_we`、`mem_we`、`mem_req/ready`。

| 现象 | 波形本质 | 例子 |
|---|---|---|
| normal | 各流水寄存器每拍进入下一条有效 instruction | 连续 `addi` |
| bubble | 某一级被写入 NOP/invalid，副作用全关 | load-use interlock 后 ID/EX 注入 bubble |
| stall | 某些寄存器保持前一拍数据不变 | cache miss/backpressure 时 PC、IF/ID hold |
| flush | 错路径前端项失效，PC 改为 redirect target | branch/JAL/JALR 预测错误 |

最推荐的第一个波形命令：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_cpu_uvm_smoke.ps1 -TestName pipeline_hazard_test
```

先在这段波形里找到 `lw x7` 和紧随其后的 `addi x8,x7,1`：你应该看到前端被 hold 一拍、ID/EX 出现 bubble，随后 `x8` 得到正确结果。再定位 `jal`/`jalr`，观察错误路径 instruction 没有写 GPR。

## 22. 面试时如何表述 PPA 证据

应该按“实现条件 → 指标 → 含义 → 限制”四步说：

> 在 ZU15EG CPU+AXI+PMU+USER2 debug profile 上，我完成了 100 MHz post-route，实现结果 WNS +1.527 ns、TNS 0、WHS +0.015 ns；说明该 FPGA profile 在该约束下 setup/hold 均收敛。28 nm Design Compiler 的结果是 pre-layout timing-cone A/B，用于定位和优化 EX-to-JALR 路径，而不是 ASIC sign-off PPA。

不要做三种夸大：

1. 不把 FPGA LUT/BRAM 说成 ASIC area；
2. 不把 pre-layout DC 说成 post-layout sign-off；
3. 不把局部 `+4.77 ns` cone slack 说成整个 CPU 的 global Fmax 提升。

## 23. 面试表达模板与已知限制

### 23.1 90 秒项目介绍

> 我做的是 LumenRV32，一个可综合的 RV32IM 单发射五级流水 CPU。微架构上实现了 forwarding、load-use interlock、branch redirect/flush、I/D Cache、BTB/2-bit BHT、prefetch queue 和 write-through store queue。存储路径采用 CPU native-memory interface 再适配到 AXI4，使 cache/pipeline 与 AXI protocol 解耦。验证上我建立了 native-memory boundary 的 SystemVerilog directed UVM foundation，覆盖 forwarding、load-use、JAL/JALR flush 和 backpressure。工程上，我复用 ZU15EG 的 USER2 JTAG 实现了自定义 DMI transport，并通过 four-phase CDC 完成 halt、GPR read、resume 的板测；另外基于 DC timing report 对 EX-to-JALR dependency 做一拍 interlock 和 MEM/WB late-forwarding 重构，消除了长组合关键 cone。

### 23.2 必须主动交代的限制

- 单发射、顺序核；不是 superscalar / OoO core；
- AXI fabric 目前不支持 ID、多 outstanding 或 OoO response；
- UVM 是 directed foundation，不是 coverage closure 或 ISS differential；
- USER2 DMI 是 custom debug transport，不是 full RISC-V Debug Spec；
- CDC/RDC 未完成静态 sign-off；28 nm 结果是 pre-layout。

把限制说清楚不会减分，反而证明你知道工程验收的边界。
