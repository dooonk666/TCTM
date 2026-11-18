# Source in the already open Vivado project. Prepares files; does not launch/run.
set dtc_root [file normalize [file join [file dirname [info script]] ..]]
if {[llength [get_projects -quiet]] == 0} {error "Open k7_clean.xpr first"}
# Regenerate BOTH quick and full streams from the current CSV; no simulation.
puts [exec powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File [file join $dtc_root scripts create_dttl_telecommand_stream.ps1]]
foreach dtc_name {DTTL_Top DTTL_NCO DTTL_Integrator DTTL_PD DTTL_Loop_Filter DTTL_Supervisor} {
    set dtc_file [file join $dtc_root rtl rx dttl ${dtc_name}.v]
    if {[llength [get_files -quiet $dtc_file]] == 0} {add_files -norecurse -fileset sources_1 $dtc_file}
    set_property library xil_defaultlib [get_files $dtc_file]
    set_property used_in {synthesis implementation simulation} [get_files $dtc_file]
}
set dtc_file [file join $dtc_root rtl rx telecommand_deframer.v]
if {[llength [get_files -quiet $dtc_file]] == 0} {add_files -norecurse -fileset sources_1 $dtc_file}
set_property library xil_defaultlib [get_files $dtc_file]
set_property used_in {synthesis implementation simulation} [get_files $dtc_file]
set dtc_tb [file join $dtc_root sim tb_DTTL_TelecommandStream.v]
if {[llength [get_files -quiet $dtc_tb]] == 0} {add_files -norecurse -fileset sim_1 $dtc_tb}
set_property file_type SystemVerilog [get_files $dtc_tb]
set_property library xil_defaultlib [get_files $dtc_tb]
set_property used_in {simulation} [get_files $dtc_tb]
foreach dtc_ip {div_gen_0 dttl_delay_bram} {
    if {[llength [get_ips -quiet $dtc_ip]] == 0} {error "Current project must contain IP $dtc_ip"}
    generate_target simulation [get_ips $dtc_ip]
}
set_property top tb_DTTL_TelecommandStream [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]
# Open at t=0 so the user can install the wave configuration before running.
set_property xsim.simulate.runtime 0ns [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
puts "DTTL_TC_READY: top=tb_DTTL_TelecommandStream. Launch Behavioral Simulation, source scripts/dttl_telecommand_fields.tcl, then run all. FULL_COVERAGE=0 selects 4168 bits; =1 selects 48616 bits."
