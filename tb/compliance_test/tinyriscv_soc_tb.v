`timescale 1 ns / 1 ps

`include "defines.v"


`define TEST_PROG  1
//`define TEST_JTAG  1


// testbench module
module tinyriscv_soc_tb;

    reg clk;
    reg rst;


    always #10 clk = ~clk;     // 50MHz

    wire[`RegBus] x3 = heterogeneous_soc_top_0.u_riscv_cpu.u_regs.regs[3];
    wire[`RegBus] x26 = heterogeneous_soc_top_0.u_riscv_cpu.u_regs.regs[26];
    wire[`RegBus] x27 = heterogeneous_soc_top_0.u_riscv_cpu.u_regs.regs[27];
    wire[63:0] perf_cycle = heterogeneous_soc_top_0.u_apb_perips.u_pmu.cycle_counter;
    wire[63:0] perf_inst = heterogeneous_soc_top_0.u_apb_perips.u_pmu.inst_counter;
    wire[63:0] perf_jump = heterogeneous_soc_top_0.u_apb_perips.u_pmu.jump_counter;
    wire[63:0] perf_load = heterogeneous_soc_top_0.u_apb_perips.u_pmu.load_counter;
    wire[63:0] perf_store = heterogeneous_soc_top_0.u_apb_perips.u_pmu.store_counter;
    wire[63:0] perf_hold = heterogeneous_soc_top_0.u_apb_perips.u_pmu.hold_counter;
    wire[63:0] perf_int = heterogeneous_soc_top_0.u_apb_perips.u_pmu.int_counter;
    wire[63:0] perf_div_wait = heterogeneous_soc_top_0.u_apb_perips.u_pmu.div_wait_counter;
    wire apb_psel = heterogeneous_soc_top_0.apb_psel;
    wire apb_penable = heterogeneous_soc_top_0.apb_penable;
    wire apb_timer_sel = heterogeneous_soc_top_0.u_apb_perips.timer_sel;
    wire apb_uart_sel = heterogeneous_soc_top_0.u_apb_perips.uart_sel;
    wire apb_gpio_sel = heterogeneous_soc_top_0.u_apb_perips.gpio_sel;
    wire apb_spi_sel = heterogeneous_soc_top_0.u_apb_perips.spi_sel;
    wire apb_pmu_sel = heterogeneous_soc_top_0.u_apb_perips.pmu_sel;
    wire apb_dma_sel = heterogeneous_soc_top_0.u_apb_perips.dma_sel;
    wire[2:0] apb_sel_count = {2'b0, apb_timer_sel} + {2'b0, apb_uart_sel} + {2'b0, apb_gpio_sel} + {2'b0, apb_spi_sel} + {2'b0, apb_pmu_sel} + {2'b0, apb_dma_sel};

    wire[31:0] ex_end_flag = heterogeneous_soc_top_0.u_ram._ram[4];
    wire[31:0] begin_signature = heterogeneous_soc_top_0.u_ram._ram[2];
    wire[31:0] end_signature = heterogeneous_soc_top_0.u_ram._ram[3];

    integer r;
    integer fd;

    always @ (posedge clk) begin
        if (rst == `RstDisable && apb_psel === 1'b1 && apb_penable === 1'b1 && apb_sel_count != 3'd1) begin
            $display("APB decode error: sel_count=%0d", apb_sel_count);
            $finish;
        end
        if (rst == `RstDisable && apb_penable === 1'b1 && apb_psel !== 1'b1) begin
            $display("APB handshake error: PENABLE without PSEL");
            $finish;
        end
    end

`ifdef TEST_JTAG
    reg TCK;
    reg TMS;
    reg TDI;
    wire TDO;

    integer i;
    reg[39:0] shift_reg;
    reg in;
    wire[39:0] req_data = heterogeneous_soc_top_0.u_jtag_top.u_jtag_driver.dtm_req_data;
    wire[4:0] ir_reg = heterogeneous_soc_top_0.u_jtag_top.u_jtag_driver.ir_reg;
    wire dtm_req_valid = heterogeneous_soc_top_0.u_jtag_top.u_jtag_driver.dtm_req_valid;
    wire[31:0] dmstatus = heterogeneous_soc_top_0.u_jtag_top.u_jtag_dm.dmstatus;
`endif

    initial begin
        clk = 0;
        rst = `RstEnable;
`ifdef TEST_JTAG
        TCK = 1;
        TMS = 1;
        TDI = 1;
`endif
        $display("test running...");
        #40
        rst = `RstDisable;
        #200
/*
`ifdef TEST_PROG
        wait(x26 === 32'b1)   // wait sim end, when x26 == 1
        #100
        if (x27 === 32'b1) begin
            $display("~~~~~~~~~~~~~~~~~~~ TEST_PASS ~~~~~~~~~~~~~~~~~~~");
            $display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
            $display("~~~~~~~~~ #####     ##     ####    #### ~~~~~~~~~");
            $display("~~~~~~~~~ #    #   #  #   #       #     ~~~~~~~~~");
            $display("~~~~~~~~~ #    #  #    #   ####    #### ~~~~~~~~~");
            $display("~~~~~~~~~ #####   ######       #       #~~~~~~~~~");
            $display("~~~~~~~~~ #       #    #  #    #  #    #~~~~~~~~~");
            $display("~~~~~~~~~ #       #    #   ####    #### ~~~~~~~~~");
            $display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
        end else begin
            $display("~~~~~~~~~~~~~~~~~~~ TEST_FAIL ~~~~~~~~~~~~~~~~~~~~");
            $display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
            $display("~~~~~~~~~~######    ##       #    #     ~~~~~~~~~~");
            $display("~~~~~~~~~~#        #  #      #    #     ~~~~~~~~~~");
            $display("~~~~~~~~~~#####   #    #     #    #     ~~~~~~~~~~");
            $display("~~~~~~~~~~#       ######     #    #     ~~~~~~~~~~");
            $display("~~~~~~~~~~#       #    #     #    #     ~~~~~~~~~~");
            $display("~~~~~~~~~~#       #    #     #    ######~~~~~~~~~~");
            $display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
            $display("fail testnum = %2d", x3);
            for (r = 0; r < 32; r = r + 1)
                $display("x%2d = 0x%x", r, heterogeneous_soc_top_0.u_riscv_cpu.u_regs.regs[r]);
        end
`endif
*/

        wait(ex_end_flag == 32'h1);  // wait sim end

        fd = $fopen(`OUTPUT);   // OUTPUT的值在命令行里定义
        for (r = begin_signature; r < end_signature; r = r + 4) begin
            $fdisplay(fd, "%x", heterogeneous_soc_top_0.u_rom._rom[r[31:2]]);
        end
        $fclose(fd);
        $display("PMU cycle     = %0d", perf_cycle);
        $display("PMU inst      = %0d", perf_inst);
        $display("PMU jump      = %0d", perf_jump);
        $display("PMU load      = %0d", perf_load);
        $display("PMU store     = %0d", perf_store);
        $display("PMU hold      = %0d", perf_hold);
        $display("PMU interrupt = %0d", perf_int);
        $display("PMU div_wait  = %0d", perf_div_wait);

`ifdef TEST_JTAG
        // reset
        for (i = 0; i < 8; i++) begin
            TMS = 1;
            TCK = 0;
            #100
            TCK = 1;
            #100
            TCK = 0;
        end

        // IR
        shift_reg = 40'b10001;

        // IDLE
        TMS = 0;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // SELECT-DR
        TMS = 1;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // SELECT-IR
        TMS = 1;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // CAPTURE-IR
        TMS = 0;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // SHIFT-IR
        TMS = 0;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // SHIFT-IR & EXIT1-IR
        for (i = 5; i > 0; i--) begin
            if (shift_reg[0] == 1'b1)
                TDI = 1'b1;
            else
                TDI = 1'b0;

            if (i == 1)
                TMS = 1;

            TCK = 0;
            #100
            in = TDO;
            TCK = 1;
            #100
            TCK = 0;

            shift_reg = {{(35){1'b0}}, in, shift_reg[4:1]};
        end

        // PAUSE-IR
        TMS = 0;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // EXIT2-IR
        TMS = 1;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // UPDATE-IR
        TMS = 1;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // IDLE
        TMS = 0;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // IDLE
        TMS = 0;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // IDLE
        TMS = 0;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // IDLE
        TMS = 0;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // dmi write
        shift_reg = {6'h10, {(32){1'b0}}, 2'b10};

        // SELECT-DR
        TMS = 1;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // CAPTURE-DR
        TMS = 0;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // SHIFT-DR
        TMS = 0;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // SHIFT-DR & EXIT1-DR
        for (i = 40; i > 0; i--) begin
            if (shift_reg[0] == 1'b1)
                TDI = 1'b1;
            else
                TDI = 1'b0;

            if (i == 1)
                TMS = 1;

            TCK = 0;
            #100
            in = TDO;
            TCK = 1;
            #100
            TCK = 0;

            shift_reg = {in, shift_reg[39:1]};
        end

        // PAUSE-DR
        TMS = 0;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // EXIT2-DR
        TMS = 1;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // UPDATE-DR
        TMS = 1;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // IDLE
        TMS = 0;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        $display("ir_reg = 0x%x", ir_reg);
        $display("dtm_req_valid = %d", dtm_req_valid);
        $display("req_data = 0x%x", req_data);

        // IDLE
        TMS = 0;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // IDLE
        TMS = 0;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        $display("dmstatus = 0x%x", dmstatus);

        // IDLE
        TMS = 0;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // SELECT-DR
        TMS = 1;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // dmi read
        shift_reg = {6'h11, {(32){1'b0}}, 2'b01};

        // CAPTURE-DR
        TMS = 0;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // SHIFT-DR
        TMS = 0;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // SHIFT-DR & EXIT1-DR
        for (i = 40; i > 0; i--) begin
            if (shift_reg[0] == 1'b1)
                TDI = 1'b1;
            else
                TDI = 1'b0;

            if (i == 1)
                TMS = 1;

            TCK = 0;
            #100
            in = TDO;
            TCK = 1;
            #100
            TCK = 0;

            shift_reg = {in, shift_reg[39:1]};
        end

        // PAUSE-DR
        TMS = 0;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // EXIT2-DR
        TMS = 1;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // UPDATE-DR
        TMS = 1;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // IDLE
        TMS = 0;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // IDLE
        TMS = 0;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // IDLE
        TMS = 0;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // IDLE
        TMS = 0;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // SELECT-DR
        TMS = 1;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // dmi read
        shift_reg = {6'h11, {(32){1'b0}}, 2'b00};

        // CAPTURE-DR
        TMS = 0;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // SHIFT-DR
        TMS = 0;
        TCK = 0;
        #100
        TCK = 1;
        #100
        TCK = 0;

        // SHIFT-DR & EXIT1-DR
        for (i = 40; i > 0; i--) begin
            if (shift_reg[0] == 1'b1)
                TDI = 1'b1;
            else
                TDI = 1'b0;

            if (i == 1)
                TMS = 1;

            TCK = 0;
            #100
            in = TDO;
            TCK = 1;
            #100
            TCK = 0;

            shift_reg = {in, shift_reg[39:1]};
        end

        #100

        $display("shift_reg = 0x%x", shift_reg[33:2]);
`endif

        $finish;
    end

    // sim timeout
    initial begin
        #500000
        $display("Time Out.");
        $finish;
    end

    // read mem data
    initial begin
        $readmemh ("inst.data", heterogeneous_soc_top_0.u_rom._rom);
    end

    // generate wave file, used by gtkwave
    initial begin
        $dumpfile("tinyriscv_soc_tb.vcd");
        $dumpvars(0, tinyriscv_soc_tb);
    end

    heterogeneous_soc_top heterogeneous_soc_top_0(
        .clk(clk),
        .rst(rst),
        .uart_debug_pin(1'b0)/*
        .jtag_TCK(TCK),
        .jtag_TMS(TMS),
        .jtag_TDI(TDI),
        .jtag_TDO(TDO)*/
    );

endmodule
