`timescale 1ns / 1ps
// Hex bytes are loaded from a CSV-derived stimulus file, serialized MSB first,
// then collected into bytes before the DUT's existing 8-bit ready/valid port.
module tb_telecommand_deframer_csv;
reg clk=0;
always #5 clk=~clk;
reg rst=1, serial_valid=0, serial_bit=0, frame_ready=0;
reg [7:0] shift=0, rx_data=0;
reg [2:0] bit_count=0;
reg rx_valid=0;
wire rx_ready, frame_valid, frame_error, sync_inverted;
wire [15:0] address;
wire [7:0] format_byte;
wire [9:0] payload_length;
wire [4095:0] payload;
wire [2:0] error_code;
wire preamble_valid;
wire [5:0] preamble_bytes;
integer guides_seen=0, saved_guide_bytes=0;
reg [383:0] guide_capture;
reg [8191:0] wire_capture;
integer source_file, result_file, bit_file, byte_file;
integer active_id=0, nbytes, expected_code, scanned, k, b, j;
integer row_count=0, observed_count=0, observed_error=0, byte_count=0;
integer total_ok=0, total_errors=0, total_none=0;
reg observed_ok=0;
reg [15:0] saved_address;
reg [7:0] saved_format;
reg [9:0] saved_length;
reg [4095:0] saved_payload;
reg saved_inverted;
reg [7:0] next_byte;
reg [8191:0] stimulus_path;

telecommand_deframer dut (
    .clk(clk), .rst(rst), .rx_valid_i(rx_valid), .rx_data_i(rx_data),
    .rx_ready_o(rx_ready), .frame_valid_o(frame_valid), .frame_ready_i(frame_ready),
    .frame_address_o(address), .frame_format_o(format_byte),
    .payload_length_o(payload_length), .payload_data_o(payload),
    .sync_inverted_o(sync_inverted), .frame_error_o(frame_error),
    .frame_error_code_o(error_code),
    .preamble_valid_o(preamble_valid), .preamble_bytes_o(preamble_bytes)
);

// TB-only bit-to-byte adapter, not an alteration to the deframer RTL.
always @(posedge clk) begin
    if (rst) begin
        shift<=0; bit_count<=0; rx_data<=0; rx_valid<=0;
    end else begin
        if (rx_valid && rx_ready) rx_valid<=0;
        if (serial_valid) begin
            if (rx_valid && !rx_ready) $fatal(1,"Adapter overrun");
            shift<={shift[6:0],serial_bit};
            if (bit_count==7) begin
                rx_data<={shift[6:0],serial_bit};
                rx_valid<=1;
                bit_count<=0;
            end else bit_count<=bit_count+1'b1;
        end
    end
end

// Record the binary byte ACTUALLY accepted by the DUT, before NBA updates.
always @(posedge clk) begin
    if (!rst && rx_valid && rx_ready) begin
        $fdisplay(byte_file,"%0d,%0d,%02h,%08b",active_id,byte_count,rx_data,rx_data);
        wire_capture[byte_count*8 +: 8]=rx_data;
        if (byte_count<48) guide_capture[byte_count*8 +: 8]=rx_data;
        byte_count=byte_count+1;
    end
end
// Capture output once, while frame_ready is low. Payload comes only from DUT.
always @(posedge clk) begin
    #1;
    if (!rst) begin
        if (preamble_valid) begin
            guides_seen=guides_seen+1;
            saved_guide_bytes=preamble_bytes;
        end
        if (frame_error) begin
            observed_count=observed_count+1;
            observed_error=error_code;
        end
        if (frame_valid && !observed_ok) begin
            observed_count=observed_count+1;
            observed_ok=1;
            saved_address=address; saved_format=format_byte;
            saved_length=payload_length; saved_payload=payload;
            saved_inverted=sync_inverted;
        end
    end
end

task serialize_byte;
    input [7:0] value;
    input integer index;
    integer bit_index;
    begin
        for (bit_index=7; bit_index>=0; bit_index=bit_index-1) begin
            @(negedge clk);
            serial_valid=1; serial_bit=value[bit_index];
            $fdisplay(bit_file,"%0d,%0d,%0d,%0b",active_id,index,bit_index,serial_bit);
            @(posedge clk); #2;
        end
    end
endtask

initial begin
    stimulus_path="telecommand_stimulus.txt";
    source_file=$fopen(stimulus_path,"r");
    result_file=$fopen("telecommand_rx_commands.csv","w");
    bit_file=$fopen("telecommand_tx_bits.csv","w");
    byte_file=$fopen("telecommand_rx_bytes.csv","w");
    if (!source_file || !result_file || !bit_file || !byte_file)
        $fatal(1,"Cannot open input/output files");
    $fdisplay(result_file,"frame_id,status,error_code,address_hex,format_hex,payload_length,command_hex,sync_inverted,preamble_detected,preamble_bytes,preamble_hex,received_wire_hex");
    $fdisplay(bit_file,"frame_id,byte_index,bit_index,bit");
    $fdisplay(byte_file,"frame_id,byte_index,hex,binary");
    repeat (4) @(negedge clk);
    rst=0;
    scanned=$fscanf(source_file,"%d %d %d",active_id,nbytes,expected_code);
    while (scanned==3) begin
        observed_count=0; observed_error=0; observed_ok=0; byte_count=0;
        guides_seen=0; saved_guide_bytes=0; guide_capture=0; wire_capture=0;
        for (k=0;k<nbytes;k=k+1) begin
            if ($fscanf(source_file,"%h",next_byte)!=1)
                $fatal(1,"Incomplete frame %0d",active_id);
            serialize_byte(next_byte,k);
        end
        @(negedge clk); serial_valid=0;
        repeat (4) begin @(posedge clk); #2; end
        if (byte_count!=nbytes || bit_count!=0)
            $fatal(1,"Incomplete bit-to-byte delivery frame %0d",active_id);
        if (observed_count>1) $fatal(1,"Multiple results for frame %0d",active_id);
        if (observed_ok) begin
            $fwrite(result_file,"%0d,OK,0,%04h,%02h,%0d,",active_id,saved_address,saved_format,saved_length);
            // DUT puts first payload byte in bits [7:0]; print wire order.
            for (j=0;j<saved_length;j=j+1)
                $fwrite(result_file,"%02h",saved_payload[j*8 +: 8]);
            $fwrite(result_file,",%0d",saved_inverted);
            total_ok=total_ok+1;
        end else if (observed_error!=0) begin
            $fwrite(result_file,"%0d,ERROR,%0d,,,,,",active_id,observed_error);
            total_errors=total_errors+1;
        end else begin
            $fwrite(result_file,"%0d,NO_FRAME,0,,,,,",active_id);
            total_none=total_none+1;
        end
        if (guides_seen>1) $fatal(1,"Multiple guide events in one CSV work period");
        $fwrite(result_file,",%0d,%0d,",guides_seen,saved_guide_bytes);
        if (guides_seen)
            for (j=0;j<saved_guide_bytes;j=j+1) $fwrite(result_file,"%02h",guide_capture[j*8 +: 8]);
        $fwrite(result_file,",");
        for (j=0;j<byte_count;j=j+1) $fwrite(result_file,"%02h",wire_capture[j*8 +: 8]);
        $fdisplay(result_file,"");
        if ((expected_code==0 && !observed_ok) ||
            (expected_code>=1 && expected_code<=3 && (observed_ok || observed_error!=expected_code)) ||
            (expected_code==4 && observed_count!=0))
            $fatal(1,"Unexpected result frame=%0d expected=%0d ok=%0d error=%0d",active_id,expected_code,observed_ok,observed_error);
        if (observed_ok) begin
            @(negedge clk); frame_ready=1;
            @(posedge clk); #2;
            if (frame_valid) $fatal(1,"Output handshake failed");
            @(negedge clk); frame_ready=0;
        end else @(negedge clk);
        row_count=row_count+1;
        $display("CSV_CASE_PASS frame=%0d expected=%0d bytes=%0d",active_id,expected_code,nbytes);
        scanned=$fscanf(source_file,"%d %d %d",active_id,nbytes,expected_code);
    end
    if (scanned!=0 && scanned!=-1) $fatal(1,"Malformed stimulus header");
    if (row_count==0) $fatal(1,"Empty stimulus");
    $fclose(source_file); $fclose(result_file); $fclose(bit_file); $fclose(byte_file);
    $display("TB_TELECOMMAND_CSV_PASS rows=%0d frames=%0d errors=%0d no_frame=%0d",row_count,total_ok,total_errors,total_none);
    $finish;
end
initial begin
    #10000000;
    $fatal(1,"CSV deframer watchdog timeout");
end
endmodule
