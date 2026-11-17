`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/09/24 15:42:30
// Design Name: 
// Module Name: DDLL_Integral_Module
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


module DDLL_Integral_Module(
    clk,
    rst,
    PN_code,
    Integral_num_EL,
    Integral_num_I,
    Integral_num_I_chip,
    sample_en,
    sample_i,
    sample_q,
    data_en_EL,
    E_data_i,
    E_data_q,
    L_data_i,
    L_data_q,
    data_en_I,
    I_data_i,
    I_data_q,
    chip_en,
    chip_i,
    chip_q
    );

    parameter I_TAP=4;
    parameter L_TAP=8;
    parameter INPUT_WIDTH = 8;
    parameter OUTPUT_WIDTH_EL_INC = 10;     // for Integral_num_EL setting
    parameter OUTPUT_WIDTH_I_INC = 11;      // for Integral_num_I setting
    parameter OUTPUT_CHIP_INC = 3;          // for oversample rate
    localparam OUTPUT_WIDTH_EL = INPUT_WIDTH + OUTPUT_WIDTH_EL_INC;
    localparam OUTPUT_WIDTH_I = INPUT_WIDTH + OUTPUT_WIDTH_I_INC;
    localparam OUTPUT_WIDTH_CHIP = INPUT_WIDTH + OUTPUT_CHIP_INC;

    input clk;
    input rst;
    input PN_code;
    input [11:0] Integral_num_EL;
    input [11:0] Integral_num_I;
    input [11:0] Integral_num_I_chip;
    input sample_en;
    input [INPUT_WIDTH-1:0] sample_i;   // [-2^(INPUT_WIDTH-1)+1, 2^(INPUT_WIDTH-1)-1]
    input [INPUT_WIDTH-1:0] sample_q;
    output data_en_EL;
    output [OUTPUT_WIDTH_EL-1:0] E_data_i;
    output [OUTPUT_WIDTH_EL-1:0] E_data_q;
    output [OUTPUT_WIDTH_EL-1:0] L_data_i;
    output [OUTPUT_WIDTH_EL-1:0] L_data_q;
    output data_en_I;
    output [OUTPUT_WIDTH_I-1:0] I_data_i;
    output [OUTPUT_WIDTH_I-1:0] I_data_q;
    output chip_en;
    output [OUTPUT_WIDTH_CHIP-1:0] chip_i;
    output [OUTPUT_WIDTH_CHIP-1:0] chip_q;


    reg [L_TAP:0] PN_code_delay;
    wire [INPUT_WIDTH-1:0] despread_E_i, despread_E_q;
    wire [INPUT_WIDTH-1:0] despread_I_i, despread_I_q;
    wire [INPUT_WIDTH-1:0] despread_L_i, despread_L_q;

    always @(posedge clk)begin
        if(rst) PN_code_delay <= {(L_TAP+1){1'b0}};
        else if(sample_en) PN_code_delay <= {PN_code_delay[L_TAP-1:0],PN_code};
    end

    assign despread_E_i = PN_code_delay[0]?(~sample_i+1'b1):sample_i;
    assign despread_E_q = PN_code_delay[0]?(~sample_q+1'b1):sample_q;
    assign despread_I_i = PN_code_delay[I_TAP]?(~sample_i+1'b1):sample_i;
    assign despread_I_q = PN_code_delay[I_TAP]?(~sample_q+1'b1):sample_q;
    assign despread_L_i = PN_code_delay[L_TAP]?(~sample_i+1'b1):sample_i;
    assign despread_L_q = PN_code_delay[L_TAP]?(~sample_q+1'b1):sample_q;

    Integral_Clean_process #(
        .INPUT_WIDTH(INPUT_WIDTH),
        .OUTPUT_WIDTH_INC(OUTPUT_WIDTH_EL_INC))
    DDLL_E_int(
        .clk(clk),
        .rst(rst),
        .din_en(sample_en),
        .din_i(despread_E_i),
        .din_q(despread_E_q),
        .Integral_num(Integral_num_EL),
        .dout_en(data_en_EL),
        .dout_i(E_data_i),
        .dout_q(E_data_q)
    );

    Integral_Clean_process #(
        .INPUT_WIDTH(INPUT_WIDTH),
        .OUTPUT_WIDTH_INC(OUTPUT_WIDTH_EL_INC))
    DDLL_L_int(
        .clk(clk),
        .rst(rst),
        .din_en(sample_en),
        .din_i(despread_L_i),
        .din_q(despread_L_q),
        .Integral_num(Integral_num_EL),
        .dout_en(),
        .dout_i(L_data_i),
        .dout_q(L_data_q)
    );

    Integral_Clean_process #(
        .INPUT_WIDTH(INPUT_WIDTH),
        .OUTPUT_WIDTH_INC(OUTPUT_WIDTH_I_INC))
    DDLL_I_int(
        .clk(clk),
        .rst(rst),
        .din_en(sample_en),
        .din_i(despread_I_i),
        .din_q(despread_I_q),
        .Integral_num(Integral_num_I),
        .dout_en(data_en_I),
        .dout_i(I_data_i),
        .dout_q(I_data_q)
    );

    Integral_Clean_process #(
        .INPUT_WIDTH(INPUT_WIDTH),
        .OUTPUT_WIDTH_INC(OUTPUT_CHIP_INC))
    DDLL_chip_int(
        .clk(clk),
        .rst(rst),
        .din_en(sample_en),
        .din_i(despread_I_i),
        .din_q(despread_I_q),
        .Integral_num(Integral_num_I_chip),
        .dout_en(chip_en),
        .dout_i(chip_i),
        .dout_q(chip_q)
    );

endmodule