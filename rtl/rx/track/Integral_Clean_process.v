`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/09/28 09:35:37
// Design Name: 
// Module Name: Integral_Clean_process
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


module Integral_Clean_process(
    clk,
    rst,
    din_en,
    din_i,
    din_q,
    Integral_num,
    dout_en,
    dout_i,
    dout_q
    );

    parameter INPUT_WIDTH = 8;
    parameter OUTPUT_WIDTH_INC = 7;     // FOR Integral_num setting
    localparam OUTPUT_WIDTH = INPUT_WIDTH + OUTPUT_WIDTH_INC;
    
    input clk;
    input rst;
    input din_en;
    input [INPUT_WIDTH-1:0] din_i;
    input [INPUT_WIDTH-1:0] din_q;
    input [11:0] Integral_num;
    output reg dout_en;
    output reg [OUTPUT_WIDTH-1:0] dout_i;
    output reg [OUTPUT_WIDTH-1:0] dout_q;

    reg [11:0] acc_cnt;
    reg [INPUT_WIDTH+11:0] acc_i, acc_q;

    always @(posedge clk)begin
        if(rst) acc_cnt <= 12'd1;
        else if(din_en)begin
            if(acc_cnt==Integral_num) acc_cnt <= 12'd1;
            else acc_cnt <= acc_cnt + 1'b1;
        end
    end

    always @(posedge clk)begin
        if(rst)begin
            acc_i <= {(INPUT_WIDTH+12){1'b0}};
            acc_q <= {(INPUT_WIDTH+12){1'b0}};
        end
        else if(din_en)begin
            if(acc_cnt==Integral_num)begin
                acc_i <= {{12{din_i[INPUT_WIDTH-1]}},din_i};
                acc_q <= {{12{din_q[INPUT_WIDTH-1]}},din_q};
            end
            else begin
                acc_i <= acc_i + {{12{din_i[INPUT_WIDTH-1]}},din_i};
                acc_q <= acc_q + {{12{din_q[INPUT_WIDTH-1]}},din_q};
            end
        end
    end

    always @(posedge clk)begin
        if(rst) dout_en <= 1'b0;
        else if(din_en&(acc_cnt==Integral_num)) dout_en <= 1'b1;
        else dout_en <= 1'b0;
    end

    always @(posedge clk)begin
        if(rst)begin
            dout_i <= {OUTPUT_WIDTH{1'b0}};
            dout_q <= {OUTPUT_WIDTH{1'b0}};
        end
        else if(din_en&(acc_cnt==Integral_num))begin
            dout_i <= acc_i[OUTPUT_WIDTH-1:0];
            dout_q <= acc_q[OUTPUT_WIDTH-1:0];
        end
    end
endmodule
