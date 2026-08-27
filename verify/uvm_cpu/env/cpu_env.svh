class cpu_env extends uvm_env;
    `uvm_component_utils(cpu_env)
    cpu_agent agent;
    cpu_scoreboard scoreboard;
    cpu_coverage coverage;
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent = cpu_agent::type_id::create("agent", this);
        scoreboard = cpu_scoreboard::type_id::create("scoreboard", this);
        coverage = cpu_coverage::type_id::create("coverage", this);
    endfunction
    function void connect_phase(uvm_phase phase);
        agent.monitor.ap.connect(scoreboard.event_imp);
        agent.monitor.ap.connect(coverage.analysis_export);
    endfunction
endclass
