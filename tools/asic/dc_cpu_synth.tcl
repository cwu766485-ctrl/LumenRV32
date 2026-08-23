# 28 nm Design Compiler CPU-only baseline.
#
# Required local environment (never commit actual values):
#   ASIC28_MAX_LIB : worst setup-corner standard-cell .db
# Optional:
#   ASIC28_MIN_LIB : matching fast hold-corner .db
#   ASIC28_CLK_NS  : core clock period in ns, default 5.000
#   ASIC28_IO_DELAY_NS / ASIC28_CLK_SETUP_UNCERTAINTY_NS
#   ASIC28_CLK_HOLD_UNCERTAINTY_NS / ASIC28_CLK_TRANSITION_NS
#   ASIC28_OUT_DIR : ignored output directory; default build/asic28_cpu
#   ASIC28_MAX_CORES : DC host cores, default 4
# SRAM-aware optional local profile:
#   ASIC28_SRAM_MAX_LIB / ASIC28_SRAM_MIN_LIB : matching SRAM macro .db files
#   ASIC28_CACHE_RAM_IMPL : local, ignored cache RAM macro wrapper Verilog
#   ASIC28_SRAM_REF_NAME : local macro reference name used only for binding check
# Optional focused integration profile:
#   ASIC28_TOP=cpu_axi_debug_profile_top and ASIC28_CPU_AXI_DEBUG_PROFILE=1
#
# This is a constraint-controlled synthesis baseline, not physical signoff.
# Cache arrays are still behavioral RTL.  Do not compare their mapped cell area
# with an SRAM-macro implementation without clearly labelling that difference.

proc require_env {name} {
    if {![info exists ::env($name)] || $::env($name) eq ""} {
        error "Required local environment variable $name is not set"
    }
    return $::env($name)
}

proc optional_env {name default_value} {
    if {[info exists ::env($name)] && $::env($name) ne ""} {
        return $::env($name)
    }
    return $default_value
}

set REPO_ROOT [require_env REPO_ROOT]
set max_lib   [require_env ASIC28_MAX_LIB]
set min_lib   [optional_env ASIC28_MIN_LIB ""]
set out_dir   [optional_env ASIC28_OUT_DIR [file join $REPO_ROOT build asic28_cpu]]
set clk_ns    [optional_env ASIC28_CLK_NS 5.000]
set io_ns     [optional_env ASIC28_IO_DELAY_NS 0.200]
set setup_unc_ns [optional_env ASIC28_CLK_SETUP_UNCERTAINTY_NS [optional_env ASIC28_CLK_UNCERTAINTY_NS 0.100]]
set hold_unc_ns  [optional_env ASIC28_CLK_HOLD_UNCERTAINTY_NS 0.020]
set tran_ns   [optional_env ASIC28_CLK_TRANSITION_NS 0.050]
set max_cores [optional_env ASIC28_MAX_CORES 4]
set sram_max_lib [optional_env ASIC28_SRAM_MAX_LIB ""]
set sram_min_lib [optional_env ASIC28_SRAM_MIN_LIB ""]
set cache_ram_impl [optional_env ASIC28_CACHE_RAM_IMPL ""]
set sram_ref_name [optional_env ASIC28_SRAM_REF_NAME ""]
set top       [optional_env ASIC28_TOP riscv_cpu_core]
set cpu_axi_debug_profile [optional_env ASIC28_CPU_AXI_DEBUG_PROFILE 0]
if {$top eq "cpu_axi_debug_profile_top" && !$cpu_axi_debug_profile} {
    error "cpu_axi_debug_profile_top requires ASIC28_CPU_AXI_DEBUG_PROFILE=1"
}
if {$cpu_axi_debug_profile && $top ne "cpu_axi_debug_profile_top"} {
    error "ASIC28_CPU_AXI_DEBUG_PROFILE=1 requires ASIC28_TOP=cpu_axi_debug_profile_top"
}

# The site-wide Synopsys template may continue after an error.  A CPU PPA
# baseline must fail closed: an unreadable library or an unmapped design is
# never a valid result.
set_app_var sh_continue_on_error false

