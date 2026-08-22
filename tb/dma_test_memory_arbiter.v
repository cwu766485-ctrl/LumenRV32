/*
Copyright 2020 Blue Liang, liangkangnan@163.com

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

`timescale 1 ns / 1 ps

`include "defines.v"

// test memory fabric bus with a single locked outstanding transaction and buffered response.
// Requests are accepted from one master at a time; after the selected slave
// responds, the response is held for the originating master until that master
// drops or changes its request.
// -----------------------------------------------------------------------------
// test memory fabric 主互联
// -----------------------------------------------------------------------------
// test memory fabric = RISC-V Internal Bus，是本项目早期自定义片上互联，不是 ARM/AMBA 标准总线。
// 当前实现特点：
// - 4 个 master：通常用于 CPU data、CPU instruction、JTAG/DMA、debug/NPU 等路径。
// - 7 个 slave：由地址高 4 位 addr[31:28] 译码，映射 ROM/RAM/APB/EXTMEM/reserved。
// - 单 outstanding：同一时间只锁定一笔事务，等待 slave ready 后再服务下一笔。
// - 带响应缓存：slave 返回后先保存在 resp_data_r，再返回给原 master。
// - 固定优先级：m3 > m0 > m2 > m1。m1 通常是取指，优先级最低，避免数据侧饿死。
// 面试重点：
// - 它的概念类似“简化 crossbar/arbiter + decoder”，不是 AXI/AHB。
// - 优点是简单、易验证；缺点是不支持 burst、多 outstanding、乱序或高并发。
// -----------------------------------------------------------------------------
/*
RIB有四个master
m0：CPU data / EX 访存通道
    来自 riscv_cpu_core.mem_ex_*
    用于 load/store，也就是 D-cache/MEM 方向

m1：CPU instruction / PC 取指通道
    来自 riscv_cpu_core.mem_pc_*
    用于 I-cache/ifetch 取指

m2：JTAG memory debug 或 DMA
    如果 jtag_mem_req = 1，m2 给 JTAG memory access
    否则 m2 给 DMA

m3：保留给测试平台辅助 master；当前 DMA 专项默认不使用。

test memory fabric 有 7 个 slave：

s0：ROM
    地址 0x0xxx_xxxx

s1：RAM
    地址 0x1xxx_xxxx

s2：AXI-Lite bridge -> AXI-Lite-to-APB bridge -> APB peripherals
    地址 0x2xxx_xxxx

s3：external_memory_wrapper -> AXI4 extmem bridge / DDR / MIG
    地址 0x3xxx_xxxx

s4：reserved
    地址 0x4xxx_xxxx

s5：reserved
    地址 0x5xxx_xxxx

s6：reserved
    地址 0x6xxx_xxxx
*/
module dma_test_memory_arbiter(

    input wire clk,
    input wire rst,

    // master 0 interface
    input wire[`MemAddrBus] m0_addr_i,
    input wire[`MemBus] m0_data_i,
    input wire[`MemMaskBus] m0_wmask_i,
    output reg[`MemBus] m0_data_o,
    input wire m0_req_i,
    input wire m0_we_i,
    output reg m0_ready_o,
/*
m0_addr_i    master访问地址
m0_data_i    master写数据
m0_wmask_i   master写字节掩码，4 bit 对应 4 个 byte
m0_data_o    RIB返回给master的读数据
m0_req_i     master请求有效
m0_we_i      1=写，0=读
m0_ready_o   本次请求完成
*/
    // master 1 interface
    input wire[`MemAddrBus] m1_addr_i,
    input wire[`MemBus] m1_data_i,
    input wire[`MemMaskBus] m1_wmask_i,
    output reg[`MemBus] m1_data_o,
    input wire m1_req_i,
    input wire m1_we_i,
    output reg m1_ready_o,

    // master 2 interface
    input wire[`MemAddrBus] m2_addr_i,
    input wire[`MemBus] m2_data_i,
    input wire[`MemMaskBus] m2_wmask_i,
    output reg[`MemBus] m2_data_o,
    input wire m2_req_i,
    input wire m2_we_i,
    output reg m2_ready_o,

    // master 3 interface
    input wire[`MemAddrBus] m3_addr_i,
    input wire[`MemBus] m3_data_i,
    input wire[`MemMaskBus] m3_wmask_i,
    output reg[`MemBus] m3_data_o,
    input wire m3_req_i,
    input wire m3_we_i,
    output reg m3_ready_o,

    // slave 0 interface
    output reg[`MemAddrBus] s0_addr_o,
    output reg[`MemBus] s0_data_o,
    output reg[`MemMaskBus] s0_wmask_o,
    output reg s0_req_o,
    output reg s0_we_o,
    input wire[`MemBus] s0_data_i,
    input wire s0_ready_i,
/*
s0_addr_o    RIB发给slave的地址
s0_data_o    RIB发给slave的写数据
s0_wmask_o   RIB发给slave的写掩码
s0_req_o     RIB请求slave
s0_we_o      1=写，0=读
s0_data_i    slave返回读数据
s0_ready_i   slave响应完成
*/
    // slave 1 interface
    output reg[`MemAddrBus] s1_addr_o,
    output reg[`MemBus] s1_data_o,
    output reg[`MemMaskBus] s1_wmask_o,
    output reg s1_req_o,
    output reg s1_we_o,
    input wire[`MemBus] s1_data_i,
    input wire s1_ready_i,

    // slave 2 interface
    output reg[`MemAddrBus] s2_addr_o,
    output reg[`MemBus] s2_data_o,
    output reg[`MemMaskBus] s2_wmask_o,
    output reg s2_req_o,
    output reg s2_we_o,
    input wire[`MemBus] s2_data_i,
    input wire s2_ready_i,
    output reg s2_sel_o,

    // slave 3 interface
    output reg[`MemAddrBus] s3_addr_o,
    output reg[`MemBus] s3_data_o,
    output reg[`MemMaskBus] s3_wmask_o,
    output reg s3_req_o,
    output reg s3_we_o,
    input wire[`MemBus] s3_data_i,
    input wire s3_ready_i,

    // slave 4 interface
    output reg[`MemAddrBus] s4_addr_o,
    output reg[`MemBus] s4_data_o,
    output reg[`MemMaskBus] s4_wmask_o,
    output reg s4_req_o,
    output reg s4_we_o,
    input wire[`MemBus] s4_data_i,
    input wire s4_ready_i,

    // slave 5 interface
    output reg[`MemAddrBus] s5_addr_o,
    output reg[`MemBus] s5_data_o,
    output reg[`MemMaskBus] s5_wmask_o,
    output reg s5_req_o,
    output reg s5_we_o,
    input wire[`MemBus] s5_data_i,
    input wire s5_ready_i,

    // slave 6 interface
    output reg[`MemAddrBus] s6_addr_o,
    output reg[`MemBus] s6_data_o,
    output reg[`MemMaskBus] s6_wmask_o,
    output reg s6_req_o,
    output reg s6_we_o,
    input wire[`MemBus] s6_data_i,
    input wire s6_ready_i,

    output reg hold_flag_o //给cpu控制逻辑用的，test memory fabric 正在处理非取指事务时，请求暂停 core
    );

    localparam [3:0] SLAVE_0 = 4'h0;
    localparam [3:0] SLAVE_1 = 4'h1;
    localparam [3:0] SLAVE_2 = 4'h2;
    localparam [3:0] SLAVE_3 = 4'h3;
    localparam [3:0] SLAVE_4 = 4'h4;
    localparam [3:0] SLAVE_5 = 4'h5;
    localparam [3:0] SLAVE_6 = 4'h6;

    localparam [1:0] GRANT0 = 2'h0;
    localparam [1:0] GRANT1 = 2'h1;
    localparam [1:0] GRANT2 = 2'h2;
    localparam [1:0] GRANT3 = 2'h3;

