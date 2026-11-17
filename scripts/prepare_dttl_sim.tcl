# Rebuild the generated divider simulation model omitted from source control.
set root [file normalize [file join [file dirname [info script]] ..]]
open_project [file join $root build k7_clean.xpr]
set divider [get_ips div_gen_0]
generate_target all $divider
synth_ip $divider
set output_dir [file join $root build ip_generated div_gen_0]
file mkdir $output_dir
open_checkpoint [file join $output_dir div_gen_0.dcp]
write_verilog -force -mode funcsim [file join $output_dir div_gen_0_sim_netlist.v]
close_design
close_project
puts K7_DTTL_SIM_MODEL_READY
