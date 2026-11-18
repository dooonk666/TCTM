# Source in an elaborated/relaunched simulation. No simulation time is advanced.
create_wave_config telecommand_fields
set tc_scope /tb_telecommand_deframer_csv
foreach tc_name {clk rst serial_valid serial_bit rx_valid rx_ready rx_data sync_word preamble_valid preamble_bytes frame_valid frame_error saved_frame_valid saved_frame_id saved_sync saved_address saved_format saved_length direct_command_valid direct_command_hex oc_code_first oc_code_repeat payload_byte0 payload_byte1 saved_payload saved_tail saved_inverted active_id byte_count observed_ok total_ok} {
    log_wave $tc_scope/$tc_name
    add_wave -radix hex $tc_scope/$tc_name
}
save_wave_config telecommand_fields.wcfg
puts "Wave fields ready: sync_word is live; saved_* belongs to saved_frame_id."