/*
内部状态寄存器
busy_r:
    当前有一笔事务正在等待 slave ready
resp_valid_r:
    slave 已经返回，响应数据保存在 resp_data_r
cooldown_r:
    响应后插入一个冷却周期，避免请求/响应粘连
grant_r:
    当前锁定的 master owner
grant_next:
    组合逻辑算出来的下一个候选 master
req_slave_r:
    当前锁定事务访问哪个 slave
req_addr_r:
    当前锁定事务的地址
req_wdata_r:
    当前锁定事务的写数据
req_wmask_r:
    当前锁定事务的写掩码
req_we_r:
    当前锁定事务是读还是写
resp_data_r:
    slave 返回后缓存的数据
*/
    reg busy_r;
    reg resp_valid_r;
    reg cooldown_r;
    reg[1:0] grant_r;
    reg[1:0] grant_next;
    reg[3:0] req_slave_r;
    reg[`MemAddrBus] req_addr_r;
    reg[`MemBus] req_wdata_r;
    reg[`MemMaskBus] req_wmask_r;
    reg req_we_r;
    reg[`MemBus] resp_data_r;

/*
sel_*:
    当前仲裁选中的 master 请求
slave_rdata/slave_ready:
    当前被选中 slave 的返回数据和 ready
*/
    reg[`MemAddrBus] sel_addr;
    reg[`MemBus] sel_wdata;
    reg[`MemMaskBus] sel_wmask;
    reg sel_req;
    reg sel_we;
    reg[3:0] sel_slave;

    reg[`MemBus] slave_rdata;
    reg slave_ready;

    wire[3:0] req = {m3_req_i, m2_req_i, m1_req_i, m0_req_i};

    // 当前响应必须返回给锁定时的 owner。owner_same_req 用来确认 master 仍保持同一请求，
    // 防止 master 已经撤销/切换请求后拿到旧响应。
    wire owner_req = (grant_r == GRANT0) ? m0_req_i :
                     (grant_r == GRANT1) ? m1_req_i :
                     (grant_r == GRANT2) ? m2_req_i : m3_req_i;
    wire[`MemAddrBus] owner_addr = (grant_r == GRANT0) ? m0_addr_i :
                                   (grant_r == GRANT1) ? m1_addr_i :
                                   (grant_r == GRANT2) ? m2_addr_i : m3_addr_i;
    wire[`MemMaskBus] owner_wmask = (grant_r == GRANT0) ? m0_wmask_i :
                                    (grant_r == GRANT1) ? m1_wmask_i :
                                    (grant_r == GRANT2) ? m2_wmask_i : m3_wmask_i;
    wire owner_we = (grant_r == GRANT0) ? m0_we_i :
                    (grant_r == GRANT1) ? m1_we_i :
                    (grant_r == GRANT2) ? m2_we_i : m3_we_i;
    wire owner_same_req = (owner_req == `True) &&
                          (owner_addr == req_addr_r) &&
                          (owner_wmask == req_wmask_r) &&
                          (owner_we == req_we_r);

    // 固定优先级仲裁。默认给 GRANT1 是为了空闲时以取指 master 为缺省 owner，
    // 但只要其他请求存在，会按 m3 > m0 > m2 > m1 选择。
    always @ (*) begin
        if (req[3] == `True) begin
            grant_next = GRANT3;
        end else if (req[0] == `True) begin
            grant_next = GRANT0;
        end else if (req[2] == `True) begin
            grant_next = GRANT2;
        end else begin
            grant_next = GRANT1;
        end
    end

    // 根据仲裁结果选择当前候选 master，并用地址高 4 位选择 slave。
    always @ (*) begin
        sel_addr = `ZeroWord;
        sel_wdata = `ZeroWord;
        sel_wmask = 4'b1111;
        sel_req = `False;
        sel_we = `WriteDisable;

        case (grant_next)
            GRANT0: begin
                sel_addr = m0_addr_i;
                sel_wdata = m0_data_i;
                sel_wmask = m0_wmask_i;
                sel_req = m0_req_i;
                sel_we = m0_we_i;
            end
            GRANT1: begin
                sel_addr = m1_addr_i;
                sel_wdata = m1_data_i;
                sel_wmask = m1_wmask_i;
                sel_req = m1_req_i;
                sel_we = m1_we_i;
            end
            GRANT2: begin
                sel_addr = m2_addr_i;
                sel_wdata = m2_data_i;
                sel_wmask = m2_wmask_i;
                sel_req = m2_req_i;
                sel_we = m2_we_i;
            end
            default: begin
                sel_addr = m3_addr_i;
                sel_wdata = m3_data_i;
                sel_wmask = m3_wmask_i;
                sel_req = m3_req_i;
                sel_we = m3_we_i;
            end
        endcase

        sel_slave = sel_addr[31:28]; // 根据地址高 4 位选 slave
    end

    // 组合输出：
    // - 若 busy_r 已锁定事务，则持续驱动锁定的 slave。
    // - 若空闲且有新请求，则把候选 master 请求送到对应 slave。
    // - 若 resp_valid_r 有效，则把缓存响应返回给原 owner。
    always @ (*) begin
        m0_data_o = `ZeroWord;
        m1_data_o = `INST_NOP;
        m2_data_o = `ZeroWord;
        m3_data_o = `ZeroWord;
        m0_ready_o = `False;
        m1_ready_o = `False;
        m2_ready_o = `False;
        m3_ready_o = `False;

        s0_addr_o = `ZeroWord;
        s1_addr_o = `ZeroWord;
        s2_addr_o = `ZeroWord;
        s3_addr_o = `ZeroWord;
        s4_addr_o = `ZeroWord;
        s5_addr_o = `ZeroWord;
        s6_addr_o = `ZeroWord;
        s0_data_o = `ZeroWord;
        s1_data_o = `ZeroWord;
        s2_data_o = `ZeroWord;
        s3_data_o = `ZeroWord;
        s4_data_o = `ZeroWord;
        s5_data_o = `ZeroWord;
        s6_data_o = `ZeroWord;
        s0_wmask_o = 4'b1111;
        s1_wmask_o = 4'b1111;
        s2_wmask_o = 4'b1111;
        s3_wmask_o = 4'b1111;
        s4_wmask_o = 4'b1111;
        s5_wmask_o = 4'b1111;
        s6_wmask_o = 4'b1111;
        s0_req_o = `False;
        s1_req_o = `False;
        s2_req_o = `False;
        s3_req_o = `False;
        s4_req_o = `False;
        s5_req_o = `False;
        s6_req_o = `False;
        s0_we_o = `WriteDisable;
        s1_we_o = `WriteDisable;
        s2_we_o = `WriteDisable;
        s3_we_o = `WriteDisable;
        s4_we_o = `WriteDisable;
        s5_we_o = `WriteDisable;
        s6_we_o = `WriteDisable;
        s2_sel_o = `False;

        slave_rdata = `ZeroWord;
        slave_ready = `False;
        // 全部默认清零，组合逻辑必做

        if (busy_r == `True) begin
            // 已有 outstanding 事务：保持同一 slave/addr/data/wmask/we 直到 ready。
            case (req_slave_r)
                SLAVE_0: begin
                    s0_addr_o = {4'h0, req_addr_r[27:0]};
                    s0_data_o = req_wdata_r;
                    s0_wmask_o = req_wmask_r;
                    s0_req_o = `True;
                    s0_we_o = req_we_r;
                    slave_rdata = s0_data_i;
                    slave_ready = s0_ready_i;
                end
                SLAVE_1: begin
                    s1_addr_o = {4'h0, req_addr_r[27:0]};
                    s1_data_o = req_wdata_r;
                    s1_wmask_o = req_wmask_r;
                    s1_req_o = `True;
                    s1_we_o = req_we_r;
                    slave_rdata = s1_data_i;
                    slave_ready = s1_ready_i;
                end
                SLAVE_2: begin
                    s2_addr_o = {4'h0, req_addr_r[27:0]};
                    s2_data_o = req_wdata_r;
                    s2_wmask_o = req_wmask_r;
                    s2_req_o = `True;
                    s2_we_o = req_we_r;
                    s2_sel_o = `True;
                    slave_rdata = s2_data_i;
                    slave_ready = s2_ready_i;
                end
                SLAVE_3: begin
                    s3_addr_o = {4'h0, req_addr_r[27:0]};
                    s3_data_o = req_wdata_r;
                    s3_wmask_o = req_wmask_r;
                    s3_req_o = `True;
                    s3_we_o = req_we_r;
                    slave_rdata = s3_data_i;
                    slave_ready = s3_ready_i;
                end
                SLAVE_4: begin
                    s4_addr_o = {4'h0, req_addr_r[27:0]};
                    s4_data_o = req_wdata_r;
                    s4_wmask_o = req_wmask_r;
                    s4_req_o = `True;
                    s4_we_o = req_we_r;
                    slave_rdata = s4_data_i;
                    slave_ready = s4_ready_i;
                end
                SLAVE_5: begin
                    s5_addr_o = {4'h0, req_addr_r[27:0]};
                    s5_data_o = req_wdata_r;
                    s5_wmask_o = req_wmask_r;
                    s5_req_o = `True;
                    s5_we_o = req_we_r;
                    slave_rdata = s5_data_i;
                    slave_ready = s5_ready_i;
                end
                SLAVE_6: begin
                    s6_addr_o = {4'h0, req_addr_r[27:0]};
                    s6_data_o = req_wdata_r;
                    s6_wmask_o = req_wmask_r;
                    s6_req_o = `True;
                    s6_we_o = req_we_r;
                    slave_rdata = s6_data_i;
                    slave_ready = s6_ready_i;
                end
                default: begin
                    slave_rdata = `ZeroWord;
                    slave_ready = `True;
                end
            endcase
        end else if (resp_valid_r != `True && cooldown_r != `True && sel_req == `True) begin
            // 空闲接收新事务：如果 slave 当拍 ready，可以直接形成响应；否则进入 busy。
/*
resp_valid_r != True:
    当前没有待返回 response

cooldown_r != True:
    不在冷却周期

sel_req == True:
    当前仲裁选中的 master 确实有请求
*/
            case (sel_slave)
                SLAVE_0: begin
                    s0_addr_o = {4'h0, sel_addr[27:0]};
                    s0_data_o = sel_wdata;
                    s0_wmask_o = sel_wmask;
                    s0_req_o = `True;
                    s0_we_o = sel_we;
                    slave_rdata = s0_data_i;
                    slave_ready = s0_ready_i;
                end
                SLAVE_1: begin
                    s1_addr_o = {4'h0, sel_addr[27:0]};
                    s1_data_o = sel_wdata;
                    s1_wmask_o = sel_wmask;
                    s1_req_o = `True;
                    s1_we_o = sel_we;
                    slave_rdata = s1_data_i;
                    slave_ready = s1_ready_i;
                end
                SLAVE_2: begin
                    s2_addr_o = {4'h0, sel_addr[27:0]};
                    s2_data_o = sel_wdata;
                    s2_wmask_o = sel_wmask;
                    s2_req_o = `True;
                    s2_we_o = sel_we;
                    s2_sel_o = `True;
                    slave_rdata = s2_data_i;
                    slave_ready = s2_ready_i;
                end
                SLAVE_3: begin
                    s3_addr_o = {4'h0, sel_addr[27:0]};
                    s3_data_o = sel_wdata;
                    s3_wmask_o = sel_wmask;
                    s3_req_o = `True;
                    s3_we_o = sel_we;
                    slave_rdata = s3_data_i;
                    slave_ready = s3_ready_i;
                end
                SLAVE_4: begin
                    s4_addr_o = {4'h0, sel_addr[27:0]};
                    s4_data_o = sel_wdata;
                    s4_wmask_o = sel_wmask;
                    s4_req_o = `True;
                    s4_we_o = sel_we;
                    slave_rdata = s4_data_i;
                    slave_ready = s4_ready_i;
                end
                SLAVE_5: begin
                    s5_addr_o = {4'h0, sel_addr[27:0]};
                    s5_data_o = sel_wdata;
                    s5_wmask_o = sel_wmask;
                    s5_req_o = `True;
                    s5_we_o = sel_we;
                    slave_rdata = s5_data_i;
                    slave_ready = s5_ready_i;
                end
                SLAVE_6: begin
                    s6_addr_o = {4'h0, sel_addr[27:0]};
                    s6_data_o = sel_wdata;
                    s6_wmask_o = sel_wmask;
                    s6_req_o = `True;
                    s6_we_o = sel_we;
                    slave_rdata = s6_data_i;
                    slave_ready = s6_ready_i;
                end
                default: begin
                    slave_rdata = `ZeroWord;
                    slave_ready = `True;
                end
            endcase
        end

        if ((resp_valid_r == `True) && (owner_same_req == `True)) begin
            // 把缓存的响应返回给当初被 grant 的 master。
            case (grant_r)
                GRANT0: begin
                    m0_data_o = resp_data_r;
                    m0_ready_o = `True;
                end
                GRANT1: begin
                    m1_data_o = resp_data_r;
                    m1_ready_o = `True;
                end
                GRANT2: begin
                    m2_data_o = resp_data_r;
                    m2_ready_o = `True;
                end
                default: begin
                    m3_data_o = resp_data_r;
                    m3_ready_o = `True;
                end
            endcase
        end

        // 取指 master(m1)等待时不需要冻结整个 core；数据侧/调试侧事务会请求 hold。
        hold_flag_o = (((busy_r == `True) || (resp_valid_r == `True)) && (grant_r != GRANT1)) ? `HoldEnable : `HoldDisable;
    end

    // 时序状态机：锁定请求、等待 slave ready、缓存响应、插入 cooldown。
    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            busy_r <= `False;
            resp_valid_r <= `False;
            cooldown_r <= `False;
            grant_r <= GRANT1;
            req_slave_r <= SLAVE_1;
            req_addr_r <= `ZeroWord;
            req_wdata_r <= `ZeroWord;
            req_wmask_r <= 4'b1111;
            req_we_r <= `WriteDisable;
            resp_data_r <= `ZeroWord;
        end else if (resp_valid_r == `True) begin
            // 响应给 master 一个周期；非取指事务后加一拍 cooldown，避免请求/响应粘连。
            resp_valid_r <= `False;
            cooldown_r <= (grant_r != GRANT1);
        end else if (cooldown_r == `True) begin
            cooldown_r <= `False;
        end else if (busy_r == `True) begin
            // 等待慢 slave ready，ready 后把数据缓存到 resp_data_r。
            if (slave_ready == `True) begin
                busy_r <= `False;
                resp_valid_r <= `True;
                resp_data_r <= slave_rdata;
            end
        end else if (sel_req == `True) begin
            // 接收并锁定一笔新请求。
            grant_r <= grant_next;
            req_slave_r <= sel_slave;
            req_addr_r <= sel_addr;
            req_wdata_r <= sel_wdata;
            req_wmask_r <= sel_wmask;
            req_we_r <= sel_we;
            if (slave_ready == `True) begin
                resp_valid_r <= `True;
                resp_data_r <= slave_rdata;
            end else begin
                busy_r <= `True;
            end
        end
    end

endmodule
