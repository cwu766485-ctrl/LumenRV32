`timescale 1 ns / 1 ps

`include "tb_cfg.vh"
`include "defines.v"

module rand_wait_ram(
    input wire clk,
    input wire rst,
    input wire req_i,
    input wire we_i,
    input wire[3:0] wmask_i,
    input wire[31:0] addr_i,
    input wire[31:0] data_i,
    output reg[31:0] data_o,
    output reg ready_o,
    output reg accept_pulse_o,
    output reg[1:0] accepted_wait_o
);

    reg[31:0] _ram[0:`MemNum - 1];
    reg busy_r;
    reg[1:0] wait_count_r;
    reg[31:0] addr_r;
    reg we_r;
    reg[3:0] wmask_r;
    reg[31:0] data_r;
    reg[1:0] sampled_wait_r;
    integer bi;

    always @ (*) begin
        if (rst == `RstEnable) begin
            data_o = `ZeroWord;
            ready_o = `False;
        end else begin
            data_o = (busy_r == `True && wait_count_r == 0) ? _ram[addr_r[31:2]] : `ZeroWord;
            ready_o = (busy_r == `True && wait_count_r == 0);
        end
    end

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            busy_r <= `False;
            wait_count_r <= 2'b00;
            addr_r <= `ZeroWord;
            we_r <= `WriteDisable;
            wmask_r <= 4'b0;
            data_r <= `ZeroWord;
            accept_pulse_o <= 1'b0;
            accepted_wait_o <= 2'b0;
            sampled_wait_r <= 2'b0;
        end else begin
            accept_pulse_o <= 1'b0;
            if (busy_r == `False) begin
                if (req_i == `True) begin
                    busy_r <= `True;
                    sampled_wait_r = $urandom() % 4;
                    wait_count_r <= sampled_wait_r;
                    addr_r <= addr_i;
                    we_r <= we_i;
                    wmask_r <= wmask_i;
                    data_r <= data_i;
                    accept_pulse_o <= 1'b1;
                    accepted_wait_o <= sampled_wait_r;
                end
            end else if (wait_count_r != 0) begin
                wait_count_r <= wait_count_r - 1'b1;
            end else begin
                if (we_r == `WriteEnable) begin
                    for (bi = 0; bi < 4; bi = bi + 1) begin
                        if (wmask_r[bi] == 1'b1) begin
                            _ram[addr_r[31:2]][bi * 8 +: 8] <= data_r[bi * 8 +: 8];
                        end
                    end
                end
                busy_r <= `False;
            end
        end
    end

endmodule

module dma_contention_tb;

    localparam [31:0] DMA_BASE = 32'h2000_5000;
    localparam [31:0] DMA_CTRL = DMA_BASE + 32'h00;
    localparam [31:0] DMA_STATUS = DMA_BASE + 32'h04;
    localparam [31:0] DMA_SRC = DMA_BASE + 32'h08;
    localparam [31:0] DMA_DST = DMA_BASE + 32'h0c;
    localparam [31:0] DMA_LEN = DMA_BASE + 32'h10;
    localparam [31:0] DMA_COUNT = DMA_BASE + 32'h14;

    localparam [31:0] RAM_BASE = 32'h1000_0000;
    localparam integer SRC_INDEX = 16;
    localparam integer DST_INDEX = 64;
    localparam integer CPU_INDEX = 160;

    reg clk;
    reg rst;

    reg[31:0] paddr;
    reg[31:0] pwdata;
    reg[3:0] pstrb;
    reg pwrite;
    reg psel;
    reg penable;
    wire[31:0] prdata;
    wire pready;
    wire pslverr;

    reg[31:0] cpu_addr;
    reg[31:0] cpu_wdata;
    reg[3:0] cpu_wmask;
    reg cpu_req;
    reg cpu_we;
    wire[31:0] cpu_rdata;
    wire cpu_ready;

    wire[31:0] dma_addr;
    wire[31:0] dma_wdata;
    wire[3:0] dma_wmask;
    wire dma_req;
    wire dma_we;
    wire[31:0] dma_rdata;
    wire dma_ready;
    wire dma_irq;

    wire[31:0] s0_addr;
    wire[31:0] s0_wdata;
    wire[3:0] s0_wmask;
    wire s0_req;
    wire s0_we;
    wire[31:0] s1_addr;
    wire[31:0] s1_wdata;
    wire[3:0] s1_wmask;
    wire s1_req;
    wire s1_we;
    wire s2_sel;
    wire[31:0] s2_addr;
    wire[31:0] s2_wdata;
    wire[3:0] s2_wmask;
    wire s2_req;
    wire s2_we;
    wire[31:0] s3_addr;
    wire[31:0] s3_wdata;
    wire[3:0] s3_wmask;
    wire s3_req;
    wire s3_we;
    wire[31:0] s4_addr;
    wire[31:0] s4_wdata;
    wire[3:0] s4_wmask;
    wire s4_req;
    wire s4_we;
    wire[31:0] s5_addr;
    wire[31:0] s5_wdata;
    wire[3:0] s5_wmask;
    wire s5_req;
    wire s5_we;
    wire[31:0] s6_addr;
    wire[31:0] s6_wdata;
    wire[3:0] s6_wmask;
    wire s6_req;
    wire s6_we;

    wire[31:0] s0_rdata;
    wire s0_ready;
    wire[31:0] s1_rdata;
    wire s1_ready;
    wire rand_accept;
    wire[1:0] rand_wait;

    reg[31:0] cpu_model[0:63];
    reg[31:0] dma_expected[0:15];
    reg[3:0] cov_dma_len_mask;
    reg[3:0] cov_ram_wait_mask;
    reg[1:0] cov_cpu_rw_mask;
    reg cov_partial_wmask_seen;
    integer seed;
    integer dummy_seed_init;
    integer i;
    integer timeout_cycles;
    integer cpu_ops;
    integer cpu_idx;
    integer dma_words;
    reg[31:0] rd_data;
    reg dma_done_seen;

    always #5 clk = ~clk;

    apb_perips u_apb_perips(
        .clk(clk),
        .rst(rst),
        .paddr_i(paddr),
        .pwdata_i(pwdata),
        .prdata_o(prdata),
        .pstrb_i(pstrb),
        .pwrite_i(pwrite),
        .psel_i(psel),
        .penable_i(penable),
        .pready_o(pready),
        .pslverr_o(pslverr),
        .perf_inst_i(`INST_NOP),
        .perf_hold_flag_i(`Hold_None),
        .perf_int_assert_i(`INT_DEASSERT),
        .perf_div_busy_i(`False),
        .timer_int_o(),
        .dma_int_o(dma_irq),
        .dma_addr_o(dma_addr),
        .dma_data_o(dma_wdata),
        .dma_wmask_o(dma_wmask),
        .dma_req_o(dma_req),
        .dma_we_o(dma_we),
        .dma_data_i(dma_rdata),
        .dma_ready_i(dma_ready),
        .uart_tx_pin(),
        .uart_rx_pin(1'b1),
        .gpio(),
        .spi_miso(1'b0),
        .spi_mosi(),
        .spi_ss(),
        .spi_clk()
    );

    dma_test_memory_arbiter u_memory_arbiter(
        .clk(clk),
        .rst(rst),
        .m0_addr_i(cpu_addr),
        .m0_data_i(cpu_wdata),
        .m0_wmask_i(cpu_wmask),
        .m0_data_o(cpu_rdata),
        .m0_req_i(cpu_req),
        .m0_we_i(cpu_we),
        .m0_ready_o(cpu_ready),
        .m1_addr_i(`ZeroWord),
        .m1_data_i(`ZeroWord),
        .m1_wmask_i(4'hf),
        .m1_data_o(),
        .m1_req_i(`False),
        .m1_we_i(`WriteDisable),
        .m1_ready_o(),
        .m2_addr_i(dma_addr),
        .m2_data_i(dma_wdata),
        .m2_wmask_i(dma_wmask),
        .m2_data_o(dma_rdata),
        .m2_req_i(dma_req),
        .m2_we_i(dma_we),
        .m2_ready_o(dma_ready),
        .m3_addr_i(`ZeroWord),
        .m3_data_i(`ZeroWord),
        .m3_wmask_i(4'hf),
        .m3_data_o(),
        .m3_req_i(`False),
        .m3_we_i(`WriteDisable),
        .m3_ready_o(),
        .s0_addr_o(s0_addr),
        .s0_data_o(s0_wdata),
        .s0_wmask_o(s0_wmask),
        .s0_req_o(s0_req),
        .s0_we_o(s0_we),
        .s0_data_i(s0_rdata),
        .s0_ready_i(s0_ready),
        .s1_addr_o(s1_addr),
        .s1_data_o(s1_wdata),
        .s1_wmask_o(s1_wmask),
        .s1_req_o(s1_req),
        .s1_we_o(s1_we),
        .s1_data_i(s1_rdata),
        .s1_ready_i(s1_ready),
        .s2_addr_o(s2_addr),
        .s2_data_o(s2_wdata),
        .s2_wmask_o(s2_wmask),
        .s2_req_o(s2_req),
        .s2_we_o(s2_we),
        .s2_data_i(`ZeroWord),
        .s2_ready_i(`True),
        .s2_sel_o(s2_sel),
        .s3_addr_o(s3_addr),
        .s3_data_o(s3_wdata),
        .s3_wmask_o(s3_wmask),
        .s3_req_o(s3_req),
        .s3_we_o(s3_we),
        .s3_data_i(`ZeroWord),
        .s3_ready_i(`True),
        .s4_addr_o(s4_addr),
        .s4_data_o(s4_wdata),
        .s4_wmask_o(s4_wmask),
        .s4_req_o(s4_req),
        .s4_we_o(s4_we),
        .s4_data_i(`ZeroWord),
        .s4_ready_i(`True),
        .s5_addr_o(s5_addr),
        .s5_data_o(s5_wdata),
        .s5_wmask_o(s5_wmask),
        .s5_req_o(s5_req),
        .s5_we_o(s5_we),
        .s5_data_i(`ZeroWord),
        .s5_ready_i(`True),
        .s6_addr_o(s6_addr),
        .s6_data_o(s6_wdata),
        .s6_wmask_o(s6_wmask),
        .s6_req_o(s6_req),
        .s6_we_o(s6_we),
        .s6_data_i(`ZeroWord),
        .s6_ready_i(`True),
        .hold_flag_o()
    );

    rom #(
        .WAIT_CYCLES(1)
    ) u_rom(
        .clk(clk),
        .rst(rst),
        .req_i(s0_req),
        .we_i(s0_we),
        .wmask_i(s0_wmask),
        .addr_i(s0_addr),
        .data_i(s0_wdata),
        .data_o(s0_rdata),
        .ready_o(s0_ready)
    );

    rand_wait_ram u_ram(
        .clk(clk),
        .rst(rst),
        .req_i(s1_req),
        .we_i(s1_we),
        .wmask_i(s1_wmask),
        .addr_i(s1_addr),
        .data_i(s1_wdata),
        .data_o(s1_rdata),
        .ready_o(s1_ready),
        .accept_pulse_o(rand_accept),
        .accepted_wait_o(rand_wait)
    );

    property apb_enable_requires_select;
        @(posedge clk) disable iff (rst == `RstEnable)
            penable |-> psel;
    endproperty

    property mem_onehot_slave;
        @(posedge clk) disable iff (rst == `RstEnable)
            $onehot0({s6_req, s5_req, s4_req, s3_req, s2_req, s1_req, s0_req});
    endproperty

    property dma_hold_stable;
        @(posedge clk) disable iff (rst == `RstEnable)
            (dma_req && !dma_ready) |=> (dma_req && $stable(dma_addr) && $stable(dma_wdata) && $stable(dma_wmask) && $stable(dma_we));
    endproperty

    assert property (apb_enable_requires_select) else begin
        $display("SVA failed: PENABLE without PSEL");
        $finish;
    end

    assert property (mem_onehot_slave) else begin
        $display("SVA failed: multiple memory interface slaves selected");
        $finish;
    end

    assert property (dma_hold_stable) else begin
        $display("SVA failed: DMA request changed while waiting");
        $finish;
    end

    task automatic apb_write(input [31:0] addr, input [31:0] data);
        begin
            @(posedge clk);
            paddr <= addr;
            pwdata <= data;
            pstrb <= 4'hf;
            pwrite <= 1'b1;
            psel <= 1'b1;
            penable <= 1'b0;
            @(posedge clk);
            penable <= 1'b1;
            while (pready !== 1'b1) @(posedge clk);
            @(posedge clk);
            paddr <= 32'h0;
            pwdata <= 32'h0;
            pstrb <= 4'h0;
            pwrite <= 1'b0;
            psel <= 1'b0;
            penable <= 1'b0;
        end
    endtask

    task automatic apb_read(input [31:0] addr, output [31:0] data);
        begin
            @(posedge clk);
            paddr <= addr;
            pwdata <= 32'h0;
            pstrb <= 4'hf;
            pwrite <= 1'b0;
            psel <= 1'b1;
            penable <= 1'b0;
            @(posedge clk);
            penable <= 1'b1;
            while (pready !== 1'b1) @(posedge clk);
            data = prdata;
            @(posedge clk);
            paddr <= 32'h0;
            pstrb <= 4'h0;
            psel <= 1'b0;
            penable <= 1'b0;
        end
    endtask

    task automatic cpu_write_word(input integer index, input [31:0] data, input [3:0] wmask);
        integer b;
        begin
            cpu_addr <= RAM_BASE + (index << 2);
            cpu_wdata <= data;
            cpu_wmask <= wmask;
            cpu_we <= `WriteEnable;
            cpu_req <= `True;
            @(posedge clk);
            while (cpu_ready !== `True) @(posedge clk);
            cpu_req <= `False;
            cpu_we <= `WriteDisable;
            cov_cpu_rw_mask[1] <= 1'b1;
            if (wmask != 4'hf) begin
                cov_partial_wmask_seen <= 1'b1;
            end
            for (b = 0; b < 4; b = b + 1) begin
                if (wmask[b]) begin
                    cpu_model[index - CPU_INDEX][b * 8 +: 8] = data[b * 8 +: 8];
                end
            end
        end
    endtask

    task automatic cpu_read_word(input integer index);
        begin
            cpu_addr <= RAM_BASE + (index << 2);
            cpu_wdata <= 32'h0;
            cpu_wmask <= 4'hf;
            cpu_we <= `WriteDisable;
            cpu_req <= `True;
            @(posedge clk);
            while (cpu_ready !== `True) @(posedge clk);
            if (cpu_rdata !== cpu_model[index - CPU_INDEX]) begin
                $display("CPU scoreboard mismatch idx=%0d got=0x%08x exp=0x%08x", index, cpu_rdata, cpu_model[index - CPU_INDEX]);
                $finish;
            end
            cpu_req <= `False;
            cov_cpu_rw_mask[0] <= 1'b1;
        end
    endtask

    initial begin
        clk = 1'b0;
        rst = `RstEnable;
        paddr = 32'h0;
        pwdata = 32'h0;
        pstrb = 4'h0;
        pwrite = 1'b0;
        psel = 1'b0;
        penable = 1'b0;
        cpu_addr = 32'h0;
        cpu_wdata = 32'h0;
        cpu_wmask = 4'hf;
        cpu_req = `False;
        cpu_we = `WriteDisable;
        cov_dma_len_mask = 4'b0;
        cov_ram_wait_mask = 4'b0;
        cov_cpu_rw_mask = 2'b0;
        cov_partial_wmask_seen = 1'b0;
        dma_done_seen = 1'b0;
`ifdef TB_SEED
        seed = `TB_SEED;
`else
        seed = 32'h2026_0329;
`endif
        dummy_seed_init = $urandom(seed);

        repeat (5) @(posedge clk);
        rst = `RstDisable;
        repeat (2) @(posedge clk);

        dma_words = ($urandom() % 8) + 1;
        if (dma_words == 1) cov_dma_len_mask[0] = 1'b1;
        else if (dma_words == 2) cov_dma_len_mask[1] = 1'b1;
        else if (dma_words <= 4) cov_dma_len_mask[2] = 1'b1;
        else cov_dma_len_mask[3] = 1'b1;

        for (i = 0; i < dma_words; i = i + 1) begin
            dma_expected[i] = $urandom();
            u_ram._ram[SRC_INDEX + i] = dma_expected[i];
            u_ram._ram[DST_INDEX + i] = 32'hdead_0000 + i;
        end
        for (i = 0; i < 64; i = i + 1) begin
            cpu_model[i] = $urandom();
            u_ram._ram[CPU_INDEX + i] = cpu_model[i];
        end

        apb_write(DMA_SRC, RAM_BASE + (SRC_INDEX << 2));
        apb_write(DMA_DST, RAM_BASE + (DST_INDEX << 2));
        apb_write(DMA_LEN, dma_words);
        apb_write(DMA_CTRL, 32'h3);

        cpu_ops = 0;
        while (!dma_done_seen && cpu_ops < 32) begin
            cpu_idx = CPU_INDEX + ($urandom() % 64);
            if (($urandom() & 1'b1) == 1'b1) begin
                cpu_write_word(cpu_idx, $urandom(), (($urandom() & 1'b1) == 1'b1) ? 4'hf : 4'h3);
            end else begin
                cpu_read_word(cpu_idx);
            end
            cpu_ops = cpu_ops + 1;
            apb_read(DMA_STATUS, rd_data);
            if (rd_data[1]) begin
                dma_done_seen = 1'b1;
            end
        end

        timeout_cycles = 0;
        while (!dma_done_seen && timeout_cycles < 4000) begin
            @(posedge clk);
            timeout_cycles = timeout_cycles + 1;
            apb_read(DMA_STATUS, rd_data);
            if (rd_data[1]) begin
                dma_done_seen = 1'b1;
            end
        end
        if (!dma_done_seen) begin
            $display("DMA contention timeout");
            $finish;
        end

        apb_read(DMA_COUNT, rd_data);
        if (rd_data != dma_words) begin
            $display("DMA contention count mismatch got=%0d exp=%0d", rd_data, dma_words);
            $finish;
        end

        for (i = 0; i < dma_words; i = i + 1) begin
            if (u_ram._ram[DST_INDEX + i] !== dma_expected[i]) begin
                $display("DMA contention data mismatch idx=%0d got=0x%08x exp=0x%08x", i, u_ram._ram[DST_INDEX + i], dma_expected[i]);
                $finish;
            end
        end
        for (i = 0; i < 64; i = i + 1) begin
            if (u_ram._ram[CPU_INDEX + i] !== cpu_model[i]) begin
                $display("CPU mirror mismatch idx=%0d got=0x%08x exp=0x%08x", i, u_ram._ram[CPU_INDEX + i], cpu_model[i]);
                $finish;
            end
        end

        if (cov_cpu_rw_mask != 2'b11) begin
            $display("Coverage failure: CPU RW mask=0x%0x", cov_cpu_rw_mask);
            $finish;
        end
        if (!cov_partial_wmask_seen) begin
            $display("Coverage failure: partial wmask not seen");
            $finish;
        end
        if (cov_ram_wait_mask != 4'b1111) begin
            $display("Coverage failure: RAM wait mask=0x%0x", cov_ram_wait_mask);
            $finish;
        end

        $display("DMA_CONTENTION_PASS words=%0d cpu_ops=%0d wait_mask=0x%0x seed=%0d", dma_words, cpu_ops, cov_ram_wait_mask, seed);
        $finish;
    end

    always @ (posedge clk) begin
        if (rst == `RstDisable && rand_accept) begin
            cov_ram_wait_mask[rand_wait] <= 1'b1;
        end
    end

    initial begin
        #4000000;
        $display("DMA_CONTENTION_TIMEOUT");
        $finish;
    end

endmodule
