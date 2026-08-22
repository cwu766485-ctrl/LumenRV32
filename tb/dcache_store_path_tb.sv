`timescale 1 ns / 1 ps

`include "../rtl/core/defines.v"

// Standalone D-Cache store-path contract test.
//
// The memory model accepts each request after two wait cycles.  This makes the
// test exercise request stability and write-through completion, rather than
// only the zero-wait path used by a simple combinational memory model.
module dcache_store_path_tb;

    reg clk;
    reg rst;
    reg[31:0] cpu_addr;
    reg[31:0] cpu_wdata;
    reg[3:0] cpu_wmask;
    reg cpu_req;
    reg cpu_we;
    reg invalidate;
    wire[31:0] cpu_rdata;
    wire cpu_ready;
    wire perf_store_buffer_enqueue;
    wire perf_store_buffer_full_stall;
    wire perf_store_buffer_drain;

    wire[31:0] mem_addr;
    wire[31:0] mem_wdata;
    wire[3:0] mem_wmask;
    wire mem_req;
    wire mem_we;
    wire[7:0] mem_burst_len;
    wire[31:0] mem_rdata;
    wire mem_ready;

    reg[31:0] mem[0:1023];
    integer wait_count;
    integer i;
    integer timeout;
    integer ready_cycles;
    reg[31:0] read_data;

    dcache dut(
        .clk(clk),
        .rst(rst),
        .cpu_addr_i(cpu_addr),
        .cpu_wdata_i(cpu_wdata),
        .cpu_wmask_i(cpu_wmask),
        .cpu_req_i(cpu_req),
        .cpu_we_i(cpu_we),
        .invalidate_i(invalidate),
        .cpu_rdata_o(cpu_rdata),
        .cpu_ready_o(cpu_ready),
        .perf_load_hit_o(),
        .perf_load_miss_o(),
        .perf_store_hit_o(),
        .perf_store_miss_o(),
        .perf_load_miss_stall_o(),
        .perf_store_wait_o(),
        .perf_store_buffer_enqueue_o(perf_store_buffer_enqueue),
        .perf_store_buffer_full_stall_o(perf_store_buffer_full_stall),
        .perf_store_buffer_drain_o(perf_store_buffer_drain),
        .mem_addr_o(mem_addr),
        .mem_wdata_o(mem_wdata),
        .mem_wmask_o(mem_wmask),
        .mem_req_o(mem_req),
        .mem_we_o(mem_we),
        .mem_burst_len_o(mem_burst_len),
        .mem_rdata_i(mem_rdata),
        .mem_ready_i(mem_ready)
    );

    always #5 clk = ~clk;

    // Read data is combinational; a request is accepted on the third active
    // memory cycle.  Writes are committed only at that acceptance edge.
    assign mem_rdata = mem[mem_addr[11:2]];
    assign mem_ready = mem_req && (wait_count == 2);

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            wait_count <= 0;
        end else if (!mem_req) begin
            wait_count <= 0;
        end else if (mem_ready) begin
            wait_count <= 0;
            if (mem_we == `WriteEnable) begin
                if (mem_wmask[0]) mem[mem_addr[11:2]][7:0]   <= mem_wdata[7:0];
                if (mem_wmask[1]) mem[mem_addr[11:2]][15:8]  <= mem_wdata[15:8];
                if (mem_wmask[2]) mem[mem_addr[11:2]][23:16] <= mem_wdata[23:16];
                if (mem_wmask[3]) mem[mem_addr[11:2]][31:24] <= mem_wdata[31:24];
            end
        end else begin
            wait_count <= wait_count + 1;
        end
    end

    task automatic store_word;
        input[31:0] addr;
        input[31:0] data;
        input[3:0] mask;
        begin
            @(negedge clk);
            cpu_addr = addr;
            cpu_wdata = data;
            cpu_wmask = mask;
            cpu_we = `WriteEnable;
            cpu_req = `True;
            timeout = 0;
            while (cpu_ready != `True) begin
                @(posedge clk);
                timeout = timeout + 1;
                if (timeout > 40) $fatal(1, "store timeout at %h", addr);
            end
            @(negedge clk);
            cpu_req = `False;
            cpu_we = `WriteDisable;
        end
    endtask

    task automatic load_word;
        input[31:0] addr;
        output[31:0] data;
        begin
            @(negedge clk);
            cpu_addr = addr;
            cpu_wdata = 32'b0;
            cpu_wmask = 4'b0;
            cpu_we = `WriteDisable;
            cpu_req = `True;
            timeout = 0;
            while (cpu_ready != `True) begin
                @(posedge clk);
                timeout = timeout + 1;
                if (timeout > 80) $fatal(1, "load timeout at %h", addr);
            end
            data = cpu_rdata;
            @(negedge clk);
            cpu_req = `False;
            while (dut.fill_active == `True) begin
                @(posedge clk);
            end
        end
    endtask

    task automatic load_miss_early_restart;
        input[31:0] addr;
        input[31:0] expected;
        begin
            @(negedge clk);
            cpu_addr = addr;
            cpu_wdata = 32'b0;
            cpu_wmask = 4'b0;
            cpu_we = `WriteDisable;
            cpu_req = `True;
            timeout = 0;
            ready_cycles = 0;
            while (cpu_ready != `True) begin
                @(posedge clk);
                timeout = timeout + 1;
                ready_cycles = ready_cycles + 1;
                if (timeout > 80) $fatal(1, "early-restart load timeout at %h", addr);
            end
            if (dut.fill_active !== `True) begin
                $fatal(1, "load miss did not restart before full line completion");
            end
            expect_word(cpu_rdata, expected, "critical word returned first");
            @(negedge clk);
            cpu_req = `False;
            while (dut.fill_active == `True) begin
                @(posedge clk);
            end
        end
    endtask

    task automatic early_restart_store_same_line;
        input[31:0] load_addr;
        input[31:0] load_expected;
        input[31:0] store_addr;
        input[31:0] store_data;
        reg[31:0] data;
        begin
            // Start a miss whose critical word returns before the remainder
            // of the line.  The store is deliberately issued while fill is
            // still active, reproducing CPU code that resumes immediately
            // after an early restart.
            @(negedge clk);
            cpu_addr = load_addr;
            cpu_wdata = 32'b0;
            cpu_wmask = 4'b0;
            cpu_we = `WriteDisable;
            cpu_req = `True;
            timeout = 0;
            while (cpu_ready != `True) begin
                @(posedge clk);
                timeout = timeout + 1;
                if (timeout > 80) $fatal(1, "early-restart setup timeout at %h", load_addr);
            end
            expect_word(cpu_rdata, load_expected, "early-restart source word");
            if (dut.fill_active !== `True) begin
                $fatal(1, "line completed before same-line store was issued");
            end

            @(negedge clk);
            cpu_addr = store_addr;
            cpu_wdata = store_data;
            cpu_wmask = 4'b1111;
            cpu_we = `WriteEnable;
            cpu_req = `True;
            timeout = 0;
            while (cpu_ready != `True) begin
                @(posedge clk);
                timeout = timeout + 1;
                if (timeout > 80) $fatal(1, "same-line store stalled indefinitely at %h", store_addr);
            end
            @(negedge clk);
            cpu_req = `False;
            cpu_we = `WriteDisable;

            // The store must update the valid cache line, not only backing
            // memory.  A dependent load therefore sees the new value.
            load_word(store_addr, data);
            expect_word(data, store_data, "store during refill updated cache line");
        end
    endtask

    task automatic expect_word;
        input[31:0] actual;
        input[31:0] expected;
        input[255:0] name;
        begin
            if (actual !== expected) begin
                $fatal(1, "%0s: expected %h, got %h", name, expected, actual);
            end
        end
    endtask

    task automatic cached_store_then_immediate_load;
        input[31:0] addr;
        input[31:0] data;
        begin
            // The preceding load has made this line valid. This store must be
            // accepted without waiting for the two-cycle backend response.
            @(negedge clk);
            cpu_addr = addr;
            cpu_wdata = data;
            cpu_wmask = 4'b1111;
            cpu_we = `WriteEnable;
            cpu_req = `True;
`ifdef CacheUseBlockRam
            // Synchronous BRAM needs one cycle to return the hit word before
            // the masked cache update and store-buffer enqueue can complete.
            @(posedge clk);
            @(negedge clk);
`endif
            #1;
            if (cpu_ready !== `True) $fatal(1, "cache-hit store was not enqueued");
            @(posedge clk);

            // The buffer now owns the backend write. A dependent same-word
            // load must observe the updated cache word immediately, without
            // waiting for write-through completion.
            @(negedge clk);
            cpu_addr = addr;
            cpu_wdata = 32'b0;
            cpu_wmask = 4'b0;
            cpu_we = `WriteDisable;
            cpu_req = `True;
`ifdef CacheUseBlockRam
            @(posedge clk);
            @(negedge clk);
`endif
            #1;
            if (cpu_ready !== `True) $fatal(1, "dependent cache-hit load stalled behind store buffer");
            expect_word(cpu_rdata, data, "store-buffer same-word forwarding via updated cache");
            @(negedge clk);
            cpu_req = `False;
        end
    endtask

    task automatic two_entry_queue_ordering;
        begin
            // The 0x20 cache line is already valid. Enqueue two writes on
            // consecutive cycles, then prove a third write sees queue-full
            // backpressure until the head entry drains.
            @(negedge clk);
            cpu_addr = 32'h10000020; cpu_wdata = 32'h11111111; cpu_wmask = 4'b1111;
            cpu_we = `WriteEnable; cpu_req = `True;
`ifdef CacheUseBlockRam
            @(posedge clk); @(negedge clk);
`endif
            #1; if (cpu_ready !== `True) $fatal(1, "first queue entry rejected");
            @(posedge clk);
            @(negedge clk);
            cpu_addr = 32'h10000024; cpu_wdata = 32'h22222222;
`ifdef CacheUseBlockRam
            @(posedge clk); @(negedge clk);
`endif
            #1; if (cpu_ready !== `True) $fatal(1, "second queue entry rejected");
            @(posedge clk);
            @(negedge clk);
            cpu_addr = 32'h10000028; cpu_wdata = 32'h33333333;
`ifdef CacheUseBlockRam
            @(posedge clk); @(negedge clk);
`endif
            #1;
`ifndef CacheUseBlockRam
            if (cpu_ready !== `False) $fatal(1, "third store bypassed full queue");
