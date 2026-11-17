`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/10/21 15:40:50
// Design Name: 
// Module Name: PLL_NCO
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


module PLL_NCO(
    clk,
    rst,
    sample_in_en,
    sample_in_i,
    sample_in_q,
    FCW_preset_en,
    FCW_preset,
    FCW_en,
    FCW,
    sample_out_en,
    sample_out_i,
    sample_out_q
    );

parameter OUTPUT_WIDTH = 8;
parameter CUTOFF_SHIFT_RIGHT = 2;

input clk;
input rst;
input sample_in_en;
input [11:0] sample_in_i;
input [11:0] sample_in_q;
input FCW_preset_en;
input [35:0] FCW_preset;
input FCW_en;
input [35:0] FCW;
output reg sample_out_en;
output reg [OUTPUT_WIDTH-1:0] sample_out_i;
output reg [OUTPUT_WIDTH-1:0] sample_out_q;

reg [35:0] FCW_preset_reg;
reg [35:0] FCW_reg;
reg [35:0] NCO_incr;
reg [35:0] NCO;
wire [31:0] wave;
wire [15:0] dds_in_i, dds_in_q;
wire [15:0] wave_in_i, wave_in_q;
wire DDS_result_valid;
wire [47:0] DDS_result;
wire [20:0] DDS_result_i;
wire [20:0] DDS_result_q;

assign dds_in_i = {{4{sample_in_i[11]}},sample_in_i};
assign dds_in_q = {{4{sample_in_q[11]}},sample_in_q};
assign wave_in_i = {{7{wave[8]}},wave[8:0]};
assign wave_in_q = ~{{7{wave[24]}},wave[24:16]} + 1'b1;
assign DDS_result_i = DDS_result[20:0];
assign DDS_result_q = DDS_result[44:24];

always @(posedge clk) begin
    if(rst) FCW_preset_reg <= {36{1'b0}};
    else if(FCW_preset_en) FCW_preset_reg <= FCW_preset;
end

always @(posedge clk) begin
    if(rst) FCW_reg <= {36{1'b0}};
    else if(FCW_en) FCW_reg <= FCW;
end

always @(posedge clk) begin
    if(rst) NCO_incr <= {36{1'b0}};
    else NCO_incr <= FCW_preset_reg + FCW_reg;
end

always @(posedge clk) begin
    if(rst) NCO <= {36{1'b0}};
    else if(sample_in_en) NCO <= NCO + NCO_incr;
end

//Carrier_Wave_ROM Wave_Neg_Freq (
//  .clka(clk),    // input wire clka
//  .ena(sample_in_en),      // input wire ena
//  .addra(NCO[35-:10]),  // input wire [9 : 0] addra
//  .douta(wave)  // output wire [17 : 0] douta
//);

Wave_Generator Wave_Neg_Freq (
  .aclk(clk),                                // input wire aclk
  .s_axis_phase_tvalid(sample_in_en),  // input wire s_axis_phase_tvalid
  .s_axis_phase_tdata({6'd0,NCO[35],NCO[35],NCO[35-:24]}),    // input wire [31 : 0] s_axis_phase_tdata
  .m_axis_dout_tvalid(),    // output wire m_axis_dout_tvalid
  .m_axis_dout_tdata(wave)      // output wire [31 : 0] m_axis_dout_tdata
);

cmpy_12x9 DDS (
  .aclk(clk),                              // input wire aclk
  .s_axis_a_tvalid(sample_in_en),        // input wire s_axis_a_tvalid
  .s_axis_a_tdata({dds_in_q,dds_in_i}),          // input wire [31 : 0] s_axis_a_tdata
  .s_axis_b_tvalid(sample_in_en),        // input wire s_axis_b_tvalid
  .s_axis_b_tdata({wave_in_q,wave_in_i}),          // input wire [31 : 0] s_axis_b_tdata
  .m_axis_dout_tvalid(DDS_result_valid),  // output wire m_axis_dout_tvalid
  .m_axis_dout_tdata(DDS_result)    // output wire [47 : 0] m_axis_dout_tdata
);

always @(posedge clk) begin
    if(rst) sample_out_en <= 1'b0;
    else sample_out_en <= DDS_result_valid;
end

always @(posedge clk) begin
    if(rst) sample_out_i <= {OUTPUT_WIDTH{1'b0}};
    else if(DDS_result_valid) sample_out_i <= DDS_result_i[(20-CUTOFF_SHIFT_RIGHT)-:OUTPUT_WIDTH];
end

always @(posedge clk) begin
    if(rst) sample_out_q <= {OUTPUT_WIDTH{1'b0}};
    else if(DDS_result_valid) sample_out_q <= DDS_result_q[(20-CUTOFF_SHIFT_RIGHT)-:OUTPUT_WIDTH];
end

endmodule
