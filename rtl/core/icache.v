/*
SPDX-License-Identifier: Apache-2.0

Project-specific implementation for heterogeneous_soc.

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

// -----------------------------------------------------------------------------
// I-Cache：直接映射指令缓存
// -----------------------------------------------------------------------------
// 结构：
// - data_array[index][word] 保存一条 cache line 的多个 32-bit 指令。
// - tag_array[index] 保存高位 tag，valid_array[index] 表示该行是否有效。
// - 地址切分：低 2 位是字节偏移，word bits 选 line 内 word，index bits 选 cache 行。
//
// 默认参数：
// - ICacheLineWords = 4：每条 cache line 有 4 个 32-bit word，也就是 16 bytes。
// - ICacheLineCount = 16：一共有 16 条 cache line。
// - 默认地址切分：
//     addr[1:0]   byte offset，RV32 指令按 4 字节对齐，通常为 00
//     addr[3:2]   word offset，选择一条 line 内第几个 word
//     addr[7:4]   index，选择 16 条 cache line 中哪一条
//     addr[31:8]  tag，用来判断这一行当前缓存的是哪个高地址块
//
// 行为：
// - hit：当拍返回 data_array 中的指令，不访问 memory interface。
// - miss：按 line base 地址从后端逐 word 读取整条 line，期间 hold_flag_o 拉高。
// - invalidate/reset：清 valid，下一次访问重新填充。
//
// direct-mapped 的含义：
// - 一个内存地址只能映射到唯一一个 cache index。
// - 如果两个不同高地址块的 index 相同，它们会互相覆盖。
// - 所以这里没有复杂替换策略，也没有 set-associative。
//
// 面试重点：
// - I-cache 只服务取指，不处理写入。
// - miss 时不是只取当前一条指令，而是取完整 cache line。
// - 本模块后端接口仍是简单 req/ready，不是 AXI/AHB 协议。
// -----------------------------------------------------------------------------
module icache #( //这里 #(...) 是 Verilog 参数化写法。意思是这个 cache 的规模可以配置。
    parameter LINE_WORDS = `ICacheLineWords, // 每条 cache line 包含多少个 32-bit 指令 word
    parameter LINE_COUNT = `ICacheLineCount  // cache line 总数
    /*
每条 cache line = 4 个 32-bit word = 16 bytes
一共 16 条 cache line
因为一个 RISC-V 指令是 32 bit = 4 bytes，所以：
每条 line = 4 条指令 = 16 bytes
整个 I-cache 容量 = 16 lines * 16 bytes
    */
)(

    input wire clk,
    input wire rst,

    input wire[`InstAddrBus] cpu_addr_i,  // 来自 ifetch 的要取指的地址
    input wire cpu_req_i,                 // 来自 ifetch 的取指请求。没有请求时，cache 不应该判断 hit/miss。
    input wire invalidate_i,              // cache 无效化请求，置位后清空 valid
    //invalidate_i：cache 无效化请求。有效时清空 valid bit，让所有 cache line 都变成无效。注意它一般不需要清空 data，只要 valid 清掉，旧数据就不会被命中。

    output reg[`InstBus] cpu_inst_o,      // 返回给 ifetch 的指令；hit 时为 cache 数据，否则为 NOP
    output wire hold_flag_o,              // I-cache miss 或 line-fill 期间拉高，要求前端暂停
    output wire perf_hit_o,
    output wire perf_miss_o,

/*
这四个是 I-cache 访问后端的接口。后端可以理解为 memory interface/ROM/RAM，它们的行为是：
- 当 mem_req_o 拉高时，后端开始处理请求，地址为 mem_addr_o。
- 处理完成后，mem_ready_i 拉高，mem_data_i 中返回一个 32-bit word。
- I-cache 可能需要连续多次 mem_ready_i 来填充完整的一条 cache line。
*/
    output reg[`MemAddrBus] mem_addr_o,   // miss line-fill 时访问后端的地址
    output reg mem_req_o,                 // miss line-fill 时访问后端的请求
    output wire[7:0] mem_burst_len_o,
    input wire[`MemBus] mem_data_i,       // 后端返回的数据，是一个 32-bit word
    input wire mem_ready_i                // 后端返回有效，mem_data_i 可写入 cache

    );

    // 计算 log2(value)，用于根据参数自动推导 word offset/index 位宽。
    // 例如 LINE_WORDS=4 时，WORD_OFFSET_BITS=2。
    // 注意：这里默认 LINE_WORDS/LINE_COUNT 是 2 的幂。
    // 表示 value 个东西，需要多少个 bit 编码。
    function integer clog2;
        input integer value;
        integer i;
        begin
            value = value - 1;
            for (i = 0; value > 0; i = i + 1) begin
                value = value >> 1;
            end
            clog2 = i;
        end
    endfunction

    // 地址切分参数：
    // - WORD_OFFSET_BITS：line 内 word 选择位数。
    // - INDEX_BITS：cache index 选择位数。
    // - TAG_LSB：tag 从地址的哪一位开始。固定的 2 是因为地址最低两位是byte offset
    localparam WORD_OFFSET_BITS = clog2(LINE_WORDS);
    localparam INDEX_BITS = clog2(LINE_COUNT);
    localparam TAG_LSB = 2 + WORD_OFFSET_BITS + INDEX_BITS;
    localparam DATA_DEPTH = LINE_COUNT * LINE_WORDS;
    localparam DATA_ADDR_BITS = clog2(DATA_DEPTH);
