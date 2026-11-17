# Log a continuous capture, excluding the divider primitive hierarchy.
log_wave /tb_DTTL_MixedStream/clk
foreach name {rst enable tx_phase tx_symbol data_in local_rst restart half_phase valid entire middle nco fcw pd_en pd_out fcw_en correction phase_difference distance expected_index sid checked bit_errors phase_bad sequence_errors pulses late_restarts} {
    log_wave /tb_DTTL_MixedStream/$name
}
log_wave /tb_DTTL_MixedStream/supervisor/*
foreach name {tx_symbol data_in sid phase_difference distance entire middle restart local_rst nco fcw checked bit_errors phase_bad sequence_errors} {
    add_wave /tb_DTTL_MixedStream/$name
}
save_wave_config mixed_stream.wcfg
run all
quit
