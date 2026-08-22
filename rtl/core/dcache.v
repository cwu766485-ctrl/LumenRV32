`timescale 1 ns / 1 ps

`include "defines.v"

// Direct-mapped data cache.
//
// Policy:
// - load hit returns the cached word directly
// - load miss fills one whole cache line and may return the requested word
//   before the tail of the line has completed
// - store is write-through
// - store miss is no-write-allocate
// - cacheable range defaults to on-chip RAM window 0x1xxx_xxxx
//
// The data array is behind cache_ram_1r1w so FPGA BRAM or ASIC SRAM can replace
// the behavioral array without changing D-Cache control logic.
module dcache #(
    parameter LINE_WORDS = `DCacheLineWords,
    parameter LINE_COUNT = `DCacheLineCount
)(
    input wire clk,
    input wire rst,

    input wire[`MemAddrBus] cpu_addr_i,
    input wire[`MemBus] cpu_wdata_i,
    input wire[`MemMaskBus] cpu_wmask_i,
    input wire cpu_req_i,
    input wire cpu_we_i,
    input wire invalidate_i,

    output reg[`MemBus] cpu_rdata_o,
    output wire cpu_ready_o,
    output wire perf_load_hit_o,
    output wire perf_load_miss_o,
    output wire perf_store_hit_o,
    output wire perf_store_miss_o,
    output wire perf_load_miss_stall_o,
    output wire perf_store_wait_o,
    output wire perf_store_buffer_enqueue_o,
    output wire perf_store_buffer_full_stall_o,
    output wire perf_store_buffer_drain_o,

    output reg[`MemAddrBus] mem_addr_o,
    output reg[`MemBus] mem_wdata_o,
    output reg[`MemMaskBus] mem_wmask_o,
    output reg mem_req_o,
    output reg mem_we_o,
    output wire[7:0] mem_burst_len_o,
    input wire[`MemBus] mem_rdata_i,
    input wire mem_ready_i
);

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

    function [`MemBus] apply_wmask;
        input [`MemBus] old_word;
        input [`MemBus] new_word;
        input [`MemMaskBus] wmask;
        begin
            apply_wmask = old_word;
            if (wmask[0]) apply_wmask[7:0] = new_word[7:0];
            if (wmask[1]) apply_wmask[15:8] = new_word[15:8];
            if (wmask[2]) apply_wmask[23:16] = new_word[23:16];
            if (wmask[3]) apply_wmask[31:24] = new_word[31:24];
        end
    endfunction

    localparam WORD_OFFSET_BITS = clog2(LINE_WORDS);
    localparam INDEX_BITS = clog2(LINE_COUNT);
    localparam TAG_LSB = 2 + WORD_OFFSET_BITS + INDEX_BITS;
    localparam DATA_DEPTH = LINE_COUNT * LINE_WORDS;
    localparam DATA_ADDR_BITS = clog2(DATA_DEPTH);
    localparam STORE_QUEUE_ENABLED = 1'b1;
`ifdef CacheUseBlockRam
    localparam CACHE_RAM_READ_LATENCY = 1;
`else
    localparam CACHE_RAM_READ_LATENCY = 0;