if {![file exists $max_lib]} {
    error "ASIC28_MAX_LIB does not name a readable .db file"
}
if {$min_lib ne "" && ![file exists $min_lib]} {
    error "ASIC28_MIN_LIB does not name a readable .db file"
}
set use_sram_macro [expr {$sram_max_lib ne "" || $sram_min_lib ne "" || $cache_ram_impl ne "" || $sram_ref_name ne ""}]
if {$use_sram_macro} {
    if {$sram_max_lib eq "" || $cache_ram_impl eq "" || $sram_ref_name eq ""} {
        error "SRAM-aware flow requires ASIC28_SRAM_MAX_LIB, ASIC28_CACHE_RAM_IMPL and ASIC28_SRAM_REF_NAME together"
    }
    if {![file exists $sram_max_lib]} {
        error "ASIC28 SRAM max-corner library does not name a readable .db file"
    }
    if {$sram_min_lib ne "" && ![file exists $sram_min_lib]} {
        error "ASIC28 SRAM min-corner library does not name a readable .db file"
    }
    if {![file exists $cache_ram_impl]} {
        error "ASIC28_CACHE_RAM_IMPL does not name a readable local wrapper Verilog file"
    }
}

file mkdir $out_dir
define_design_lib WORK -path [file join $out_dir WORK]
set_host_options -max_cores $max_cores

set core_dir [file join $REPO_ROOT rtl core]
set existing_search_path [get_app_var search_path]
set_app_var search_path [concat [list $core_dir] $existing_search_path]
set_app_var target_library [list $max_lib]
set link_libs [list "*" $max_lib]
if {$use_sram_macro} {
    lappend link_libs $sram_max_lib
}
set_app_var link_library $link_libs
if {$min_lib ne ""} {
    set_min_library $max_lib -min_version $min_lib
}
if {$use_sram_macro} {
    if {$sram_min_lib ne ""} {
        set_min_library $sram_max_lib -min_version $sram_min_lib
    }
    # The technology-specific macro module and pin mapping are intentionally
    # kept in ASIC28_CACHE_RAM_IMPL, a local ignored file.  Tracked RTL and
    # flow scripts remain PDK-neutral.
    set CACHE_RAM_IMPL $cache_ram_impl
}

set CPU_AXI_DEBUG_PROFILE $cpu_axi_debug_profile

source [file join $REPO_ROOT tools asic dc_cpu_sources.tcl]
if {$use_sram_macro && $cpu_axi_debug_profile} {
    analyze -format verilog -define {CacheUseBlockRam SOC_CPU_AXI_DEBUG_PROFILE SOC_DDR_BOARD_MINIMAL ASIC_DC} $CORE_RTL_FILES
} elseif {$use_sram_macro} {
    analyze -format verilog -define CacheUseBlockRam $CORE_RTL_FILES
} elseif {$cpu_axi_debug_profile} {
    analyze -format verilog -define {SOC_CPU_AXI_DEBUG_PROFILE SOC_DDR_BOARD_MINIMAL ASIC_DC} $CORE_RTL_FILES
} else {
    analyze -format verilog $CORE_RTL_FILES
}
elaborate $top
current_design $top
link
uniquify

if {$use_sram_macro} {
    # The SRAM profile must contain exactly the I-cache and D-cache instances.
    # If a local wrapper or its library binding is wrong, stop before compile.
    set sram_instances [get_cells -hierarchical -filter "ref_name == $sram_ref_name"]
    if {[sizeof_collection $sram_instances] != 2} {
        error "SRAM-aware flow expected two macro instances after link; check the local wrapper and SRAM library binding"
    }
    set_dont_touch $sram_instances
}

redirect -file [file join $out_dir check_design.rpt] { check_design }

# The CPU core boundary is a synchronous integration boundary for this first
# comparison.  These I/O assumptions are deliberately explicit and must remain
# unchanged across PPA A/B experiments.  They are not a package/board signoff.
create_clock -name core_clk -period $clk_ns [get_ports clk]
# Setup jitter and hold margin are distinct quantities.  Applying a setup
# uncertainty blindly to hold over-constrains a pre-CTS CPU-only model.  The
# hold value remains explicit and conservative until CTS/physical parasitics
# are available.
set_clock_uncertainty -setup $setup_unc_ns [get_clocks core_clk]
set_clock_uncertainty -hold  $hold_unc_ns  [get_clocks core_clk]
set_clock_transition $tran_ns [get_clocks core_clk]
set_false_path -from [get_ports rst]

