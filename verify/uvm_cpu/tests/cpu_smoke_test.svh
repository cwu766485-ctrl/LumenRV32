class cpu_smoke_test extends uvm_test;
    `uvm_component_utils(cpu_smoke_test)
    cpu_env env;
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = cpu_env::type_id::create("env", this);
    endfunction
    task run_phase(uvm_phase phase);
        cpu_program_sequence seq;
        phase.raise_objection(this);
        seq = cpu_program_sequence::type_id::create("seq");
        seq.start(env.agent.sequencer);
        repeat (280) @(posedge env.scoreboard.vif.clk);
        env.scoreboard.check_smoke_result();
        if (!env.scoreboard.passed) `uvm_fatal(get_type_name(), "CPU UVM scoreboard failed")
        `uvm_info(get_type_name(), "CPU_UVM_SMOKE_PASS", UVM_NONE)
        phase.drop_objection(this);
    endtask
endclass
