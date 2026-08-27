`timescale 1ns/1ps
module cpu_core_uvm_tb;
    import uvm_pkg::*;
    import cpu_core_uvm_pkg::*;
    logic clk = 1'b0;
    always #5 clk = ~clk;
    cpu_core_if cpu_if(clk);
    riscv_cpu_core dut (
        .clk(clk), .rst(cpu_if.rst), .mem_ex_addr_o(cpu_if.mem_ex_addr_o), .mem_ex_data_i(cpu_if.mem_ex_data_i), .mem_ex_data_o(cpu_if.mem_ex_data_o), .mem_ex_wmask_o(cpu_if.mem_ex_wmask_o), .mem_ex_req_o(cpu_if.mem_ex_req_o), .mem_ex_we_o(cpu_if.mem_ex_we_o), .mem_ex_burst_len_o(cpu_if.mem_ex_burst_len_o), .mem_ex_ready_i(cpu_if.mem_ex_ready_i),
        .mem_pc_addr_o(cpu_if.mem_pc_addr_o), .mem_pc_data_i(cpu_if.mem_pc_data_i), .mem_pc_req_o(cpu_if.mem_pc_req_o), .mem_pc_burst_len_o(cpu_if.mem_pc_burst_len_o), .mem_pc_ready_i(cpu_if.mem_pc_ready_i),
        .jtag_reg_addr_i(cpu_if.jtag_reg_addr_i), .jtag_reg_data_i(cpu_if.jtag_reg_data_i), .jtag_reg_we_i(cpu_if.jtag_reg_we_i), .jtag_reg_data_o(cpu_if.jtag_reg_data_o), .jtag_halt_flag_i(cpu_if.jtag_halt_flag_i), .jtag_reset_flag_i(cpu_if.jtag_reset_flag_i), .int_i(cpu_if.int_i),
        .perf_inst_o(cpu_if.perf_inst_o), .perf_hold_flag_o(cpu_if.perf_hold_flag_o), .perf_int_assert_o(cpu_if.perf_int_assert_o), .perf_div_busy_o(cpu_if.perf_div_busy_o), .perf_icache_hit_o(cpu_if.perf_icache_hit_o), .perf_icache_miss_o(cpu_if.perf_icache_miss_o), .perf_dcache_load_hit_o(cpu_if.perf_dcache_load_hit_o), .perf_dcache_load_miss_o(cpu_if.perf_dcache_load_miss_o), .perf_dcache_store_hit_o(cpu_if.perf_dcache_store_hit_o), .perf_dcache_store_miss_o(cpu_if.perf_dcache_store_miss_o), .perf_branch_redirect_o(cpu_if.perf_branch_redirect_o), .perf_branch_flush_o(cpu_if.perf_branch_flush_o), .perf_prefetch_occupancy_o(cpu_if.perf_prefetch_occupancy_o), .perf_prefetch_full_o(cpu_if.perf_prefetch_full_o), .perf_prefetch_stall_o(cpu_if.perf_prefetch_stall_o), .perf_branch_predict_hit_o(cpu_if.perf_branch_predict_hit_o), .perf_branch_predict_miss_o(cpu_if.perf_branch_predict_miss_o), .perf_dcache_load_miss_stall_o(cpu_if.perf_dcache_load_miss_stall_o), .perf_dcache_store_wait_o(cpu_if.perf_dcache_store_wait_o), .perf_id_contention_o(cpu_if.perf_id_contention_o), .perf_store_buffer_enqueue_o(cpu_if.perf_store_buffer_enqueue_o), .perf_store_buffer_full_stall_o(cpu_if.perf_store_buffer_full_stall_o), .perf_store_buffer_drain_o(cpu_if.perf_store_buffer_drain_o)
    );
    cpu_core_properties properties (
        .clk(clk), .rst(cpu_if.rst), .mem_pc_req_i(cpu_if.mem_pc_req_o), .mem_pc_ready_i(cpu_if.mem_pc_ready_i), .mem_pc_addr_i(cpu_if.mem_pc_addr_o),
        .mem_ex_req_i(cpu_if.mem_ex_req_o), .mem_ex_ready_i(cpu_if.mem_ex_ready_i), .mem_ex_addr_i(cpu_if.mem_ex_addr_o), .mem_ex_we_i(cpu_if.mem_ex_we_o), .mem_ex_wdata_i(cpu_if.mem_ex_data_o),
        .jtag_reg_addr_i(cpu_if.jtag_reg_addr_i), .jtag_reg_data_i(cpu_if.jtag_reg_data_o)
    );
    initial begin
        uvm_config_db#(virtual cpu_core_if)::set(null, "*", "vif", cpu_if);
        // XSim 2024.1 accepts boolean --testplusarg values but rejects the
        // '=' form required by the conventional +UVM_TESTNAME=<name> syntax.
        // Keep selection portable with an explicit boolean harness plusarg.
        if ($test$plusargs("PIPELINE_HAZARD"))
            run_test("pipeline_hazard_test");
        else
            run_test("cpu_smoke_test");
    end
endmodule
