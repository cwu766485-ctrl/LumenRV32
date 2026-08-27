class cpu_event extends uvm_sequence_item;
    int unsigned cycle;
    bit fetch_req, data_req, branch_redirect, load_hazard_hold, icache_miss, dcache_load_miss, dcache_store_miss;
    `uvm_object_utils_begin(cpu_event)
        `uvm_field_int(cycle, UVM_DEFAULT)
        `uvm_field_int(fetch_req, UVM_DEFAULT)
        `uvm_field_int(data_req, UVM_DEFAULT)
        `uvm_field_int(branch_redirect, UVM_DEFAULT)
        `uvm_field_int(load_hazard_hold, UVM_DEFAULT)
        `uvm_field_int(icache_miss, UVM_DEFAULT)
        `uvm_field_int(dcache_load_miss, UVM_DEFAULT)
        `uvm_field_int(dcache_store_miss, UVM_DEFAULT)
    `uvm_object_utils_end
    function new(string name = "cpu_event"); super.new(name); endfunction
endclass
