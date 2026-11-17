# Vivado 2020.2; source this script to create the project from canonical sources.
set root [file normalize [file join [file dirname [info script]] ..]]
file mkdir [file join $root build]
file mkdir [file join $root reports]
cd [file join $root build]
create_project k7_clean [file join $root build] -part xc7k325tffg676-1
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
set_property default_lib xil_defaultlib [current_project]
set_property ip_output_repo [file join $root build ip_cache] [current_project]

set_property top TCTM_uplink_top [get_filesets sources_1]
source [file join $root scripts files.tcl]
set_property top TCTM_uplink_top [get_filesets sources_1]
set_property top_auto_set false [get_filesets sources_1]
set_property top tb_Data_Buffer_Xclk [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
report_ip_status -file [file join $root reports ip_status.rpt]
report_compile_order -used_in synthesis -file [file join $root reports compile_order.rpt]
close_project
puts K7_CLEAN_PROJECT_CREATED
