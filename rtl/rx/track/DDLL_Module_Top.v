`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/10/13 16:29:15
// Design Name: 
// Module Name: DDLL_Module_Top
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


module DDLL_Module_Top(
    clk,
    rst,
    Enable,
    Coherent_length_PD,
    Coherent_length_I,
    Chip_osr,
    C1,
    C2,
    Poly1,
    Poly2,
    init_Poly1,
    init_Poly2,
    sample_in_en,
    sample_in_i,
    sample_in_q,
    coherent_out_en,
    coherent_out_i,
    coherent_out_q,
    chip_out_en,
    chip_out_i,
    chip_out_q
);

parameter INPUT_WIDTH = 8;
parameter OUTPUT_WIDTH_EL_INC = 10;     // for Integral_num_EL setting
parameter OUTPUT_WIDTH_I_INC = 11;      // for Integral_num_I setting
parameter OUTPUT_CHIP_INC = 3;          // for oversample rate
parameter I_TAP=4;
parameter L_TAP=8;
parameter GOLD_ORDER=10;
localparam OUTPUT_WIDTH_EL = INPUT_WIDTH + OUTPUT_WIDTH_EL_INC;
localparam OUTPUT_WIDTH_I = INPUT_WIDTH + OUTPUT_WIDTH_I_INC;
localparam OUTPUT_WIDTH_CHIP = INPUT_WIDTH + OUTPUT_CHIP_INC;
localparam PD_RESULT_WIDTH = 10;

input clk;
input rst;
input Enable;
input [11:0] Coherent_length_PD;   //1024=8*128
input [11:0] Coherent_length_I;   //2048=8*256  // for PLL
input [11:0] Chip_osr;   //8
input [23:0] C1;                //378
input [23:0] C2;                //17
input [GOLD_ORDER-1:0] Poly1;
input [GOLD_ORDER-1:0] Poly2;
input [GOLD_ORDER-1:0] init_Poly1;
input [GOLD_ORDER-1:0] init_Poly2;
input sample_in_en;
input [INPUT_WIDTH-1:0] sample_in_i;
input [INPUT_WIDTH-1:0] sample_in_q;
output coherent_out_en;
output [OUTPUT_WIDTH_I-1:0] coherent_out_i;
output [OUTPUT_WIDTH_I-1:0] coherent_out_q;
output chip_out_en;
output [OUTPUT_WIDTH_CHIP-1:0] chip_out_i;
output [OUTPUT_WIDTH_CHIP-1:0] chip_out_q;

wire data_en_EL;
wire data_en_I;
wire [OUTPUT_WIDTH_EL-1:0] E_data_i;
wire [OUTPUT_WIDTH_EL-1:0] E_data_q;
wire [OUTPUT_WIDTH_EL-1:0] L_data_i;
wire [OUTPUT_WIDTH_EL-1:0] L_data_q;
wire [OUTPUT_WIDTH_I-1:0] I_data_i;
wire [OUTPUT_WIDTH_I-1:0] I_data_q;
wire PN;
wire PD_out_en;
wire [PD_RESULT_WIDTH-1:0] PD_out;
wire FCW_en;
wire [9:0] FCW_modifying;
wire PN_move_trig;
wire [9:0] chip_index;
wire sample_in_valid;

assign coherent_out_en = data_en_I;
assign coherent_out_i = I_data_i;
assign coherent_out_q = I_data_q;
assign sample_in_valid = Enable & sample_in_en;

DDLL_Integral_Module #(
    .I_TAP(I_TAP),
    .L_TAP(L_TAP),
    .INPUT_WIDTH(INPUT_WIDTH),
    .OUTPUT_WIDTH_EL_INC(OUTPUT_WIDTH_EL_INC),
    .OUTPUT_WIDTH_I_INC(OUTPUT_WIDTH_I_INC),
    .OUTPUT_CHIP_INC(OUTPUT_CHIP_INC))
Integral_Module(
    .clk(clk),
    .rst(rst),
    .PN_code(PN),
    .Integral_num_EL(Coherent_length_PD),
    .Integral_num_I(Coherent_length_I),
    .Integral_num_I_chip(Chip_osr),
    .sample_en(sample_in_valid),
    .sample_i(sample_in_i),
    .sample_q(sample_in_q),
    .data_en_EL(data_en_EL),
    .E_data_i(E_data_i),
    .E_data_q(E_data_q),
    .L_data_i(L_data_i),
    .L_data_q(L_data_q),
    .data_en_I(data_en_I),
    .I_data_i(I_data_i),
    .I_data_q(I_data_q),
    .chip_en(chip_out_en),
    .chip_i(chip_out_i),
    .chip_q(chip_out_q));

DDLL_PD #(
    .INPUT_WIDTH(OUTPUT_WIDTH_EL),
    .OUTPUT_WIDTH(PD_RESULT_WIDTH))
PD_Module(
    .clk(clk),
    .rst(rst),
    .data_en(data_en_EL),
    .data_E_i(E_data_i),
    .data_E_q(E_data_q),
    .data_L_i(L_data_i),
    .data_L_q(L_data_q),
    .PD_out_en(PD_out_en),
    .PD_out(PD_out));

Loop_Filter #(
    .CUTOFF_WIDTH(11))
LP_Module(
    .clk(clk),
    .rst(rst),
    .eck_en(PD_out_en),
    .eck(PD_out),
    .C1(C1),
    .C2(C2),
    .FCW_en(FCW_en),
    .FCW_modifying(FCW_modifying));

Code_NCO #(
    .CODE_CHIP_NCO_WIDTH(19),
    .FCW_MODIFY_WIDTH(10),
    .SPREAD_RATIO(1023),
    .FCW_BASIC_DEFAULT(65536))
NCO_Module(
    .clk(clk),
    .rst(rst),
    .FCW_basic(65536),
    .FCW_modifying_en(FCW_en),
    .FCW_modifying(FCW_modifying),
    .update_en(sample_in_valid),
    .trig(PN_move_trig),
    .chip_index(chip_index)
);

Gold_Code_Generator #(
    .M_LENGTH(GOLD_ORDER))
PN_Generator (
    .clk(clk),
    .rst(rst),
    .trigger(PN_move_trig),
    .Poly1(Poly1),
    .Poly2(Poly2),
    .init_Poly1(init_Poly1),
    .init_Poly2(init_Poly2),
    .PN_out(PN)
);

endmodule
