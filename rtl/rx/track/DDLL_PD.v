`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/09/28 11:25:05
// Design Name: 
// Module Name: DDLL_PD
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module DDLL_PD(
    clk,
    rst,
    data_en,
    data_E_i,
    data_E_q,
    data_L_i,
    data_L_q,
    PD_out_en,
    PD_out
);

parameter INPUT_WIDTH = 18;
parameter OUTPUT_WIDTH = 10;
localparam DIVISOR_WIDTH = 24;
localparam DIVISOR_MSB_EXTEND = DIVISOR_WIDTH - INPUT_WIDTH - 3;

input clk;
input rst;
input data_en;
input [INPUT_WIDTH-1:0] data_E_i;
input [INPUT_WIDTH-1:0] data_E_q;
input [INPUT_WIDTH-1:0] data_L_i;
input [INPUT_WIDTH-1:0] data_L_q;
output reg PD_out_en;
output reg [OUTPUT_WIDTH-1:0] PD_out;

wire abs_valid;
wire [INPUT_WIDTH:0] E_abs, L_abs;
reg divide_rdy;
reg [INPUT_WIDTH+2:0] SUM, SUB;

wire s_axis_divisor_tready;
wire s_axis_dividend_tready;
wire div_result_en;
wire [55:0] div_result;
wire div_by_0_flag;

wire [24:0] QUOTIENT;
wire [16:0] REMAINDER;

assign QUOTIENT = div_result[49:24];
assign REMAINDER = div_result[17:0];

ABS_Calc #(
    .INPUT_WIDTH(INPUT_WIDTH))
E_abs_calc (
    .clk(clk),
    .rst(rst),
    .data_en(data_en),
    .I_data(data_E_i),
    .Q_data(data_E_q),
    .abs_en(abs_valid),
    .abs(E_abs)
);

ABS_Calc #(
    .INPUT_WIDTH(INPUT_WIDTH))
L_abs_calc (
    .clk(clk),
    .rst(rst),
    .data_en(data_en),
    .I_data(data_L_i),
    .Q_data(data_L_q),
    .abs_en(),
    .abs(L_abs)
);

always @(posedge clk ) begin
    if(rst)begin
        SUM <= {(INPUT_WIDTH+3){1'b0}};
        SUB <= {(INPUT_WIDTH+3){1'b0}};
    end
    else if(abs_valid)begin
        SUM <= {2'b00,E_abs} + {2'b00,L_abs};
        SUB <= {2'b00,E_abs} - {2'b00,L_abs};
    end
end

always @(posedge clk)begin
    if(rst) divide_rdy <= 1'b0;
    else divide_rdy <= abs_valid;
end

always @(posedge clk)begin
    if(rst) PD_out <= {OUTPUT_WIDTH{1'b0}};
    else if(div_result_en)begin
        if(div_by_0_flag) PD_out <= {OUTPUT_WIDTH{1'b0}};
        else PD_out <= QUOTIENT[OUTPUT_WIDTH-1:0];
    end
end

always @(posedge clk ) begin
    if(rst) PD_out_en <= 1'b0;
    else PD_out_en <= div_result_en;
end

div_26by18 PD_divider (
  .aclk(clk),                                      // input wire aclk
  .aresetn(~rst),                                // input wire aresetn
  .s_axis_divisor_tvalid(divide_rdy),    // input wire s_axis_divisor_tvalid
  .s_axis_divisor_tready(s_axis_divisor_tready),    // output wire s_axis_divisor_tready
  .s_axis_divisor_tdata({{DIVISOR_MSB_EXTEND{1'b0}},SUM}),      // input wire [23 : 0] s_axis_divisor_tdata
  .s_axis_dividend_tvalid(divide_rdy),  // input wire s_axis_dividend_tvalid
  .s_axis_dividend_tready(s_axis_dividend_tready),  // output wire s_axis_dividend_tready
  .s_axis_dividend_tdata({{DIVISOR_MSB_EXTEND{SUB[INPUT_WIDTH+2]}},SUB,8'd0}),    // input wire [31 : 0] s_axis_dividend_tdata
  .m_axis_dout_tvalid(div_result_en),          // output wire m_axis_dout_tvalid
  .m_axis_dout_tuser(div_by_0_flag),            // output wire [0 : 0] m_axis_dout_tuser
  .m_axis_dout_tdata(div_result)            // output wire [55 : 0] m_axis_dout_tdata
);


endmodule