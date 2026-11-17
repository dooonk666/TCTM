`timescale 1ns / 1ps

// Real DTTL RTL + real Divider Generator functional netlist.
// Injection substitutes only monitor measurements to deterministically request
// a restart. NCO, integrator, PD, divider and loop filter remain real modules.
module tb_DTTL_Restart;
reg clk = 1'b0;
always #5 clk = ~clk;
reg rst = 1'b1;
reg enable = 1'b0;
reg [1:0] mode = 2'd3;
reg inject = 1'b0;
reg inject_valid = 1'b0;
wire dttl_rst;
wire restart_pulse;
wire raw_valid;
wire signed [21:0] entire_out;
wire signed [21:0] middle_out;
wire pd_en;
wire signed [16:0] pd_out;
wire fcw_en;
wire signed [25:0] fcw_modifying;
wire [24:0] fcw_out;
wire [31:0] nco_out;
wire trig;
integer selected_mode;
integer symbol_count;
integer restart_count = 0;
integer i;

DTTL_Supervisor supervisor (
    .clk(clk), .rst(rst), .enable(enable), .mode(mode),
    .symbol_valid(inject ? inject_valid : raw_valid),
    .entire_in(inject ? 22'sd100 : entire_out),
    .middle_in(inject ? 22'sd200 : middle_out),
    .dttl_rst(dttl_rst), .restart_pulse(restart_pulse)
);

DTTL_Top dttl (
    .clk(clk), .rst(dttl_rst), .update_en(enable && !dttl_rst),
    .restart_half_phase(dttl_rst && !rst && enable),
    .MODE(mode), .data_in(11'sd100),
    .entire_en(raw_valid), .entire_out(entire_out), .middle_out(middle_out),
    .PD_en(pd_en), .PD_out(pd_out), .FCW_update_en(fcw_en),
    .FCW_modifying(fcw_modifying), .FCW_out(fcw_out),
    .NCO_out(nco_out), .trig(trig)
);

always @(posedge clk)
    if (!rst && restart_pulse)
        restart_count = restart_count + 1;

task check;
    input condition;
    input [8*160-1:0] message;
    begin
        if (condition !== 1'b1)
            $fatal(1, "FAIL: mode=%0d %0s at %0t", mode, message, $time);
    end
endtask

task tick;
    begin
        @(posedge clk);
        #1;
    end
endtask

task check_cleared;
    begin
        check(nco_out == 32'h80000001 && fcw_out == dttl.FCW_basic,
              "local restart must load half-cycle phase and nominal FCW");
        check(!raw_valid && entire_out == 0 && middle_out == 0,
              "integrator outputs and valid must reset");
        check(dttl.DTTL_Integrator_inst.entire_acc == 0 &&
              dttl.DTTL_Integrator_inst.middle_acc == 0 &&
              dttl.DTTL_Integrator_inst.sample_count == 0 &&
              dttl.DTTL_Integrator_inst.w_pos == 0,
              "accumulators and delay-memory validity must reset");
        check(!dttl.DTTL_PD_inst.have_last &&
              dttl.DTTL_PD_inst.ref_magnitude == 0 &&
              !dttl.DTTL_PD_inst.div_input_valid && !pd_en && pd_out == 0,
              "PD history, valid and output must reset");
        check(dttl.DTTL_Loop_Filter_inst.PD_last == 0 &&
              !dttl.DTTL_Loop_Filter_inst.PD_en_d1 &&
              !dttl.DTTL_Loop_Filter_inst.PD_en_d2 &&
              !dttl.DTTL_Loop_Filter_inst.PD_en_d3 &&
              !fcw_en && fcw_modifying == 0,
              "loop-filter history and pipeline must reset");
        check(supervisor.cnt == 0 && supervisor.entire_sum == 0 &&
              supervisor.middle_sum == 0, "monitor statistics must reset");
    end
endtask

initial begin
    // Let Xilinx glbl.GSR finish before exercising the design.
    repeat (15) tick;
    for (selected_mode = 1; selected_mode <= 3; selected_mode = selected_mode + 1) begin
        @(negedge clk);
        rst = 1'b1;
        enable = 1'b0;
        mode = selected_mode;
        inject = 1'b0;
        inject_valid = 1'b0;
        repeat (4) tick;
        @(negedge clk);
        rst = 1'b0;
        enable = 1'b1;

        // A real 32-symbol healthy window must not request a restart.
        wait (supervisor.cnt == 6'd32);
        tick;
        check(!restart_pulse && supervisor.cnt == 0,
              "real healthy window must complete without restarting");
        $display("PASS: mode %0d real DTTL healthy window", mode);

        // Inject 32 bad measurements while the real PD divider is in flight.
        @(negedge clk);
        inject = 1'b1;
        inject_valid = 1'b1;
        repeat (32) tick;
        check(supervisor.cnt == 32 && !restart_pulse,
              "injected window must accumulate all 32 samples");
        check(nco_out != 1 && dttl.DTTL_Integrator_inst.sample_count != 0,
              "real DTTL must be running before restart");
        @(negedge clk);
        inject_valid = 1'b0;
        tick;
        check(restart_pulse && dttl_rst, "bad measurements must request restart");

        tick;
        check(!restart_pulse && dttl_rst, "second reset cycle must remain asserted");
        check_cleared;
        tick;
        check(!dttl_rst, "local reset must release automatically");
        check_cleared;
        @(negedge clk);
        inject = 1'b0;

        // Old divider results must not leak into the newly started loop.
        repeat (64) begin
            tick;
            check(!pd_en && !fcw_en && !restart_pulse,
                  "old divider results must not reappear after local reset");
        end
        check(nco_out != 1 && dttl.DTTL_Integrator_inst.sample_count != 0,
              "NCO and integrator must resume after reset");

        symbol_count = 0;
        while (symbol_count < 2) begin
            tick;
            if (raw_valid)
                symbol_count = symbol_count + 1;
            check(!restart_pulse, "healthy resumed DTTL must not restart again");
        end
        $display("PASS: mode %0d local reset clears real DTTL and symbols resume", mode);
    end
    check(restart_count == 3, "one restart per mode");
    $display("DTTL_RESTART_TEST_PASS");
    $finish;
end

initial begin
    #2000000;
    $fatal(1, "timeout");
end
endmodule
