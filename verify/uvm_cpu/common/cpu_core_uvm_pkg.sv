package cpu_core_uvm_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    `include "cpu_event.svh"
    `include "../agent/cpu_native_agent.svh"
    `include "../env/cpu_scoreboard.svh"
    `include "../env/cpu_coverage.svh"
    `include "../env/cpu_env.svh"
    `include "../tests/cpu_smoke_test.svh"
    `include "../tests/pipeline_hazard_test.svh"
endpackage
