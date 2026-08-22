`timescale 1 ns / 1 ps

`include "defines.v"

`ifndef SIM_TIMEOUT
`define SIM_TIMEOUT 500000
`endif

// select one option only
`define TEST_PROG  1
//`define TEST_JTAG  1


// testbench module
module tinyriscv_soc_tb;

    reg clk;
    reg rst;

    wire tb_spi_mosi;
    wire tb_spi_ss;
    wire tb_spi_clk;
    reg tb_spi_miso;
    wire[3:0] tb_qspi_io;
    wire tb_qspi_cs_n;
    wire tb_qspi_clk;
    reg tb_qspi_io1_drv;

    assign tb_qspi_io[1] = tb_qspi_io1_drv;
    assign tb_qspi_io[2] = 1'bz;
    assign tb_qspi_io[3] = 1'bz;

    localparam [2:0] FLASH_ST_IDLE = 3'd0;
    localparam [2:0] FLASH_ST_ID = 3'd1;
    localparam [2:0] FLASH_ST_READ_ADDR = 3'd2;
    localparam [2:0] FLASH_ST_READ_DATA = 3'd3;
    localparam [2:0] QSPI_ST_CMD = 3'd0;
    localparam [2:0] QSPI_ST_ADDR = 3'd1;
    localparam [2:0] QSPI_ST_READ = 3'd2;

    reg[2:0] flash_state;
    reg[7:0] flash_shift_in;
    reg[7:0] flash_shift_out;
    reg[1:0] flash_id_idx;
    reg[1:0] flash_addr_idx;
    reg[23:0] flash_addr;
    reg[3:0] flash_miso_bit_idx;
    reg[3:0] flash_session_idx;
    reg[7:0] flash_byte_idx;
    reg[7:0] flash_mem[0:511];
    reg[2:0] qspi_flash_state;
    reg[7:0] qspi_flash_shift_in;
    reg[7:0] qspi_flash_shift_out;
    reg[2:0] qspi_flash_bit_count;
    reg[2:0] qspi_flash_out_bit;
    reg[1:0] qspi_flash_addr_idx;
    reg[1:0] qspi_flash_id_idx;
    reg qspi_flash_is_id;
    reg[23:0] qspi_flash_addr;
    integer flash_init_idx;

    function [7:0] flash_jedec_id;
        input [1:0] idx;
        begin
            case (idx)
                2'd0: flash_jedec_id = 8'h20;
                2'd1: flash_jedec_id = 8'hba;
                2'd2: flash_jedec_id = 8'h18;
                default: flash_jedec_id = 8'hff;
            endcase
        end
    endfunction

    function [7:0] flash_response_byte;
        input [3:0] session;
        input [7:0] byte_idx;
        begin
            flash_response_byte = 8'hff;
            if (session == 4'd0) begin
                case (byte_idx)
                    8'd1: flash_response_byte = 8'h20;
                    8'd2: flash_response_byte = 8'hba;
                    8'd3: flash_response_byte = 8'h18;
                    default: flash_response_byte = 8'hff;
                endcase
            end else if (session == 4'd1 && byte_idx >= 8'd4) begin
                flash_response_byte = flash_mem[byte_idx - 8'd4];
            end
        end
    endfunction

    function [7:0] flash_next_byte;
        begin
            flash_next_byte = flash_response_byte(flash_session_idx, flash_byte_idx);
        end
    endfunction

    wire[7:0] flash_next_byte_w = flash_response_byte(flash_session_idx, flash_byte_idx);
    wire[7:0] flash_after_done_byte_w = flash_response_byte(flash_session_idx, flash_byte_idx + 1'b1);
    wire[7:0] flash_tx_byte = heterogeneous_soc_top_0.u_apb_perips.u_spi.spi_data[7:0];

    initial begin
        tb_spi_miso = 1'b1;
        tb_qspi_io1_drv = 1'b1;
        flash_state = FLASH_ST_IDLE;
        flash_shift_in = 8'h00;
        flash_shift_out = 8'hff;
        flash_id_idx = 2'd0;
        flash_addr_idx = 2'd0;
        flash_addr = 24'h0;
        flash_miso_bit_idx = 4'd7;
        flash_session_idx = 4'd0;
        flash_byte_idx = 8'd0;
        qspi_flash_state = QSPI_ST_CMD;
        qspi_flash_shift_in = 8'h00;
        qspi_flash_shift_out = 8'hff;
        qspi_flash_bit_count = 3'h0;
        qspi_flash_out_bit = 3'd7;
        qspi_flash_addr_idx = 2'h0;
        qspi_flash_id_idx = 2'h0;
        qspi_flash_is_id = 1'b0;
        qspi_flash_addr = 24'h0;
        for (flash_init_idx = 0; flash_init_idx < 512; flash_init_idx = flash_init_idx + 1) begin
            flash_mem[flash_init_idx] = (8'ha5 ^ flash_init_idx[7:0]);
        end
        flash_mem[8'h00] = 8'h54; // 'T'
        flash_mem[8'h01] = 8'h52; // 'R'
        flash_mem[8'h02] = 8'h56; // 'V'
        flash_mem[8'h03] = 8'h31; // '1'
        // qspi_flash_boot_copy payload. The software uses 0x0080_0100 on
        // real W25Q128 so it does not overlap a configuration image; this
        // small model aliases the lower address bits to keep the test compact.
        //   addi a0, zero, 0x5a
        //   ret
        flash_mem[9'h100] = 8'h13;
        flash_mem[9'h101] = 8'h05;
        flash_mem[9'h102] = 8'ha0;
        flash_mem[9'h103] = 8'h05;
        flash_mem[9'h104] = 8'h67;
        flash_mem[9'h105] = 8'h80;
        flash_mem[9'h106] = 8'h00;
        flash_mem[9'h107] = 8'h00;
    end

    always #10 clk = ~clk;     // 50MHz

    wire[`RegBus] x1 = heterogeneous_soc_top_0.u_riscv_cpu.u_regs.regs[1];
    wire[`RegBus] x3 = heterogeneous_soc_top_0.u_riscv_cpu.u_regs.regs[3];
    wire[`RegBus] x10 = heterogeneous_soc_top_0.u_riscv_cpu.u_regs.regs[10];
    wire[`RegBus] x11 = heterogeneous_soc_top_0.u_riscv_cpu.u_regs.regs[11];
    wire[`RegBus] x12 = heterogeneous_soc_top_0.u_riscv_cpu.u_regs.regs[12];
    wire[`RegBus] x26 = heterogeneous_soc_top_0.u_riscv_cpu.u_regs.regs[26];
    wire[`RegBus] x27 = heterogeneous_soc_top_0.u_riscv_cpu.u_regs.regs[27];
    wire[`RegBus] x28 = heterogeneous_soc_top_0.u_riscv_cpu.u_regs.regs[28];
    wire[`RegBus] x29 = heterogeneous_soc_top_0.u_riscv_cpu.u_regs.regs[29];
    wire[`RegBus] x30 = heterogeneous_soc_top_0.u_riscv_cpu.u_regs.regs[30];
    wire[31:0] pmu_sim_done = heterogeneous_soc_top_0.u_apb_perips.u_pmu.sim_done_reg;
    wire[63:0] coremark_ticks = heterogeneous_soc_top_0.u_apb_perips.u_pmu.sim_ticks_reg;
    wire[`InstAddrBus] dbg_pc = heterogeneous_soc_top_0.u_riscv_cpu.u_pc_reg.pc_o;
    wire[`InstBus] dbg_if_inst = heterogeneous_soc_top_0.u_riscv_cpu.u_if_id.inst_o;
    wire[`InstAddrBus] dbg_if_addr = heterogeneous_soc_top_0.u_riscv_cpu.u_if_id.inst_addr_o;
    wire[`InstBus] dbg_fetch_inst = heterogeneous_soc_top_0.u_riscv_cpu.fetch_resp_inst_o;
    wire[`InstAddrBus] dbg_fetch_addr = heterogeneous_soc_top_0.u_riscv_cpu.fetch_resp_addr_o;
    wire dbg_fetch_hold = heterogeneous_soc_top_0.u_riscv_cpu.fetch_hold_flag_o;
    wire[`MemAddrBus] dbg_fetch_backend_addr = heterogeneous_soc_top_0.u_riscv_cpu.fetch_mem_addr_o;
`ifndef DisableICache
    wire dbg_icache_fill_active = heterogeneous_soc_top_0.u_riscv_cpu.u_icache.fill_active;
    wire[`MemAddrBus] dbg_icache_fill_base = heterogeneous_soc_top_0.u_riscv_cpu.u_icache.fill_base_addr;
`else
    wire dbg_icache_fill_active = 1'b0;
    wire[`MemAddrBus] dbg_icache_fill_base = `ZeroWord;
`endif
    wire[`InstBus] dbg_id_inst = heterogeneous_soc_top_0.u_riscv_cpu.u_id.inst_o;
    wire[`InstBus] dbg_ex_inst = heterogeneous_soc_top_0.u_riscv_cpu.u_id_ex.inst_o;
    wire[`InstBus] dbg_mem_inst = heterogeneous_soc_top_0.u_riscv_cpu.u_ex_mem.inst_o;
    wire[`InstBus] dbg_wb_inst = heterogeneous_soc_top_0.u_riscv_cpu.u_mem_wb.inst_o;
    wire dbg_fetch_resp_valid = heterogeneous_soc_top_0.u_riscv_cpu.fetch_resp_valid_o;
    wire dbg_fetch_backend_hold = heterogeneous_soc_top_0.u_riscv_cpu.fetch_backend_hold_o;
    wire dbg_ifetch_pending = heterogeneous_soc_top_0.u_riscv_cpu.u_ifetch.req_pending_r;
    wire dbg_ifetch_resp_valid = heterogeneous_soc_top_0.u_riscv_cpu.u_ifetch.resp_valid_o;
    wire[`InstAddrBus] dbg_ifetch_req_addr = heterogeneous_soc_top_0.u_riscv_cpu.u_ifetch.req_addr_r;
    wire dbg_if_replay_hold = heterogeneous_soc_top_0.u_riscv_cpu.if_replay_hold_o;
    wire[1:0] dbg_if_slot_count = heterogeneous_soc_top_0.u_riscv_cpu.u_if_id.slot_count;
    wire dbg_em_req = heterogeneous_soc_top_0.u_riscv_cpu.u_ex_mem.mem_req_o;
    wire dbg_em_load = heterogeneous_soc_top_0.u_riscv_cpu.u_ex_mem.mem_load_o;
    wire[`MemAddrBus] dbg_em_addr = heterogeneous_soc_top_0.u_riscv_cpu.u_ex_mem.mem_addr_o;
    wire dbg_mem_req = heterogeneous_soc_top_0.u_riscv_cpu.mem_bus_req_o;
    wire[`MemAddrBus] dbg_mem_addr = heterogeneous_soc_top_0.u_riscv_cpu.mem_bus_addr_o;
    wire dbg_mem_reg_we = heterogeneous_soc_top_0.u_riscv_cpu.mem_reg_we_o;
    wire[`RegAddrBus] dbg_mem_reg_waddr = heterogeneous_soc_top_0.u_riscv_cpu.mem_reg_waddr_o;
    wire[`RegBus] dbg_mem_reg_wdata = heterogeneous_soc_top_0.u_riscv_cpu.mem_reg_wdata_o;
    wire dbg_wb_reg_we = heterogeneous_soc_top_0.u_riscv_cpu.wb_reg_we_o;
    wire[`RegAddrBus] dbg_wb_reg_waddr = heterogeneous_soc_top_0.u_riscv_cpu.wb_reg_waddr_o;
    wire[`RegBus] dbg_wb_reg_wdata = heterogeneous_soc_top_0.u_riscv_cpu.wb_reg_wdata_o;
    wire[`RegBus] dbg_id_reg1 = heterogeneous_soc_top_0.u_riscv_cpu.u_id.reg1_data;
    wire[`RegBus] dbg_id_reg2 = heterogeneous_soc_top_0.u_riscv_cpu.u_id.reg2_data;
    wire[63:0] perf_cycle = heterogeneous_soc_top_0.u_apb_perips.u_pmu.cycle_counter;
    wire[63:0] perf_inst = heterogeneous_soc_top_0.u_apb_perips.u_pmu.inst_counter;
    wire[63:0] perf_jump = heterogeneous_soc_top_0.u_apb_perips.u_pmu.jump_counter;
    wire[63:0] perf_load = heterogeneous_soc_top_0.u_apb_perips.u_pmu.load_counter;
    wire[63:0] perf_store = heterogeneous_soc_top_0.u_apb_perips.u_pmu.store_counter;
    wire[63:0] perf_hold = heterogeneous_soc_top_0.u_apb_perips.u_pmu.hold_counter;
    wire[63:0] perf_int = heterogeneous_soc_top_0.u_apb_perips.u_pmu.int_counter;
    wire[63:0] perf_div_wait = heterogeneous_soc_top_0.u_apb_perips.u_pmu.div_wait_counter;
    wire[63:0] perf_icache_hit = heterogeneous_soc_top_0.u_apb_perips.u_pmu.icache_hit_counter;
    wire[63:0] perf_icache_miss = heterogeneous_soc_top_0.u_apb_perips.u_pmu.icache_miss_counter;
    wire[63:0] perf_dcache_load_hit = heterogeneous_soc_top_0.u_apb_perips.u_pmu.dcache_load_hit_counter;
    wire[63:0] perf_dcache_load_miss = heterogeneous_soc_top_0.u_apb_perips.u_pmu.dcache_load_miss_counter;
    wire[63:0] perf_dcache_store_hit = heterogeneous_soc_top_0.u_apb_perips.u_pmu.dcache_store_hit_counter;
    wire[63:0] perf_dcache_store_miss = heterogeneous_soc_top_0.u_apb_perips.u_pmu.dcache_store_miss_counter;
    wire[63:0] perf_branch_redirect = heterogeneous_soc_top_0.u_apb_perips.u_pmu.branch_redirect_counter;
    wire[63:0] perf_branch_flush = heterogeneous_soc_top_0.u_apb_perips.u_pmu.branch_flush_counter;
    wire[63:0] perf_prefetch_occupancy_sum = heterogeneous_soc_top_0.u_apb_perips.u_pmu.prefetch_occupancy_sum_counter;
    wire[63:0] perf_prefetch_full = heterogeneous_soc_top_0.u_apb_perips.u_pmu.prefetch_full_counter;
    wire[63:0] perf_prefetch_stall = heterogeneous_soc_top_0.u_apb_perips.u_pmu.prefetch_stall_counter;
    wire[63:0] perf_branch_predict_hit = heterogeneous_soc_top_0.u_apb_perips.u_pmu.branch_predict_hit_counter;
    wire[63:0] perf_branch_predict_miss = heterogeneous_soc_top_0.u_apb_perips.u_pmu.branch_predict_miss_counter;
    wire[63:0] perf_dcache_load_miss_stall = heterogeneous_soc_top_0.u_apb_perips.u_pmu.dcache_load_miss_stall_counter;
    wire[63:0] perf_dcache_store_wait = heterogeneous_soc_top_0.u_apb_perips.u_pmu.dcache_store_wait_counter;
    wire[63:0] perf_fetch_bus_wait = heterogeneous_soc_top_0.u_apb_perips.u_pmu.fetch_bus_wait_counter;
    wire[63:0] perf_data_bus_wait = heterogeneous_soc_top_0.u_apb_perips.u_pmu.data_bus_wait_counter;
    wire[63:0] perf_id_contention = heterogeneous_soc_top_0.u_apb_perips.u_pmu.id_contention_counter;
    wire[63:0] perf_store_buffer_enqueue = heterogeneous_soc_top_0.u_apb_perips.u_pmu.store_buffer_enqueue_counter;
    wire[63:0] perf_store_buffer_full_stall = heterogeneous_soc_top_0.u_apb_perips.u_pmu.store_buffer_full_stall_counter;
    wire[63:0] perf_store_buffer_drain = heterogeneous_soc_top_0.u_apb_perips.u_pmu.store_buffer_drain_counter;
    wire uart_tx_valid = heterogeneous_soc_top_0.u_apb_perips.u_uart.tx_data_valid;
    wire[7:0] uart_tx_char = heterogeneous_soc_top_0.u_apb_perips.u_uart.tx_data;
    wire[`MemAddrBus] axil_awaddr = heterogeneous_soc_top_0.axil_awaddr;
    wire axil_awvalid = heterogeneous_soc_top_0.axil_awvalid;
    wire axil_awready = heterogeneous_soc_top_0.axil_awready;
    wire[`MemBus] axil_wdata = heterogeneous_soc_top_0.axil_wdata;
    wire[3:0] axil_wstrb = heterogeneous_soc_top_0.axil_wstrb;
    wire axil_wvalid = heterogeneous_soc_top_0.axil_wvalid;
    wire axil_wready = heterogeneous_soc_top_0.axil_wready;
    wire axil_bvalid = heterogeneous_soc_top_0.axil_bvalid;
    wire axil_bready = heterogeneous_soc_top_0.axil_bready;
    wire[`MemAddrBus] axil_araddr = heterogeneous_soc_top_0.axil_araddr;
    wire axil_arvalid = heterogeneous_soc_top_0.axil_arvalid;
    wire axil_arready = heterogeneous_soc_top_0.axil_arready;
    wire axil_rvalid = heterogeneous_soc_top_0.axil_rvalid;
    wire axil_rready = heterogeneous_soc_top_0.axil_rready;
    wire[`MemAddrBus] apb_paddr = heterogeneous_soc_top_0.apb_paddr;
    wire apb_psel = heterogeneous_soc_top_0.apb_psel;
    wire apb_penable = heterogeneous_soc_top_0.apb_penable;
    wire apb_pwrite = heterogeneous_soc_top_0.apb_pwrite;
    wire[`MemBus] apb_pwdata = heterogeneous_soc_top_0.apb_pwdata;
    wire[`MemBus] apb_prdata = heterogeneous_soc_top_0.apb_prdata;
    wire apb_pready = heterogeneous_soc_top_0.apb_pready;
    wire[`MemAddrBus] fetch_bus_addr = heterogeneous_soc_top_0.m1_addr_i;
    wire fetch_bus_req = heterogeneous_soc_top_0.m1_req_i;
    wire fetch_bus_ready = heterogeneous_soc_top_0.m1_ready_o;
    wire[`MemAddrBus] data_bus_addr = heterogeneous_soc_top_0.m0_addr_i;
    wire[`MemBus] data_bus_wdata = heterogeneous_soc_top_0.m0_data_i;
    wire[3:0] data_bus_wmask = heterogeneous_soc_top_0.m0_wmask_i;
    wire data_bus_req = heterogeneous_soc_top_0.m0_req_i;
    wire data_bus_we = heterogeneous_soc_top_0.m0_we_i;
    wire data_bus_ready = heterogeneous_soc_top_0.m0_ready_o;
    wire mem_wait_active = heterogeneous_soc_top_0.u_riscv_cpu.mem_hold_flag_o;
    wire load_hazard_active = heterogeneous_soc_top_0.u_riscv_cpu.load_hazard_flag;
    wire[2:0] ctrl_hold_flag = heterogeneous_soc_top_0.u_riscv_cpu.ctrl_hold_flag_o;
    wire apb_timer_sel = heterogeneous_soc_top_0.u_apb_perips.timer_sel;
    wire apb_uart_sel = heterogeneous_soc_top_0.u_apb_perips.uart_sel;
    wire apb_gpio_sel = heterogeneous_soc_top_0.u_apb_perips.gpio_sel;
    wire apb_spi_sel = heterogeneous_soc_top_0.u_apb_perips.spi_sel;
    wire apb_pmu_sel = heterogeneous_soc_top_0.u_apb_perips.pmu_sel;
    wire apb_dma_sel = heterogeneous_soc_top_0.u_apb_perips.dma_sel;
    wire apb_qspi_sel = heterogeneous_soc_top_0.u_apb_perips.qspi_sel;
    wire[3:0] apb_sel_count = {3'b0, apb_timer_sel} + {3'b0, apb_uart_sel} + {3'b0, apb_gpio_sel} + {3'b0, apb_spi_sel} + {3'b0, apb_pmu_sel} + {3'b0, apb_dma_sel} + {3'b0, apb_qspi_sel};
    wire dbg_mem_busy = heterogeneous_soc_top_0.axi_busy;
    wire dbg_mem_resp_valid = |heterogeneous_soc_top_0.axi_bvalid |
                              |heterogeneous_soc_top_0.axi_rvalid;
    wire dbg_mem_cooldown = 1'b0;
    wire dbg_mem_sel_req = |heterogeneous_soc_top_0.axi_slave_awvalid |
                           |heterogeneous_soc_top_0.axi_slave_arvalid;
    wire dbg_mem_slave_ready = |heterogeneous_soc_top_0.axi_slave_awready |
                               |heterogeneous_soc_top_0.axi_slave_arready;

    integer r;
    time sim_timeout;
    integer fetch_bus_req_count;
    integer fetch_bus_wait_count;
    integer data_bus_req_count;
    integer data_bus_wait_count;
    reg fetch_wait_active;
    reg[`MemAddrBus] fetch_wait_addr;
    reg data_wait_active;
    reg[`MemAddrBus] data_wait_addr;
    reg[`MemBus] data_wait_wdata;
    reg[3:0] data_wait_wmask;
    reg data_wait_we;
    integer copy_trace_count;
    reg [4:0] prev_dma_state;
    reg prev_dma_done;
    reg prev_dma_error;
    reg [2:0] prev_axil_bridge_state;
    reg [2:0] prev_apb_bridge_state;
    reg prev_s2_req;
    reg prev_s2_ready;

    always @ (posedge clk) begin
        if (rst == `RstDisable && uart_tx_valid == 1'b1) begin
            $write("%c", uart_tx_char);
        end
    end

    always @ (posedge heterogeneous_soc_top_0.u_apb_perips.u_spi.en or negedge rst) begin
        if (rst == `RstEnable) begin
            flash_shift_in <= 8'h00;
            flash_shift_out <= 8'hff;
            flash_miso_bit_idx <= 4'd7;
            tb_spi_miso <= 1'b1;
        end else if (tb_spi_ss == 1'b0) begin
            flash_shift_in <= 8'h00;
            flash_shift_out <= flash_next_byte_w;
            flash_miso_bit_idx <= 4'd7;
            tb_spi_miso <= flash_next_byte_w[7];
            case (flash_state)
                FLASH_ST_IDLE: begin
                    if (flash_tx_byte == 8'h9f) begin
                        flash_state <= FLASH_ST_ID;
                        flash_id_idx <= 2'd0;
                    end else if (flash_tx_byte == 8'h03) begin
                        flash_state <= FLASH_ST_READ_ADDR;
                        flash_addr_idx <= 2'd0;
                        flash_addr <= 24'h0;
                    end
                end
                FLASH_ST_READ_ADDR: begin
                    flash_addr <= {flash_addr[15:0], flash_tx_byte};
                    if (flash_addr_idx == 2'd2) begin
                        flash_state <= FLASH_ST_READ_DATA;
                        flash_addr_idx <= 2'd0;
                    end else begin
                        flash_addr_idx <= flash_addr_idx + 1'b1;
                    end
                end
                default: begin
                end
            endcase
        end else begin
            flash_shift_in <= 8'h00;
            flash_shift_out <= 8'hff;
            flash_miso_bit_idx <= 4'd7;
            tb_spi_miso <= 1'b1;
        end
    end

    always @ (posedge tb_spi_clk) begin
        if (rst == `RstDisable && heterogeneous_soc_top_0.u_apb_perips.u_spi.en == 1'b1 && tb_spi_ss == 1'b0) begin
            flash_shift_in <= {flash_shift_in[6:0], tb_spi_mosi};
        end
    end

    always @ (negedge tb_spi_clk) begin
        if (rst == `RstDisable && heterogeneous_soc_top_0.u_apb_perips.u_spi.en == 1'b1 && tb_spi_ss == 1'b0) begin
            if (flash_miso_bit_idx > 0) begin
                flash_miso_bit_idx <= flash_miso_bit_idx - 1'b1;
                tb_spi_miso <= flash_shift_out[flash_miso_bit_idx - 1'b1];
            end
        end
    end

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            flash_state <= FLASH_ST_IDLE;
            flash_id_idx <= 2'd0;
            flash_addr_idx <= 2'd0;
            flash_addr <= 24'h0;
            flash_session_idx <= 4'd0;
            flash_byte_idx <= 8'd0;
        end else if (tb_spi_ss == 1'b1) begin
            flash_state <= FLASH_ST_IDLE;
            flash_id_idx <= 2'd0;
            flash_addr_idx <= 2'd0;
            flash_addr <= 24'h0;
            if (flash_byte_idx != 8'd0) begin
                flash_session_idx <= flash_session_idx + 1'b1;
            end
            flash_byte_idx <= 8'd0;
        end else if (heterogeneous_soc_top_0.u_apb_perips.u_spi.done == 1'b1) begin
            flash_byte_idx <= flash_byte_idx + 1'b1;
            flash_shift_out <= flash_after_done_byte_w;
            tb_spi_miso <= flash_after_done_byte_w[7];
            case (flash_state)
                FLASH_ST_ID: begin
                    if (flash_id_idx != 2'd3) begin
                        flash_id_idx <= flash_id_idx + 1'b1;
                    end
                end
                FLASH_ST_READ_DATA: begin
                    flash_addr <= flash_addr + 1'b1;
                end
                default: begin
                end
            endcase
        end
    end

    always @ (posedge tb_qspi_cs_n or negedge rst) begin
        if (rst == `RstEnable) begin
            qspi_flash_state <= QSPI_ST_CMD;
            qspi_flash_shift_in <= 8'h00;
            qspi_flash_shift_out <= 8'hff;
            qspi_flash_bit_count <= 3'h0;
            qspi_flash_out_bit <= 3'd7;
            qspi_flash_addr_idx <= 2'h0;
            qspi_flash_id_idx <= 2'h0;
            qspi_flash_is_id <= 1'b0;
            qspi_flash_addr <= 24'h0;
            tb_qspi_io1_drv <= 1'b1;
        end else begin
            qspi_flash_state <= QSPI_ST_CMD;
            qspi_flash_shift_in <= 8'h00;
            qspi_flash_shift_out <= 8'hff;
            qspi_flash_bit_count <= 3'h0;
            qspi_flash_out_bit <= 3'd7;
            qspi_flash_addr_idx <= 2'h0;
            qspi_flash_id_idx <= 2'h0;
            qspi_flash_is_id <= 1'b0;
            qspi_flash_addr <= 24'h0;
            tb_qspi_io1_drv <= 1'b1;
        end
    end

    always @ (posedge tb_qspi_clk) begin
        if (rst == `RstDisable && tb_qspi_cs_n == 1'b0) begin
            qspi_flash_shift_in <= {qspi_flash_shift_in[6:0], tb_qspi_io[0]};
            if (qspi_flash_bit_count == 3'd7) begin
                qspi_flash_bit_count <= 3'h0;
                case (qspi_flash_state)
                    QSPI_ST_CMD: begin
                        if ({qspi_flash_shift_in[6:0], tb_qspi_io[0]} == 8'h9f) begin
                            qspi_flash_state <= QSPI_ST_READ;
                            qspi_flash_id_idx <= 2'h0;
                            qspi_flash_is_id <= 1'b1;
                            qspi_flash_shift_out <= flash_jedec_id(2'h0);
                            qspi_flash_out_bit <= 3'd7;
                        end else if ({qspi_flash_shift_in[6:0], tb_qspi_io[0]} == 8'h03) begin
                            qspi_flash_state <= QSPI_ST_ADDR;
                            qspi_flash_is_id <= 1'b0;
                            qspi_flash_addr <= 24'h0;
                            qspi_flash_addr_idx <= 2'h0;
                        end
                    end
                    QSPI_ST_ADDR: begin
                        qspi_flash_addr <= {qspi_flash_addr[15:0], qspi_flash_shift_in[6:0], tb_qspi_io[0]};
                        if (qspi_flash_addr_idx == 2'd2) begin
                            qspi_flash_state <= QSPI_ST_READ;
                            qspi_flash_shift_out <= flash_mem[{qspi_flash_addr[7:0], qspi_flash_shift_in[6:0], tb_qspi_io[0]}];
                            qspi_flash_out_bit <= 3'd7;
                        end else begin
                            qspi_flash_addr_idx <= qspi_flash_addr_idx + 1'b1;
                        end
                    end
                    default: begin
                    end
                endcase
            end else begin
                qspi_flash_bit_count <= qspi_flash_bit_count + 1'b1;
            end
        end
    end

    always @ (negedge tb_qspi_clk) begin
        if (rst == `RstDisable && tb_qspi_cs_n == 1'b0 && qspi_flash_state == QSPI_ST_READ) begin
            tb_qspi_io1_drv <= qspi_flash_shift_out[qspi_flash_out_bit];
            if (qspi_flash_out_bit == 3'd0) begin
                qspi_flash_out_bit <= 3'd7;
                if (qspi_flash_is_id == 1'b1 && qspi_flash_id_idx != 2'd3) begin
                    qspi_flash_id_idx <= qspi_flash_id_idx + 1'b1;
                    qspi_flash_shift_out <= flash_jedec_id(qspi_flash_id_idx + 1'b1);
                end else begin
                    qspi_flash_addr <= qspi_flash_addr + 1'b1;
                    qspi_flash_shift_out <= flash_mem[qspi_flash_addr[8:0] + 1'b1];
                end
            end else begin
                qspi_flash_out_bit <= qspi_flash_out_bit - 1'b1;
            end
        end
    end

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            fetch_bus_req_count <= 0;
            fetch_bus_wait_count <= 0;
            data_bus_req_count <= 0;
            data_bus_wait_count <= 0;
            fetch_wait_active <= 1'b0;
            fetch_wait_addr <= `ZeroWord;
            data_wait_active <= 1'b0;
            data_wait_addr <= `ZeroWord;
            data_wait_wdata <= `ZeroWord;
            data_wait_wmask <= 4'b0;
            data_wait_we <= 1'b0;
            copy_trace_count <= 0;
            prev_dma_state <= 5'h0;
            prev_dma_done <= 1'b0;
            prev_dma_error <= 1'b0;
            prev_axil_bridge_state <= 3'h0;
            prev_apb_bridge_state <= 3'h0;
            prev_s2_req <= 1'b0;
            prev_s2_ready <= 1'b0;
        end else begin
            if (fetch_bus_req === 1'b1) begin
                fetch_bus_req_count <= fetch_bus_req_count + 1;
                if (fetch_bus_ready !== 1'b1) begin
                    fetch_bus_wait_count <= fetch_bus_wait_count + 1;
                end
            end
            if (data_bus_req === 1'b1) begin
                data_bus_req_count <= data_bus_req_count + 1;
                if (data_bus_ready !== 1'b1) begin
                    data_bus_wait_count <= data_bus_wait_count + 1;
                end
            end

            if (fetch_wait_active == 1'b0) begin
                if (fetch_bus_req === 1'b1 && fetch_bus_ready !== 1'b1) begin
                    fetch_wait_active <= 1'b1;
                    fetch_wait_addr <= fetch_bus_addr;
                end
            end else begin
                if (fetch_bus_req !== 1'b1) begin
                    $display("Fetch handshake error: req dropped before ready at pc=0x%08x", dbg_pc);
                    $finish;
                end
                if (fetch_bus_addr !== fetch_wait_addr) begin
                    $display("Fetch handshake error: addr changed while waiting old=0x%08x new=0x%08x", fetch_wait_addr, fetch_bus_addr);
                    $finish;
                end
                if (fetch_bus_ready === 1'b1) begin
                    fetch_wait_active <= 1'b0;
                end
            end

            if (data_wait_active == 1'b0) begin
                if (data_bus_req === 1'b1 && data_bus_ready !== 1'b1) begin
                    data_wait_active <= 1'b1;
                    data_wait_addr <= data_bus_addr;
                    data_wait_wdata <= data_bus_wdata;
                    data_wait_wmask <= data_bus_wmask;
                    data_wait_we <= data_bus_we;
                end
            end else begin
                if (data_bus_req !== 1'b1) begin
                    $display("Data handshake error: req dropped before ready at pc=0x%08x", dbg_pc);
                    $finish;
                end
                if (data_bus_addr !== data_wait_addr || data_bus_wdata !== data_wait_wdata || data_bus_wmask !== data_wait_wmask || data_bus_we !== data_wait_we) begin
                    $display("Data handshake error: request changed while waiting old_addr=0x%08x new_addr=0x%08x", data_wait_addr, data_bus_addr);
                    $finish;
                end
                if (data_bus_ready === 1'b1) begin
                    data_wait_active <= 1'b0;
                end
            end

`ifdef TRACE_AUTONOMOUS_MAC_DEBUG
            if (heterogeneous_soc_top_0.u_apb_perips.u_dma.state_r !== prev_dma_state ||
                heterogeneous_soc_top_0.u_apb_perips.u_dma.done_r !== prev_dma_done ||
                heterogeneous_soc_top_0.u_apb_perips.u_dma.error_r !== prev_dma_error) begin
                $display("DMATRACE t=%0t pc=%08x dma_state=%0d done=%0b err=%0b src=%08x dst=%08x len=%08x moved=%08x rem=%08x",
                    $time,
                    dbg_pc,
                    heterogeneous_soc_top_0.u_apb_perips.u_dma.state_r,
                    heterogeneous_soc_top_0.u_apb_perips.u_dma.done_r,
                    heterogeneous_soc_top_0.u_apb_perips.u_dma.error_r,
                    heterogeneous_soc_top_0.u_apb_perips.u_dma.src_reg,
                    heterogeneous_soc_top_0.u_apb_perips.u_dma.dst_reg,
                    heterogeneous_soc_top_0.u_apb_perips.u_dma.len_reg,
                    heterogeneous_soc_top_0.u_apb_perips.u_dma.moved_count_r,
                    heterogeneous_soc_top_0.u_apb_perips.u_dma.remaining_r);
                prev_dma_state <= heterogeneous_soc_top_0.u_apb_perips.u_dma.state_r;
                prev_dma_done <= heterogeneous_soc_top_0.u_apb_perips.u_dma.done_r;
                prev_dma_error <= heterogeneous_soc_top_0.u_apb_perips.u_dma.error_r;
            end

            if (heterogeneous_soc_top_0.u_axi4_to_apb_bridge.u_bridge.state_r !== prev_apb_bridge_state ||
                heterogeneous_soc_top_0.axi_slave_awvalid[2] !== prev_s2_req ||
                heterogeneous_soc_top_0.s2_ready_i !== prev_s2_ready) begin
                $display("BRIDGETRACE t=%0t pc=%08x s2_req=%0b s2_ready=%0b mem_busy=%0b axil_state=%0d apb_state=%0d awv=%0b awr=%0b wv=%0b wr=%0b bv=%0b arv=%0b arr=%0b rv=%0b",
                    $time,
                    dbg_pc,
                    heterogeneous_soc_top_0.axi_slave_awvalid[2] | heterogeneous_soc_top_0.axi_slave_arvalid[2],
                    heterogeneous_soc_top_0.axi_slave_awready[2] | heterogeneous_soc_top_0.axi_slave_arready[2],
                    heterogeneous_soc_top_0.axi_busy,
                    3'd0,
                    heterogeneous_soc_top_0.u_axi4_to_apb_bridge.u_bridge.state_r,
                    axil_awvalid,
                    axil_awready,
                    axil_wvalid,
                    axil_wready,
                    axil_bvalid,
                    axil_arvalid,
                    axil_arready,
                    axil_rvalid);
                prev_axil_bridge_state <= 3'd0;
                prev_apb_bridge_state <= heterogeneous_soc_top_0.u_axi4_to_apb_bridge.u_bridge.state_r;
                prev_s2_req <= heterogeneous_soc_top_0.axi_slave_awvalid[2] |
                               heterogeneous_soc_top_0.axi_slave_arvalid[2];
                prev_s2_ready <= heterogeneous_soc_top_0.s2_ready_i;
            end

`endif
        end
    end

`ifdef TRACE_COPY_LOOP
    always @ (posedge clk) begin
        if (rst == `RstDisable && copy_trace_count < 80 && dbg_pc >= 32'h00000030 && dbg_pc <= 32'h00000040) begin
            copy_trace_count <= copy_trace_count + 1;
            $display("TRACE pc=%08x f_addr=%08x f_hold=%b f_inst=%08x if_addr=%08x hold=%0d load_hzd=%b mem_wait=%b if=%08x id=%08x ex=%08x mem=%08x a0=%08x a1=%08x bus_req=%b bus_we=%b bus_addr=%08x",
                dbg_pc, dbg_fetch_addr, dbg_fetch_hold, dbg_fetch_inst, dbg_if_addr, ctrl_hold_flag, load_hazard_active, mem_wait_active,
                dbg_if_inst, dbg_id_inst, dbg_ex_inst, dbg_mem_inst, x10, x11,
                data_bus_req, data_bus_we, data_bus_addr);
        end
    end
`endif

`ifdef TRACE_LW_WAIT
    always @ (posedge clk) begin
        if (rst == `RstDisable && dbg_pc <= 32'h00000024) begin
            $display("LWTRACE pc=%08x hold=%0d if=%08x id=%08x ex=%08x mem=%08x f_inst=%08x f_addr=%08x f_be_addr=%08x f_resp_v=%b f_hold=%b ic_fill=%b ic_base=%08x if_req_p=%b if_resp_p=%b if_req_addr=%08x em_req=%b em_load=%b em_addr=%08x mem_req=%b mem_addr=%08x m0_ready=%b m1_ready=%b mem_sel=%b mem_sready=%b mem_busy=%b mem_resp=%b mem_cd=%b mem_reg_we=%b mem_reg=%0d mem_wdata=%08x x1=%08x x29=%08x x30=%08x",
                dbg_pc, ctrl_hold_flag, dbg_if_inst, dbg_id_inst, dbg_ex_inst, dbg_mem_inst,
                dbg_fetch_inst, dbg_fetch_addr, dbg_fetch_backend_addr, dbg_fetch_resp_valid, dbg_fetch_backend_hold, dbg_icache_fill_active, dbg_icache_fill_base,
                dbg_ifetch_pending, dbg_ifetch_resp_valid, dbg_ifetch_req_addr,
                dbg_em_req, dbg_em_load, dbg_em_addr, dbg_mem_req, dbg_mem_addr, data_bus_ready, fetch_bus_ready, dbg_mem_sel_req, dbg_mem_slave_ready, dbg_mem_busy, dbg_mem_resp_valid, dbg_mem_cooldown,
                dbg_mem_reg_we, dbg_mem_reg_waddr, dbg_mem_reg_wdata, heterogeneous_soc_top_0.u_riscv_cpu.u_regs.regs[1], x29, x30);
        end
    end
`endif

`ifdef TRACE_PC80
    always @ (posedge clk) begin
        if (rst == `RstDisable && dbg_pc <= 32'h00000080) begin
            $display("PCTRACE pc=%08x hold=%0d if=%08x id=%08x ex=%08x mem=%08x f_inst=%08x f_addr=%08x f_be=%08x f_resp=%b f_hold=%b if_pend=%b if_resp=%b if_slots=%0d replay=%b ic_fill=%b ic_base=%08x m1_ready=%b mem_busy=%b mem_resp=%b jump=%b jump_addr=%08x gp=%08x",
                dbg_pc, ctrl_hold_flag, dbg_if_inst, dbg_id_inst, dbg_ex_inst, dbg_mem_inst,
                dbg_fetch_inst, dbg_fetch_addr, dbg_fetch_backend_addr, dbg_fetch_resp_valid, dbg_fetch_hold,
                dbg_ifetch_pending, dbg_ifetch_resp_valid, dbg_if_slot_count, dbg_if_replay_hold,
                dbg_icache_fill_active, dbg_icache_fill_base, fetch_bus_ready, dbg_mem_busy, dbg_mem_resp_valid,
                heterogeneous_soc_top_0.u_riscv_cpu.ex_jump_flag_o, heterogeneous_soc_top_0.u_riscv_cpu.ex_jump_addr_o, x3);
        end
    end
`endif

`ifdef TRACE_MAIN_PROLOGUE
    always @ (posedge clk) begin
        if (rst == `RstDisable && dbg_pc >= 32'h000003e0 && dbg_pc <= 32'h000004c0) begin
            $display("MAINTRACE pc=%08x hold=%0d if=%08x@%08x id=%08x ex=%08x mem=%08x wb=%08x fetch=%08x@%08x fv=%b rdyp=%b q=%0d slot=%0d pend=%b paddr=%08x em_req=%b em_addr=%08x bus_req=%b bus_addr=%08x bus_we=%b a4=%08x a5=%08x wb_we=%b wb_rd=%0d wb_data=%08x jump=%b jump_addr=%08x",
                dbg_pc, ctrl_hold_flag, dbg_if_inst, dbg_if_addr, dbg_id_inst,
                dbg_ex_inst, dbg_mem_inst, dbg_wb_inst,
                dbg_fetch_inst, dbg_fetch_addr, dbg_fetch_resp_valid,
                heterogeneous_soc_top_0.u_riscv_cpu.fetch_resp_ready_o,
                heterogeneous_soc_top_0.u_riscv_cpu.u_ifetch.queue_count,
                dbg_if_slot_count, dbg_ifetch_pending, dbg_ifetch_req_addr,
                dbg_em_req, dbg_em_addr, dbg_mem_req, dbg_mem_addr,
                heterogeneous_soc_top_0.u_riscv_cpu.mem_bus_we_o,
                heterogeneous_soc_top_0.u_riscv_cpu.u_regs.regs[14],
                heterogeneous_soc_top_0.u_riscv_cpu.u_regs.regs[15],
                dbg_wb_reg_we, dbg_wb_reg_waddr, dbg_wb_reg_wdata,
                heterogeneous_soc_top_0.u_riscv_cpu.ex_jump_flag_o,
                heterogeneous_soc_top_0.u_riscv_cpu.ex_jump_addr_o);
        end
    end
`endif

`ifdef TRACE_INIT_EPILOGUE
    always @ (posedge clk) begin
        if (rst == `RstDisable && dbg_pc >= 32'h00000198 && dbg_pc <= 32'h000001c0) begin
            $display("INITTRACE pc=%08x hold=%0d if=%08x id=%08x ex=%08x mem=%08x wb=%08x sp=%08x s0=%08x ra=%08x wb_we=%b wb_rd=%0d wb_data=%08x jump=%b jump_addr=%08x",
                dbg_pc, ctrl_hold_flag, dbg_if_inst, dbg_id_inst, dbg_ex_inst,
                dbg_mem_inst, dbg_wb_inst,
                heterogeneous_soc_top_0.u_riscv_cpu.u_regs.regs[2],
                heterogeneous_soc_top_0.u_riscv_cpu.u_regs.regs[8],
                heterogeneous_soc_top_0.u_riscv_cpu.u_regs.regs[1],
                dbg_wb_reg_we, dbg_wb_reg_waddr, dbg_wb_reg_wdata,
                heterogeneous_soc_top_0.u_riscv_cpu.ex_jump_flag_o,
                heterogeneous_soc_top_0.u_riscv_cpu.ex_jump_addr_o);
        end
    end
`endif

`ifdef TRACE_TEST25
    always @ (posedge clk) begin
        if (rst == `RstDisable && dbg_pc >= 32'h00000268 && dbg_pc <= 32'h000002a8) begin
            $display("T25 pc=%08x hold=%0d if=%08x id=%08x ex=%08x mem=%08x wb=%08x x0=%08x x1=%08x x3=%08x x29=%08x wb_we=%b wb_rd=%0d wb_data=%08x mem_we=%b mem_rd=%0d mem_data=%08x id_r1=%08x id_r2=%08x jump=%b jump_addr=%08x",
                dbg_pc, ctrl_hold_flag, dbg_if_inst, dbg_id_inst, dbg_ex_inst, dbg_mem_inst, dbg_wb_inst,
                heterogeneous_soc_top_0.u_riscv_cpu.u_regs.regs[0], x1, x3, x29,
                dbg_wb_reg_we, dbg_wb_reg_waddr, dbg_wb_reg_wdata,
                dbg_mem_reg_we, dbg_mem_reg_waddr, dbg_mem_reg_wdata,
                dbg_id_reg1, dbg_id_reg2,
                heterogeneous_soc_top_0.u_riscv_cpu.ex_jump_flag_o, heterogeneous_soc_top_0.u_riscv_cpu.ex_jump_addr_o);
        end
    end
`endif

    always @ (posedge clk) begin
        if (rst == `RstDisable && apb_psel === 1'b1 && apb_penable === 1'b1 && apb_sel_count != 3'd1) begin
            $display("APB decode error: addr=0x%08x sel_count=%0d timer=%b uart=%b gpio=%b spi=%b pmu=%b dma=%b",
                apb_paddr, apb_sel_count, apb_timer_sel, apb_uart_sel, apb_gpio_sel, apb_spi_sel, apb_pmu_sel, apb_dma_sel);
            $finish;
        end
        if (rst == `RstDisable && apb_penable === 1'b1 && apb_psel !== 1'b1) begin
            $display("APB handshake error: PENABLE without PSEL");
            $finish;
        end
`ifndef IVERILOG
        if (rst == `RstDisable && axil_awvalid === 1'b1 && axil_awready !== 1'b1 && $isunknown(axil_awaddr)) begin
            $display("AXI-Lite handshake error: AWADDR unknown while waiting");
            $finish;
        end
        if (rst == `RstDisable && axil_wvalid === 1'b1 && axil_wready !== 1'b1 && ($isunknown(axil_wdata) || $isunknown(axil_wstrb))) begin
            $display("AXI-Lite handshake error: WDATA/WSTRB unknown while waiting");
            $finish;
        end
        if (rst == `RstDisable && axil_bvalid === 1'b1 && axil_bready !== 1'b1) begin
            $display("AXI-Lite handshake error: BVALID asserted while BREADY low");
            $finish;
        end
        if (rst == `RstDisable && axil_rvalid === 1'b1 && axil_rready !== 1'b1) begin
            $display("AXI-Lite handshake error: RVALID asserted while RREADY low");
            $finish;
        end
        if (rst == `RstDisable && mem_wait_active === 1'b1 && data_bus_ready !== 1'b1 && ctrl_hold_flag != `Hold_Ex) begin
            $display("Pipeline stall error: mem wait without Hold_Ex pc=%08x hold=%0d if=%08x id=%08x ex=%08x mem=%08x data_req=%b data_we=%b data_addr=%08x ready=%b jump=%b jump_addr=%08x",
                dbg_pc, ctrl_hold_flag, dbg_if_inst, dbg_id_inst, dbg_ex_inst, dbg_mem_inst,
                data_bus_req, data_bus_we, data_bus_addr, data_bus_ready,
                heterogeneous_soc_top_0.u_riscv_cpu.ex_jump_flag_o,
                heterogeneous_soc_top_0.u_riscv_cpu.ex_jump_addr_o);
            $finish;
        end
`ifndef DisableICache
        if (rst == `RstDisable && heterogeneous_soc_top_0.u_riscv_cpu.u_icache.fill_active === 1'b1 && fetch_bus_ready !== 1'b1 && ctrl_hold_flag != `Hold_If && ctrl_hold_flag != `Hold_Ex && ctrl_hold_flag != `Hold_Id && ctrl_hold_flag != `Hold_Load) begin
            $display("I-Cache stall error: fill_active without Hold_If");
            $finish;
        end
`endif
    end
`endif

`ifndef IVERILOG
`ifndef ALLOW_ARCH_X
    // Stop at the first architectural X so the original failing transaction
    // is visible before an unknown return address contaminates the PC.
    always @ (posedge clk) begin
        if (rst == `RstDisable && $isunknown(dbg_pc)) begin
            $display("ARCH_X: PC became unknown, wb_inst=%08x wb_we=%b wb_rd=%0d wb_data=%08x",
                dbg_wb_inst, dbg_wb_reg_we, dbg_wb_reg_waddr, dbg_wb_reg_wdata);
            $finish;
        end
        if (rst == `RstDisable && dbg_wb_reg_we === 1'b1 && dbg_wb_reg_waddr != 5'd0 &&
            $isunknown(dbg_wb_reg_wdata)) begin
            $display("ARCH_X: unknown WB data pc=%08x wb_inst=%08x wb_rd=%0d mem_inst=%08x mem_addr=%08x mem_req=%b mem_ready=%b",
                dbg_pc, dbg_wb_inst, dbg_wb_reg_waddr, dbg_mem_inst, dbg_mem_addr,
                data_bus_req, data_bus_ready);
            $finish;
        end
    end
`endif
`endif

`ifdef TRACE_AUTONOMOUS_MAC_DEBUG
    always @ (posedge clk) begin
        if (rst == `RstDisable && apb_psel === 1'b1 && apb_penable === 1'b1 && apb_pready === 1'b1 && apb_dma_sel === 1'b1) begin
            $display("APB %s addr=%08x wdata=%08x rdata=%08x dma_sel=%b pc=%08x",
                apb_pwrite ? "WR" : "RD",
                apb_paddr,
                apb_pwdata,
                apb_prdata,
                apb_dma_sel,
                dbg_pc);
        end
    end
`endif

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

`ifdef TEST_PROG
`ifdef COREMARK_SIM_DONE
        wait(pmu_sim_done === 32'h1)
        #100
        $display("~~~~~~~~~~~~~~~~~~~ TEST_PASS ~~~~~~~~~~~~~~~~~~~");
        $display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
        $display("~~~~~~~~~ #####     ##     ####    #### ~~~~~~~~~");
        $display("~~~~~~~~~ #    #   #  #   #       #     ~~~~~~~~~");
        $display("~~~~~~~~~ #    #  #    #   ####    #### ~~~~~~~~~");
        $display("~~~~~~~~~ #####   ######       #       #~~~~~~~~~");
        $display("~~~~~~~~~ #       #    #  #    #  #    #~~~~~~~~~");
        $display("~~~~~~~~~ #       #    #   ####    #### ~~~~~~~~~");
        $display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
        $display("Perf baseline cycle = %0d", coremark_ticks);
        $display("Perf baseline inst  = %0d", x28);
        $display("Perf baseline hold  = %0d", x29);
        $display("Perf aux value      = %0d", x30);
`else
        wait(x26 === 32'b1)   // wait sim end, when x26 == 1
        repeat (64) @(posedge clk);
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
            $display("extmem_dbg[7fd] = 0x%08x", heterogeneous_soc_top_0.u_axi4_mem_model.mem['h7fd]);
            $display("extmem_dbg[7fe] = 0x%08x", heterogeneous_soc_top_0.u_axi4_mem_model.mem['h7fe]);
            $display("extmem_dbg[7ff] = 0x%08x", heterogeneous_soc_top_0.u_axi4_mem_model.mem['h7ff]);
        end
`endif
        $display("PMU cycle     = %0d", perf_cycle);
        $display("PMU inst      = %0d", perf_inst);
        $display("PMU jump      = %0d", perf_jump);
        $display("PMU load      = %0d", perf_load);
        $display("PMU store     = %0d", perf_store);
        $display("PMU hold      = %0d", perf_hold);
        $display("PMU interrupt = %0d", perf_int);
        $display("PMU div_wait  = %0d", perf_div_wait);
        $display("PMU ic_hit    = %0d", perf_icache_hit);
        $display("PMU ic_miss   = %0d", perf_icache_miss);
        $display("PMU dc_ld_hit = %0d", perf_dcache_load_hit);
        $display("PMU dc_ld_miss= %0d", perf_dcache_load_miss);
        $display("PMU dc_st_hit = %0d", perf_dcache_store_hit);
        $display("PMU dc_st_miss= %0d", perf_dcache_store_miss);
        $display("PMU br_redir  = %0d", perf_branch_redirect);
        $display("PMU br_flush  = %0d", perf_branch_flush);
        $display("PMU pfq_occ_sum = %0d", perf_prefetch_occupancy_sum);
        $display("PMU pfq_full    = %0d", perf_prefetch_full);
        $display("PMU pfq_stall   = %0d", perf_prefetch_stall);
        $display("PMU bp_hit/miss = %0d/%0d", perf_branch_predict_hit, perf_branch_predict_miss);
        $display("PMU dc_ld_stall = %0d", perf_dcache_load_miss_stall);
        $display("PMU dc_st_wait  = %0d", perf_dcache_store_wait);
        $display("PMU fetch_wait  = %0d", perf_fetch_bus_wait);
        $display("PMU data_wait   = %0d", perf_data_bus_wait);
        $display("PMU id_contend  = %0d", perf_id_contention);
        $display("PMU sb_enq       = %0d", perf_store_buffer_enqueue);
        $display("PMU sb_full      = %0d", perf_store_buffer_full_stall);
        $display("PMU sb_drain     = %0d", perf_store_buffer_drain);
        $display("Fetch bus req = %0d", fetch_bus_req_count);
        $display("Fetch bus wait = %0d", fetch_bus_wait_count);
        $display("Data bus req  = %0d", data_bus_req_count);
        $display("Data bus wait = %0d", data_bus_wait_count);
        $display("CoreMark ticks = %0d", coremark_ticks);
`endif

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

        if (dmstatus == shift_reg[33:2]) begin
            $display("######################");
            $display("### jtag test pass ###");
            $display("######################");
        end else begin
            $display("######################");
            $display("!!! jtag test fail !!!");
            $display("######################");
        end
`endif

        $finish;
    end

    // sim timeout
    initial begin
        sim_timeout = `SIM_TIMEOUT;
        #sim_timeout
        $display("Time Out.");
        $display("dbg_pc        = 0x%08x", dbg_pc);
        $display("dbg_if_inst   = 0x%08x", dbg_if_inst);
        $display("dbg_id_inst   = 0x%08x", dbg_id_inst);
        $display("dbg_ex_inst   = 0x%08x", dbg_ex_inst);
        $display("dbg_mem_inst  = 0x%08x", dbg_mem_inst);
        $display("ctrl_hold     = %0d", ctrl_hold_flag);
        $display("fetch_hold    = %0b", dbg_fetch_hold);
        $display("fetch_resp_v  = %0b", dbg_fetch_resp_valid);
        $display("ifetch_pend   = %0b", dbg_ifetch_pending);
        $display("ifetch_resp_v = %0b", dbg_ifetch_resp_valid);
        $display("if_replay     = %0b", dbg_if_replay_hold);
        $display("if_slots      = %0d", dbg_if_slot_count);
        $display("fetch_addr    = 0x%08x", dbg_fetch_addr);
        $display("if_addr       = 0x%08x", dbg_if_addr);
        $display("ifetch_req    = 0x%08x", dbg_ifetch_req_addr);
        $display("fetch_baddr   = 0x%08x", dbg_fetch_backend_addr);
        $display("m1_ready      = %0b", fetch_bus_ready);
        $display("mem_busy      = %0b", dbg_mem_busy);
        $display("mem_resp_v    = %0b", dbg_mem_resp_valid);
        $display("mem_cooldown  = %0b", dbg_mem_cooldown);
        $display("axi master arvalid/ready = %b/%b", heterogeneous_soc_top_0.axi_arvalid, heterogeneous_soc_top_0.axi_arready);
        $display("axi slave  arvalid/ready = %b/%b", heterogeneous_soc_top_0.axi_slave_arvalid, heterogeneous_soc_top_0.axi_slave_arready);
        $display("axi slave  rvalid/ready/last = %b/%b/%b", heterogeneous_soc_top_0.axi_slave_rvalid, heterogeneous_soc_top_0.axi_slave_rready, heterogeneous_soc_top_0.axi_slave_rlast);
        $display("axi active master/slave/busy = %0d/%0d/%0b", heterogeneous_soc_top_0.axi_active_master, heterogeneous_soc_top_0.axi_active_slave, heterogeneous_soc_top_0.axi_busy);
        $display("cpu if native req/addr/adapter_state = %0b/%08x/%0d", heterogeneous_soc_top_0.m1_req_i, heterogeneous_soc_top_0.m1_addr_i, heterogeneous_soc_top_0.u_cpu_instruction_axi_master.state_r);
        $display("cpu data native req/we/addr/adapter_state = %0b/%0b/%08x/%0d",
            heterogeneous_soc_top_0.m0_req_i, heterogeneous_soc_top_0.m0_we_i,
            heterogeneous_soc_top_0.m0_addr_i, heterogeneous_soc_top_0.u_cpu_data_axi_master.state_r);
        $display("axi master awvalid/ready wvalid/ready bvalid/ready = %b/%b %b/%b %b/%b",
            heterogeneous_soc_top_0.axi_awvalid, heterogeneous_soc_top_0.axi_awready,
            heterogeneous_soc_top_0.axi_wvalid, heterogeneous_soc_top_0.axi_wready,
            heterogeneous_soc_top_0.axi_bvalid, heterogeneous_soc_top_0.axi_bready);
        $display("xbar state/owner/target aw_done/w_done/bvalid = %0d/%0d/%0d %0b/%0b/%0b",
            heterogeneous_soc_top_0.u_axi4_crossbar.state_r,
            heterogeneous_soc_top_0.u_axi4_crossbar.owner_r,
            heterogeneous_soc_top_0.u_axi4_crossbar.target_r,
            heterogeneous_soc_top_0.u_axi4_crossbar.aw_done_r,
            heterogeneous_soc_top_0.u_axi4_crossbar.w_done_r,
            heterogeneous_soc_top_0.u_axi4_crossbar.bvalid_r);
        $display("x3/gp         = 0x%08x", x3);
        $display("x5/t0         = 0x%08x", heterogeneous_soc_top_0.u_riscv_cpu.u_regs.regs[5]);
        $display("x6/t1         = 0x%08x", heterogeneous_soc_top_0.u_riscv_cpu.u_regs.regs[6]);
        $display("x1/ra         = 0x%08x", x1);
        $display("x26           = 0x%08x", x26);
        $display("x27           = 0x%08x", x27);
        $display("x28           = 0x%08x", x28);
        $display("x29           = 0x%08x", x29);
        $display("x10/a0        = 0x%08x", x10);
        $display("x11/a1        = 0x%08x", x11);
        $display("x12/a2        = 0x%08x", x12);
        $display("pmu_sim_done  = 0x%08x", pmu_sim_done);
        $display("PMU cycle     = %0d", perf_cycle);
        $display("PMU inst      = %0d", perf_inst);
        $display("PMU jump      = %0d", perf_jump);
        $display("PMU load      = %0d", perf_load);
        $display("PMU store     = %0d", perf_store);
        $display("PMU hold      = %0d", perf_hold);
        $display("PMU interrupt = %0d", perf_int);
        $display("PMU div_wait  = %0d", perf_div_wait);
        $display("PMU ic_hit    = %0d", perf_icache_hit);
        $display("PMU ic_miss   = %0d", perf_icache_miss);
        $display("PMU dc_ld_hit = %0d", perf_dcache_load_hit);
        $display("PMU dc_ld_miss= %0d", perf_dcache_load_miss);
        $display("PMU dc_st_hit = %0d", perf_dcache_store_hit);
        $display("PMU dc_st_miss= %0d", perf_dcache_store_miss);
        $display("PMU br_redir  = %0d", perf_branch_redirect);
        $display("PMU br_flush  = %0d", perf_branch_flush);
        $display("PMU pfq_occ_sum = %0d", perf_prefetch_occupancy_sum);
        $display("PMU pfq_full    = %0d", perf_prefetch_full);
        $display("PMU pfq_stall   = %0d", perf_prefetch_stall);
        $display("PMU bp_hit/miss = %0d/%0d", perf_branch_predict_hit, perf_branch_predict_miss);
        $display("PMU dc_ld_stall = %0d", perf_dcache_load_miss_stall);
        $display("PMU dc_st_wait  = %0d", perf_dcache_store_wait);
        $display("PMU fetch_wait  = %0d", perf_fetch_bus_wait);
        $display("PMU data_wait   = %0d", perf_data_bus_wait);
        $display("PMU id_contend  = %0d", perf_id_contention);
        $display("PMU sb_enq       = %0d", perf_store_buffer_enqueue);
        $display("PMU sb_full      = %0d", perf_store_buffer_full_stall);
        $display("PMU sb_drain     = %0d", perf_store_buffer_drain);
        $display("Fetch bus req = %0d", fetch_bus_req_count);
        $display("Fetch bus wait = %0d", fetch_bus_wait_count);
        $display("Data bus req  = %0d", data_bus_req_count);
        $display("Data bus wait = %0d", data_bus_wait_count);
        $display("CoreMark ticks = %0d", coremark_ticks);
        $display("extmem_dbg[7fd] = 0x%08x", heterogeneous_soc_top_0.u_axi4_mem_model.mem['h7fd]);
        $display("extmem_dbg[7fe] = 0x%08x", heterogeneous_soc_top_0.u_axi4_mem_model.mem['h7fe]);
        $display("extmem_dbg[7ff] = 0x%08x", heterogeneous_soc_top_0.u_axi4_mem_model.mem['h7ff]);
        $finish;
    end

    // read mem data
    initial begin
        $readmemh ("inst.data", heterogeneous_soc_top_0.u_rom._rom);
    end

    // generate wave file, used by gtkwave
    initial begin
`ifndef DISABLE_WAVE_DUMP
        $dumpfile("tinyriscv_soc_tb.vcd");
        $dumpvars(0, tinyriscv_soc_tb);
`endif
    end

    heterogeneous_soc_top heterogeneous_soc_top_0(
        .clk(clk),
        .rst(rst),
        .uart_debug_pin(1'b0),
        .spi_miso(tb_spi_miso),
        .spi_mosi(tb_spi_mosi),
        .spi_ss(tb_spi_ss),
        .spi_clk(tb_spi_clk),
        .qspi_io(tb_qspi_io),
        .qspi_cs_n(tb_qspi_cs_n),
        .qspi_clk(tb_qspi_clk)
`ifdef TEST_JTAG
        ,
        .jtag_TCK(TCK),
        .jtag_TMS(TMS),
        .jtag_TDI(TDI),
        .jtag_TDO(TDO)
`endif
    );

endmodule
