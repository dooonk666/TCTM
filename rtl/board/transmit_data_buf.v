
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    10:38:29 11/18/2016 
// Design Name: 
// Module Name:    transmit_data_buf 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module transmit_data_buf(
	input  clk,
	output TX_FB_clk,
	input  [11:0] data_I_T,
	input  [11:0] data_Q_T,	
	output Tx_frame,
	input  rst,
	output [11:0] data_tx_out
    );


reg [11:0] data_I_T_d1,data_I_T_d2;
reg [11:0] data_Q_T_d1,data_Q_T_d2;
always @(posedge clk)
	begin
		data_I_T_d1<=data_I_T; data_I_T_d2<=data_I_T_d1;
		data_Q_T_d1<=data_Q_T; data_Q_T_d2<=data_Q_T_d1;
	end


//ODDR2 #( .DDR_ALIGNMENT("C0"), .INIT(1'b0),  .SRTYPE("ASYNC") ) ODDR_inst0  (.Q(data_tx_out[0 ]),.C0(clk),.C1(~clk),.CE(1'b1),.D0(data_I_T_d2[0 ]),.D1(data_Q_T_d2[0 ]),.R(1'b0),.S(1'b0));
//ODDR2 #( .DDR_ALIGNMENT("C0"), .INIT(1'b0),  .SRTYPE("ASYNC") ) ODDR_inst1  (.Q(data_tx_out[1 ]),.C0(clk),.C1(~clk),.CE(1'b1),.D0(data_I_T_d2[1 ]),.D1(data_Q_T_d2[1 ]),.R(1'b0),.S(1'b0));
//ODDR2 #( .DDR_ALIGNMENT("C0"), .INIT(1'b0),  .SRTYPE("ASYNC") ) ODDR_inst2  (.Q(data_tx_out[2 ]),.C0(clk),.C1(~clk),.CE(1'b1),.D0(data_I_T_d2[2 ]),.D1(data_Q_T_d2[2 ]),.R(1'b0),.S(1'b0));
//ODDR2 #( .DDR_ALIGNMENT("C0"), .INIT(1'b0),  .SRTYPE("ASYNC") ) ODDR_inst3  (.Q(data_tx_out[3 ]),.C0(clk),.C1(~clk),.CE(1'b1),.D0(data_I_T_d2[3 ]),.D1(data_Q_T_d2[3 ]),.R(1'b0),.S(1'b0));
//ODDR2 #( .DDR_ALIGNMENT("C0"), .INIT(1'b0),  .SRTYPE("ASYNC") ) ODDR_inst4  (.Q(data_tx_out[4 ]),.C0(clk),.C1(~clk),.CE(1'b1),.D0(data_I_T_d2[4 ]),.D1(data_Q_T_d2[4 ]),.R(1'b0),.S(1'b0));
//ODDR2 #( .DDR_ALIGNMENT("C0"), .INIT(1'b0),  .SRTYPE("ASYNC") ) ODDR_inst5  (.Q(data_tx_out[5 ]),.C0(clk),.C1(~clk),.CE(1'b1),.D0(data_I_T_d2[5 ]),.D1(data_Q_T_d2[5 ]),.R(1'b0),.S(1'b0));
//ODDR2 #( .DDR_ALIGNMENT("C0"), .INIT(1'b0),  .SRTYPE("ASYNC") ) ODDR_inst6  (.Q(data_tx_out[6 ]),.C0(clk),.C1(~clk),.CE(1'b1),.D0(data_I_T_d2[6 ]),.D1(data_Q_T_d2[6 ]),.R(1'b0),.S(1'b0));
//ODDR2 #( .DDR_ALIGNMENT("C0"), .INIT(1'b0),  .SRTYPE("ASYNC") ) ODDR_inst7  (.Q(data_tx_out[7 ]),.C0(clk),.C1(~clk),.CE(1'b1),.D0(data_I_T_d2[7 ]),.D1(data_Q_T_d2[7 ]),.R(1'b0),.S(1'b0));
//ODDR2 #( .DDR_ALIGNMENT("C0"), .INIT(1'b0),  .SRTYPE("ASYNC") ) ODDR_inst8  (.Q(data_tx_out[8 ]),.C0(clk),.C1(~clk),.CE(1'b1),.D0(data_I_T_d2[8 ]),.D1(data_Q_T_d2[8 ]),.R(1'b0),.S(1'b0));
//ODDR2 #( .DDR_ALIGNMENT("C0"), .INIT(1'b0),  .SRTYPE("ASYNC") ) ODDR_inst9  (.Q(data_tx_out[9 ]),.C0(clk),.C1(~clk),.CE(1'b1),.D0(data_I_T_d2[9 ]),.D1(data_Q_T_d2[9 ]),.R(1'b0),.S(1'b0));
//ODDR2 #( .DDR_ALIGNMENT("C0"), .INIT(1'b0),  .SRTYPE("ASYNC") ) ODDR_inst10 (.Q(data_tx_out[10]),.C0(clk),.C1(~clk),.CE(1'b1),.D0(data_I_T_d2[10]),.D1(data_Q_T_d2[10]),.R(1'b0),.S(1'b0));
//ODDR2 #( .DDR_ALIGNMENT("C0"), .INIT(1'b0),  .SRTYPE("ASYNC") ) ODDR_inst11 (.Q(data_tx_out[11]),.C0(clk),.C1(~clk),.CE(1'b1),.D0(data_I_T_d2[11]),.D1(data_Q_T_d2[11]),.R(1'b0),.S(1'b0));
ODDR #(.DDR_CLK_EDGE("SAME_EDGE"),.INIT(1'b0),.SRTYPE("ASYNC")) ODDR_inst0  (.Q(data_tx_out[0 ]), .C(clk), .CE(1'b1),.D1(data_I_T_d2[0 ]),.D2(data_Q_T_d2[0 ]),.R(1'b0),.S(1'b0));  
ODDR #(.DDR_CLK_EDGE("SAME_EDGE"),.INIT(1'b0),.SRTYPE("ASYNC")) ODDR_inst1  (.Q(data_tx_out[1 ]), .C(clk), .CE(1'b1),.D1(data_I_T_d2[1 ]),.D2(data_Q_T_d2[1 ]),.R(1'b0),.S(1'b0));  
ODDR #(.DDR_CLK_EDGE("SAME_EDGE"),.INIT(1'b0),.SRTYPE("ASYNC")) ODDR_inst2  (.Q(data_tx_out[2 ]), .C(clk), .CE(1'b1),.D1(data_I_T_d2[2 ]),.D2(data_Q_T_d2[2 ]),.R(1'b0),.S(1'b0));  
ODDR #(.DDR_CLK_EDGE("SAME_EDGE"),.INIT(1'b0),.SRTYPE("ASYNC")) ODDR_inst3  (.Q(data_tx_out[3 ]), .C(clk), .CE(1'b1),.D1(data_I_T_d2[3 ]),.D2(data_Q_T_d2[3 ]),.R(1'b0),.S(1'b0));  
ODDR #(.DDR_CLK_EDGE("SAME_EDGE"),.INIT(1'b0),.SRTYPE("ASYNC")) ODDR_inst4  (.Q(data_tx_out[4 ]), .C(clk), .CE(1'b1),.D1(data_I_T_d2[4 ]),.D2(data_Q_T_d2[4 ]),.R(1'b0),.S(1'b0));  
ODDR #(.DDR_CLK_EDGE("SAME_EDGE"),.INIT(1'b0),.SRTYPE("ASYNC")) ODDR_inst5  (.Q(data_tx_out[5 ]), .C(clk), .CE(1'b1),.D1(data_I_T_d2[5 ]),.D2(data_Q_T_d2[5 ]),.R(1'b0),.S(1'b0));  
ODDR #(.DDR_CLK_EDGE("SAME_EDGE"),.INIT(1'b0),.SRTYPE("ASYNC")) ODDR_inst6  (.Q(data_tx_out[6 ]), .C(clk), .CE(1'b1),.D1(data_I_T_d2[6 ]),.D2(data_Q_T_d2[6 ]),.R(1'b0),.S(1'b0));  
ODDR #(.DDR_CLK_EDGE("SAME_EDGE"),.INIT(1'b0),.SRTYPE("ASYNC")) ODDR_inst7  (.Q(data_tx_out[7 ]), .C(clk), .CE(1'b1),.D1(data_I_T_d2[7 ]),.D2(data_Q_T_d2[7 ]),.R(1'b0),.S(1'b0));  
ODDR #(.DDR_CLK_EDGE("SAME_EDGE"),.INIT(1'b0),.SRTYPE("ASYNC")) ODDR_inst8  (.Q(data_tx_out[8 ]), .C(clk), .CE(1'b1),.D1(data_I_T_d2[8 ]),.D2(data_Q_T_d2[8 ]),.R(1'b0),.S(1'b0));  
ODDR #(.DDR_CLK_EDGE("SAME_EDGE"),.INIT(1'b0),.SRTYPE("ASYNC")) ODDR_inst9  (.Q(data_tx_out[9 ]), .C(clk), .CE(1'b1),.D1(data_I_T_d2[9 ]),.D2(data_Q_T_d2[9 ]),.R(1'b0),.S(1'b0));  
ODDR #(.DDR_CLK_EDGE("SAME_EDGE"),.INIT(1'b0),.SRTYPE("ASYNC")) ODDR_inst10 (.Q(data_tx_out[10]), .C(clk), .CE(1'b1),.D1(data_I_T_d2[10]),.D2(data_Q_T_d2[10]),.R(1'b0),.S(1'b0));  
ODDR #(.DDR_CLK_EDGE("SAME_EDGE"),.INIT(1'b0),.SRTYPE("ASYNC")) ODDR_inst11 (.Q(data_tx_out[11]), .C(clk), .CE(1'b1),.D1(data_I_T_d2[11]),.D2(data_Q_T_d2[11]),.R(1'b0),.S(1'b0));      
     

assign TX_FB_clk  = clk;
assign Tx_frame   = clk;


endmodule