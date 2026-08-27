class cpu_coverage extends uvm_subscriber #(cpu_event);
    `uvm_component_utils(cpu_coverage)
    cpu_event sample;
    covergroup cpu_cg;
        option.per_instance = 1;
        fetch_cp: coverpoint sample.fetch_req;
        data_cp: coverpoint sample.data_req;
        redirect_cp: coverpoint sample.branch_redirect;
        ic_miss_cp: coverpoint sample.icache_miss;
        dc_load_miss_cp: coverpoint sample.dcache_load_miss;
        fetch_data_redirect: cross fetch_cp, data_cp, redirect_cp;
    endgroup
    function new(string name, uvm_component parent); super.new(name, parent); cpu_cg = new(); endfunction
    function void write(cpu_event t); sample = t; cpu_cg.sample(); endfunction
endclass
