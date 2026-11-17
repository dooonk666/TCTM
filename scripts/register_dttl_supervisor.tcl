# Add the supervisor and its tests without changing the existing sim top.
set root [file normalize [file join [file dirname [info script]] ..]]
open_project [file join $root build k7_clean.xpr]
set original_sim_top [get_property top [get_filesets sim_1]]
foreach relative {rtl/rx/dttl/DTTL_Supervisor.v} {
    set source [file join $root $relative]
    if {[llength [get_files -quiet $source]] == 0} {
        add_files -norecurse -fileset sources_1 $source
    }
    set_property used_in {synthesis implementation simulation} [get_files $source]
}
foreach relative {sim/tb_DTTL_Supervisor.v sim/tb_DTTL_Restart.v sim/tb_DTTL_HalfCycle.v sim/tb_DTTL_MixedStream.v sim/tb_DTTL_PD_Saturation.v} {
    set source [file join $root $relative]
    if {[llength [get_files -quiet $source]] == 0} {
        add_files -norecurse -fileset sim_1 $source
    }
}
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
set_property top $original_sim_top [get_filesets sim_1]
# RTL elaboration checks the actual top-level connections and port names.
synth_design -rtl -name dttl_wiring_check -top TMTC_Track_Top -part xc7k325tffg676-1
puts "DTTL_SUPERVISOR_CELLS [get_cells -hier -filter {REF_NAME == DTTL_Supervisor}]"
proc pin_net {pin} {
    set nets [get_nets -quiet -of_objects [get_pins -quiet $pin]]
    if {[llength $nets] != 1} {error "Expected exactly one net on $pin, got $nets"}
    return [get_property NAME $nets]
}
set local_reset_net [pin_net u_DTTL_Supervisor/dttl_rst]
if {[pin_net DTTL/rst] ne $local_reset_net} {error "DTTL does not receive local reset"}
foreach pin {PLL_DDS/rst DDLL/rst PLL_PD/rst u_DTTL_Supervisor/rst} {
    if {[pin_net $pin] eq $local_reset_net} {error "Local reset incorrectly reaches $pin"}
}
if {[pin_net DTTL/entire_en] ne [pin_net u_DTTL_Supervisor/symbol_valid]} {
    error "Supervisor is not connected to raw DTTL valid"
}
puts DTTL_RESET_ISOLATION_AND_RAW_VALID_PASS
close_design
close_project
puts DTTL_PROJECT_WIRING_PASS
