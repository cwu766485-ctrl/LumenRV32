`timescale 1ns/1ps

// Native instruction/data memory BFM for core-level UVM tests.
interface cpu_core_if(input logic clk);
    localparam int MEM_WORDS = 256;
    logic rst;
    logic [31:0] mem_ex_addr_o, mem_ex_data_i, mem_ex_data_o;
    logic [3:0] mem_ex_wmask_o;
    logic mem_ex_req_o, mem_ex_we_o;
    logic [7:0] mem_ex_burst_len_o;
    logic mem_ex_ready_i;
    logic [31:0] mem_pc_addr_o, mem_pc_data_i;
    logic mem_pc_req_o;
    logic [7:0] mem_pc_burst_len_o;
    logic mem_pc_ready_i;
    logic [4:0] jtag_reg_addr_i;
    logic [31:0] jtag_reg_data_i, jtag_reg_data_o;
    logic jtag_reg_we_i, jtag_halt_flag_i, jtag_reset_flag_i;
    logic [7:0] int_i;
    logic [31:0] perf_inst_o;
    logic [2:0] perf_hold_flag_o, perf_prefetch_occupancy_o;
    logic perf_int_assert_o, perf_div_busy_o, perf_icache_hit_o, perf_icache_miss_o;
    logic perf_dcache_load_hit_o, perf_dcache_load_miss_o, perf_dcache_store_hit_o, perf_dcache_store_miss_o;
    logic perf_branch_redirect_o, perf_branch_flush_o, perf_prefetch_full_o, perf_prefetch_stall_o;
    logic perf_branch_predict_hit_o, perf_branch_predict_miss_o, perf_dcache_load_miss_stall_o, perf_dcache_store_wait_o;
    logic perf_id_contention_o, perf_store_buffer_enqueue_o, perf_store_buffer_full_stall_o, perf_store_buffer_drain_o;
    logic [31:0] imem [0:MEM_WORDS-1];
    logic [31:0] dmem [0:MEM_WORDS-1];
    int unsigned cycle_count, backpressure_period;

    function automatic logic allow_response();
        if (backpressure_period == 0) allow_response = 1'b1;
        else allow_response = ((cycle_count % backpressure_period) != 0);
    endfunction
    always_comb begin
        mem_pc_data_i = imem[mem_pc_addr_o[9:2]];
        mem_ex_data_i = dmem[mem_ex_addr_o[9:2]];
        mem_pc_ready_i = mem_pc_req_o && allow_response();
        mem_ex_ready_i = mem_ex_req_o && allow_response();
    end
    always_ff @(posedge clk) begin
        cycle_count <= cycle_count + 1;
        if (mem_ex_req_o && mem_ex_ready_i && mem_ex_we_o) begin
            if (mem_ex_wmask_o[0]) dmem[mem_ex_addr_o[9:2]][7:0] <= mem_ex_data_o[7:0];
            if (mem_ex_wmask_o[1]) dmem[mem_ex_addr_o[9:2]][15:8] <= mem_ex_data_o[15:8];
            if (mem_ex_wmask_o[2]) dmem[mem_ex_addr_o[9:2]][23:16] <= mem_ex_data_o[23:16];
            if (mem_ex_wmask_o[3]) dmem[mem_ex_addr_o[9:2]][31:24] <= mem_ex_data_o[31:24];
        end
    end
    task automatic clear_memories();
        for (int i = 0; i < MEM_WORDS; i++) begin imem[i] = 32'h00000013; dmem[i] = '0; end
        cycle_count = 0; backpressure_period = 0;
        jtag_reg_addr_i = '0; jtag_reg_data_i = '0; jtag_reg_we_i = 1'b0;
        jtag_halt_flag_i = 1'b0; jtag_reset_flag_i = 1'b0; int_i = '0;
    endtask
    task automatic load_smoke_program();
        clear_memories();
        imem[0] = 32'h00500093; // addi x1, x0, 5
        imem[1] = 32'h00708113; // addi x2, x1, 7
        imem[2] = 32'h002081b3; // add x3, x1, x2 = 17
        imem[3] = 32'h10000337; // lui x6, 0x10000: cacheable RAM window
        imem[4] = 32'h00332023; // sw x3, 0(x6)
        imem[5] = 32'h00032203; // lw x4, 0(x6)
        imem[6] = 32'h00320463; // beq x4, x3, +8
        imem[7] = 32'h00100293; // flushed wrong path
        imem[8] = 32'h00200293; // x5 = 2
        imem[9] = 32'h0000006f; // stable loop
    endtask
    task automatic load_pipeline_hazard_program();
        clear_memories();
        imem[0]  = 32'h00500093; // addi x1, x0, 5
        imem[1]  = 32'h00708113; // addi x2, x1, 7: EX forwarding
        imem[2]  = 32'h001101b3; // add x3, x2, x1 = 17
        imem[3]  = 32'h01400213; // addi x4, x0, 20
        imem[4]  = 32'h00000013; // nop: make x4 a later forwarding source
        imem[5]  = 32'h003202b3; // add x5, x4, x3 = 37
        imem[6]  = 32'h10000337; // lui x6, 0x10000: cacheable RAM window
        imem[7]  = 32'h00532023; // sw x5, 0(x6)
        imem[8]  = 32'h00032383; // lw x7, 0(x6)
        imem[9]  = 32'h00138413; // addi x8, x7, 1: load-use interlock
        imem[10] = 32'h0080006f; // jal x0, +8
        imem[11] = 32'h00100493; // JAL wrong path: must flush
        imem[12] = 32'h00200493; // x9 = 2
        imem[13] = 32'h04400513; // addi x10, x0, 68 (word 17)
        imem[14] = 32'h00050067; // jalr x0, 0(x10)
        imem[15] = 32'h00100593; // JALR wrong path: must flush
        imem[16] = 32'h00200593; // JALR wrong path: must flush
        imem[17] = 32'h00400593; // x11 = 4
        imem[18] = 32'h0000006f; // stable loop
    endtask
    task automatic apply_reset(); rst = 1'b0; repeat (4) @(posedge clk); rst = 1'b1; endtask
    task automatic read_gpr(input logic [4:0] addr, output logic [31:0] value); jtag_reg_addr_i = addr; #1 value = jtag_reg_data_o; endtask
    function automatic logic [31:0] read_dmem(input int unsigned word_addr); read_dmem = dmem[word_addr]; endfunction
endinterface
