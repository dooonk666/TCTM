`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/09/29 15:40:24
// Design Name: 
// Module Name: Loop_Filter
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


module Loop_Filter(
    clk,
    rst,
    eck_en,
    eck,
    C1,
    C2,
    FCW_en,
    FCW_modifying
);

parameter CUTOFF_WIDTH = 11;

input clk;
input rst;
input eck_en;
input [9:0] eck;
input [23:0] C1;    // P coe
input [23:0] C2;    // I coe
output reg FCW_en;
output reg [9:0] FCW_modifying;

reg eck_en_d1, eck_en_d2, eck_en_d3, eck_en_d4, eck_en_d5, eck_en_d6;
reg [18:0] Integral_arm_data;
reg [20:0] LP_out_data;
reg [24:0] A;
reg [17:0] B;
wire [42:0] Mult_result;

always @(posedge clk) begin
    if(rst)begin
        eck_en_d1 <= 1'b0;
        eck_en_d2 <= 1'b0;
        eck_en_d3 <= 1'b0;
        eck_en_d4 <= 1'b0;
        eck_en_d5 <= 1'b0;
        eck_en_d6 <= 1'b0;
        FCW_en <= 1'b0;
    end
    else begin
        eck_en_d1 <= eck_en;
        eck_en_d2 <= eck_en_d1;
        eck_en_d3 <= eck_en_d2;
        eck_en_d4 <= eck_en_d3;
        eck_en_d5 <= eck_en_d4;
        eck_en_d6 <= eck_en_d5;
        FCW_en <= eck_en_d6;
    end
end

always @(posedge clk) begin
    if(rst)begin
        A <= 25'd0;
        B <= 18'd0;
    end
    else begin
        case({eck_en,eck_en_d1})
        2'b10:begin
            A <= {C2[23],C2};
            B <= {{8{eck[9]}},eck};
        end
        2'b01:begin
            A <= {C1[23],C1};
            B <= {{8{eck[9]}},eck};
        end
        default:begin
            A <= 25'd0;
            B <= 18'd0;
        end
        endcase
    end
end


always @(posedge clk) begin
    if(rst) Integral_arm_data <= 19'd0;
    else if(eck_en_d4) Integral_arm_data <= Integral_arm_data + Mult_result[18:0];
end

always @(posedge clk) begin
    if(rst) LP_out_data <= 21'd0;
    else if(eck_en_d5) LP_out_data <= {{2{Integral_arm_data[18]}},Integral_arm_data} + Mult_result[20:0];
end

always @(posedge clk) begin
    if(rst) FCW_modifying <= 10'd0;
    else if(eck_en_d6) FCW_modifying <= LP_out_data[CUTOFF_WIDTH+9:CUTOFF_WIDTH];
end

MULT_MACRO #(
    .DEVICE("7SERIES"),
    .LATENCY(3),
    .WIDTH_A(25),
    .WIDTH_B(18))
MULT_MACRO_inst (
    .P(Mult_result),
    .A(A),
    .B(B),
    .CE(1),
    .CLK(clk),
    .RST(rst));

endmodule
