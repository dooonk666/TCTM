# Keep only top-level and supervisor signals; avoid logging the divider netlist.
log_wave /tb_DTTL_HalfCycle/*
log_wave /tb_DTTL_HalfCycle/supervisor/*
add_wave /tb_DTTL_HalfCycle/clk
add_wave /tb_DTTL_HalfCycle/scenario
add_wave /tb_DTTL_HalfCycle/data_in
add_wave /tb_DTTL_HalfCycle/tx_phase
add_wave /tb_DTTL_HalfCycle/nco
add_wave /tb_DTTL_HalfCycle/phase_error
add_wave /tb_DTTL_HalfCycle/entire
add_wave /tb_DTTL_HalfCycle/middle
add_wave /tb_DTTL_HalfCycle/restart
add_wave /tb_DTTL_HalfCycle/local_rst
save_wave_config halfcycle.wcfg
run all
quit
