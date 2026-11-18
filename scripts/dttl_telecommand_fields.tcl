# Source after elaboration, BEFORE running. This script never advances time.
create_wave_config dttl_telecommand_fields
set dtc_scope /tb_DTTL_TelecommandStream
foreach dtc_name {tx_symbol tx_byte_index tx_frame_id tx_oc_no tx_field tx_field_byte_index tx_bit_index expected_index checked_bits bit_errors phase_errors sequence_errors restart_count late_restarts received_frames matched_frames frame_errors frame_mismatches rx_frame_id rx_oc_no received_bytes guide_events} {
    log_wave $dtc_scope/$dtc_name
    add_wave -radix unsigned $dtc_scope/$dtc_name
}
foreach dtc_name {tx_case_name tx_field_name} {
    log_wave $dtc_scope/$dtc_name
    add_wave -radix ascii $dtc_scope/$dtc_name
}
foreach dtc_name {rst enable tx_bit tx_symbol_end tx_byte_end symbol_out_valid symbol_bit decision_valid decision_checked reference_bit decoded_bit decision_error decision_phase_bad restart dttl_rst restart_half_phase rx_sync_found rx_byte_valid frame_valid frame_error rx_frame_match preamble_valid} {
    log_wave $dtc_scope/$dtc_name
    add_wave -radix bin $dtc_scope/$dtc_name
}
foreach dtc_name {data_in entire_accum middle_accum entire_out middle_out symbol_out pd_out correction} {
    log_wave $dtc_scope/$dtc_name
    add_wave -radix dec $dtc_scope/$dtc_name
}
foreach dtc_name {tx_byte tx_recent_bytes tx_workperiod_hex tx_frame_hex tx_phase nco fcw phase_difference phase_distance rx_sync_search rx_sync_word rx_byte rx_state saved_sync_word saved_address saved_format saved_length saved_tail saved_payload saved_frame_hex direct_command_hex oc_code_first oc_code_repeat error_code preamble_bytes} {
    log_wave $dtc_scope/$dtc_name
    add_wave -radix hex $dtc_scope/$dtc_name
}
foreach dtc_name {symbol_bit_count symbol_shift sync_shift alternating_count} {
    log_wave $dtc_scope/deframer/$dtc_name
    add_wave -radix hex $dtc_scope/deframer/$dtc_name
}
save_wave_config dttl_telecommand.wcfg
puts "TX is continuous: tx_byte/tx_bit + ASCII field names show ALL guide, idle and frame bits. TX full-frame hex is in transmission order. Read signed integrals as decimal. Compare bits at decision_valid; inspect actual received bytes at rx_byte_valid and complete frames at frame_valid."
