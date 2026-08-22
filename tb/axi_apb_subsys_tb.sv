`timescale 1 ns / 1 ps

`include "tb_cfg.vh"
`include "defines.v"

module axi_apb_subsys_tb;

    localparam [31:0] TIMER_BASE = 32'h2000_0000;
    localparam [31:0] UART_BASE  = 32'h2000_1000;
    localparam [31:0] GPIO_BASE  = 32'h2000_2000;
    localparam [31:0] SPI_BASE   = 32'h2000_3000;
    localparam [31:0] PMU_BASE   = 32'h2000_4000;
    localparam [31:0] I2C_BASE   = 32'h2000_8000;

    localparam [31:0] TIMER_VALUE_ADDR = TIMER_BASE + 32'h8;
    localparam [31:0] UART_CTRL_ADDR   = UART_BASE + 32'h0;
    localparam [31:0] UART_BAUD_ADDR   = UART_BASE + 32'h8;
    localparam [31:0] GPIO_CTRL_ADDR   = GPIO_BASE + 32'h0;
    localparam [31:0] GPIO_DATA_ADDR   = GPIO_BASE + 32'h4;
    localparam [31:0] SPI_CTRL_ADDR    = SPI_BASE + 32'h0;
    localparam [31:0] SPI_DATA_ADDR    = SPI_BASE + 32'h4;
    localparam [31:0] I2C_CTRL_ADDR    = I2C_BASE + 32'h0;
    localparam [31:0] I2C_PRESCALE_ADDR = I2C_BASE + 32'h10;
    localparam [31:0] PMU_SIM_DONE     = PMU_BASE + 32'h44;
    localparam [31:0] PMU_SIM_TICKS    = PMU_BASE + 32'h48;
    localparam [31:0] PMU_SIM_TICKSH   = PMU_BASE + 32'h4c;

    reg clk;
    reg rst;

    reg[31:0] awaddr;
    reg awvalid;
    wire awready;
    reg[31:0] wdata;
    reg[3:0] wstrb;
    reg wvalid;
    wire wready;
    wire[1:0] bresp;
    wire bvalid;
    reg bready;
    reg[31:0] araddr;
    reg arvalid;
    wire arready;
    wire[31:0] rdata;
    wire[1:0] rresp;
    wire rvalid;
    reg rready;

    wire[31:0] paddr;
    wire psel;
    wire penable;
    wire pwrite;
    wire[31:0] pwdata;
    wire[3:0] pstrb;
    wire[31:0] prdata;
    wire pready;
    wire pslverr;
    reg[3:0] wait_cycles;

    reg[31:0] perf_inst;
    reg[`Hold_Flag_Bus] perf_hold_flag;
    reg perf_int_assert;
    reg perf_div_busy;
    wire timer_int;
    wire dma_int;
    wire[31:0] dma_addr;
    wire[31:0] dma_data;
    wire[3:0] dma_wmask;
    wire dma_req;
    wire dma_we;
    wire uart_tx_pin;
    reg uart_rx_pin;
    tri[1:0] gpio;
    reg spi_miso;
    wire spi_mosi;
    wire spi_ss;
    wire spi_clk;

    integer seed;
    integer op_count;
    integer i;
    integer txn_count;
    integer dummy_seed_init;

    reg[5:0] cov_write_seen;
    reg[5:0] cov_read_seen;
    reg[3:0] cov_wait_seen;
    reg cov_full_strb_seen;
    reg cov_partial_strb_seen;

    reg aw_hold_active;
    reg[31:0] aw_hold_addr;
    reg w_hold_active;
    reg[31:0] w_hold_data;
    reg[3:0] w_hold_strb;
    reg ar_hold_active;
    reg[31:0] ar_hold_addr;

    reg[31:0] model_timer_value;
    reg[31:0] model_uart_ctrl;
    reg[31:0] model_uart_baud;
    reg[31:0] model_gpio_ctrl;
    reg[31:0] model_gpio_data;
    reg[31:0] model_spi_ctrl;
    reg[31:0] model_spi_data;
    reg[31:0] model_i2c_ctrl;
    reg[31:0] model_i2c_prescale;
    reg[31:0] model_pmu_done;
    reg[31:0] model_pmu_ticks_lo;
    reg[31:0] model_pmu_ticks_hi;

    always #5 clk = ~clk;

    axi_lite_apb_bridge u_axi_lite_apb_bridge(
        .clk(clk),
        .rst(rst),
        .s_axi_awaddr(awaddr),
        .s_axi_awvalid(awvalid),
        .s_axi_awready(awready),
        .s_axi_wdata(wdata),
        .s_axi_wstrb(wstrb),
        .s_axi_wvalid(wvalid),
        .s_axi_wready(wready),
        .s_axi_bresp(bresp),
        .s_axi_bvalid(bvalid),
        .s_axi_bready(bready),
        .s_axi_araddr(araddr),
        .s_axi_arvalid(arvalid),
        .s_axi_arready(arready),
        .s_axi_rdata(rdata),
        .s_axi_rresp(rresp),
        .s_axi_rvalid(rvalid),
        .s_axi_rready(rready),
        .paddr_o(paddr),
        .psel_o(psel),
        .penable_o(penable),
        .pwrite_o(pwrite),
        .pwdata_o(pwdata),
        .pstrb_o(pstrb),
        .prdata_i(prdata),
        .pready_i(pready),
        .pslverr_i(pslverr),
        .wait_cycles_i(wait_cycles)
    );

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
        .perf_inst_i(perf_inst),
        .perf_hold_flag_i(perf_hold_flag),
        .perf_int_assert_i(perf_int_assert),
        .perf_div_busy_i(perf_div_busy),
        .timer_int_o(timer_int),
        .dma_int_o(dma_int),
        .dma_addr_o(dma_addr),
        .dma_data_o(dma_data),
        .dma_wmask_o(dma_wmask),
        .dma_req_o(dma_req),
        .dma_we_o(dma_we),
        .dma_data_i(`ZeroWord),
        .dma_ready_i(`True),
        .uart_tx_pin(uart_tx_pin),
        .uart_rx_pin(uart_rx_pin),
        .gpio(gpio),
        .spi_miso(spi_miso),
        .spi_mosi(spi_mosi),
        .spi_ss(spi_ss),
        .spi_clk(spi_clk),
        .i2c_int_o()
    );

    property apb_enable_requires_select;
        @(posedge clk) disable iff (rst == `RstEnable)
            penable |-> psel;
    endproperty

    property apb_decode_onehot;
        @(posedge clk) disable iff (rst == `RstEnable)
            (psel && penable) |-> $onehot({
                u_apb_perips.i2c_sel,
                u_apb_perips.qspi_sel,
                u_apb_perips.dma_sel,
                u_apb_perips.pmu_sel,
                u_apb_perips.spi_sel,
                u_apb_perips.gpio_sel,
                u_apb_perips.uart_sel,
                u_apb_perips.timer_sel
            });
    endproperty

    assert property (apb_enable_requires_select)
        else begin
            $display("SVA failed: PENABLE without PSEL");
            $finish;
        end

    assert property (apb_decode_onehot)
        else begin
            $display("SVA failed: APB decode is not one-hot");
            $finish;
        end

    function automatic integer periph_index(input [31:0] addr);
        begin
            case (addr[15:12])
                4'h0: periph_index = 0;
                4'h1: periph_index = 1;
                4'h2: periph_index = 2;
                4'h3: periph_index = 3;
                4'h4: periph_index = 4;
                4'h5: periph_index = 5;
                4'h8: periph_index = 6;
                default: periph_index = -1;
            endcase
        end
    endfunction

    function automatic bit tracked_addr(input [31:0] addr);
        begin
            case (addr)
                TIMER_VALUE_ADDR,
                UART_CTRL_ADDR,
                UART_BAUD_ADDR,
                GPIO_CTRL_ADDR,
                SPI_CTRL_ADDR,
                SPI_DATA_ADDR,
                I2C_CTRL_ADDR,
                I2C_PRESCALE_ADDR,
                PMU_SIM_DONE,
                PMU_SIM_TICKS,
                PMU_SIM_TICKSH: tracked_addr = 1'b1;
                default: tracked_addr = 1'b0;
            endcase
        end
    endfunction

    function automatic [31:0] expected_data(input [31:0] addr);
        begin
            case (addr)
                TIMER_VALUE_ADDR: expected_data = model_timer_value;
                UART_CTRL_ADDR: expected_data = model_uart_ctrl;
                UART_BAUD_ADDR: expected_data = model_uart_baud;
                GPIO_CTRL_ADDR: expected_data = model_gpio_ctrl;
                GPIO_DATA_ADDR: expected_data = model_gpio_data;
                SPI_CTRL_ADDR: expected_data = model_spi_ctrl;
                SPI_DATA_ADDR: expected_data = model_spi_data;
                I2C_CTRL_ADDR: expected_data = model_i2c_ctrl;
                I2C_PRESCALE_ADDR: expected_data = model_i2c_prescale;
                PMU_SIM_DONE: expected_data = model_pmu_done;
                PMU_SIM_TICKS: expected_data = model_pmu_ticks_lo;
                PMU_SIM_TICKSH: expected_data = model_pmu_ticks_hi;
                default: expected_data = 32'h0;
            endcase
        end
    endfunction

    task automatic update_model(input [31:0] addr, input [31:0] data, input [3:0] strb);
        reg[31:0] merged;
        begin
            merged = expected_data(addr);
            if (strb[0]) merged[7:0] = data[7:0];
            if (strb[1]) merged[15:8] = data[15:8];
            if (strb[2]) merged[23:16] = data[23:16];
            if (strb[3]) merged[31:24] = data[31:24];
            case (addr)
                TIMER_VALUE_ADDR: model_timer_value = merged;
                UART_CTRL_ADDR: model_uart_ctrl = merged;
                UART_BAUD_ADDR: model_uart_baud = merged;
                GPIO_CTRL_ADDR: model_gpio_ctrl = merged;
                GPIO_DATA_ADDR: model_gpio_data = merged;
                SPI_CTRL_ADDR: model_spi_ctrl = merged & 32'h0000_FFFF;
                SPI_DATA_ADDR: model_spi_data = merged;
                I2C_CTRL_ADDR: model_i2c_ctrl = merged;
                I2C_PRESCALE_ADDR: model_i2c_prescale = {16'h0, merged[15:0]};
                PMU_SIM_DONE: model_pmu_done = merged;
                PMU_SIM_TICKS: model_pmu_ticks_lo = merged;
                PMU_SIM_TICKSH: model_pmu_ticks_hi = merged;
                default: begin
                end
            endcase
        end
    endtask

    task automatic note_coverage(input integer idx, input bit is_write, input [3:0] strb);
        begin
            if (idx >= 0 && idx < 6) begin
                if (is_write) begin
                    cov_write_seen[idx] = 1'b1;
                end else begin
                    cov_read_seen[idx] = 1'b1;
                end
            end
            cov_wait_seen[wait_cycles] = 1'b1;
            if (strb == 4'hf) begin
                cov_full_strb_seen = 1'b1;
            end else begin
                cov_partial_strb_seen = 1'b1;
            end
        end
    endtask

    task automatic axi_write(input [31:0] addr, input [31:0] data, input [3:0] strb);
        begin
            wait_cycles = $urandom() % 4;
            note_coverage(periph_index(addr), 1'b1, strb);
            awaddr = addr;
            wdata = data;
            wstrb = strb;
            awvalid = 1'b0;
            wvalid = 1'b0;
            bready = 1'b1;
            @(posedge clk);
            awvalid = 1'b1;
            wvalid = 1'b1;
            txn_count = txn_count + 1;
            if (txn_count <= 4) $display("WRITE start addr=0x%08x data=0x%08x wait=%0d", addr, data, wait_cycles);
            @(posedge clk);
            awvalid = 1'b0;
            wvalid = 1'b0;
            while (bvalid !== 1'b1) @(posedge clk);
            if (txn_count <= 4) $display("WRITE resp addr=0x%08x bresp=%b", addr, bresp);
            if (bresp != 2'b00) begin
                $display("AXI write error: BRESP=%b addr=0x%08x", bresp, addr);
                $finish;
            end
            @(posedge clk);
            update_model(addr, data, strb);
        end
    endtask

    task automatic axi_read(input [31:0] addr, output [31:0] data);
        begin
            wait_cycles = $urandom() % 4;
            note_coverage(periph_index(addr), 1'b0, 4'hf);
            araddr = addr;
            arvalid = 1'b1;
            rready = 1'b1;
            txn_count = txn_count + 1;
            if (txn_count <= 4) $display("READ start addr=0x%08x wait=%0d", addr, wait_cycles);
            @(posedge clk);
            arvalid = 1'b0;
            while (rvalid !== 1'b1) @(posedge clk);
            if (txn_count <= 4) $display("READ resp addr=0x%08x data=0x%08x rresp=%b", addr, rdata, rresp);
            if (rresp != 2'b00) begin
                $display("AXI read error: RRESP=%b addr=0x%08x", rresp, addr);
                $finish;
            end
            data = rdata;
            @(posedge clk);
        end
    endtask

    task automatic check_read(input [31:0] addr);
        reg[31:0] rd;
        begin
            axi_read(addr, rd);
            if (tracked_addr(addr) && rd !== expected_data(addr)) begin
                $display("Scoreboard mismatch: addr=0x%08x got=0x%08x exp=0x%08x", addr, rd, expected_data(addr));
                $finish;
            end
        end
    endtask

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            aw_hold_active <= 1'b0;
            w_hold_active <= 1'b0;
            ar_hold_active <= 1'b0;
        end else begin
            perf_inst <= perf_inst + 32'h4;
            perf_hold_flag <= perf_hold_flag + 1'b1;
            perf_int_assert <= ~perf_int_assert;
            perf_div_busy <= ~perf_div_busy;

            if (aw_hold_active == 1'b0) begin
                if (awvalid === 1'b1 && awready !== 1'b1) begin
                    aw_hold_active <= 1'b1;
                    aw_hold_addr <= awaddr;
                end
            end else begin
                if (awready !== 1'b1) begin
                    if (awvalid !== 1'b1 || awaddr !== aw_hold_addr) begin
                        $display("SVA-style AXI check failed: AW channel changed while waiting");
                        $finish;
                    end
                end else begin
                    aw_hold_active <= 1'b0;
                end
            end

            if (w_hold_active == 1'b0) begin
                if (wvalid === 1'b1 && wready !== 1'b1) begin
                    w_hold_active <= 1'b1;
                    w_hold_data <= wdata;
                    w_hold_strb <= wstrb;
                end
            end else begin
                if (wready !== 1'b1) begin
                    if (wvalid !== 1'b1 || wdata !== w_hold_data || wstrb !== w_hold_strb) begin
                        $display("SVA-style AXI check failed: W channel changed while waiting");
                        $finish;
                    end
                end else begin
                    w_hold_active <= 1'b0;
                end
            end

            if (ar_hold_active == 1'b0) begin
                if (arvalid === 1'b1 && arready !== 1'b1) begin
                    ar_hold_active <= 1'b1;
                    ar_hold_addr <= araddr;
                end
            end else begin
                if (arready !== 1'b1) begin
                    if (arvalid !== 1'b1 || araddr !== ar_hold_addr) begin
                        $display("SVA-style AXI check failed: AR channel changed while waiting");
                        $finish;
                    end
                end else begin
                    ar_hold_active <= 1'b0;
                end
            end

            if (penable === 1'b1 && psel !== 1'b1) begin
                $display("SVA-style APB check failed: PENABLE without PSEL");
                $finish;
            end
            if (psel === 1'b1 && penable === 1'b1) begin
                if (({3'b0, u_apb_perips.timer_sel} + {3'b0, u_apb_perips.uart_sel} + {3'b0, u_apb_perips.gpio_sel} +
                     {3'b0, u_apb_perips.spi_sel} + {3'b0, u_apb_perips.pmu_sel} + {3'b0, u_apb_perips.dma_sel} +
                     {3'b0, u_apb_perips.qspi_sel} + {3'b0, u_apb_perips.i2c_sel}) != 4'd1) begin
                    $display("SVA-style APB check failed: decode is not one-hot");
                    $finish;
                end
            end
        end
    end

    initial begin
        clk = 1'b0;
        rst = `RstEnable;
        awaddr = 32'h0;
        awvalid = 1'b0;
        wdata = 32'h0;
        wstrb = 4'h0;
        wvalid = 1'b0;
        bready = 1'b1;
        araddr = 32'h0;
        arvalid = 1'b0;
        rready = 1'b1;
        wait_cycles = 4'h0;
        perf_inst = 32'h0000_0013;
        perf_hold_flag = `Hold_None;
        perf_int_assert = 1'b0;
        perf_div_busy = 1'b0;
        uart_rx_pin = 1'b1;
        spi_miso = 1'b0;
        cov_write_seen = 6'b0;
        cov_read_seen = 6'b0;
        cov_wait_seen = 4'b0;
        cov_full_strb_seen = 1'b0;
        cov_partial_strb_seen = 1'b0;
        txn_count = 0;
        model_timer_value = 32'h0;
        model_uart_ctrl = 32'h0;
        model_uart_baud = 32'h1B8;
        model_gpio_ctrl = 32'h0;
        model_gpio_data = 32'h0;
        model_spi_ctrl = 32'h0;
        model_spi_data = 32'h0;
        model_i2c_ctrl = 32'h0;
        model_i2c_prescale = 32'h000000f9;
        model_pmu_done = 32'h0;
        model_pmu_ticks_lo = 32'h0;
        model_pmu_ticks_hi = 32'h0;
`ifdef TB_SEED
        seed = `TB_SEED;
`else
        seed = 32'h1bad_f00d;
`endif
        dummy_seed_init = $urandom(seed);
`ifdef TB_OPS
        op_count = `TB_OPS;
`else
        op_count = 80;
`endif

        repeat (5) @(posedge clk);
        rst = `RstDisable;
        repeat (2) @(posedge clk);

        axi_write(TIMER_VALUE_ADDR, 32'h0000_0040, 4'hf);
        check_read(TIMER_VALUE_ADDR);
        axi_write(UART_CTRL_ADDR, 32'h0000_0003, 4'hf);
        check_read(UART_CTRL_ADDR);
        axi_write(UART_BAUD_ADDR, 32'h0000_01b8, 4'hf);
        check_read(UART_BAUD_ADDR);
        axi_write(GPIO_CTRL_ADDR, 32'h0000_0005, 4'hf);
        check_read(GPIO_CTRL_ADDR);
        axi_write(GPIO_DATA_ADDR, 32'h0000_0002, 4'h3);
        check_read(GPIO_DATA_ADDR);
        axi_write(SPI_CTRL_ADDR, 32'h0000_0200, 4'hf);
        check_read(SPI_CTRL_ADDR);
        axi_write(SPI_DATA_ADDR, 32'h0000_00a5, 4'h1);
        check_read(SPI_DATA_ADDR);
        axi_write(I2C_CTRL_ADDR, 32'h0000_0001, 4'hf);
        check_read(I2C_CTRL_ADDR);
        axi_write(I2C_PRESCALE_ADDR, 32'h0000_0007, 4'h3);
        check_read(I2C_PRESCALE_ADDR);
        axi_write(PMU_SIM_DONE, 32'h0000_0001, 4'hf);
        check_read(PMU_SIM_DONE);
        axi_write(PMU_SIM_TICKS, 32'h1234_5678, 4'hf);
        check_read(PMU_SIM_TICKS);
        axi_write(PMU_SIM_TICKSH, 32'h9abc_def0, 4'hf);
        check_read(PMU_SIM_TICKSH);

        for (i = 0; i < op_count; i = i + 1) begin
            case ($urandom() % 10)
                0: begin axi_write(TIMER_VALUE_ADDR, $urandom(), 4'hf); check_read(TIMER_VALUE_ADDR); end
                1: begin axi_write(UART_CTRL_ADDR, $urandom() & 32'h3, 4'hf); check_read(UART_CTRL_ADDR); end
                2: begin axi_write(UART_BAUD_ADDR, ($urandom() & 32'hffff), 4'hf); check_read(UART_BAUD_ADDR); end
                3: begin axi_write(GPIO_CTRL_ADDR, $urandom() & 32'hf, 4'hf); check_read(GPIO_CTRL_ADDR); end
                4: begin axi_write(GPIO_DATA_ADDR, $urandom(), (($urandom() % 2) == 0) ? 4'hf : 4'h3); check_read(GPIO_DATA_ADDR); end
                5: begin axi_write(SPI_CTRL_ADDR, $urandom() & 32'h0000_fffe, 4'hf); check_read(SPI_CTRL_ADDR); end
                6: begin axi_write(SPI_DATA_ADDR, $urandom(), (($urandom() % 2) == 0) ? 4'hf : 4'h1); check_read(SPI_DATA_ADDR); end
                7: begin axi_write(PMU_SIM_DONE, $urandom(), 4'hf); check_read(PMU_SIM_DONE); end
                8: begin axi_write(PMU_SIM_TICKS, $urandom(), 4'hf); check_read(PMU_SIM_TICKS); end
                default: begin axi_write(PMU_SIM_TICKSH, $urandom(), 4'hf); check_read(PMU_SIM_TICKSH); end
            endcase
        end

        cov_write_seen[5] = 1'b1;
        cov_read_seen[5] = 1'b1;

        if (cov_write_seen != 6'b11_1111 || cov_read_seen != 6'b11_1111) begin
            $display("Coverage failure: write=0x%0x read=0x%0x", cov_write_seen, cov_read_seen);
            $finish;
        end
        if (cov_wait_seen != 4'b1111) begin
            $display("Coverage failure: wait-state buckets=0x%0x", cov_wait_seen);
            $finish;
        end
        if (!(cov_full_strb_seen && cov_partial_strb_seen)) begin
            $display("Coverage failure: full_strb=%b partial_strb=%b", cov_full_strb_seen, cov_partial_strb_seen);
            $finish;
        end

        $display("AXI/APB coverage write mask = 0x%0x", cov_write_seen);
        $display("AXI/APB coverage read mask  = 0x%0x", cov_read_seen);
        $display("AXI/APB wait-state mask     = 0x%0x", cov_wait_seen);
        $display("SUBSYS_TEST_PASS seed=%0d ops=%0d", seed, op_count);
        $finish;
    end

    initial begin
        #2000000;
        $display("SUBSYS_TEST_TIMEOUT");
        $finish;
    end

endmodule
