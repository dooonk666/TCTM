`timescale 1ns / 1ps
// Continuous ideal NRZ sample stream -> real DTTL + supervisor -> real deframer.
// No symbol injection, byte adapter, per-frame reset, or TX backpressure.
module tb_DTTL_TelecommandStream;
localparam integer MAX_BYTES = 65536;
// Start with the 4168-symbol smoke test. Set to 1 for all 42 OC + 5 formats.
parameter FULL_COVERAGE = 1;
localparam integer CASES = FULL_COVERAGE ? 47 : 3;
localparam [24:0] TX_FCW = 25'd11195744;
parameter DATA_DIR = "E:/k7_clean/sim/data";

reg clk=0;
always #5 clk=~clk;
reg rst=1, enable=0;
reg [31:0] tx_phase=32'h80000000;
wire [32:0] tx_sum={1'b0,tx_phase}+{8'd0,TX_FCW};
integer tx_symbol=0;
reg [7:0] stream_bytes [0:MAX_BYTES-1];
reg [31:0] stream_meta [0:MAX_BYTES-1];
reg [31:0] config_words [0:3];
integer total_bytes, total_bits, startup_bits;
integer case_start [0:CASES-1];
integer case_guide [0:CASES-1];
integer case_frame_bytes [0:CASES-1];
integer case_length [0:CASES-1];
integer case_oc [0:CASES-1];
reg [7:0] case_format [0:CASES-1];
reg [35:0] case_code [0:CASES-1];
reg [127:0] case_name [0:CASES-1];
reg [8191:0] case_wire_hex [0:CASES-1];
reg [4199:0] case_frame_hex [0:CASES-1];
reg [4095:0] case_payload [0:CASES-1];

wire [31:0] tx_byte_index=tx_symbol/8;
wire [2:0] tx_bit_index=7-(tx_symbol%8);
wire [7:0] tx_byte=(tx_byte_index<total_bytes) ? stream_bytes[tx_byte_index] : 8'h55;
wire [31:0] tx_metadata=(tx_byte_index<total_bytes) ? stream_meta[tx_byte_index] : 32'h00008000;
wire [15:0] tx_frame_id=tx_metadata[31:16];
wire [3:0] tx_field=tx_metadata[15:12];
wire [11:0] tx_field_byte_index=tx_metadata[11:0];
wire tx_bit=tx_byte[tx_bit_index];
wire tx_symbol_end=enable && tx_sum[32];
wire signed [10:0] data_in=tx_bit ? 11'sd500 : -11'sd500;
wire [8191:0] tx_workperiod_hex=(tx_frame_id>0 && tx_frame_id<=CASES) ? case_wire_hex[tx_frame_id-1] : 8192'd0;
wire [4199:0] tx_frame_hex=(tx_frame_id>0 && tx_frame_id<=CASES) ? case_frame_hex[tx_frame_id-1] : 4200'd0;
wire [127:0] tx_case_name=(tx_frame_id>0 && tx_frame_id<=CASES) ? case_name[tx_frame_id-1] : "IDLE";
wire [31:0] tx_oc_no=(tx_frame_id>0 && tx_frame_id<=CASES) ? case_oc[tx_frame_id-1] : 0;
wire tx_byte_end=tx_symbol_end && (tx_bit_index==0);
reg [127:0] tx_recent_bytes=0;
reg [95:0] tx_field_name;
always @* begin
    case (tx_field)
        0: tx_field_name="STARTUP_IDLE";
        1: tx_field_name="GUIDE";
        2: tx_field_name="SYNC_EB90";
        3: tx_field_name="ADDRESS";
        4: tx_field_name="FORMAT";
        5: tx_field_name="PAYLOAD";
        6: tx_field_name="TAIL";
        7: tx_field_name="IDLE";
        8: tx_field_name="DRAIN_IDLE";
        default: tx_field_name="UNKNOWN";
    endcase
end

wire dttl_rst, restart, raw_symbol_valid;
wire signed [21:0] symbol_out, middle_out;
wire symbol_out_valid=raw_symbol_valid && !dttl_rst;
wire symbol_bit=~symbol_out[21];
wire restart_half_phase=dttl_rst && !rst && enable;
wire [31:0] nco;
wire [24:0] fcw;
wire pd_en, fcw_en;
wire signed [16:0] pd_out;
wire signed [25:0] correction;
wire signed [21:0] entire_out=symbol_out;
wire signed [21:0] entire_accum=dttl.DTTL_Integrator_inst.entire_acc;
wire signed [21:0] middle_accum=dttl.DTTL_Integrator_inst.middle_acc;

DTTL_Top dttl (
    .clk(clk), .rst(dttl_rst), .restart_half_phase(restart_half_phase),
    .update_en(enable && !dttl_rst), .MODE(2'd3), .data_in(data_in),
    .entire_en(raw_symbol_valid), .entire_out(symbol_out), .middle_out(middle_out),
    .PD_en(pd_en), .PD_out(pd_out), .FCW_update_en(fcw_en),
    .FCW_modifying(correction), .FCW_out(fcw), .NCO_out(nco), .trig()
);
DTTL_Supervisor supervisor (
    .clk(clk), .rst(rst), .enable(enable), .mode(2'd3),
    .symbol_valid(raw_symbol_valid), .entire_in(symbol_out), .middle_in(middle_out),
    .dttl_rst(dttl_rst), .restart_pulse(restart)
);
wire frame_valid, frame_error, sync_inverted, preamble_valid;
wire [2:0] error_code;
wire [5:0] preamble_bytes;
wire [15:0] frame_address;
wire [7:0] frame_format;
wire [9:0] payload_length;
wire [4095:0] payload;
telecommand_deframer deframer (
    .clk(clk), .rst(rst | dttl_rst),
    .symbol_valid_i(symbol_out_valid), .symbol_data_i(symbol_out),
    .rx_ready_o(), .frame_valid_o(frame_valid), .frame_ready_i(1'b1),
    .frame_address_o(frame_address), .frame_format_o(frame_format),
    .payload_length_o(payload_length), .payload_data_o(payload),
    .sync_inverted_o(sync_inverted), .frame_error_o(frame_error),
    .frame_error_code_o(error_code), .preamble_valid_o(preamble_valid),
    .preamble_bytes_o(preamble_bytes)
);

integer cycle=0, checked_bits=0, bit_errors=0, phase_errors=0, sequence_errors=0;
integer restart_count=0, late_restarts=0, half_phase_observations=0;
integer next_expected, expected_index=-1;
reg [31:0] phase_difference=0, phase_distance=0;
reg reference_bit=0, decoded_bit=0;
reg decision_valid=0, decision_checked=0, decision_error=0;
reg decision_phase_bad=0;
integer received_frames=0, matched_frames=0, frame_mismatches=0, frame_errors=0;
integer unexpected_frames=0, guide_events=0, payload_guide_errors=0;
integer received_bytes=0, rx_frame_id=0, rx_oc_no=0;
reg rx_frame_match=0;
reg [15:0] rx_sync_word=0, saved_sync_word=0;
reg [63:0] saved_tail=0;
reg [15:0] saved_address=0;
reg [7:0] saved_format=0;
reg [9:0] saved_length=0;
reg [4095:0] saved_payload=0;
reg [4199:0] rx_frame_capture=0, saved_frame_hex=0;
reg [71:0] direct_command_hex=0;
wire [35:0] oc_code_first=direct_command_hex[71:36];
wire [35:0] oc_code_repeat=direct_command_hex[35:0];
wire rx_byte_valid=deframer.accept_byte && (deframer.state!=3'd0);
wire [7:0] rx_byte=deframer.rx_data_i;
wire [2:0] rx_state=deframer.state;
wire [15:0] rx_sync_search=deframer.sync_candidate;
wire rx_sync_found=!dttl_rst && deframer.state==3'd0 && symbol_out_valid && deframer.sync_is_valid;
reg [15:0] previous_tx_frame=0;
reg [3:0] previous_tx_field=15;
integer f_tx, f_bits, f_symbols, f_rx, f_events, f_summary, f_cases, f_rx_bytes;
integer i,j,k,scan,id,base,guide_size,frame_size,len,oc;
reg [7:0] fmt;
reg [35:0] code;
reg [127:0] name;
reg this_match;

// Only the transmitter controls the stream position. Receiver resets do not
// stop it, restart a frame, or replay any data.
always @(posedge clk) begin
    if (rst) begin
        tx_phase<=32'h80000000;
        tx_symbol<=0;
    end else if (enable) begin
        tx_phase<=tx_sum[31:0];
        if (tx_sum[32]) begin
            if (tx_symbol<total_bits) begin
                $fdisplay(f_bits,"%0d,%0d,%0d,%0d,%0d,%0d,%0d",tx_symbol,tx_byte_index,tx_frame_id,tx_field,tx_field_byte_index,tx_bit_index,tx_bit);
                if (tx_bit_index==7)
                    $fdisplay(f_tx,"%0d,%0d,%0d,%0d,%0d,%02h,%08b",tx_byte_index,tx_symbol,tx_frame_id,tx_field,tx_field_byte_index,tx_byte,tx_byte);
                if (tx_bit_index==0) tx_recent_bytes<={tx_recent_bytes[119:0],tx_byte};
            end
            tx_symbol<=tx_symbol+1;
            if ((tx_symbol+1)%1024==0)
                $display("DTTL_TC_PROGRESS tx=%0d/%0d frames=%0d/%0d bit_errors=%0d restarts=%0d",tx_symbol+1,total_bits,received_frames,CASES,bit_errors,restart_count);
        end
    end
end

// Sample the SAME pre-NBA integral and valid that the real deframer consumes.
// Reference is a TX lookup for checking only; it is never fed to the receiver.
always @(posedge clk) begin
    decision_valid=0; decision_checked=0; decision_error=0; decision_phase_bad=0;
    if (!rst && enable) begin
        cycle=cycle+1;
        if (tx_frame_id!=previous_tx_frame || tx_field!=previous_tx_field) begin
            $fdisplay(f_events,"%0t,%0d,%0d,TX_SECTION,%0d,%0d",$time,tx_symbol,tx_frame_id,tx_field,tx_field_byte_index);
            previous_tx_frame=tx_frame_id; previous_tx_field=tx_field;
        end
        if (restart) begin
            restart_count=restart_count+1;
            if (tx_symbol>=startup_bits) late_restarts=late_restarts+1;
            $fdisplay(f_events,"%0t,%0d,%0d,RESTART,%0d,0",$time,tx_symbol,tx_frame_id,restart_count);
        end
        if (symbol_out_valid) begin
            phase_difference=tx_phase-nco;
            phase_distance=phase_difference[31] ? (~phase_difference+32'd1) : phase_difference;
            expected_index=tx_symbol-(tx_phase[31] ? 0 : 1);
            if (expected_index>=0 && expected_index<total_bits)
                reference_bit=stream_bytes[expected_index/8][7-(expected_index%8)];
            else reference_bit=0;
            decoded_bit=symbol_bit;
            decision_valid=1;
            decision_checked=(expected_index>=startup_bits && expected_index<total_bits);
            decision_error=decision_checked && (decoded_bit !== reference_bit);
            decision_phase_bad=decision_checked && (phase_distance>=32'h0ccccccd);
            if (tx_symbol<startup_bits && phase_distance>32'h66666666)
                half_phase_observations=half_phase_observations+1;
            if (decision_checked) begin
                checked_bits=checked_bits+1;
                if (decision_error) bit_errors=bit_errors+1;
                if (decision_phase_bad) phase_errors=phase_errors+1;
                if (expected_index!=next_expected) sequence_errors=sequence_errors+1;
                next_expected=expected_index+1;
            end
            $fdisplay(f_symbols,"%0t,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",$time,tx_symbol,expected_index,symbol_out,middle_out,reference_bit,decoded_bit,decision_checked,decision_error,phase_distance,restart_count,fcw);
        end
        // Capture actual received sync and all following assembled bytes.
        if (rx_sync_found) begin
            rx_sync_word=deframer.sync_candidate;
            rx_frame_capture={4184'd0,deframer.sync_candidate};
            received_bytes=2;
            $fdisplay(f_rx_bytes,"%0t,%0d,0,SYNC,%02h",$time,received_frames+1,rx_sync_word[15:8]);
            $fdisplay(f_rx_bytes,"%0t,%0d,1,SYNC,%02h",$time,received_frames+1,rx_sync_word[7:0]);
            $fdisplay(f_events,"%0t,%0d,%0d,RX_SYNC,%04h,0",$time,tx_symbol,tx_frame_id,rx_sync_word);
        end else if (!dttl_rst && rx_byte_valid) begin
            $fdisplay(f_rx_bytes,"%0t,%0d,%0d,%0d,%02h",$time,received_frames+1,received_bytes,rx_state,rx_byte);
            rx_frame_capture=(rx_frame_capture<<8) | rx_byte;
            received_bytes=received_bytes+1;
        end
        if (dttl_rst) begin
            rx_frame_capture=0;
            received_bytes=0;
        end
    end
end

// Inspect registered frame outputs after NBA. Match in FIFO order against the
// source CSV, including every valid payload byte and the actual received frame.
always @(posedge clk) begin
    #1;
    if (!rst && enable && !dttl_rst) begin
        if (preamble_valid) begin
            guide_events=guide_events+1;
            if (deframer.state!=3'd0 || preamble_bytes!==6'd48)
                payload_guide_errors=payload_guide_errors+1;
            $fdisplay(f_events,"%0t,%0d,%0d,ALTERNATING_384_BITS,%0d,0",$time,tx_symbol,tx_frame_id,preamble_bytes);
        end
        if (frame_error) begin
            frame_errors=frame_errors+1;
            $fdisplay(f_events,"%0t,%0d,%0d,FRAME_ERROR,%0d,0",$time,tx_symbol,tx_frame_id,error_code);
            $display("DTTL_TC_FRAME_ERROR tx=%0d code=%0d",tx_symbol,error_code);
        end
        if (frame_valid) begin
            rx_frame_id=received_frames+1;
            saved_sync_word=rx_sync_word;
            saved_tail=deframer.tail_shift;
            saved_address=frame_address; saved_format=frame_format;
            saved_length=payload_length;
            saved_payload=0; direct_command_hex=0; rx_oc_no=0;
            saved_frame_hex=rx_frame_capture;
            if (^payload_length === 1'bx || payload_length>512)
                $fatal(1,"Unknown/out-of-range DUT payload length");
            for (k=0;k<payload_length;k=k+1)
                saved_payload[k*8 +: 8]=payload[k*8 +: 8];
            if (frame_format==8'h39 && payload_length==9) begin
                for (k=0;k<9;k=k+1)
                    direct_command_hex=(direct_command_hex<<8) | payload[k*8 +: 8];
                for (k=0;k<CASES;k=k+1)
                    if (direct_command_hex === {case_code[k],case_code[k]}) rx_oc_no=case_oc[k];
            end
            this_match=0;
            if (received_frames<CASES) begin
                this_match=(saved_sync_word===16'hEB90) && (frame_address===16'hB42E) &&
                    (frame_format===case_format[received_frames]) &&
                    (payload_length===case_length[received_frames]) &&
                    (saved_tail===64'hC5C5C5C5C5C5C579) && (sync_inverted===1'b0) &&
                    (received_bytes==case_frame_bytes[received_frames]) &&
                    (saved_frame_hex===case_frame_hex[received_frames]) &&
                    (rx_oc_no==case_oc[received_frames]);
                for (k=0;k<case_length[received_frames];k=k+1)
                    if (payload[k*8 +: 8] !== case_payload[received_frames][k*8 +: 8]) this_match=0;
            end else unexpected_frames=unexpected_frames+1;
            rx_frame_match=this_match;
            if (this_match) matched_frames=matched_frames+1;
            else frame_mismatches=frame_mismatches+1;
            received_frames=received_frames+1;
            $fwrite(f_rx,"%0d,%0d,%0d,%04h,%04h,%02h,%0d,%016h,%0d,",rx_frame_id,this_match,rx_oc_no,saved_sync_word,frame_address,frame_format,payload_length,saved_tail,sync_inverted);
            for (k=0;k<payload_length;k=k+1) $fwrite(f_rx,"%02h",payload[k*8 +: 8]);
            $fwrite(f_rx,",%018h,",direct_command_hex);
            if (received_bytes<=525)
                for (k=received_bytes-1;k>=0;k=k-1) $fwrite(f_rx,"%02h",saved_frame_hex[k*8 +: 8]);
            $fdisplay(f_rx,"");
            $display("DTTL_TC_FRAME id=%0d format=%02h length=%0d oc=%0d match=%0d",rx_frame_id,frame_format,payload_length,rx_oc_no,this_match);
        end
    end
end

initial begin
    $timeformat(-9,0,"",0);
    if (FULL_COVERAGE)
        $readmemh({DATA_DIR,"/dttl_telecommand_config.mem"},config_words);
    else
        $readmemh({DATA_DIR,"/dttl_telecommand_quick_config.mem"},config_words);
    if (^config_words[0] === 1'bx || config_words[0]>MAX_BYTES || config_words[1]!=CASES)
        $fatal(1,"Missing/invalid stream config; run create_dttl_telecommand_stream.ps1");
    total_bytes=config_words[0]; total_bits=total_bytes*8;
    startup_bits=config_words[2]*8; next_expected=startup_bits;
    if (FULL_COVERAGE) begin
        $readmemh({DATA_DIR,"/dttl_telecommand_bytes.mem"},stream_bytes,0,total_bytes-1);
        $readmemh({DATA_DIR,"/dttl_telecommand_meta.mem"},stream_meta,0,total_bytes-1);
        f_cases=$fopen({DATA_DIR,"/dttl_telecommand_cases.txt"},"r");
    end else begin
        $readmemh({DATA_DIR,"/dttl_telecommand_quick_bytes.mem"},stream_bytes,0,total_bytes-1);
        $readmemh({DATA_DIR,"/dttl_telecommand_quick_meta.mem"},stream_meta,0,total_bytes-1);
        f_cases=$fopen({DATA_DIR,"/dttl_telecommand_quick_cases.txt"},"r");
    end
    if (!f_cases) $fatal(1,"Cannot open case manifest");
    for (i=0;i<CASES;i=i+1) begin
        scan=$fscanf(f_cases,"%d %d %d %d %d %h %d %h %s",id,base,guide_size,frame_size,len,fmt,oc,code,name);
        if (scan!=9 || id!=i+1 || guide_size!=48 || len>512 || base+guide_size+frame_size>total_bytes)
            $fatal(1,"Invalid manifest case %0d",i+1);
        case_start[i]=base; case_guide[i]=guide_size; case_frame_bytes[i]=frame_size;
        case_length[i]=len; case_format[i]=fmt; case_oc[i]=oc; case_code[i]=code; case_name[i]=name;
        case_wire_hex[i]=0; case_frame_hex[i]=0; case_payload[i]=0;
        for (j=0;j<guide_size+frame_size;j=j+1) begin
            if (^stream_bytes[base+j] === 1'bx) $fatal(1,"Missing source byte");
            case_wire_hex[i]=(case_wire_hex[i]<<8) | stream_bytes[base+j];
            if (j>=guide_size) case_frame_hex[i]=(case_frame_hex[i]<<8) | stream_bytes[base+j];
        end
        for (j=0;j<len;j=j+1) case_payload[i][j*8 +: 8]=stream_bytes[base+guide_size+5+j];
    end
    $fclose(f_cases);
    f_tx=$fopen("dttl_tc_tx_bytes.csv","w");
    f_bits=$fopen("dttl_tc_tx_bits.csv","w");
    f_symbols=$fopen("dttl_tc_rx_symbols.csv","w");
    f_rx=$fopen("dttl_tc_rx_commands.csv","w");
    f_events=$fopen("dttl_tc_events.csv","w");
    f_summary=$fopen("dttl_tc_summary.csv","w");
    f_rx_bytes=$fopen("dttl_tc_rx_bytes.csv","w");
    if (!f_tx || !f_bits || !f_symbols || !f_rx || !f_events || !f_summary || !f_rx_bytes) $fatal(1,"Cannot open CSV outputs");
    $fdisplay(f_tx,"byte_index,start_bit,frame_id,field_id,field_byte_index,hex,binary");
    $fdisplay(f_bits,"symbol,byte_index,frame_id,field_id,field_byte_index,bit_index,bit");
    $fdisplay(f_symbols,"time_ns,tx_symbol,expected_index,entire,middle,reference_bit,decoded_bit,checked,bit_error,phase_distance,restarts,fcw");
    $fdisplay(f_rx,"frame_id,match,decoded_oc_no,sync_hex,address_hex,format_hex,payload_length,tail_hex,inverted,payload_hex,direct_command_hex,frame_hex");
    $fdisplay(f_events,"time_ns,tx_symbol,tx_frame_id,event,value,offset");
    $fdisplay(f_rx_bytes,"time_ns,frame_id,byte_index,state_or_sync,hex");
    $display("DTTL_TC_CONFIG frames=%0d bytes=%0d symbols=%0d startup=%0d TX_phase=80000000 RX_reset_phase=00000001",CASES,total_bytes,total_bits,startup_bits);
    repeat (20) @(negedge clk);
    if (nco !== 32'h00000001) $fatal(1,"Expected the normal NCO reset phase before acquisition");
    rst=0; enable=1;
    wait (tx_symbol>=total_bits+8);
    @(negedge clk);
    enable=0;
    $fdisplay(f_summary,"expected_frames,received_frames,matched_frames,frame_errors,frame_mismatches,unexpected_frames,checked_bits,expected_checked_bits,bit_errors,phase_errors,sequence_errors,restarts,late_restarts,half_phase_observations,guide_events,payload_guide_errors");
    $fdisplay(f_summary,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",CASES,received_frames,matched_frames,frame_errors,frame_mismatches,unexpected_frames,checked_bits,total_bits-startup_bits,bit_errors,phase_errors,sequence_errors,restart_count,late_restarts,half_phase_observations,guide_events,payload_guide_errors);
    $fclose(f_tx); $fclose(f_bits); $fclose(f_symbols); $fclose(f_rx); $fclose(f_events); $fclose(f_summary); $fclose(f_rx_bytes);
    $display("DTTL_TC_RESULT frames=%0d matched=%0d frame_errors=%0d checked=%0d/%0d bit_errors=%0d phase_errors=%0d sequence_errors=%0d restarts=%0d late_restarts=%0d",received_frames,matched_frames,frame_errors,checked_bits,total_bits-startup_bits,bit_errors,phase_errors,sequence_errors,restart_count,late_restarts);
    if (received_frames!=CASES || matched_frames!=CASES || frame_errors!=0 || frame_mismatches!=0 ||
        unexpected_frames!=0 || checked_bits!=total_bits-startup_bits || next_expected!=total_bits ||
        bit_errors!=0 || phase_errors!=0 || sequence_errors!=0 || late_restarts!=0 ||
        guide_events<CASES || payload_guide_errors!=0)
        $fatal(1,"DTTL/telecommand continuous stream FAILED; inspect CSV and waves");
    $display("DTTL_TELECOMMAND_STREAM_TEST_PASS");
    $finish;
end
initial begin
    #1000000000;
    $fatal(1,"DTTL/telecommand watchdog: 1 second of simulated time");
end
endmodule
