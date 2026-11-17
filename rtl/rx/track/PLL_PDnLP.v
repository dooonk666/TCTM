`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/10/21 16:07:41
// Design Name: 
// Module Name: PLL_PDnLP
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


module PLL_PDnLP(
    clk,
    rst,
    signal_en,
    signal_i,
    signal_q,
    C1,
    C2,
    C3,
    FCW_en,
    FCW_modifying
    // TEMP1_out,
    // TEMP2_out,
    // TEMP3_out,
    // TEMP4_out
    );

parameter INPUT_WIDTH = 19;
parameter PLL_NCO_GAIN_CUTOFF = 11;     // PLL renew period = 2048 samples

input clk;
input rst;
input signal_en;
input [INPUT_WIDTH-1:0] signal_i;
input [INPUT_WIDTH-1:0] signal_q;
input [19:0] C1;    // P coe
input [19:0] C2;    // I coe
input [19:0] C3;    // I^2 coe
output FCW_en;
output [35:0] FCW_modifying;
// output [26:0] TEMP1_out;
// output [27:0] TEMP2_out;
// output [35:0] TEMP3_out;
// output [36:0] TEMP4_out;

wire PD_en;
wire [7:0] PD;

PLL_BPSK_PD #(
    .INPUT_WIDTH(INPUT_WIDTH))
PD_part(
    .clk(clk),
    .rst(rst),
    .signal_en(signal_en),
    .signal_i(signal_i),
    .signal_q(signal_q),
    .PD_en(PD_en),
    .PD(PD)
);

PLL_Loop_Filter #(
    .PLL_NCO_GAIN_CUTOFF(PLL_NCO_GAIN_CUTOFF))
LP_part(
    .clk(clk),
    .rst(rst),
    .eck_en(PD_en),
    .eck(PD),
    .C1(C1),
    .C2(C2),
    .C3(C3),
    .FCW_en(FCW_en),
    .FCW_modifying(FCW_modifying)
    // .TEMP1_out(TEMP1_out),
    // .TEMP2_out(TEMP2_out),
    // .TEMP3_out(TEMP3_out),
    // .TEMP4_out(TEMP4_out)
);

endmodule
