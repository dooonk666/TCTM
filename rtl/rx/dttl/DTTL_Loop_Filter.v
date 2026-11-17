`timescale 1ns / 1ps

module DTTL_Loop_Filter(
    clk,
    rst,
    PD_en,
    PD_in,
    Ceq,
    FCW_en,
    FCW_modifying
);

parameter PD_WIDTH = 17;
parameter CEQ_WIDTH = 23;
parameter FCW_MOD_WIDTH = 26;

parameter LOOP_FRAC = 15;
parameter CEQ_FRAC = 4;

localparam PD_DELTA_WIDTH = PD_WIDTH + 1;
localparam MULT_WIDTH = PD_DELTA_WIDTH + CEQ_WIDTH;
localparam TOTAL_FRAC = LOOP_FRAC + CEQ_FRAC;

input clk;
input rst;
input PD_en;
input signed [PD_WIDTH-1:0] PD_in;
input signed [CEQ_WIDTH-1:0] Ceq;

output reg FCW_en;
output reg signed [FCW_MOD_WIDTH-1:0] FCW_modifying;

reg signed [PD_WIDTH-1:0] PD_last;
wire signed [PD_DELTA_WIDTH-1:0] PD_delta;

reg PD_en_d1;
reg PD_en_d2;
reg PD_en_d3;

wire signed [MULT_WIDTH-1:0] Mult_result;

reg signed [MULT_WIDTH:0] mult_abs;
reg signed [MULT_WIDTH:0] mult_round;
reg signed [MULT_WIDTH:0] fcw_calc;


// PD(k)-PD(k-1)
assign PD_delta = $signed({PD_in[PD_WIDTH-1], PD_in}) - $signed({PD_last[PD_WIDTH-1], PD_last});

// 保存上一笔PD
always @(posedge clk) begin
    if(rst)
        PD_last <= {PD_WIDTH{1'b0}};
    else if(PD_en)
        PD_last <= PD_in;
end


// MULT_MACRO latency = 3，对应延迟有效信号
always @(posedge clk) begin
    if(rst) begin
        PD_en_d1 <= 1'b0;
        PD_en_d2 <= 1'b0;
        PD_en_d3 <= 1'b0;
    end
    else begin
        PD_en_d1 <= PD_en;
        PD_en_d2 <= PD_en_d1;
        PD_en_d3 <= PD_en_d2;
    end
end


// Q19 -> integer，正负数都做四舍五入
always @(*) begin
    if(Mult_result >= 0) begin
        mult_abs   = {1'b0, Mult_result};
        mult_round = mult_abs + ({{MULT_WIDTH{1'b0}},1'b1} <<< (TOTAL_FRAC-1));
        fcw_calc   = mult_round >>> TOTAL_FRAC;
    end
    else begin
        mult_abs   = -$signed({Mult_result[MULT_WIDTH-1], Mult_result});
        mult_round = mult_abs + ({{MULT_WIDTH{1'b0}},1'b1} <<< (TOTAL_FRAC-1));
        fcw_calc   = -(mult_round >>> TOTAL_FRAC);
    end
end


always @(posedge clk) begin
    if(rst) begin
        FCW_en        <= 1'b0;
        FCW_modifying <= {FCW_MOD_WIDTH{1'b0}};
    end
    else begin
        FCW_en <= PD_en_d3;

        if(PD_en_d3)
            FCW_modifying <= fcw_calc[FCW_MOD_WIDTH-1:0];
    end
end



// 23 x 18，单个DSP48即可完成
MULT_MACRO #(
    .DEVICE("7SERIES"),
    .LATENCY(3),
    .WIDTH_A(CEQ_WIDTH),
    .WIDTH_B(PD_DELTA_WIDTH)
)
MULT_MACRO_inst (
    .P(Mult_result),
    .A(Ceq),
    .B(PD_delta),
    .CE(1'b1),
    .CLK(clk),
    .RST(rst)
);

endmodule
