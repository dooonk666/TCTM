`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/10/12 10:43:38
// Design Name: 
// Module Name: Code_NCO
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


module Code_NCO(
    clk,
    rst,
    FCW_basic,
    FCW_modifying_en,
    FCW_modifying,
    update_en,
    trig,
    chip_index
);


parameter CODE_CHIP_NCO_WIDTH = 19;
parameter FCW_MODIFY_WIDTH = 10;
parameter SPREAD_RATIO = 1023;
parameter FCW_BASIC_DEFAULT = 65536;
localparam PN_CNT_WIDTH = $clog2(SPREAD_RATIO);
localparam CHIP_INDEX_MINUS_1 = SPREAD_RATIO - 1;

input clk;
input rst;
input [CODE_CHIP_NCO_WIDTH-1:0] FCW_basic;
input FCW_modifying_en;
input [FCW_MODIFY_WIDTH-1:0] FCW_modifying;
input update_en;
output reg trig;
output reg [PN_CNT_WIDTH-1:0] chip_index;

reg [CODE_CHIP_NCO_WIDTH-1:0] FCW;
reg [CODE_CHIP_NCO_WIDTH-1:0] CHIP_NCO;
wire [CODE_CHIP_NCO_WIDTH:0] NCO_SUM;

always @(posedge clk) begin
    if(rst) FCW <= FCW_BASIC_DEFAULT;
    else if(FCW_modifying_en) FCW <= FCW_basic + {{(CODE_CHIP_NCO_WIDTH-FCW_MODIFY_WIDTH){FCW_modifying[FCW_MODIFY_WIDTH-1]}},FCW_modifying};
end

assign NCO_SUM = CHIP_NCO + FCW;

always @(posedge clk) begin
    if(rst) CHIP_NCO <= {CODE_CHIP_NCO_WIDTH{1'b0}};
    else if(update_en) CHIP_NCO <= NCO_SUM[CODE_CHIP_NCO_WIDTH-1:0];
end

always @(posedge clk) begin
    if(rst) trig <= 1'b0;
    else if(update_en) trig <= NCO_SUM[CODE_CHIP_NCO_WIDTH];
    else trig <= 1'b0;
end

always @(posedge clk) begin
    if(rst) chip_index <= {PN_CNT_WIDTH{1'b0}};
    else if(update_en&NCO_SUM[CODE_CHIP_NCO_WIDTH])begin
        if(chip_index==CHIP_INDEX_MINUS_1) chip_index <= {PN_CNT_WIDTH{1'b0}};
        else chip_index <= chip_index + 1'b1;
    end
end
endmodule
