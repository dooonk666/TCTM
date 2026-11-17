`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/11/02 12:58:23
// Design Name: 
// Module Name: Data_Buffer_Xclk
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


module Data_Buffer_Xclk(
    clk,
    rst,
    clk_R,
    ad_din_i,
    ad_din_q,
    dout_en,
    dout_i,
    dout_q
    );

input clk;
input rst;
input clk_R;
input [11:0] ad_din_i;
input [11:0] ad_din_q;
output dout_en;
output [11:0] dout_i;
output [11:0] dout_q;

wire [23:0] fifo_in;
reg rd_en;
reg rd_pause;
wire [23:0] fifo_out;
wire full, almost_full, empty, almost_empty;
reg  rd_en_d1;

assign fifo_in = {ad_din_i,ad_din_q};
assign dout_en = rd_en_d1;
assign dout_i = fifo_out[23:12];
assign dout_q = fifo_out[11:0];

always @(posedge clk) begin
    if(rst) rd_en <= 1'b0;
    else if((~empty)&(~rd_en)) rd_en <= 1'b1;
    else rd_en <= 1'b0;
end

always @(posedge clk) begin
    if(rst) rd_en_d1 <= 1'b0;
    else rd_en_d1 <= rd_en;
end

data_buffer_fifo_24x16 data_buffer (
  .rst(rst),                    // input wire rst
  .wr_clk(clk_R),              // input wire wr_clk
  .rd_clk(clk),              // input wire rd_clk
  .din(fifo_in),                    // input wire [23 : 0] din
  .wr_en(1'b1),                // input wire wr_en
  .rd_en(rd_en),                // input wire rd_en
  .dout(fifo_out),                  // output wire [23 : 0] dout
  .full(full),                  // output wire full
  .almost_full(almost_full),    // output wire almost_full
  .empty(empty),                // output wire empty
  .almost_empty(almost_empty)  // output wire almost_empty
);

endmodule
