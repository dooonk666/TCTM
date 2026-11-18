# Source in Vivado AFTER elaborating tb_DTTL_MixedStream. Does not advance time.
create_wave_config dttl_mixed_stream_fields
set dttl_scope /tb_DTTL_MixedStream
foreach dttl_name {tx_symbol tx_segment expected_index sid rx_symbols checked bit_errors sequence_errors pulses late_restarts} {
    log_wave $dttl_scope/$dttl_name
    add_wave -radix unsigned $dttl_scope/$dttl_name
}
foreach dttl_name {rst enable tx_bit tx_symbol_start symbol_out_valid symbol_bit decision_valid decision_checked reference_bit decoded_bit decision_error decision_phase_bad restart local_rst half_phase} {
    log_wave $dttl_scope/$dttl_name
    add_wave -radix bin $dttl_scope/$dttl_name
}
foreach dttl_name {data_in entire_accum middle_accum entire_out middle_out symbol_out pd_out correction} {
    log_wave $dttl_scope/$dttl_name
    add_wave -radix dec $dttl_scope/$dttl_name
}
foreach dttl_name {tx_phase nco fcw phase_difference distance} {
    log_wave $dttl_scope/$dttl_name
    add_wave -radix hex $dttl_scope/$dttl_name
}
log_wave $dttl_scope/supervisor/*
save_wave_config mixed_stream.wcfg
puts "DTTL waves: compare reference_bit/decoded_bit at decision_valid; tx_segment=1..4 marks 0101 bursts."
