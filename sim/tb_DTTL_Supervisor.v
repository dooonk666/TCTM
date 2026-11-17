`timescale 1ns / 1ps

// Standalone tests: no multiplier, no next signals, no DTTL IP required.
module tb_DTTL_Supervisor;
reg clk = 1'b0;
always #5 clk = ~clk;
reg rst = 1'b1;
reg enable = 1'b0;
reg symbol_valid = 1'b0;
reg signed [21:0] entire_in = 22'sd0;
reg signed [21:0] middle_in = 22'sd0;
wire dttl_rst;
wire restart_pulse;
integer i;
integer pulse_count = 0;

DTTL_Supervisor #(.MIN_SUM_MAG(29'd100)) dut (
    .clk(clk), .rst(rst), .enable(enable), .mode(2'd3),
    .symbol_valid(symbol_valid), .entire_in(entire_in),
    .middle_in(middle_in), .dttl_rst(dttl_rst),
    .restart_pulse(restart_pulse)
);

always @(posedge clk)
    if (!rst && restart_pulse)
        pulse_count = pulse_count + 1;

task check;
    input condition;
    input [8*160-1:0] message;
    begin
        if (condition !== 1'b1)
            $fatal(1, "FAIL: %0s at %0t", message, $time);
    end
endtask

task step;
    input valid;
    input signed [21:0] e;
    input signed [21:0] m;
    begin
        @(negedge clk);
        symbol_valid = valid;
        entire_in = e;
        middle_in = m;
        @(posedge clk);
        #1;
    end
endtask

task reset_test;
    begin
        @(negedge clk);
        rst = 1'b1;
        enable = 1'b1;
        symbol_valid = 1'b0;
        repeat (3) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;
        @(posedge clk);
        #1;
        check(!dttl_rst && !restart_pulse && dut.cnt == 0,
              "reset must release with empty statistics");
    end
endtask

task finish_window;
    input expect_bad;
    begin
        check(dut.cnt == 32 && !restart_pulse,
              "all 32 symbols must be accumulated before comparison");
        step(0, 0, 0);
        check(restart_pulse === expect_bad, "window classification");
        if (expect_bad) begin
            check(dttl_rst, "restart must assert local reset immediately");
            step(0, 0, 0);
            check(!restart_pulse && dttl_rst && dut.cnt == 0,
                  "pulse must be one cycle, reset must remain for second cycle");
            step(0, 0, 0);
            check(!dttl_rst && dut.entire_sum == 0 && dut.middle_sum == 0,
                  "local reset must release after two cycles");
        end
        else begin
            check(!dttl_rst && dut.cnt == 0, "healthy window must clear without reset");
        end
    end
endtask

task window;
    input signed [21:0] e;
    input signed [21:0] m;
    input integer gap;
    input expect_bad;
    integer j;
    integer k;
    begin
        for (j = 0; j < 32; j = j + 1) begin
            step(1, e, m);
            check(!restart_pulse, "must not restart before completed window is checked");
            if (j < 31)
                for (k = 0; k < gap; k = k + 1) begin
                    step(0, -22'sd2097152, 22'sd2097151);
                    check(dut.cnt == j + 1, "invalid cycles must not advance count");
                end
        end
        finish_window(expect_bad);
    end
endtask

initial begin
    reset_test;
    window(1000, 100, 2, 0);
    $display("PASS: healthy window, invalid cycles ignored");
    window(-100, 200, 0, 1);
    window(-1000, -100, 1, 0);
    $display("PASS: signed magnitudes, bad window and recovery");
    window(100, 150, 0, 0);
    window(100, 151, 0, 1);
    $display("PASS: exact 1.5 boundary and above-boundary classification");
    window(0, 0, 0, 0);
    window(1, 2, 0, 0);
    $display("PASS: zero input and configured low-magnitude floor");
    window(-22'sd2097152, -22'sd2097152, 0, 0);
    step(0, -22'sd2097152, -22'sd2097152);
    check(dut.entire_abs == 22'd2097152, "most-negative absolute value");
    $display("PASS: maximum magnitudes do not overflow window arithmetic");

    // The 32nd sample alone changes a healthy prefix into a bad window.
    for (i = 0; i < 31; i = i + 1)
        step(1, 100, 100);
    step(1, 0, 2000);
    check(dut.entire_sum == 3100 && dut.middle_sum == 5100,
          "32nd sample must be included");
    finish_window(1);

    // An apparently bad prefix must not trigger before the 32nd sample.
    for (i = 0; i < 31; i = i + 1) begin
        step(1, 100, 1000);
        check(!restart_pulse, "partial bad window must not restart");
    end
    step(1, 100000, 0);
    finish_window(0);
    $display("PASS: full-window decisions include sample 32 and ignore partial windows");

    for (i = 1; i <= 96; i = i + 1) begin
        step(1, -100, 10);
        check(!restart_pulse, "continuous healthy stream must not restart");
        if (i == 33 || i == 65)
            check(dut.cnt == 1 && dut.entire_sum == 100 && dut.middle_sum == 10,
                  "sample after window boundary must not be lost");
    end
    finish_window(0);
    $display("PASS: three continuous windows without losing samples 33 or 65");

    repeat (7) step(1, 100, 10);
    @(negedge clk);
    enable = 1'b0;
    @(posedge clk);
    #1;
    check(dttl_rst && dut.cnt == 0 && !restart_pulse,
          "disable must reset immediately even with valid input");
    @(negedge clk);
    enable = 1'b1;
    symbol_valid = 1'b0;
    @(posedge clk);
    #1;
    window(100, 200, 0, 1);
    check(pulse_count == 4, "exactly four bad windows must create four pulses");
    $display("PASS: disable/re-enable and repeated restart");
    $display("DTTL_SUPERVISOR_TEST_PASS");
    $finish;
end

initial begin
    #100000;
    $fatal(1, "timeout");
end
endmodule
