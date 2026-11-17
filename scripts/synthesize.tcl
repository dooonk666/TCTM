set root [file normalize [file join [file dirname [info script]] ..]]
cd [file join $root build]
open_project [file join $root build k7_clean.xpr]
generate_target all [get_ips]
foreach ipfile [get_files -all -filter {FILE_TYPE == IP}] {
    if {[get_property GENERATE_SYNTH_CHECKPOINT $ipfile]} {
        set run_name "[file rootname [file tail $ipfile]]_synth_1"
        if {[llength [get_runs -quiet $run_name]] == 0} {create_ip_run $ipfile}
    }
}
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "Synthesis failed"}
open_run synth_1
report_timing_summary -file [file join $root reports timing_summary_synth.rpt]
report_utilization -file [file join $root reports utilization_synth.rpt]
report_drc -file [file join $root reports synthesis_drc.rpt]
close_project
puts K7_CLEAN_SYNTHESIS_PASSED