set timing_inputs [remove_from_collection [all_inputs] [get_ports {clk rst}]]
if {[sizeof_collection $timing_inputs] > 0} {
    set_input_delay $io_ns -clock core_clk $timing_inputs
}
set timing_outputs [all_outputs]
if {[sizeof_collection $timing_outputs] > 0} {
    set_output_delay $io_ns -clock core_clk $timing_outputs
}

# The JALR timing harness exposes the ID/EX result only to keep the cone from
# being optimized away.  Its top-level output is not an I/O timing endpoint;
# compare the registered producer-to-ID/EX paths instead of a register-to-pad
# path with an arbitrary output delay.
if {$top eq "jalr_timing_cone_top"} {
    set_false_path -to $timing_outputs
}

# Do not enable retiming or clock-gating inference in the baseline.  Both are
# valid later experiments, but would obscure architectural comparison and need
# separate functional/DFT/power validation.
# Let DC insert ordinary delay cells for reg-to-SRAM min paths.  This is a
# pre-CTS repair only; final hold closure requires propagated clocks, physical
# parasitics and CTS in implementation.
set_fix_hold [get_clocks core_clk]
compile_ultra

redirect -file [file join $out_dir qor.rpt]              { report_qor }
redirect -file [file join $out_dir area.rpt]             { report_area -hierarchy }
redirect -file [file join $out_dir timing_setup.rpt]     { report_timing -delay max -max_paths 20 -transition_time -nets -attributes }
redirect -file [file join $out_dir timing_hold.rpt]      { report_timing -delay min -max_paths 20 -transition_time -nets -attributes }
redirect -file [file join $out_dir constraints.rpt]      { report_constraint -all_violators }
redirect -file [file join $out_dir power_vectorless.rpt] { report_power }
if {$top eq "jalr_timing_cone_top"} {
    # Explicit A/B evidence for the architectural change.  In the baseline
    # the first report contains the EX feedback cone; after the interlock it
    # must have no path.  The second report measures the replacement
    # registered MEM/WB-value to ID/EX capture path.
    set idex_to [get_pins -of_objects [get_cells -hierarchical *u_id_ex/op1_jump_reg*] -filter "direction == in"]
    set ex_from [get_pins -of_objects [get_cells -hierarchical *producer_op2_r_reg*] -filter "direction == out"]
    set late_from [get_pins -of_objects [get_cells -hierarchical *late_data_r_reg*] -filter "direction == out"]
    redirect -file [file join $out_dir jalr_ex_to_idex.rpt] {
        if {[sizeof_collection $ex_from] == 0 || [sizeof_collection $idex_to] == 0} {
            puts "NO_MATCHING_EX_TO_IDEX_REGISTERS"
        } else {
            report_timing -from $ex_from -to $idex_to -delay max -max_paths 20 -transition_time -nets -attributes
        }
    }
    redirect -file [file join $out_dir jalr_late_to_idex.rpt] {
        if {[sizeof_collection $late_from] == 0 || [sizeof_collection $idex_to] == 0} {
            puts "NO_MATCHING_LATE_TO_IDEX_REGISTERS"
        } else {
            report_timing -from $late_from -to $idex_to -delay max -max_paths 20 -transition_time -nets -attributes
        }
    }
}

write -format ddc     -hierarchy -output [file join $out_dir ${top}.ddc]
write -format verilog -hierarchy -output [file join $out_dir ${top}_mapped.v]
write_sdc [file join $out_dir ${top}.sdc]

set manifest [open [file join $out_dir run_manifest.txt] w]
puts $manifest "TOP=$top"
puts $manifest "CPU_AXI_DEBUG_PROFILE=$cpu_axi_debug_profile"
puts $manifest "CLOCK_NS=$clk_ns"
puts $manifest "IO_DELAY_NS=$io_ns"
puts $manifest "CLOCK_SETUP_UNCERTAINTY_NS=$setup_unc_ns"
puts $manifest "CLOCK_HOLD_UNCERTAINTY_NS=$hold_unc_ns"
puts $manifest "CLOCK_TRANSITION_NS=$tran_ns"
puts $manifest "MIN_LIBRARY_ENABLED=[expr {$min_lib ne ""}]"
puts $manifest "SRAM_MACRO_ENABLED=$use_sram_macro"
puts $manifest "SRAM_MIN_LIBRARY_ENABLED=[expr {$sram_min_lib ne ""}]"
puts $manifest "NOTE=PDK paths are intentionally omitted from this manifest."
close $manifest

exit
