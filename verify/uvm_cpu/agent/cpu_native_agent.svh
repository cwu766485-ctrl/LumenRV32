// Transaction, sequencer, driver and monitor for the CPU native memory boundary.
typedef enum int {CPU_PROGRAM_SMOKE, CPU_PROGRAM_PIPELINE_HAZARD} cpu_program_kind_e;

class cpu_program_item extends uvm_sequence_item;
    rand int unsigned backpressure_period;
    cpu_program_kind_e program_kind;
    constraint legal_backpressure { backpressure_period inside {0, 3, 5}; }
    `uvm_object_utils_begin(cpu_program_item)
        `uvm_field_int(backpressure_period, UVM_DEFAULT)
        `uvm_field_enum(cpu_program_kind_e, program_kind, UVM_DEFAULT)
    `uvm_object_utils_end
    function new(string name = "cpu_program_item"); super.new(name); endfunction
endclass

class cpu_program_sequence extends uvm_sequence #(cpu_program_item);
    `uvm_object_utils(cpu_program_sequence)
    function new(string name = "cpu_program_sequence"); super.new(name); endfunction
    task body();
        cpu_program_item req = cpu_program_item::type_id::create("req");
        start_item(req);
        if (!req.randomize() with { backpressure_period == 3; })
            `uvm_fatal(get_type_name(), "item randomization failed")
        finish_item(req);
    endtask
endclass

class cpu_pipeline_hazard_sequence extends uvm_sequence #(cpu_program_item);
    `uvm_object_utils(cpu_pipeline_hazard_sequence)
    function new(string name = "cpu_pipeline_hazard_sequence"); super.new(name); endfunction
    task body();
        cpu_program_item req = cpu_program_item::type_id::create("req");
        start_item(req);
        if (!req.randomize() with { backpressure_period == 3; })
            `uvm_fatal(get_type_name(), "item randomization failed")
        req.program_kind = CPU_PROGRAM_PIPELINE_HAZARD;
        finish_item(req);
    endtask
endclass

class cpu_sequencer extends uvm_sequencer #(cpu_program_item);
    `uvm_component_utils(cpu_sequencer)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
endclass

class cpu_driver extends uvm_driver #(cpu_program_item);
    `uvm_component_utils(cpu_driver)
    virtual cpu_core_if vif;
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual cpu_core_if)::get(this, "", "vif", vif))
            `uvm_fatal(get_type_name(), "cpu_core_if was not configured")
    endfunction
    task run_phase(uvm_phase phase);
        cpu_program_item req;
        forever begin
            seq_item_port.get_next_item(req);
            case (req.program_kind)
                CPU_PROGRAM_PIPELINE_HAZARD: vif.load_pipeline_hazard_program();
                default:                     vif.load_smoke_program();
            endcase
            vif.backpressure_period = req.backpressure_period;
            vif.apply_reset();
            `uvm_info(get_type_name(), $sformatf("program=%s backpressure period=%0d", req.program_kind.name(), req.backpressure_period), UVM_LOW)
            seq_item_port.item_done();
        end
    endtask
endclass

class cpu_monitor extends uvm_component;
    `uvm_component_utils(cpu_monitor)
    virtual cpu_core_if vif;
    uvm_analysis_port #(cpu_event) ap;
    int unsigned cycle;
    function new(string name, uvm_component parent); super.new(name, parent); ap = new("ap", this); endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual cpu_core_if)::get(this, "", "vif", vif))
            `uvm_fatal(get_type_name(), "cpu_core_if was not configured")
    endfunction
    task run_phase(uvm_phase phase);
        cpu_event tr;
        forever begin
            @(posedge vif.clk);
            cycle++;
            if (vif.rst && (vif.mem_pc_req_o || vif.mem_ex_req_o || vif.perf_branch_redirect_o || vif.perf_hold_flag_o == 3'b100 || vif.perf_icache_miss_o || vif.perf_dcache_load_miss_o || vif.perf_dcache_store_miss_o)) begin
                tr = cpu_event::type_id::create("tr");
                tr.cycle = cycle; tr.fetch_req = vif.mem_pc_req_o; tr.data_req = vif.mem_ex_req_o;
                tr.branch_redirect = vif.perf_branch_redirect_o; tr.icache_miss = vif.perf_icache_miss_o;
                tr.load_hazard_hold = (vif.perf_hold_flag_o == 3'b100);
                tr.dcache_load_miss = vif.perf_dcache_load_miss_o; tr.dcache_store_miss = vif.perf_dcache_store_miss_o;
                ap.write(tr);
            end
        end
    endtask
endclass

class cpu_agent extends uvm_agent;
    `uvm_component_utils(cpu_agent)
    cpu_sequencer sequencer;
    cpu_driver driver;
    cpu_monitor monitor;
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sequencer = cpu_sequencer::type_id::create("sequencer", this);
        driver = cpu_driver::type_id::create("driver", this);
        monitor = cpu_monitor::type_id::create("monitor", this);
    endfunction
    function void connect_phase(uvm_phase phase); driver.seq_item_port.connect(sequencer.seq_item_export); endfunction
endclass
