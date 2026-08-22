`timescale 1 ns / 1 ps

`include "tb_cfg.vh"
`include "defines.v"

module dma_spi_stream_tb;

    localparam [31:0] DMA_CTRL = 32'h0000_0000;
    localparam [31:0] DMA_STATUS = 32'h0000_0004;
    localparam [31:0] DMA_SRC = 32'h0000_0008;
    localparam [31:0] DMA_DST = 32'h0000_000c;
    localparam [31:0] DMA_LEN = 32'h0000_0010;
    localparam [31:0] DMA_COUNT = 32'h0000_0014;
    localparam [31:0] DMA_AUX = 32'h0000_0018;

    localparam [31:0] SPI_CTRL = 32'h2000_3000;
    localparam [31:0] SPI_DATA = 32'h2000_3004;
    localparam [31:0] RAM_BASE = 32'h1000_0000;
    localparam [31:0] SPI_CTRL_TEMPLATE = 32'h0000_0208;

    reg clk;
    reg rst;
    reg spi_miso;

    reg cfg_we;
    reg[31:0] cfg_addr;
    reg[31:0] cfg_wdata;
    wire[31:0] cfg_rdata;

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
    wire[31:0] s2_addr;
    wire[31:0] s2_wdata;
    wire[3:0] s2_wmask;
    wire s2_req;
    wire s2_we;
    wire s2_sel;
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
    wire[31:0] s2_rdata;
    wire s2_ready;
    wire[31:0] spi_data_o;

    wire spi_mosi;
    wire spi_ss;
    wire spi_clk;
    wire[4:0] dma_state = u_dma.state_r;
    wire[31:0] dma_remaining = u_dma.remaining_r;
    wire[31:0] dma_count_dbg = u_dma.moved_count_r;
    wire dma_done_dbg = u_dma.done_r;
    wire dma_error_dbg = u_dma.error_r;
    wire dma_fixed_src_dbg = u_dma.fixed_src_r;
    wire dma_fixed_dst_dbg = u_dma.fixed_dst_r;
    wire dma_byte_mode_dbg = u_dma.byte_mode_r;
    wire dma_spi_mode_dbg = u_dma.spi_stream_r;

    reg[7:0] tx_expected[0:15];
    reg[7:0] tx_seen[0:31];
    reg[7:0] rx_expected[0:15];
    reg[7:0] slave_shift_in;
    reg[7:0] slave_shift_out;
    integer tx_expected_count;
    integer rx_expected_count;
    integer tx_seen_count;
    integer rx_launch_count;
    integer wait_cycles;
    integer i;
    integer seed;
    integer dummy_seed_init;
    integer miso_bit_index;
    reg rx_mode;
    reg[31:0] rd_data;

    always #5 clk = ~clk;

    assign s2_rdata = spi_data_o;
    assign s2_ready = `True;

    dma u_dma(
        .clk(clk),
        .rst(rst),
        .we_i(cfg_we),
        .addr_i(cfg_addr),
        .data_i(cfg_wdata),
        .data_o(cfg_rdata),
        .mem_addr_o(dma_addr),
        .mem_data_o(dma_wdata),
        .mem_wmask_o(dma_wmask),
        .mem_req_o(dma_req),
        .mem_we_o(dma_we),
        .mem_data_i(dma_rdata),
        .mem_ready_i(dma_ready),
        .irq_o(dma_irq)
    );

    dma_test_memory_arbiter u_memory_arbiter(
        .clk(clk),
        .rst(rst),
        .m0_addr_i(`ZeroWord),
        .m0_data_i(`ZeroWord),
        .m0_wmask_i(4'hf),
        .m0_data_o(),
        .m0_req_i(`False),
        .m0_we_i(`WriteDisable),
        .m0_ready_o(),
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
        .s2_data_i(s2_rdata),
        .s2_ready_i(s2_ready),
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

    ram #(
        .WAIT_CYCLES(2)
    ) u_ram(
        .clk(clk),
        .rst(rst),
        .req_i(s1_req),
        .we_i(s1_we),
        .wmask_i(s1_wmask),
        .addr_i(s1_addr),
        .data_i(s1_wdata),
        .data_o(s1_rdata),
        .ready_o(s1_ready)
    );

    spi u_spi(
        .clk(clk),
        .rst(rst),
        .data_i(s2_wdata),
        .addr_i({20'h0, s2_addr[11:0]}),
        .we_i(s2_req & s2_we),
        .data_o(spi_data_o),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .spi_ss(spi_ss),
        .spi_clk(spi_clk)
    );

    task automatic cfg_write(input [31:0] addr, input [31:0] data);
        begin
            @(posedge clk);
            cfg_addr <= addr;
            cfg_wdata <= data;
            cfg_we <= `WriteEnable;
            @(posedge clk);
            cfg_we <= `WriteDisable;
            cfg_addr <= 32'h0;
            cfg_wdata <= 32'h0;
        end
    endtask

    task automatic cfg_read(input [31:0] addr, output [31:0] data);
        begin
            cfg_addr <= addr;
            #1;
            data = cfg_rdata;
            @(posedge clk);
            cfg_addr <= 32'h0;
        end
    endtask

    task automatic wait_dma_done;
        begin
            wait_cycles = 0;
            rd_data = 32'h0;
            while (wait_cycles < 8000 && rd_data[1] != 1'b1) begin
                @(posedge clk);
                wait_cycles = wait_cycles + 1;
                cfg_read(DMA_STATUS, rd_data);
            end
            if (wait_cycles >= 8000) begin
                $display("DMA SPI timeout state=%0d remaining=%0d moved=%0d tx_seen=%0d rx_launch=%0d done=%0d error=%0d fixed_src=%0d fixed_dst=%0d byte=%0d spi=%0d status=0x%08x",
                    dma_state, dma_remaining, dma_count_dbg, tx_seen_count, rx_launch_count,
                    dma_done_dbg, dma_error_dbg, dma_fixed_src_dbg, dma_fixed_dst_dbg, dma_byte_mode_dbg, dma_spi_mode_dbg, cfg_rdata);
                $finish;
            end
            if (rd_data[2] != 1'b1) begin
                $display("DMA SPI expected irq_pending, got status=0x%08x", rd_data);
                $finish;
            end
            cfg_write(DMA_STATUS, 32'h6);
        end
    endtask

    always @ (posedge u_spi.en or negedge rst) begin
        if (rst == `RstEnable) begin
            slave_shift_in <= 8'h00;
            slave_shift_out <= 8'hff;
            miso_bit_index <= 7;
            spi_miso <= 1'b1;
        end else begin
            slave_shift_in <= 8'h00;
            miso_bit_index <= 7;
            if (rx_mode && rx_launch_count < rx_expected_count) begin
                slave_shift_out <= rx_expected[rx_launch_count];
                spi_miso <= rx_expected[rx_launch_count][7];
                rx_launch_count <= rx_launch_count + 1;
            end else begin
                slave_shift_out <= 8'hff;
                spi_miso <= 1'b1;
            end
        end
    end

    always @ (posedge spi_clk) begin
        if (rst == `RstDisable && u_spi.en == 1'b1 && spi_ss == 1'b0) begin
            slave_shift_in <= {slave_shift_in[6:0], spi_mosi};
        end
    end

    always @ (negedge spi_clk) begin
        if (rst == `RstDisable && u_spi.en == 1'b1 && spi_ss == 1'b0) begin
            if (miso_bit_index > 0) begin
                miso_bit_index <= miso_bit_index - 1;
                spi_miso <= slave_shift_out[miso_bit_index - 1];
            end
        end
    end

    always @ (posedge u_spi.done) begin
        if (rst == `RstDisable) begin
            tx_seen[tx_seen_count] <= slave_shift_in;
            tx_seen_count <= tx_seen_count + 1;
        end
    end

    initial begin
        clk = 1'b0;
        rst = `RstEnable;
        spi_miso = 1'b1;
        cfg_we = `WriteDisable;
        cfg_addr = 32'h0;
        cfg_wdata = 32'h0;
        tx_expected_count = 0;
        rx_expected_count = 0;
        tx_seen_count = 0;
        rx_launch_count = 0;
        rx_mode = 1'b0;
`ifdef TB_SEED
        seed = `TB_SEED;
`else
        seed = 32'h3141_5926;
`endif
        dummy_seed_init = $urandom(seed);

        repeat (5) @(posedge clk);
        rst = `RstDisable;
        repeat (2) @(posedge clk);

        cfg_write(DMA_AUX, SPI_CTRL_TEMPLATE);

        tx_expected_count = 6;
        for (i = 0; i < tx_expected_count; i = i + 1) begin
            tx_expected[i] = $urandom();
        end
        u_ram._ram[0] = {tx_expected[3], tx_expected[2], tx_expected[1], tx_expected[0]};
        u_ram._ram[1] = {16'h0000, tx_expected[5], tx_expected[4]};

        cfg_write(DMA_SRC, RAM_BASE);
        cfg_write(DMA_DST, SPI_DATA);
        cfg_write(DMA_LEN, tx_expected_count);
        cfg_write(DMA_CTRL, 32'h3b);
        wait_dma_done();

        while (tx_seen_count < tx_expected_count) @(posedge clk);
        for (i = 0; i < tx_expected_count; i = i + 1) begin
            if (tx_seen[i] !== tx_expected[i]) begin
                $display("SPI TX DMA mismatch idx=%0d got=0x%02x exp=0x%02x", i, tx_seen[i], tx_expected[i]);
                $finish;
            end
        end

        rx_expected_count = 5;
        for (i = 0; i < rx_expected_count; i = i + 1) begin
            rx_expected[i] = $urandom();
        end
        rx_mode = 1'b1;
        tx_seen_count = 0;
        rx_launch_count = 0;

        cfg_write(DMA_SRC, SPI_DATA);
        cfg_write(DMA_DST, RAM_BASE + 32'h40);
        cfg_write(DMA_LEN, rx_expected_count);
        cfg_write(DMA_CTRL, 32'h37);
        wait_dma_done();

        for (i = 0; i < rx_expected_count; i = i + 1) begin
            if (u_ram._ram[16 + (i >> 2)][8 * (i[1:0]) +: 8] !== rx_expected[i]) begin
                $display("SPI RX DMA mismatch idx=%0d got=0x%02x exp=0x%02x",
                    i,
                    u_ram._ram[16 + (i >> 2)][8 * (i[1:0]) +: 8],
                    rx_expected[i]);
                $finish;
            end
        end

        cfg_read(DMA_COUNT, rd_data);
        if (rd_data != rx_expected_count) begin
            $display("SPI RX DMA count mismatch got=%0d exp=%0d", rd_data, rx_expected_count);
            $finish;
        end

        $display("DMA_SPI_STREAM_PASS tx=%0d rx=%0d seed=%0d", tx_expected_count, rx_expected_count, seed);
        $finish;
    end

    initial begin
        #6000000;
        $display("DMA_SPI_STREAM_TIMEOUT");
        $finish;
    end

endmodule
