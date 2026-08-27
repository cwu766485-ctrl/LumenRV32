`uvm_analysis_imp_decl(_cpu_event)

class cpu_scoreboard extends uvm_component;
    `uvm_component_utils(cpu_scoreboard)
    virtual cpu_core_if vif;
    uvm_analysis_imp_cpu_event #(cpu_event, cpu_scoreboard) event_imp;
    int unsigned fetch_requests, data_requests, branch_redirects, load_hazard_holds, icache_misses, dcache_load_misses, dcache_store_misses;
    int unsigned check_errors;
    bit passed;
    function new(string name, uvm_component parent); super.new(name, parent); event_imp = new("event_imp", this); endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual cpu_core_if)::get(this, "", "vif", vif)) `uvm_fatal(get_type_name(), "cpu_core_if was not configured")
    endfunction
    function void write_cpu_event(cpu_event tr);
        fetch_requests += tr.fetch_req; data_requests += tr.data_req; branch_redirects += tr.branch_redirect; load_hazard_holds += tr.load_hazard_hold;
        icache_misses += tr.icache_miss; dcache_load_misses += tr.dcache_load_miss; dcache_store_misses += tr.dcache_store_miss;
    endfunction
    task automatic expect_gpr(input logic [4:0] addr, input logic [31:0] expected, input string label);
        logic [31:0] actual;
        vif.read_gpr(addr, actual);
        if (actual !== expected) begin
            check_errors++;
            `uvm_error(get_type_name(), $sformatf("%s: x%0d actual=%08h expected=%08h", label, addr, actual, expected))
        end
    endtask
    task check_smoke_result();
        check_errors = 0;
        passed = 1'b0;
        expect_gpr(5'd3, 32'd17, "forwarded add result");
        expect_gpr(5'd4, 32'd17, "load result");
        expect_gpr(5'd5, 32'd2, "branch flush result");
        if (vif.read_dmem(0) !== 32'd17) begin
            check_errors++;
            `uvm_error(get_type_name(), $sformatf("store actual=%08h expected=00000011", vif.read_dmem(0)))
        end
        if (fetch_requests == 0 || data_requests == 0 || branch_redirects == 0 || dcache_load_misses == 0) check_errors++;
        if (check_errors == 0) begin
            passed = 1'b1;
            `uvm_info(get_type_name(), $sformatf("CPU_UVM_SCOREBOARD_PASS fetch=%0d data=%0d redirect=%0d ic_miss=%0d dc_load_miss=%0d dc_store_miss=%0d", fetch_requests, data_requests, branch_redirects, icache_misses, dcache_load_misses, dcache_store_misses), UVM_NONE)
        end else begin
            `uvm_error(get_type_name(), $sformatf("scoreboard failures=%0d fetch=%0d data=%0d redirect=%0d dc_load_miss=%0d", check_errors, fetch_requests, data_requests, branch_redirects, dcache_load_misses))
        end
    endtask
    task check_pipeline_hazard_result();
        check_errors = 0;
        passed = 1'b0;
        expect_gpr(5'd1, 32'd5, "EX forwarding producer");
        expect_gpr(5'd2, 32'd12, "EX forwarding consumer");
        expect_gpr(5'd3, 32'd17, "dependent add result");
        expect_gpr(5'd5, 32'd37, "MEM/WB forwarding result");
        expect_gpr(5'd7, 32'd37, "load result");
        expect_gpr(5'd8, 32'd38, "load-use interlock result");
        expect_gpr(5'd9, 32'd2, "JAL flush result");
        expect_gpr(5'd11, 32'd4, "JALR flush result");
        if (vif.read_dmem(0) !== 32'd37) begin
            check_errors++;
            `uvm_error(get_type_name(), $sformatf("hazard store actual=%08h expected=00000025", vif.read_dmem(0)))
        end
        if (load_hazard_holds == 0 || branch_redirects < 2 || data_requests == 0) check_errors++;
        if (check_errors == 0) begin
            passed = 1'b1;
            `uvm_info(get_type_name(), $sformatf("CPU_UVM_PIPELINE_HAZARD_SCOREBOARD_PASS hold_load=%0d redirect=%0d data=%0d", load_hazard_holds, branch_redirects, data_requests), UVM_NONE)
        end else begin
            `uvm_error(get_type_name(), $sformatf("pipeline hazard failures=%0d hold_load=%0d redirect=%0d data=%0d", check_errors, load_hazard_holds, branch_redirects, data_requests))
        end
    endtask
endclass
