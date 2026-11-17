`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/08/31 18:14:05
// Design Name: 
// Module Name: AD9361_CON_TOP
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


module AD9361_CON_TOP(
    input clk,
    input rst,
   //Comm
    output  RST_9361,//0:RST
    output  EN_9361,//PULSE
    output EN_AGC_9361,
    output  TXNRX_9361,
    output SPI_ENB_9361,
    output SPI_DI_9361,
    output SPI_CLK_9361,
    input  SPI_DO_9361,
    output [3:0] CONTROL_I_9361,
    input  [7:0] CONTROL_O_9361,
    output  ad9361_finish,
    output dbg_auto_instruction_en,
    output [11:0] dbg_auto_instruction_addr,
    //Receiver 
    input rst_TR,
    input clk_TR,
    output [11:0] data_I_R,
    output [11:0] data_Q_R,
    input Rx_frame_9361,
    input [11:0] Rx_data_9361,
    //Transmit
    input  [11:0] data_I_T,
    input  [11:0] data_Q_T,
    output TX_FB_clk,
   output Tx_frame_9361,
    output [11:0] Tx_data_9361,
    input  [8:0]  SET_att,
    input  [8:0]  MIN_att,
    //Config
    (* MARK_DEBUG="true" *) input rs422_en,
    (* MARK_DEBUG="true" *) input [7:0] rs422
    );
    
    parameter [15:0] NUM_OF_CLK_FOR_1_MS = 16'd40000;
    (* MARK_DEBUG="true" *) wire instruction_finished;

    wire        serial_instruction_en;
    wire [39:0] serial_instruction;

    wire        auto_instruction_en;
    wire [39:0] auto_instruction;
    wire [11:0] auto_instruction_addr;

    (* MARK_DEBUG="true" *) wire        instruction_en;
    (* MARK_DEBUG="true" *) wire [39:0] instruction;

    parameter AUTO_CONFIG = 1'b1;

    assign instruction_en =
        AUTO_CONFIG ? auto_instruction_en : serial_instruction_en;

    assign instruction =
        AUTO_CONFIG ? auto_instruction : serial_instruction;
    // 引出调试信号
    assign dbg_auto_instruction_en = auto_instruction_en;
    assign dbg_auto_instruction_addr = auto_instruction_addr;

    AD9361_instructor instructor(
        .clk(clk),
        .rst(rst),
        .rfd(instruction_finished),
        .rx_en(rs422_en),
        .rx_data(rs422),
        .dout_en(serial_instruction_en),
        .dout(serial_instruction)
    );

    AD9361_auto_instructor auto_instructor(
        .clk(clk),
        .rst(rst),
        .instruction_finished(instruction_finished),
        .instruction_en(auto_instruction_en),
        .instruction(auto_instruction),
        .debug_addr(auto_instruction_addr)
    );
    
    AD9361_SPI_wrrd_control #(
    .NUM_OF_CLK_FOR_1_MS(NUM_OF_CLK_FOR_1_MS))
    AD9361_SPI_wrrd_control(
    .clk(clk),
    .rst(rst),
    .instruction_in_en(instruction_en),
    .instruction_in(instruction),
    .instruction_finished(instruction_finished),
    .RST_9361_n(RST_9361),
    .EN_9361(EN_9361),
    .EN_AGC_9361(EN_AGC_9361),
    .TXNRX_9361(TXNRX_9361),
    .SPI_ENB_9361(SPI_ENB_9361),
    .SPI_DI_9361(SPI_DI_9361),
    .SPI_CLK_9361(SPI_CLK_9361),
    .SPI_DO_9361(SPI_DO_9361),
    .CONTROL_I_9361(CONTROL_I_9361),
    .CONTROL_O_9361(CONTROL_O_9361),
    .ad9361_finish(ad9361_finish)
    );
    
    receive_data_buf receive_data_buf_inst ( 
	.clk(clk_TR),
    .rst(rst_TR), 	 
	.Rx_frame(Rx_frame_9361),
	.data_I_R(data_I_R),
	.data_Q_R(data_Q_R),
    .data_in(Rx_data_9361)
    );

    transmit_data_buf transmit_data_buf_inst (
    .clk(clk_TR), 
	.rst(rst_TR), 
	.data_I_T(data_I_T),
	.data_Q_T(data_Q_T),
    .TX_FB_clk(TX_FB_clk), 
    .Tx_frame(Tx_frame_9361), 
    .data_tx_out(Tx_data_9361)
    );
    
    

endmodule
