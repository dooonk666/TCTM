`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/10/20 17:09:02
// Design Name: 
// Module Name: ABS_Calc
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


module ABS_Calc(
    clk,
    rst,
    data_en,
    I_data,
    Q_data,
    abs_en,
    abs
);
parameter INPUT_WIDTH = 18;

input clk;
input rst;
input data_en;
input [INPUT_WIDTH-1:0] I_data;
input [INPUT_WIDTH-1:0] Q_data;
output reg abs_en;
output reg [INPUT_WIDTH:0] abs;

reg data_en_d1, data_en_d2;
reg [INPUT_WIDTH-1:0] I_abs, Q_abs;
reg [INPUT_WIDTH-1:0] data_max;
reg [INPUT_WIDTH-2:0] data_half_min;

always @(posedge clk ) begin
    if(rst)begin
        data_en_d1 <= 1'b0;
        data_en_d2 <= 1'b0;
        abs_en <= 1'b0;
    end
    else begin
        data_en_d1 <= data_en;
        data_en_d2 <= data_en_d1;
        abs_en <= data_en_d2;
    end
end

always @(posedge clk)begin
    if(rst) I_abs <= {INPUT_WIDTH{1'b0}};
    else if(data_en)begin
        case(I_data[INPUT_WIDTH-1])
            1'b0: I_abs <= I_data;
            default: I_abs <= ~I_data;
        endcase
    end
end

always @(posedge clk)begin
    if(rst) Q_abs <= {INPUT_WIDTH{1'b0}};
    else if(data_en)begin
        case(Q_data[INPUT_WIDTH-1])
            1'b0: Q_abs <= Q_data;
            default: Q_abs <= ~Q_data;
        endcase
    end
end

always @(posedge clk)begin
    if(rst) data_max <= {INPUT_WIDTH{1'b0}};
    else if(data_en_d1)begin
        if(I_abs>Q_abs) data_max <= I_abs;
        else data_max <= Q_abs;
    end
end

always @(posedge clk)begin
    if(rst) data_half_min <= {(INPUT_WIDTH-1){1'b0}};
    else if(data_en_d1)begin
        if(I_abs>Q_abs) data_half_min <= Q_abs[INPUT_WIDTH-1:1];
        else data_half_min <= I_abs[INPUT_WIDTH-1:1];
    end
end

always @(posedge clk)begin
    if(rst) abs <= {(INPUT_WIDTH+1){1'b0}};
    else if(data_en_d2) abs <= {1'b0,data_max} + {2'b00,data_half_min};
end
endmodule