`endif

    reg[`MemAddrBus] tag_array[0:LINE_COUNT - 1];
    reg valid_array[0:LINE_COUNT - 1];

    reg fill_active;
    // BRAM-mode hit response state.  The request is held by MEM until
    // cpu_ready_o, so CPU address/write data remain stable while this flag is
    // set.  A store keeps the flag set if the ordered store queue is full.
    reg hit_read_pending;
    reg[INDEX_BITS - 1:0] fill_index;
    reg[WORD_OFFSET_BITS - 1:0] fill_word;
    reg[WORD_OFFSET_BITS - 1:0] fill_req_word;
    reg[`MemAddrBus] fill_tag;
    reg[`MemAddrBus] fill_base_addr;
    reg fill_cpu_released;
    reg[`MemAddrBus] hit_pending_addr;
    reg[`MemBus] hit_pending_wdata;
    reg[`MemMaskBus] hit_pending_wmask;
    reg hit_pending_we;
    reg[INDEX_BITS - 1:0] hit_pending_index;
    reg[WORD_OFFSET_BITS - 1:0] hit_pending_word;

    // Strictly ordered two-entry write-through store queue.
    // Only cache-hit writes enter the buffer. Store misses and non-cacheable
    // writes stay on the existing blocking path, so they cannot bypass an
    // older buffered store or change allocation/I/O ordering semantics.
    reg store_buffer_head;
    reg store_buffer_tail;
    reg[1:0] store_buffer_count;
    reg[`MemAddrBus] store_buffer_addr[0:1];
    reg[`MemBus] store_buffer_wdata[0:1];
    reg[`MemMaskBus] store_buffer_wmask[0:1];
    reg req_active;
    reg[`MemAddrBus] req_addr;
    reg[`MemBus] req_wdata;
    reg[`MemMaskBus] req_wmask;
    reg req_we;
    integer idx;

    wire[`MemAddrBus] active_addr = (req_active == `True) ? req_addr : cpu_addr_i;
    wire[`MemBus] active_wdata = (req_active == `True) ? req_wdata : cpu_wdata_i;
    wire[`MemMaskBus] active_wmask = (req_active == `True) ? req_wmask : cpu_wmask_i;
    wire active_we = (req_active == `True) ? req_we : cpu_we_i;
    wire active_req = (req_active == `True) ? `True : cpu_req_i;

`ifdef CacheExternalMemory
    wire cacheable = (active_addr[31:28] == 4'h1) || (active_addr[31:28] == 4'h3);
`else
    wire cacheable = (active_addr[31:28] == 4'h1);
`endif

    wire[INDEX_BITS - 1:0] cpu_index = active_addr[2 + WORD_OFFSET_BITS + INDEX_BITS - 1:2 + WORD_OFFSET_BITS];
    wire[WORD_OFFSET_BITS - 1:0] cpu_word = active_addr[2 + WORD_OFFSET_BITS - 1:2];
    wire[`MemAddrBus] cpu_tag = {{TAG_LSB{1'b0}}, active_addr[31:TAG_LSB]};

    wire[DATA_ADDR_BITS - 1:0] cpu_data_addr = (cpu_index * LINE_WORDS) + cpu_word;
    wire[DATA_ADDR_BITS - 1:0] hit_pending_data_addr = (hit_pending_index * LINE_WORDS) + hit_pending_word;
    wire[DATA_ADDR_BITS - 1:0] fill_data_addr = (fill_index * LINE_WORDS) + fill_word;
    wire[DATA_ADDR_BITS - 1:0] fill_req_data_addr = (fill_index * LINE_WORDS) + fill_req_word;
    wire[DATA_ADDR_BITS - 1:0] cache_data_raddr = (fill_active == `True) ? fill_req_data_addr :
                                                   ((hit_read_pending == `True) ? hit_pending_data_addr : cpu_data_addr);
    wire[`MemBus] cache_data_rdata;

    wire tag_hit = !hit_read_pending && active_req && cacheable &&
                   valid_array[cpu_index] && (tag_array[cpu_index] == cpu_tag);
    wire hit_response_ready = (fill_active == `True) ? `False :
                              ((CACHE_RAM_READ_LATENCY == 0) ? tag_hit : hit_read_pending);
    wire hit_req_we = (CACHE_RAM_READ_LATENCY == 0) ? active_we : hit_pending_we;
    wire[`MemAddrBus] hit_req_addr = (CACHE_RAM_READ_LATENCY == 0) ? active_addr : hit_pending_addr;
    wire[`MemBus] hit_req_wdata = (CACHE_RAM_READ_LATENCY == 0) ? active_wdata : hit_pending_wdata;
    wire[`MemMaskBus] hit_req_wmask = (CACHE_RAM_READ_LATENCY == 0) ? active_wmask : hit_pending_wmask;
    wire[DATA_ADDR_BITS - 1:0] hit_req_data_addr = (CACHE_RAM_READ_LATENCY == 0) ? cpu_data_addr : hit_pending_data_addr;
    wire load_hit = hit_response_ready && (hit_req_we == `WriteDisable);
    wire store_hit = hit_response_ready && (hit_req_we == `WriteEnable);
    wire store_req = !hit_read_pending && active_req && (active_we == `WriteEnable);
    wire bypass_req = !hit_read_pending && active_req && !cacheable;
    wire load_miss = active_req && cacheable && (active_we == `WriteDisable) &&
                     !tag_hit && !fill_active && (store_buffer_count == 0);
    wire fill_last_word = fill_active && mem_ready_i && (fill_word == LINE_WORDS - 1);
    // Critical-word-first / early-restart boundary.  The AXI/native burst still
    // starts at the line base and fills in order, but the original load can
    // complete as soon as its requested word returns.
    wire fill_req_word_ready = fill_active && mem_ready_i && !fill_cpu_released &&
                               (fill_word == fill_req_word);
    wire fill_last_word_release = fill_last_word && !fill_cpu_released;
    wire store_miss = store_req && cacheable && !tag_hit;
    wire store_hit_enqueue = STORE_QUEUE_ENABLED && store_hit && (store_buffer_count != 2);
    // A synchronous-BRAM cache hit is not response-ready in its first cycle,
    // but it is still a cache hit and must not be sent as a direct store.
    // A cacheable store that arrives while a load refill is still active must
    // wait for that line to become valid.  Treating it as a direct store here
    // would write through memory after the fill, but leave the freshly-filled
    // cache line with stale data; a following load could then observe the
    // pre-store word.  req_active keeps the CPU transaction stable until the
    // line can be re-evaluated as a normal cache-hit store.
    wire direct_store_req = store_req && !fill_active &&
                            (!tag_hit || !STORE_QUEUE_ENABLED);
    // The CPU MEM stage holds addr/data/mask stable until ready.  Keep
    // uncached/MMIO accesses on that direct req/ready path instead of adding
    // a second bypass latch: a latch can accidentally replay a prior MMIO
    // store when back-to-back register writes are issued.
    wire bypass_current_req = (store_buffer_count == 0) &&
                              (direct_store_req || bypass_req);
    wire store_buffer_owns_backend = (fill_active != `True) && !bypass_current_req &&
                                     (store_buffer_count != 0);
    wire store_buffer_drain = store_buffer_owns_backend && mem_ready_i;

    wire cache_fill_we = fill_active && mem_ready_i;
    // The cache reflects the accepted architectural store immediately. The
    // write-through copy remains in store_buffer_* until backend completion.
    wire cache_store_we = store_hit_enqueue;
    wire cache_data_we = cache_fill_we || cache_store_we;
    wire[DATA_ADDR_BITS - 1:0] cache_data_waddr = cache_fill_we ? fill_data_addr : hit_req_data_addr;
    wire[`MemBus] cache_data_wdata = cache_fill_we ? mem_rdata_i :
                                    apply_wmask(cache_data_rdata, hit_req_wdata, hit_req_wmask);
    wire store_buffer_head_valid = (store_buffer_count != 0);
    wire store_buffer_tail_valid = (store_buffer_count == 2);
    wire store_forward_head_hit = store_buffer_head_valid &&
                                  (store_buffer_addr[store_buffer_head][31:2] == hit_req_addr[31:2]);
    wire store_forward_tail_hit = store_buffer_tail_valid &&
                                  (store_buffer_addr[~store_buffer_head][31:2] == hit_req_addr[31:2]);
    wire store_forward_hit = load_hit && (store_forward_head_hit || store_forward_tail_hit);
    wire[`MemBus] store_forward_head_data =
        apply_wmask(cache_data_rdata,
                    store_buffer_wdata[store_buffer_head],
                    store_buffer_wmask[store_buffer_head]);
    wire[`MemBus] store_forward_tail_data =
        apply_wmask(store_forward_head_hit ? store_forward_head_data : cache_data_rdata,
                    store_buffer_wdata[~store_buffer_head],
                    store_buffer_wmask[~store_buffer_head]);
    wire[`MemBus] load_hit_data = store_forward_tail_hit ? store_forward_tail_data :
                                  (store_forward_head_hit ? store_forward_head_data : cache_data_rdata);

    cache_ram_1r1w #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(DATA_ADDR_BITS),
        .DEPTH(DATA_DEPTH),
        .READ_LATENCY(CACHE_RAM_READ_LATENCY)
    ) u_dcache_data_ram (
        .clk(clk),
        .rst(rst),
        .raddr_i(cache_data_raddr),
        .rdata_o(cache_data_rdata),
        .we_i(cache_data_we),
        .waddr_i(cache_data_waddr),
        .wdata_i(cache_data_wdata)
    );

    assign perf_load_hit_o = load_hit;
    assign perf_load_miss_o = load_miss;
    assign perf_store_hit_o = store_hit_enqueue;
    assign perf_store_miss_o = store_miss && mem_ready_i;
    assign perf_load_miss_stall_o = fill_active && cpu_req_i &&
                                    (cpu_we_i == `WriteDisable) && !cpu_ready_o;
    assign perf_store_wait_o = store_req && !store_hit_enqueue &&
                               !(direct_store_req && (store_buffer_count == 0) && mem_ready_i);
    assign perf_store_buffer_enqueue_o = store_hit_enqueue;
    assign perf_store_buffer_full_stall_o = store_req && (store_buffer_count == 2);
    assign perf_store_buffer_drain_o = (store_buffer_count != 0);
    assign mem_burst_len_o = fill_active ? (LINE_WORDS - 1) : 8'd0;

    assign cpu_ready_o = load_hit ? `True :
                         fill_req_word_ready ? `True :
                         fill_last_word_release ? `True :
                         store_hit_enqueue ? `True :
                         ((bypass_current_req && mem_ready_i) ? `True : `False);

    always @ (*) begin
        mem_addr_o = active_addr;
        mem_wdata_o = active_wdata;
        mem_wmask_o = active_wmask;
        mem_req_o = `False;
        mem_we_o = active_we;
        cpu_rdata_o = mem_rdata_i;

        // A buffered write owns the external memory port, but it does not
        // prevent an independent CPU cache-hit load from reading the data RAM.
        if (load_hit == `True) begin
            cpu_rdata_o = load_hit_data;
        end

        if (fill_active == `True) begin
            mem_addr_o = fill_base_addr + {{30{1'b0}}, fill_word, 2'b00};
            mem_wdata_o = `ZeroWord;
            mem_wmask_o = 4'b0000;
            mem_req_o = `True;
            mem_we_o = `WriteDisable;
            if (fill_req_word_ready || fill_last_word_release) begin
                cpu_rdata_o = (fill_req_word == fill_word) ? mem_rdata_i : cache_data_rdata;
            end
        end else if (bypass_current_req == `True) begin
            mem_req_o = `True;
        end else if (store_buffer_owns_backend) begin
            mem_addr_o = store_buffer_addr[store_buffer_head];
            mem_wdata_o = store_buffer_wdata[store_buffer_head];
            mem_wmask_o = store_buffer_wmask[store_buffer_head];
            mem_req_o = `True;
            mem_we_o = `WriteEnable;
        end
    end

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            fill_active <= `False;
            hit_read_pending <= `False;
            fill_index <= {INDEX_BITS{1'b0}};
            fill_word <= {WORD_OFFSET_BITS{1'b0}};
            fill_req_word <= {WORD_OFFSET_BITS{1'b0}};
            fill_tag <= `ZeroWord;
            fill_base_addr <= `ZeroWord;
            fill_cpu_released <= `False;
            hit_pending_addr <= `ZeroWord;
            hit_pending_wdata <= `ZeroWord;
            hit_pending_wmask <= 4'b0000;
            hit_pending_we <= `WriteDisable;
            hit_pending_index <= {INDEX_BITS{1'b0}};
            hit_pending_word <= {WORD_OFFSET_BITS{1'b0}};
            store_buffer_head <= 1'b0;
            store_buffer_tail <= 1'b0;
            store_buffer_count <= 2'd0;
            store_buffer_addr[0] <= `ZeroWord;
            store_buffer_addr[1] <= `ZeroWord;
            store_buffer_wdata[0] <= `ZeroWord;
            store_buffer_wdata[1] <= `ZeroWord;
            store_buffer_wmask[0] <= 4'b0000;
            store_buffer_wmask[1] <= 4'b0000;
            req_active <= `False;
            req_addr <= `ZeroWord;
            req_wdata <= `ZeroWord;
            req_wmask <= 4'b0000;
            req_we <= `WriteDisable;
            for (idx = 0; idx < LINE_COUNT; idx = idx + 1) begin
                valid_array[idx] <= `False;
                tag_array[idx] <= `ZeroWord;
            end
        end else begin
            // An invalidate discards cached lines/fill metadata, but must not
            // discard a store already accepted architecturally. That write
            // remains owned by the buffer until its backend handshake.
            if (invalidate_i == `True) begin
                fill_active <= `False;
                hit_read_pending <= `False;
                fill_word <= {WORD_OFFSET_BITS{1'b0}};
                fill_cpu_released <= `False;
                hit_pending_we <= `WriteDisable;
                req_active <= `False;
                for (idx = 0; idx < LINE_COUNT; idx = idx + 1) begin
                    valid_array[idx] <= `False;
                    tag_array[idx] <= `ZeroWord;
                end
            end

            if (CACHE_RAM_READ_LATENCY != 0 && invalidate_i != `True) begin
                if (hit_read_pending == `True) begin
                    if (load_hit == `True || store_hit_enqueue == `True) begin
                        hit_read_pending <= `False;
                        hit_pending_we <= `WriteDisable;
                    end
                end else if (tag_hit == `True) begin
                    hit_read_pending <= `True;
                    hit_pending_addr <= active_addr;
                    hit_pending_wdata <= active_wdata;
                    hit_pending_wmask <= active_wmask;
                    hit_pending_we <= active_we;
                    hit_pending_index <= cpu_index;
                    hit_pending_word <= cpu_word;
                end
            end

            if (req_active == `True) begin
                if (cpu_ready_o == `True) begin
                    req_active <= `False;
                end
            end else if (cpu_req_i == `True && cpu_ready_o != `True) begin
                req_active <= `True;
                req_addr <= cpu_addr_i;
                req_wdata <= cpu_wdata_i;
                req_wmask <= cpu_wmask_i;
                req_we <= cpu_we_i;
            end

            // A full buffer blocks new store acceptance and all new backend
            // traffic; therefore this drain cannot be overtaken.
            if (store_hit_enqueue == `True) begin
                store_buffer_addr[store_buffer_tail] <= hit_req_addr;
                store_buffer_wdata[store_buffer_tail] <= hit_req_wdata;
                store_buffer_wmask[store_buffer_tail] <= hit_req_wmask;
                store_buffer_tail <= ~store_buffer_tail;
            end
            if (store_buffer_drain == `True) begin
                store_buffer_head <= ~store_buffer_head;
            end
            case ({store_hit_enqueue, store_buffer_drain})
                2'b10: store_buffer_count <= store_buffer_count + 1'b1;
                2'b01: store_buffer_count <= store_buffer_count - 1'b1;
                default: store_buffer_count <= store_buffer_count;
            endcase

            if (invalidate_i == `True) begin
                // The invalidation above owns fill metadata in this cycle.
            end else if (fill_active == `True) begin
                if (mem_ready_i == `True) begin
                    if (fill_word == fill_req_word) begin
                        fill_cpu_released <= `True;
                    end
                    if (fill_word == LINE_WORDS - 1) begin
                        valid_array[fill_index] <= `True;
                        tag_array[fill_index] <= fill_tag;
                        fill_active <= `False;
                        fill_word <= {WORD_OFFSET_BITS{1'b0}};
                        fill_cpu_released <= `False;
                    end else begin
                        fill_word <= fill_word + 1'b1;
                    end
                end
            end else if (load_miss == `True) begin
                fill_active <= `True;
                fill_index <= cpu_index;
                fill_word <= {WORD_OFFSET_BITS{1'b0}};
                fill_req_word <= cpu_word;
                fill_tag <= cpu_tag;
                fill_base_addr <= {active_addr[31:2 + WORD_OFFSET_BITS], {WORD_OFFSET_BITS{1'b0}}, 2'b00};
                fill_cpu_released <= `False;
                valid_array[cpu_index] <= `False;
            end
        end
    end

endmodule
