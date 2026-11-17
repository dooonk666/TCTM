`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/10/20 15:04:06
// Design Name: 
// Module Name: PLL_BPSK_PD
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


module PLL_BPSK_PD(
    clk,
    rst,
    signal_en,
    signal_i,
    signal_q,
    PD_en,
    PD
);

parameter INPUT_WIDTH = 19;
localparam OUTPUT_WIDTH = 8;
reg[8:0] cnt = 9'd0;

input clk;
input rst;
input signal_en;
input [INPUT_WIDTH-1:0] signal_i;
input [INPUT_WIDTH-1:0] signal_q;
output PD_en;
output [OUTPUT_WIDTH-1:0] PD;

wire signal_abs_en;
wire [INPUT_WIDTH:0] signal_abs;

reg [INPUT_WIDTH-1:0] PD_raw;
wire div_by_0_index;
wire PD_result_en;
wire [55:0] PD_result;
localparam [INPUT_WIDTH:0] VALUE_INIT = 20000;
reg [INPUT_WIDTH:0] value;

always @(posedge clk) begin
    if(rst) PD_raw <= {INPUT_WIDTH{1'b0}};
    else if(signal_en)begin
        case(signal_i[INPUT_WIDTH-1])
        1'b0: PD_raw <= signal_q;
        1'b1: PD_raw <= ~signal_q;
        endcase
    end
end

ABS_Calc #(
    .INPUT_WIDTH(INPUT_WIDTH))
Input_Abs_Calc (
    .clk(clk),
    .rst(rst),
    .data_en(signal_en),
    .I_data(signal_i),
    .Q_data(signal_q),
    .abs_en(signal_abs_en),
    .abs(signal_abs)
);

always@(posedge clk) begin
    if(rst) begin
        value <= VALUE_INIT;
    end
    else begin 
        if (cnt == 0) begin
             value <= VALUE_INIT;
         end
        else if (value <= signal_abs) value <= signal_abs;
        else value <= value;
    end
  end
    
always @(posedge clk) begin
    if(rst)
        cnt <= 0;
    else begin
        if(signal_en) begin
            cnt <= cnt + 1;
        end
    end
end

div_26by21 PD_noraml_calc (      // 被除数额外右�?1bit，相当于除以2
  .aclk(clk),                                      // input wire aclk
  .s_axis_divisor_tvalid(signal_abs_en),    // input wire s_axis_divisor_tvalid
  .s_axis_divisor_tdata({{(24-INPUT_WIDTH-1){1'b0}},value}),      // input wire [23 : 0] s_axis_divisor_tdata
  .s_axis_dividend_tvalid(signal_abs_en),  // input wire s_axis_dividend_tvalid
  .s_axis_dividend_tdata({{(33-OUTPUT_WIDTH-INPUT_WIDTH){PD_raw[INPUT_WIDTH-1]}},PD_raw,{(OUTPUT_WIDTH-1){1'b0}}}),    // input wire [31 : 0] s_axis_dividend_tdata
  .m_axis_dout_tuser(div_by_0_index),            // output wire [0 : 0] m_axis_dout_tuser
  .m_axis_dout_tvalid(PD_result_en),          // output wire m_axis_dout_tvalid
  .m_axis_dout_tdata(PD_result)            // output wire [55 : 0] m_axis_dout_tdata
);

assign PD_en = PD_result_en;
assign PD = div_by_0_index ? {OUTPUT_WIDTH{1'b0}} : PD_result[24+:OUTPUT_WIDTH];

endmodule