`ifdef CacheUseBlockRam
    localparam CACHE_RAM_READ_LATENCY = 1;
`else
    localparam CACHE_RAM_READ_LATENCY = 0;
`endif

    // cache 数据阵列：
    // - data_array[index][word]：某条 line 内的某个 32-bit 指令。
    // - tag_array[index]：该 index 当前缓存的高位地址 tag。
    // - valid_array[index]：该 index 是否已经填充过有效数据。
    reg[`InstAddrBus] tag_array[0:LINE_COUNT - 1];
    reg valid_array[0:LINE_COUNT - 1]; //表示这一行有没有有效数据。

    // line-fill 状态：
    // 这几个是在 miss 后用的
    // - fill_active：当前是否正在处理一次 miss line-fill。
    // - fill_index：要填充到哪一个 cache index。
    // - fill_word：当前正在从后端读取 line 内第几个 word。
    // - fill_tag：填充完成后写入 tag_array 的 tag。
    // - fill_base_addr：本条 cache line 的起始地址，低位按 line 大小对齐为 0。
    reg fill_active;
    // In BRAM mode a tag hit still needs one clock to return data.  ifetch
    // already handles backend_hold_i as a pending request, so this flag turns
    // a hit into a one-cycle response without changing its request protocol.
    reg hit_read_pending;
    reg[INDEX_BITS - 1:0] fill_index;
    reg[WORD_OFFSET_BITS - 1:0] fill_word;
    reg[`InstAddrBus] fill_tag;
    reg[`InstAddrBus] fill_base_addr;

    integer idx;

    // 从 CPU 取指地址中拆出 index、word offset、tag。
    // 默认 LINE_WORDS=4、LINE_COUNT=16 时：
    // - cpu_word  = cpu_addr_i[3:2]
    // - cpu_index = cpu_addr_i[7:4]
    // - cpu_tag   = {8'h00, cpu_addr_i[31:8]}
    wire[INDEX_BITS - 1:0] cpu_index = cpu_addr_i[2 + WORD_OFFSET_BITS + INDEX_BITS - 1:2 + WORD_OFFSET_BITS];
    wire[WORD_OFFSET_BITS - 1:0] cpu_word = cpu_addr_i[2 + WORD_OFFSET_BITS - 1:2];
    wire[`InstAddrBus] cpu_tag = {{TAG_LSB{1'b0}}, cpu_addr_i[31:TAG_LSB]};
    wire[DATA_ADDR_BITS - 1:0] cpu_data_addr = (cpu_index * LINE_WORDS) + cpu_word;
    wire[DATA_ADDR_BITS - 1:0] fill_data_addr = (fill_index * LINE_WORDS) + fill_word;
    wire[`InstBus] cache_data_rdata;
    wire cache_data_we = fill_active && mem_ready_i;

    cache_ram_1r1w #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(DATA_ADDR_BITS),
        .DEPTH(DATA_DEPTH),
        .READ_LATENCY(CACHE_RAM_READ_LATENCY)
    ) u_icache_data_ram (
        .clk(clk),
        .rst(rst),
        .raddr_i(cpu_data_addr),
        .rdata_o(cache_data_rdata),
        .we_i(cache_data_we),
        .waddr_i(fill_data_addr),
        .wdata_i(mem_data_i)
    );

    // hit 条件：
    // - 当前确实有取指请求。
    // - 对应 index 的 line 有效。
    // - 该 line 的 tag 与当前地址 tag 相等。
    wire tag_hit = cpu_req_i && valid_array[cpu_index] && (tag_array[cpu_index] == cpu_tag);
    wire hit_start = tag_hit && (CACHE_RAM_READ_LATENCY != 0) && !hit_read_pending;
    wire hit = (CACHE_RAM_READ_LATENCY == 0) ? tag_hit : hit_read_pending;

    // miss 条件：有取指请求但没有命中。
    wire miss = cpu_req_i && !tag_hit;
    assign perf_hit_o = hit;
    assign perf_miss_o = miss && !fill_active;

    // miss 或 line-fill 期间冻结前端，避免 PC 前进到尚未返回的指令。
    assign hold_flag_o = fill_active || miss || hit_start;
    assign mem_burst_len_o = fill_active ? (LINE_WORDS - 1) : 8'd0;

    // 组合读/后端请求逻辑：
    // - 默认返回 NOP，不发后端请求。
    // - hit 时直接组合读 cache，返回 data_array[cpu_index][cpu_word]。
    // - fill_active 时持续发后端请求，地址为 fill_base_addr + fill_word * 4。
    always @ (*) begin
        cpu_inst_o = `INST_NOP;
        mem_addr_o = fill_base_addr + {{30{1'b0}}, fill_word, 2'b00};
        mem_req_o = fill_active;

        if (hit) begin
            // hit 路径是组合读，直接给 ifetch backend_inst_i。
            cpu_inst_o = cache_data_rdata;
        end
    end

    // 时序逻辑：
    // - reset/invalidate：清空 cache valid 和正在进行的 fill 状态。
    // - fill_active：后端每 ready 一次，写入一个 word；整条 line 填完后置 valid/tag。
    // - miss：启动新 line-fill，记录 index/tag/base address。
    always @ (posedge clk) begin
        if (rst == `RstEnable || invalidate_i == `True) begin
            // cache 无效化：数据阵列无需清零，只要 valid 清 0，后续就不会命中旧数据。
            fill_active <= `False;
            hit_read_pending <= `False;
            fill_index <= {INDEX_BITS{1'b0}};
            fill_word <= {WORD_OFFSET_BITS{1'b0}};
            fill_tag <= `ZeroWord;
            fill_base_addr <= `ZeroWord;
            for (idx = 0; idx < LINE_COUNT; idx = idx + 1) begin
                valid_array[idx] <= `False;
                tag_array[idx] <= `ZeroWord;
            end
        end else begin
            if (CACHE_RAM_READ_LATENCY != 0) begin
                if (hit_read_pending == `True) begin
                    hit_read_pending <= `False;
                end else if (tag_hit == `True) begin
                    hit_read_pending <= `True;
                end
            end
            if (fill_active == `True) begin
                // line-fill：每次后端 ready 返回一个 word，写入当前 fill_word。
                if (mem_ready_i == `True) begin
                    if (fill_word == LINE_WORDS - 1) begin
                        // 最后一个 word 到达：整条 line 有效，写 tag，结束 fill。
                        valid_array[fill_index] <= `True;
                        tag_array[fill_index] <= fill_tag;
                        fill_active <= `False;
                        fill_word <= {WORD_OFFSET_BITS{1'b0}};
                    end else begin
                        fill_word <= fill_word + 1'b1;
                    end
                end
            end else if (miss) begin
                // 新 miss：记录 index/tag/base，从 line 的第 0 个 word 开始填充。
                fill_active <= `True;
                fill_index <= cpu_index;
                fill_word <= {WORD_OFFSET_BITS{1'b0}};
                fill_tag <= cpu_tag;
                // line base address：把 line 内偏移位清 0。
                // 默认一条 line 16 bytes，所以低 4 位清 0。
                fill_base_addr <= {cpu_addr_i[31:2 + WORD_OFFSET_BITS], {WORD_OFFSET_BITS{1'b0}}, 2'b00};
            end
        end
    end

endmodule
