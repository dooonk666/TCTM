`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/10/20 18:27:12
// Design Name: 
// Module Name: PLL_Loop_Filter
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


module PLL_Loop_Filter(
    clk,
    rst,
    eck_en,
    eck,
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

parameter NORMINAL_FREQ_EXTEND_WIDTH = 7;   // pd rate = 12KHz, extend fcw to +-768KHz
parameter PLL_NCO_GAIN_CUTOFF = 11;     // PLL renew period = 2048 samples
localparam COMMON_SCALE = 272;  // should be 278, but 272(256+16) could be simpler for implementation

input clk;
input rst;
input eck_en;
input [7:0] eck;
input [19:0] C1;    // P coe
input [19:0] C2;    // I coe
input [19:0] C3;    // I^2 coe
output reg FCW_en;
output reg [35:0] FCW_modifying;
// output [26:0] TEMP1_out;
// output [27:0] TEMP2_out;
// output [35:0] TEMP3_out;
// output [36:0] TEMP4_out;

reg [12:0] EN_shift;
reg [24:0] A;
reg [17:0] B;
wire [42:0] Mult_result;

reg [26:0] TEMP1;
reg [27:0] TEMP2;
reg [28+NORMINAL_FREQ_EXTEND_WIDTH:0] TEMP3;
reg [29+NORMINAL_FREQ_EXTEND_WIDTH:0] TEMP4;
reg [35+NORMINAL_FREQ_EXTEND_WIDTH:0] Loop_result;

// assign TEMP1_out = TEMP1;
// assign TEMP2_out = TEMP2;
// assign TEMP3_out = TEMP3;
// assign TEMP4_out = TEMP4;

always @(posedge clk)begin
    if(rst) EN_shift <= {13{1'b0}};
    else EN_shift <= {EN_shift[11:0],eck_en};
end

always @(posedge clk) begin
    if(rst)begin
        A <= 25'd0;
        B <= 18'd0; 
    end
    else begin
        case(EN_shift)
        13'b0000000000001:begin       // at 5 result
            A <= {{5{1'b0}},C1};
            B <= {{10{eck[7]}},eck};
        end
        13'b0000000000010:begin
            A <= {{5{1'b0}},C2};
            B <= {{10{eck[7]}},eck};
        end
        13'b0000000000100:begin
            A <= {{5{1'b0}},C3};
            B <= {{10{eck[7]}},eck};
        end
        default:begin
            A <= A;
            B <= B;
        end
        endcase
    end
end

always @(posedge clk) begin
    if(rst) TEMP1 <= 27'd0;
    else if(EN_shift[4]) TEMP1 <= TEMP1 + Mult_result[26:0];
end

always @(posedge clk) begin
    if(rst) TEMP2 <= 28'd0;
    else if(EN_shift[5]) TEMP2 <= {TEMP1[26],TEMP1} + Mult_result[27:0];
end

always @(posedge clk) begin
    if(rst) TEMP3 <= {(29+NORMINAL_FREQ_EXTEND_WIDTH){1'b0}};
    else if(EN_shift[6]) TEMP3 <= TEMP3 + {{(1+NORMINAL_FREQ_EXTEND_WIDTH){TEMP2[27]}},TEMP2};
end
always @(posedge clk) begin
    if(rst) TEMP4 <= {(30+NORMINAL_FREQ_EXTEND_WIDTH){1'b0}};
    else if(EN_shift[7]) TEMP4 <= {TEMP3[28+NORMINAL_FREQ_EXTEND_WIDTH],TEMP3} + {{NORMINAL_FREQ_EXTEND_WIDTH{Mult_result[29]}},Mult_result[29:0]};
end

always @(posedge clk) begin
    if (rst) Loop_result <= 0;
    else if (EN_shift[8]) Loop_result <= {TEMP4[27+NORMINAL_FREQ_EXTEND_WIDTH:0], 8'd0} + {{2{TEMP4[29+NORMINAL_FREQ_EXTEND_WIDTH]}}, TEMP4[29+NORMINAL_FREQ_EXTEND_WIDTH:0], 4'd0};
end

always @(posedge clk)begin
    if(rst) FCW_modifying <= {36{1'b0}};
    else if(EN_shift[9]) FCW_modifying <= {{(PLL_NCO_GAIN_CUTOFF-NORMINAL_FREQ_EXTEND_WIDTH){Loop_result[35+NORMINAL_FREQ_EXTEND_WIDTH]}},Loop_result[35+NORMINAL_FREQ_EXTEND_WIDTH:PLL_NCO_GAIN_CUTOFF]};
end

always @(posedge clk)begin
    if(rst) FCW_en <= 1'b0;
    else FCW_en <= EN_shift[9];
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
