# Run with source from the Tcl Console of the CURRENTLY OPEN Vivado project.
# Do not edit the on-disk XPR behind an already open GUI session.
set tc_root [file normalize [file join [file dirname [info script]] ..]]
if {[llength [get_projects -quiet]] == 0} {
    error "Open k7_clean.xpr first, then source this script."
}
set tc_rtl [file join $tc_root rtl rx telecommand_deframer.v]
set tc_tb [file join $tc_root sim tb_telecommand_deframer_csv.v]
set tc_stimulus [file join $tc_root temp telecommand_csv_sim telecommand_stimulus.txt]
foreach tc_file [list $tc_rtl $tc_tb $tc_stimulus] {
    if {![file exists $tc_file]} {error "Missing file: $tc_file"}
}
if {[llength [get_files -quiet $tc_rtl]] == 0} {
    add_files -norecurse -fileset sources_1 $tc_rtl
}
if {[llength [get_files -quiet $tc_tb]] == 0} {
    add_files -norecurse -fileset sim_1 $tc_tb
}
set_property library xil_defaultlib [get_files $tc_rtl]
set_property used_in {synthesis implementation simulation} [get_files $tc_rtl]
set_property library xil_defaultlib [get_files $tc_tb]
set_property file_type SystemVerilog [get_files $tc_tb]
set_property used_in {simulation} [get_files $tc_tb]
set_property top tb_telecommand_deframer_csv [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# The TB reads a relative filename. Place the current CSV-derived stimulus in
# Vivado's default behavioral XSim working directory before launching simulation.
set tc_project_dir [get_property DIRECTORY [current_project]]
set tc_project_name [get_property NAME [current_project]]
set tc_sim_dir [file normalize [file join $tc_project_dir ${tc_project_name}.sim sim_1 behav xsim]]
file mkdir $tc_sim_dir
file copy -force $tc_stimulus [file join $tc_sim_dir telecommand_stimulus.txt]
puts "TELECOMMAND_SIM_READY: top=tb_telecommand_deframer_csv"
puts "DUT=$tc_rtl"
puts "STIMULUS=[file join $tc_sim_dir telecommand_stimulus.txt]"
puts "Run Behavioral Simulation, then enter: run all"
