`timescale 1ns / 1ps

// End-to-end PD tests using the real Divider Generator functional netlist.
// No forced quotient or substituted divider model.
module tb_DTTL_PD_Saturation;
reg clk=0;
always #5 clk=~clk;
reg rst=1;
reg entire_en=0;
reg signed [21:0] entire_in=0;
reg signed [21:0] middle_in=0;
wire pd_en;
wire signed [16:0] pd_out;
integer expected [0:255];
integer head=0;
integer tail=0;
integer matched_count=0;
integer wait_cycles;
reg negative_symbol=0;

DTTL_PD dut (
    .clk(clk), .rst(rst), .entire_en(entire_en),
    .entire_in(entire_in), .middle_in(middle_in),
    .PD_en(pd_en), .PD_out(pd_out)
);

always @(posedge clk) begin
    #1;
    if (!rst && pd_en) begin
        if (head>=tail)
            $fatal(1,"Unexpected or stale PD output %0d",pd_out);
        if ($signed(pd_out) !== expected[head])
            $fatal(1,"Sample %0d: expected %0d, got %0d",head,expected[head],pd_out);
        $display("MATCH sample=%0d expected=%0d actual=%0d",head,expected[head],pd_out);
        head=head+1;
        matched_count=matched_count+1;
    end
end

task reset_dut;
    begin
        @(negedge clk);
        rst=1; entire_en=0;
        head=0; tail=0; negative_symbol=0;
        repeat (4) @(posedge clk);
        @(negedge clk);
        rst=0;
    end
endtask

task sample;
    input signed [21:0] e;
    input signed [21:0] m;
    input integer result;
    begin
        @(negedge clk);
        expected[tail]=result;
        tail=tail+1;
        entire_en=1; entire_in=e; middle_in=m;
    end
endtask

task quotient;
    input integer q;
    input integer result;
    begin
        // With ref=32768, round(|Middle|*32768/ref) is exactly |Middle|.
        // Alternate Entire signs and choose Middle's sign for the desired q.
        negative_symbol=~negative_symbol;
        if (negative_symbol)
            sample(-22'sd32768,-q,result);
        else
            sample(22'sd32768,q,result);
    end
endtask

task drain;
    begin
        @(negedge clk);
        entire_en=0;
        wait_cycles=0;
        while (head<tail && wait_cycles<200) begin
            @(posedge clk); #2;
            wait_cycles=wait_cycles+1;
        end
        if (head!=tail) $fatal(1,"Missing outputs: matched %0d of %0d",head,tail);
        repeat (5) begin
            @(posedge clk); #2;
            if (pd_en) $fatal(1,"Duplicated output after drain");
        end
    end
endtask

initial begin
    repeat (15) @(negedge clk); // Let Xilinx glbl.GSR release.
    reset_dut;
    sample(22'sd32768,0,0); // First symbol always gives zero PD.
    quotient(-65537,-65536);
    quotient(-65536,-65536);
    quotient(-65535,-65535);
    quotient(-32768,-32768);
    quotient(-1,-1);
    quotient(0,0);
    quotient(1,1);
    quotient(32768,32768);
    quotient(65534,65534);
    quotient(65535,65535);
    quotient(65536,65535);
    quotient(65537,65535);
    quotient(98304,65535);   // +3 used to wrap to -1 in Q15.
    quotient(131072,65535);  // +4 used to wrap to zero.
    quotient(-98304,-65536);
    quotient(-131072,-65536);
    // Same sign and Entire=0 must retain the existing zero-PD behavior.
    sample(entire_in,22'sd100000,0);
    sample(0,22'sd100000,0);
    drain;
    $display("PASS: both boundaries, one-step overflow, +/-3 and +/-4, unchanged in-range values");

    reset_dut;
    sample(1,0,0);
    // ref=1 and minimum signed Middle generate +/-2^36 in the real divider.
    sample(-1,-22'sd2097152,65535);
    sample(1,-22'sd2097152,-65536);
    sample(-1,22'sd2097151,-65536);
    sample(1,22'sd2097151,65535);
    drain;
    $display("PASS: wide signed quotients and minimum signed Middle");

    reset_dut;
    sample(22'sd32768,0,0);
    quotient(131072,65535);
    @(negedge clk); entire_en=0;
    repeat (3) @(posedge clk);
    reset_dut; // Flush both pending divider transactions.
    repeat (80) begin
        @(posedge clk); #2;
        if (pd_en) $fatal(1,"Stale divider result after reset");
    end
    sample(22'sd32768,0,0);
    quotient(32768,32768);
    drain;
    $display("PASS: reset flush and valid/data alignment after restart");
    if (matched_count!=26) $fatal(1,"Unexpected matched sample count %0d",matched_count);
    $display("DTTL_PD_SATURATION_TEST_PASS matched_count=%0d",matched_count);
    $finish;
end
initial begin
    #100000;
    $fatal(1,"PD saturation test timeout");
end
endmodule
