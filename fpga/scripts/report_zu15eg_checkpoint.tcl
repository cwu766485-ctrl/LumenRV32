set script_dir [file dirname [file normalize [info script]]]
set root_dir [file normalize [file join $script_dir .. ..]]
set report_dir [file join $root_dir build vivado_impl_zu15eg_current]

open_checkpoint [file join $report_dir post_route.dcp]

report_utilization -hierarchical -hierarchical_depth 3 \
    -file [file join $report_dir post_route_hierarchical_utilization.rpt]
report_timing -delay_type max -max_paths 20 -nworst 2 \
    -file [file join $report_dir post_route_critical_paths.rpt]
report_route_status -file [file join $report_dir post_route_route_status.rpt]
report_drc -file [file join $report_dir post_route_drc.rpt]
report_methodology -file [file join $report_dir post_route_methodology.rpt]

close_project
