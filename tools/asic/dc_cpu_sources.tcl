# RV32IM CPU-only synthesis source list.
#
# This deliberately excludes SoC, AXI fabric, peripherals and external accelerators.  The
# first 28 nm baseline must answer a narrow question: what are the PPA and
# critical paths of riscv_cpu_core under one reproducible constraint set?

if {![info exists REPO_ROOT]} {
    error "REPO_ROOT must be set before sourcing dc_cpu_sources.tcl"
}

set core_dir [file normalize [file join $REPO_ROOT rtl core]]
if {![info exists CACHE_RAM_IMPL]} {
    set CACHE_RAM_IMPL [file join $core_dir cache_ram_1r1w.v]
}
set CORE_RTL_FILES [list \
    [file join $core_dir defines.v] \
    $CACHE_RAM_IMPL \
    [file join $core_dir branch_predictor.v] \
    [file join $core_dir clint.v] \
    [file join $core_dir csr_reg.v] \
    [file join $core_dir ctrl.v] \
    [file join $core_dir div.v] \
    [file join $core_dir ex.v] \
    [file join $core_dir ex_mem.v] \
    [file join $core_dir dcache.v] \
    [file join $core_dir icache.v] \
    [file join $core_dir id.v] \
    [file join $core_dir id_ex.v] \
    [file join $core_dir ifetch.v] \
    [file join $core_dir if_id.v] \
    [file join $core_dir mem.v] \
    [file join $core_dir mem_wb.v] \
    [file join $core_dir pc_reg.v] \
    [file join $core_dir regs.v] \
    [file join $core_dir riscv_cpu_core.v] \
]

if {[info exists ::env(ASIC28_TOP)] && $::env(ASIC28_TOP) eq "jalr_timing_cone_top"} {
    set CORE_RTL_FILES [list \
        [file join $core_dir defines.v] \
        [file join $core_dir ex.v] \
        [file join $core_dir id.v] \
        [file join $core_dir id_ex.v] \
        [file join $REPO_ROOT rtl soc jalr_timing_cone_top.v] \
    ]
}

if {[info exists CPU_AXI_DEBUG_PROFILE] && $CPU_AXI_DEBUG_PROFILE} {
    set profile_dirs [list \
        [file join $REPO_ROOT rtl interconnect] \
        [file join $REPO_ROOT rtl perips] \
        [file join $REPO_ROOT rtl debug] \
        [file join $REPO_ROOT rtl utils] \
    ]
    foreach dir $profile_dirs {
        foreach file [lsort [glob -nocomplain -directory $dir *.v]] {
            lappend CORE_RTL_FILES $file
        }
    }
    lappend CORE_RTL_FILES \
        [file join $REPO_ROOT rtl soc heterogeneous_soc_top.v] \
        [file join $REPO_ROOT rtl soc cpu_axi_debug_profile_top.v]
}
