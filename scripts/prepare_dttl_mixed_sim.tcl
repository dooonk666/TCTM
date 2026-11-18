# Run in the currently open Vivado project; simulation setup only.
set dm_root [file normalize [file join [file dirname [info script]] ..]]
if {[llength [get_projects -quiet]] == 0} {error "Open k7_clean.xpr first"}
foreach dm_name {DTTL_Top DTTL_NCO DTTL_Integrator DTTL_PD DTTL_Loop_Filter DTTL_Supervisor} {
    set dm_file [file join $dm_root rtl rx dttl ${dm_name}.v]
    if {[llength [get_files -quiet $dm_file]] == 0} {add_files -norecurse -fileset sources_1 $dm_file}
    set_property library xil_defaultlib [get_files $dm_file]
    set_property used_in {synthesis implementation simulation} [get_files $dm_file]
}
set dm_tb [file join $dm_root sim tb_DTTL_MixedStream.v]
if {[llength [get_files -quiet $dm_tb]] == 0} {add_files -norecurse -fileset sim_1 $dm_tb}
set_property file_type SystemVerilog [get_files $dm_tb]
set_property library xil_defaultlib [get_files $dm_tb]
set_property used_in {simulation} [get_files $dm_tb]
if {[llength [get_ips -quiet div_gen_0]] == 0} {error "Current project must contain the div_gen_0 IP"}
generate_target simulation [get_ips div_gen_0]
set_property top tb_DTTL_MixedStream [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
puts "DTTL_MIXED_SIM_READY: run Behavioral Simulation, source scripts/dttl_mixed_stream_fields.tcl, then run all."
