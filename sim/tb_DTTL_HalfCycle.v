`timescale 1ns / 1ps

// Real input waveform and complete DTTL feedback paths. No monitor injection.
module tb_DTTL_HalfCycle;
reg clk = 0;
always #5 clk = ~clk;
reg rst = 1;
reg enable = 0;
reg [1:0] mode = 3;
reg [31:0] tx_phase = 32'h80000000;
reg [15:0] prbs = 16'hace1;
reg alternating = 1;
reg tx_bit = 0;
wire [24:0] tx_fcw = mode == 3 ? 25'd11195744 : mode == 2 ? 25'd5597872 : 25'd2798936;
wire [32:0] tx_sum = {1'b0,tx_phase} + tx_fcw;
wire signed [10:0] data_in = (alternating ? tx_bit : prbs[0]) ? 11'sd500 : -11'sd500;
wire local_rst, restart;
wire [1:0] valid;
wire signed [21:0] entire [0:1];
wire signed [21:0] middle [0:1];
wire [31:0] nco [0:1];
wire [24:0] fcw [0:1];
integer cycle = 0;
integer pulses = 0;
integer f;
integer j;
integer symbols [0:1];
reg [63:0] esum [0:1];
reg [63:0] msum [0:1];
reg [31:0] phase_error [0:1];
integer scenario;
integer half_symbols [0:1];
integer good_symbols [0:1];
integer errors [0:1];
integer late_restarts;
integer reset_edges;
integer masked_first [0:1];
wire half_phase = local_rst && !rst && enable;
reg previous_bit;
wire expected_bit = tx_phase[31] ? (alternating ? tx_bit : prbs[0]) : previous_bit;
function [21:0] magnitude;
    input signed [21:0] value;
    begin magnitude = value < 0 ? -value : value; end
endfunction
genvar g;
generate for (g=0; g<2; g=g+1) begin: loops
    DTTL_Top dut (
        .clk(clk), .rst(g == 0 ? rst : local_rst),
        .restart_half_phase(g == 0 ? 1'b0 : half_phase),
        .update_en(enable && !(g == 0 ? rst : local_rst)),
        .MODE(mode), .data_in(data_in), .entire_en(valid[g]),
        .entire_out(entire[g]), .middle_out(middle[g]),
        .NCO_out(nco[g]), .FCW_out(fcw[g])
    );
end endgenerate
DTTL_Supervisor supervisor (
    .clk(clk), .rst(rst), .enable(enable), .mode(mode),
    .symbol_valid(valid[1]), .entire_in(entire[1]), .middle_in(middle[1]),
    .dttl_rst(local_rst), .restart_pulse(restart)
);
always @(posedge clk) begin
    if (rst) begin
        tx_phase <= 32'h80000000;
        prbs <= 16'hace1;
        tx_bit <= 0;
        previous_bit <= 1;
    end else if (enable) begin
        tx_phase <= tx_sum[31:0];
        if (tx_sum[32]) begin
            previous_bit <= alternating ? tx_bit : prbs[0];
            tx_bit <= ~tx_bit;
            prbs <= {prbs[14:0],prbs[15]^prbs[13]^prbs[12]^prbs[10]};
        end
    end
end
always @(posedge clk) begin
    // Observe the reset inputs before NBA updates can release local_rst.
    if (rst) begin
        reset_edges = 0;
    end else if (local_rst && enable) begin
        reset_edges = reset_edges+1;
        #1;
        if (nco[1] !== 32'h80000001)
            $fatal(1,"Half-cycle seed must be held on every local reset edge");
    end
end
always @(posedge clk) begin
    #1;
    if (enable && !rst) begin
        if (loops[0].dut.integrator_entire_en && !loops[0].dut.first_symbol_seen) begin
            if (valid[0]) $fatal(1,"Control first integration leaked");
            masked_first[0]=masked_first[0]+1;
        end
        if (loops[1].dut.integrator_entire_en && !loops[1].dut.first_symbol_seen) begin
            if (valid[1]) $fatal(1,"Supervised first integration leaked");
            masked_first[1]=masked_first[1]+1;
        end
        cycle = cycle + 1;
        if (restart) begin
            pulses = pulses + 1;
            if (symbols[1]>(alternating ? 128 : 448)) late_restarts=late_restarts+1;
            $display("RESTART cycle=%0d count=%0d E=%0d M=%0d",cycle,pulses,supervisor.entire_sum,supervisor.middle_sum);
        end
        for (j=0;j<2;j=j+1) if (valid[j]) begin
            symbols[j] = symbols[j]+1;
            esum[j] = esum[j] + magnitude(entire[j]);
            msum[j] = msum[j] + magnitude(middle[j]);
            phase_error[j] = tx_phase-nco[j];
            if (phase_error[j] > 32'h70000000 && phase_error[j] < 32'h90000000)
                half_symbols[j] = half_symbols[j]+1;
            if (symbols[j]>(alternating ? 128 : 448)) begin
                if (phase_error[j] < 32'h0ccccccd || phase_error[j] > 32'hf3333333)
                    good_symbols[j] = good_symbols[j]+1;
                // Use the TX symbol at the nominal interval midpoint. This covers
                // both early (phase near 1T) and late (phase near 0T) recovery.
                if ((entire[j]>=0) !== expected_bit) errors[j]=errors[j]+1;
            end
            $fdisplay(f,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",scenario,cycle,j,symbols[j],entire[j],middle[j],phase_error[j],fcw[j],restart,local_rst);
            if (symbols[j]%32 == 0) begin
                $display("WINDOW loop=%0d symbol=%0d E=%0d M=%0d phase=%h fcw=%0d",j,symbols[j],esum[j],msum[j],phase_error[j],fcw[j]);
                esum[j]=0; msum[j]=0;
            end
        end
    end
end
initial begin
    f=$fopen("halfcycle_symbols.csv","w");
    $fdisplay(f,"scenario,cycle,loop,symbol,entire,middle,phase_error,fcw,restart,reset");
    for (scenario=0;scenario<2;scenario=scenario+1) begin
        rst=1; enable=0; alternating=(scenario==0); cycle=0; pulses=0;
        late_restarts=0;
        for (j=0;j<2;j=j+1) begin
            symbols[j]=0; esum[j]=0; msum[j]=0;
            half_symbols[j]=0; good_symbols[j]=0; errors[j]=0;
            masked_first[j]=0;
        end
        repeat (20) @(negedge clk);
        rst=0; enable=1;
        wait (symbols[1] >= (alternating ? 192 : 512));
        repeat (4) @(negedge clk);
        if (alternating) begin
            // Saturated PD can now escape without supervisor assistance.
            // Verify the half-cycle starting condition and recovery of BOTH paths.
            if (half_symbols[0]<1 || half_symbols[1]<1)
                $fatal(1,"Both paths must start near the half-cycle phase");
            if (pulses>1 || late_restarts!=0 || good_symbols[1]!=64 || errors[1]!=0 || good_symbols[0]!=64 || errors[0]!=0)
                $fatal(1,"Half-cycle recovery failed: good=%0d errors=%0d restarts=%0d",good_symbols[1],errors[1],pulses);
            $display("HALFCYCLE_RECOVERY_PASS: control_half=%0d supervised_half=%0d last64_good=%0d errors=%0d restarts=%0d",half_symbols[0],half_symbols[1],good_symbols[1],errors[1],pulses);
        end else begin
            if (pulses!=1 || late_restarts!=0 || good_symbols[1]!=64 || errors[1]!=0)
                $fatal(1,"PRBS recovery failed: good=%0d errors=%0d restarts=%0d",good_symbols[1],errors[1],pulses);
            $display("PRBS_RECOVERY_PASS: last64_phase_within_0.05T=%0d errors=%0d restarts=%0d control_good=%0d",good_symbols[1],errors[1],pulses,good_symbols[0]);
        end
        if (reset_edges!=2*pulses || masked_first[0]!=1 || masked_first[1]!=pulses+1)
            $fatal(1,"Reset length/first-symbol suppression failed: edges=%0d masked=%0d/%0d",reset_edges,masked_first[0],masked_first[1]);
        $display("RESET_AND_FIRST_SYMBOL_PASS: reset_edges=%0d masked=%0d/%0d",reset_edges,masked_first[0],masked_first[1]);
        @(negedge clk);
    end
    $fclose(f);
    $display("DTTL_HALFCYCLE_TEST_PASS");
    $finish;
end
initial begin
    #5000000;
    $fatal(1,"Half-cycle simulation timeout");
end
endmodule