`endif
            // In BRAM mode the two hit-lookup cycles give the backend enough
            // time to drain the head entry, so the third store may already be
            // accepted. FIFO ordering is checked against memory below.
            timeout = 0;
            while (cpu_ready != `True) begin
                @(posedge clk);
                timeout = timeout + 1;
                if (timeout > 40) $fatal(1, "full queue did not drain");
            end
            @(negedge clk);
            cpu_req = `False; cpu_we = `WriteDisable;
            repeat (10) @(posedge clk);
            expect_word(mem[10'h008], 32'h11111111, "queue FIFO word 0");
            expect_word(mem[10'h009], 32'h22222222, "queue FIFO word 1");
            expect_word(mem[10'h00a], 32'h33333333, "queue FIFO word 2");
        end
    endtask

    initial begin
        clk = 1'b0;
        rst = `RstEnable;
        cpu_addr = 32'b0;
        cpu_wdata = 32'b0;
        cpu_wmask = 4'b0;
        cpu_req = `False;
        cpu_we = `WriteDisable;
        invalidate = `False;
        wait_count = 0;
        for (i = 0; i < 1024; i = i + 1) begin
            mem[i] = 32'h00000000;
        end

        repeat (3) @(posedge clk);
        rst = `RstDisable;

        // Critical-word-first / early-restart load miss.  The requested word is
        // offset 3 in the line, so cpu_ready must assert before the full
        // eight-word line has been filled.
        mem[10'h010] = 32'h10000040;
        mem[10'h011] = 32'h10000044;
        mem[10'h012] = 32'h10000048;
        mem[10'h013] = 32'h1000004c;
        mem[10'h014] = 32'h10000050;
        mem[10'h015] = 32'h10000054;
        mem[10'h016] = 32'h10000058;
        mem[10'h017] = 32'h1000005c;
        load_miss_early_restart(32'h1000004c, 32'h1000004c);
        load_word(32'h10000040, read_data);
        expect_word(read_data, 32'h10000040, "early restart line later valid");

        // A store immediately after critical-word-first restart targets a
        // different word in the same line.  It must be accepted only after
        // refill completion, then update both cache-visible state and the
        // ordered write-through path.
        mem[10'h018] = 32'h20000060;
        mem[10'h019] = 32'h20000064;
        mem[10'h01a] = 32'h20000068;
        mem[10'h01b] = 32'h2000006c;
        mem[10'h01c] = 32'h20000070;
        mem[10'h01d] = 32'h20000074;
        mem[10'h01e] = 32'h20000078;
        mem[10'h01f] = 32'h2000007c;
        early_restart_store_same_line(32'h1000006c, 32'h2000006c,
                                      32'h10000060, 32'hC0DEC0DE);

        // Cacheable RAM: full store, partial-byte overwrite, and load after a
        // line fill.  Expected final word is AABB_22DD.
        store_word(32'h10000020, 32'hAABBCCDD, 4'b1111);
        store_word(32'h10000020, 32'h00002200, 4'b0010);
        load_word(32'h10000020, read_data);
        expect_word(read_data, 32'hAABB22DD, "cached full+byte store");
        // Allow the fill-valid nonblocking update to settle before issuing the
        // cache-hit store sequence below.
        @(posedge clk);

        // A cache-hit store is accepted into the buffer. Its dependent load
        // must not wait for write-through drain.
        cached_store_then_immediate_load(32'h10000020, 32'h55667788);
        repeat (6) @(posedge clk);
        expect_word(mem[10'h008], 32'h55667788, "buffered store drained to memory");

        two_entry_queue_ordering();
        // Refill the test line after the ordering sequence before testing
        // invalidate-during-drain below.
        load_word(32'h10000020, read_data);

        // FENCE.I drives invalidate_i. It may arrive after the architectural
        // store has been accepted but before its backend write completes.
        @(negedge clk);
        cpu_addr = 32'h10000020;
        cpu_wdata = 32'hCAFEBABE;
        cpu_wmask = 4'b1111;
        cpu_we = `WriteEnable;
        cpu_req = `True;
`ifdef CacheUseBlockRam
        @(posedge clk); @(negedge clk);
`endif
        #1;
        if (cpu_ready !== `True) $fatal(1, "cache-hit store before invalidate was not accepted");
        @(posedge clk);
        @(negedge clk);
        cpu_req = `False;
        cpu_we = `WriteDisable;
        invalidate = `True;
        @(posedge clk);
        @(negedge clk);
        invalidate = `False;
        repeat (6) @(posedge clk);
        expect_word(mem[10'h008], 32'hCAFEBABE, "invalidate preserved buffered store");

        // Invalidate discards only cache metadata; write-through backing memory
        // must retain the result and refill to the same architectural value.
        @(negedge clk);
        invalidate = `True;
        @(negedge clk);
        invalidate = `False;
        load_word(32'h10000020, read_data);
        expect_word(read_data, 32'hCAFEBABE, "invalidate then refill");

        // Non-cacheable window must preserve the same byte-mask semantics and
        // never rely on a cache line allocation.
        store_word(32'h20000040, 32'h11223344, 4'b1111);
        store_word(32'h20000040, 32'hAA000000, 4'b1000);
        load_word(32'h20000040, read_data);
        expect_word(read_data, 32'hAA223344, "uncached store ordering");

        $display("DCACHE_STORE_PATH_TB_PASS");
        $finish;
    end
endmodule
