`timescale 1ns / 1ps

// One continuous stream. Real DTTL RTL, real divider netlist, no state injection.
module tb_DTTL_MixedStream;
localparam integer TOTAL = 4096;
localparam integer WARMUP = 512;
localparam integer BURSTS = 4;
localparam [31:0] SCHEDULE_SEED = 32'h6d2b79f5;
localparam [24:0] TX_FCW = 25'd11195744;
reg clk = 0;
always #5 clk = ~clk;
reg rst = 1;
reg enable = 0;
reg [31:0] tx_phase = 32'h80000000;
wire [32:0] tx_sum = {1'b0,tx_phase}+TX_FCW;
reg tx_bits [0:TOTAL+7];
integer segment [0:TOTAL+7];
integer burst_start [0:BURSTS-1];
integer burst_length [0:BURSTS-1];
integer tx_symbol = 0;
wire signed [10:0] data_in = tx_bits[tx_symbol] ? 11'sd500 : -11'sd500;
wire tx_bit = tx_bits[tx_symbol];
wire [2:0] tx_segment = segment[tx_symbol]; // 0=PRBS; 1..4=alternating bursts
wire tx_symbol_start = enable && tx_sum[32];
wire local_rst, restart, valid;
wire signed [21:0] entire, middle;
// Same naming and polarity as TMTC_Track_Top: symbol_out IS Entire's integral.
wire signed [21:0] entire_out = entire;
wire signed [21:0] middle_out = middle;
wire signed [21:0] symbol_out = entire;
wire symbol_out_valid = valid && !local_rst;
wire symbol_bit = ~symbol_out[21]; // +amplitude=1, -amplitude=0 in this test
wire signed [21:0] entire_accum = dttl.DTTL_Integrator_inst.entire_acc;
wire signed [21:0] middle_accum = dttl.DTTL_Integrator_inst.middle_acc;
wire [31:0] nco;
wire [24:0] fcw;
wire half_phase = local_rst && !rst && enable;
wire pd_en, fcw_en;
wire signed [16:0] pd_out;
wire signed [25:0] correction;
integer cycle = 0;
integer rx_symbols = 0;
integer pulses = 0;
integer late_restarts = 0;
integer reset_edges = 0;
integer masked_first = 0;
integer checked = 0;
integer phase_bad = 0;
integer bit_errors = 0;
integer sequence_errors = 0;
integer next_expected = WARMUP;
integer counts [0:BURSTS];
integer errors [0:BURSTS];
integer phase_failures [0:BURSTS];
reg [31:0] max_distance [0:BURSTS];
reg [31:0] phase_difference=0;
reg [31:0] distance=0;
integer expected_index=-1;
integer sid=0;
reg reference_bit=0;
reg decoded_bit=0;
reg decision_valid=0;
reg decision_checked=0;
reg decision_error=0;
reg decision_phase_bad=0;
integer f, events, bits_file;
integer i, b, cursor, gap;
reg [31:0] schedule_state;
reg [15:0] data_state;
function [31:0] random_next;
    input [31:0] value;
    reg [31:0] x;
    begin
        x=value^(value<<13);
        x=x^(x>>17);
        random_next=x^(x<<5);
    end
endfunction

DTTL_Top dttl (
    .clk(clk), .rst(local_rst), .restart_half_phase(half_phase),
    .update_en(enable && !local_rst), .MODE(2'd3), .data_in(data_in),
    .entire_en(valid), .entire_out(entire), .middle_out(middle),
    .PD_en(pd_en), .PD_out(pd_out), .FCW_update_en(fcw_en),
    .FCW_modifying(correction), .FCW_out(fcw), .NCO_out(nco), .trig()
);
DTTL_Supervisor supervisor (
    .clk(clk), .rst(rst), .enable(enable), .mode(2'd3),
    .symbol_valid(valid), .entire_in(entire), .middle_in(middle),
    .dttl_rst(local_rst), .restart_pulse(restart)
);

always @(posedge clk) begin
    if (rst) begin
        tx_phase<=32'h80000000;
        tx_symbol<=0;
    end else if (enable) begin
        tx_phase<=tx_sum[31:0];
        if (tx_sum[32]) begin
            tx_symbol<=tx_symbol+1;
            if (tx_symbol+1<TOTAL && segment[tx_symbol+1]!=segment[tx_symbol]) begin
                $display("SEGMENT tx=%0d segment=%0d cycle=%0d",tx_symbol+1,segment[tx_symbol+1],cycle);
                $fdisplay(events,"%0d,%0d,segment,%0d",cycle,tx_symbol+1,segment[tx_symbol+1]);
            end
            if ((tx_symbol+1)%256==0)
                $display("PROGRESS tx=%0d checked=%0d errors=%0d phase_bad=%0d restarts=%0d",tx_symbol+1,checked,bit_errors,phase_bad,pulses);
        end
    end
end

always @(posedge clk) begin
    if (!rst && enable && local_rst) begin
        reset_edges=reset_edges+1;
        #1;
        if (nco !== 32'h80000001)
            $fatal(1,"Local reset must hold the half-cycle phase seed");
    end
end

always @(posedge clk) begin
    #1;
    decision_valid=0;
    decision_checked=0;
    decision_error=0;
    decision_phase_bad=0;
    if (enable && !rst) begin
        cycle=cycle+1;
        if (restart) begin
            pulses=pulses+1;
            if (tx_symbol>=WARMUP) late_restarts=late_restarts+1;
            $display("RESTART tx=%0d cycle=%0d count=%0d",tx_symbol,cycle,pulses);
            $fdisplay(events,"%0d,%0d,restart,%0d",cycle,tx_symbol,pulses);
        end
        if (dttl.integrator_entire_en && !dttl.first_symbol_seen) begin
            if (valid) $fatal(1,"First incomplete integral leaked");
            masked_first=masked_first+1;
        end
        if (valid) begin
            rx_symbols=rx_symbols+1;
            phase_difference=tx_phase-nco;
            distance=phase_difference[31] ? (~phase_difference+32'd1) : phase_difference;
            // Independent TX lookup at the nominal RX interval midpoint.
            expected_index=tx_symbol-(tx_phase[31] ? 0 : 1);
            sid=expected_index>=0 ? segment[expected_index] : 0;
            reference_bit=expected_index>=0 ? tx_bits[expected_index] : 0;
            decoded_bit=symbol_bit;
            decision_valid=1;
            decision_checked=expected_index>=WARMUP && expected_index<TOTAL;
            decision_error=decision_checked && (decoded_bit !== reference_bit);
            decision_phase_bad=decision_checked && (distance>=32'h0ccccccd);
            $fdisplay(f,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",cycle,tx_symbol,rx_symbols,expected_index,sid,entire,middle,phase_difference,fcw,expected_index>=0 ? tx_bits[expected_index] : 0,entire>=0,pulses);
            if (expected_index>=WARMUP && expected_index<TOTAL) begin
                checked=checked+1;
                counts[sid]=counts[sid]+1;
                if (distance>max_distance[sid]) max_distance[sid]=distance;
                if (distance>=32'h0ccccccd) begin
                    phase_bad=phase_bad+1;
                    phase_failures[sid]=phase_failures[sid]+1;
                end
                if ((entire>=0) !== tx_bits[expected_index]) begin
                    bit_errors=bit_errors+1;
                    errors[sid]=errors[sid]+1;
                end
                if (expected_index!=next_expected) sequence_errors=sequence_errors+1;
                next_expected=expected_index+1;
            end
        end
    end
end

initial begin
    f=$fopen("mixed_stream_symbols.csv","w");
    events=$fopen("mixed_stream_events.csv","w");
    bits_file=$fopen("mixed_stream_bits.csv","w");
    if (!f || !events || !bits_file) $fatal(1,"Cannot open trace files");
    $fdisplay(f,"cycle,tx_symbol,rx_symbol,expected_index,segment,entire,middle,phase_error,fcw,expected_bit,decoded_bit,restarts");
    $fdisplay(events,"cycle,tx_symbol,event,value");
    $fdisplay(bits_file,"tx_symbol,segment,bit");
    schedule_state=SCHEDULE_SEED;
    cursor=WARMUP;
    for (b=0;b<BURSTS;b=b+1) begin
        schedule_state=random_next(schedule_state);
        gap=128+(schedule_state & 32'h7f);
        cursor=cursor+gap;
        burst_start[b]=cursor;
        schedule_state=random_next(schedule_state);
        burst_length[b]=256+(schedule_state & 32'hff);
        cursor=cursor+burst_length[b];
        $display("BURST id=%0d start=%0d length=%0d end_exclusive=%0d",b+1,burst_start[b],burst_length[b],cursor);
    end
    if (cursor>TOTAL-512) $fatal(1,"Need at least 512 PRBS symbols after final burst");
    data_state=16'hace1;
    for (i=0;i<TOTAL+8;i=i+1) begin
        segment[i]=0;
        tx_bits[i]=data_state[0];
        data_state={data_state[14:0],data_state[15]^data_state[13]^data_state[12]^data_state[10]};
        for (b=0;b<BURSTS;b=b+1)
            if (i>=burst_start[b] && i<burst_start[b]+burst_length[b]) begin
                segment[i]=b+1;
                tx_bits[i]=((i-burst_start[b])%2)!=0;
            end
        if (i<TOTAL) $fdisplay(bits_file,"%0d,%0d,%0d",i,segment[i],tx_bits[i]);
    end
    $fclose(bits_file);
    for (i=0;i<=BURSTS;i=i+1) begin
        counts[i]=0; errors[i]=0; phase_failures[i]=0; max_distance[i]=0;
    end
    $display("CONFIG total=%0d warmup=%0d checked_target=%0d schedule_seed=%h data_seed=ace1",TOTAL,WARMUP,TOTAL-WARMUP,SCHEDULE_SEED);
    repeat (20) @(negedge clk);
    rst=0; enable=1;
    wait (tx_symbol==TOTAL+4);
    @(negedge clk);
    for (i=0;i<=BURSTS;i=i+1) begin
        $display("SEGMENT_RESULT id=%0d checked=%0d bit_errors=%0d phase_bad=%0d max_distance=%0d",i,counts[i],errors[i],phase_failures[i],max_distance[i]);
        if (i>0 && counts[i]!=burst_length[i-1])
            $fatal(1,"Incomplete burst coverage id=%0d",i);
    end
    $display("MIXED_RESULT checked=%0d bit_errors=%0d phase_bad=%0d sequence_errors=%0d restarts=%0d late_restarts=%0d reset_edges=%0d masked=%0d",checked,bit_errors,phase_bad,sequence_errors,pulses,late_restarts,reset_edges,masked_first);
    $fclose(f); $fclose(events);
    if (checked!=TOTAL-WARMUP || next_expected!=TOTAL || bit_errors!=0 || phase_bad!=0 || sequence_errors!=0 || late_restarts!=0 || pulses!=1 || reset_edges!=2 || masked_first!=2)
        $fatal(1,"Mixed stream stability check failed; see MIXED_RESULT");
    $display("DTTL_MIXED_STREAM_TEST_PASS");
    $finish;
end
initial begin
    #20000000;
    $fatal(1,"Mixed stream simulation timeout");
end
endmodule
