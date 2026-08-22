`timescale 1 ns / 1 ps

`include "tb_cfg.vh"
`include "defines.v"

module dma_extmem_tb;

    localparam [31:0] DMA_BASE = 32'h2000_5000;
    localparam [31:0] DMA_CTRL = DMA_BASE + 32'h00;
    localparam [31:0] DMA_STATUS = DMA_BASE + 32'h04;
    localparam [31:0] DMA_SRC = DMA_BASE + 32'h08;
    localparam [31:0] DMA_DST = DMA_BASE + 32'h0c;
    localparam [31:0] DMA_LEN = DMA_BASE + 32'h10;
    localparam [31:0] DMA_COUNT = DMA_BASE + 32'h14;

    localparam [31:0] RAM_BASE = 32'h1000_0000;
    localparam [31:0] EXTMEM_BASE = 32'h3000_0000;

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
    wire[31:0] s3_rdata;
    wire s3_ready;

    wire ext_backend_req;
    wire ext_backend_we;
    wire[31:0] ext_backend_addr;
    wire[31:0] ext_backend_wdata;
    wire[3:0] ext_backend_wmask;

    integer seed;
    integer case_count;
    integer i;
    integer j;
    integer words;
    integer src_index;
    integer dst_index;
    integer timeout_cycles;
    integer pass_count;
    integer irq_seen;
    integer done_seen;
    integer direction_cov_mask;
    integer word_cov_mask;
    integer dummy_seed_init;
    reg[31:0] rd_data;
    reg[31:0] expected_word[0:31];

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
        .s2_data_i(`ZeroWord),
        .s2_ready_i(`True),
        .s2_sel_o(s2_sel),
        .s3_addr_o(s3_addr),
        .s3_data_o(s3_wdata),
        .s3_wmask_o(s3_wmask),
        .s3_req_o(s3_req),
        .s3_we_o(s3_we),
        .s3_data_i(s3_rdata),
        .s3_ready_i(s3_ready),
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

`ifdef TB_RAM_WAIT
    localparam integer RAM_WAIT = `TB_RAM_WAIT;
`else
    localparam integer RAM_WAIT = 2;
`endif

`ifdef TB_EXT_WAIT
    localparam integer EXT_WAIT = `TB_EXT_WAIT;
`else
    localparam integer EXT_WAIT = 5;
`endif

    ram #(
        .WAIT_CYCLES(RAM_WAIT)
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

    external_memory_wrapper #(
        .USE_MODEL(1),
        .WAIT_CYCLES(EXT_WAIT),
        .DEPTH_WORDS(4096)
    ) u_extmem(
        .clk(clk),
        .rst(rst),
        .req_i(s3_req),
        .we_i(s3_we),
        .wmask_i(s3_wmask),
        .addr_i(s3_addr),
        .data_i(s3_wdata),
        .data_o(s3_rdata),
        .ready_o(s3_ready),
        .backend_req_o(ext_backend_req),
        .backend_we_o(ext_backend_we),
        .backend_addr_o(ext_backend_addr),
        .backend_wdata_o(ext_backend_wdata),
        .backend_wmask_o(ext_backend_wmask),
        .backend_rdata_i(`ZeroWord),
        .backend_ready_i(`False)
    );

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

    task automatic clear_ram_region(input integer base_idx, input integer words_local);
        begin
            for (j = 0; j < words_local; j = j + 1) begin
                u_ram._ram[base_idx + j] = 32'h0;
            end
        end
    endtask

    task automatic clear_ext_region(input integer base_idx, input integer words_local);
        begin
            for (j = 0; j < words_local; j = j + 1) begin
                u_extmem.g_model.model_mem[base_idx + j] = 32'h0;
            end
        end
    endtask

    task automatic wait_done;
        begin
            timeout_cycles = 0;
            irq_seen = 0;
            done_seen = 0;
            while (done_seen == 0) begin
                apb_read(DMA_STATUS, rd_data);
                if (rd_data[2]) irq_seen = 1;
                if (rd_data[1]) done_seen = 1;
                timeout_cycles = timeout_cycles + 1;
                if (timeout_cycles > 300) begin
                    $display("DMA_EXTMEM_TIMEOUT status=0x%08x", rd_data);
                    $finish;
                end
            end
            if (irq_seen == 0) begin
                $display("DMA_EXTMEM irq was not observed");
                $finish;
            end
        end
    endtask

    task automatic clear_status;
        begin
            apb_write(DMA_STATUS, 32'h6);
            apb_read(DMA_STATUS, rd_data);
            if (rd_data[2:1] !== 2'b00) begin
                $display("DMA_EXTMEM status clear failed status=0x%08x", rd_data);
                $finish;
            end
        end
    endtask

    task automatic run_ram_to_ext_case;
        input integer local_words;
        input integer ram_idx;
        input integer ext_idx;
        begin
            direction_cov_mask = direction_cov_mask | 2'b01;
            word_cov_mask = word_cov_mask | (1 << (local_words - 1));

            clear_ext_region(ext_idx, local_words + 2);
            for (j = 0; j < local_words; j = j + 1) begin
                expected_word[j] = $urandom(seed);
                u_ram._ram[ram_idx + j] = expected_word[j];
            end

            apb_write(DMA_SRC, RAM_BASE + (ram_idx << 2));
            apb_write(DMA_DST, EXTMEM_BASE + (ext_idx << 2));
            apb_write(DMA_LEN, local_words);
            apb_write(DMA_CTRL, 32'h3);
            wait_done();

            apb_read(DMA_COUNT, rd_data);
            if (rd_data !== local_words[31:0]) begin
                $display("DMA_EXTMEM ram->ext count mismatch got=%0d exp=%0d", rd_data, local_words);
                $finish;
            end

            for (j = 0; j < local_words; j = j + 1) begin
                if (u_extmem.g_model.model_mem[ext_idx + j] !== expected_word[j]) begin
                    $display("DMA_EXTMEM ram->ext mismatch idx=%0d got=0x%08x exp=0x%08x",
                        j, u_extmem.g_model.model_mem[ext_idx + j], expected_word[j]);
                    $finish;
                end
            end

            clear_status();
            pass_count = pass_count + 1;
        end
    endtask

    task automatic run_ext_to_ram_case;
        input integer local_words;
        input integer ext_idx;
        input integer ram_idx;
        begin
            direction_cov_mask = direction_cov_mask | 2'b10;
            word_cov_mask = word_cov_mask | (1 << (local_words - 1));

            clear_ram_region(ram_idx, local_words + 2);
            for (j = 0; j < local_words; j = j + 1) begin
                expected_word[j] = $urandom(seed);
                u_extmem.g_model.model_mem[ext_idx + j] = expected_word[j];
            end

            apb_write(DMA_SRC, EXTMEM_BASE + (ext_idx << 2));
            apb_write(DMA_DST, RAM_BASE + (ram_idx << 2));
            apb_write(DMA_LEN, local_words);
            apb_write(DMA_CTRL, 32'h3);
            wait_done();

            apb_read(DMA_COUNT, rd_data);
            if (rd_data !== local_words[31:0]) begin
                $display("DMA_EXTMEM ext->ram count mismatch got=%0d exp=%0d", rd_data, local_words);
                $finish;
            end

            for (j = 0; j < local_words; j = j + 1) begin
                if (u_ram._ram[ram_idx + j] !== expected_word[j]) begin
                    $display("DMA_EXTMEM ext->ram mismatch idx=%0d got=0x%08x exp=0x%08x",
                        j, u_ram._ram[ram_idx + j], expected_word[j]);
                    $finish;
                end
            end

            clear_status();
            pass_count = pass_count + 1;
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
        pass_count = 0;
        direction_cov_mask = 0;
        word_cov_mask = 0;
`ifdef TB_SEED
        seed = `TB_SEED;
`else
        seed = 32'h7eed_1234;
`endif
        dummy_seed_init = $urandom(seed);
`ifdef TB_CASES
        case_count = `TB_CASES;
`else
        case_count = 4;
`endif

        repeat (5) @(posedge clk);
        rst = `RstDisable;
        repeat (2) @(posedge clk);

        for (i = 0; i < case_count; i = i + 1) begin
            words = ($urandom(seed) % 8) + 1;
            src_index = ($urandom(seed) % 128);
            dst_index = (($urandom(seed) % 128) + 160);
            if ((i[0]) == 1'b0) begin
                run_ram_to_ext_case(words, src_index, dst_index);
            end else begin
                run_ext_to_ram_case(words, src_index, dst_index);
            end
        end

        if (direction_cov_mask !== 2'b11) begin
            $display("DMA_EXTMEM direction coverage incomplete mask=0x%0x", direction_cov_mask);
            $finish;
        end

        $display("DMA_EXTMEM_PASS cases=%0d seed=%0d dir_mask=0x%0x word_mask=0x%0x ram_wait=%0d ext_wait=%0d",
            pass_count, seed, direction_cov_mask, word_cov_mask, RAM_WAIT, EXT_WAIT);
        $finish;
    end

endmodule
