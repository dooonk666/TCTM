`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    10:37:10 11/18/2016 
// Design Name: 
// Module Name:    receive_data_buf 
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
module receive_data_buf(
											input clk,
											input Rx_frame,
											input rst,
											output [11:0] data_I_R,
											output [11:0] data_Q_R,
											input [11:0] data_in
										  );


reg rst_d11,rst_d12,rst_d13,rst_d14;
reg en_buffer=0;
reg [2:0] addra=0;
reg [2:0] addrb=0;
always @(posedge clk)
	begin
		rst_d11<=rst;
		rst_d12<=rst_d11;
		rst_d13<=rst_d12;
		rst_d14<=rst_d13;
		
		if(rst_d14)
			begin
				en_buffer<=0;addra<=0;addrb<=4;
			end
		else
			begin
				en_buffer<=1;addra<=addra+1; addrb<=addrb+1;
			end
end


wire [11:0] data_I_R_temp,data_Q_R_temp;
//IDDR2 #(.DDR_ALIGNMENT("C0"),.INIT_Q0(1'b0), .INIT_Q1(1'b0),.SRTYPE("ASYNC") ) IDDR_inst0  (.Q0(data_I_R_temp[0 ]),.Q1(data_Q_R_temp[0 ]),.C0(clk),.C1(~clk),.D(data_in[0 ]), .CE(1'b1),.R(1'b0),.S(1'b0) );               
//IDDR2 #(.DDR_ALIGNMENT("C0"),.INIT_Q0(1'b0), .INIT_Q1(1'b0),.SRTYPE("ASYNC") ) IDDR_inst1  (.Q0(data_I_R_temp[1 ]),.Q1(data_Q_R_temp[1 ]),.C0(clk),.C1(~clk),.D(data_in[1 ]), .CE(1'b1),.R(1'b0),.S(1'b0) );               
//IDDR2 #(.DDR_ALIGNMENT("C0"),.INIT_Q0(1'b0), .INIT_Q1(1'b0),.SRTYPE("ASYNC") ) IDDR_inst2  (.Q0(data_I_R_temp[2 ]),.Q1(data_Q_R_temp[2 ]),.C0(clk),.C1(~clk),.D(data_in[2 ]), .CE(1'b1),.R(1'b0),.S(1'b0) );               
//IDDR2 #(.DDR_ALIGNMENT("C0"),.INIT_Q0(1'b0), .INIT_Q1(1'b0),.SRTYPE("ASYNC") ) IDDR_inst3  (.Q0(data_I_R_temp[3 ]),.Q1(data_Q_R_temp[3 ]),.C0(clk),.C1(~clk),.D(data_in[3 ]), .CE(1'b1),.R(1'b0),.S(1'b0) );               
//IDDR2 #(.DDR_ALIGNMENT("C0"),.INIT_Q0(1'b0), .INIT_Q1(1'b0),.SRTYPE("ASYNC") ) IDDR_inst4  (.Q0(data_I_R_temp[4 ]),.Q1(data_Q_R_temp[4 ]),.C0(clk),.C1(~clk),.D(data_in[4 ]), .CE(1'b1),.R(1'b0),.S(1'b0) );               
//IDDR2 #(.DDR_ALIGNMENT("C0"),.INIT_Q0(1'b0), .INIT_Q1(1'b0),.SRTYPE("ASYNC") ) IDDR_inst5  (.Q0(data_I_R_temp[5 ]),.Q1(data_Q_R_temp[5 ]),.C0(clk),.C1(~clk),.D(data_in[5 ]), .CE(1'b1),.R(1'b0),.S(1'b0) );               
//IDDR2 #(.DDR_ALIGNMENT("C0"),.INIT_Q0(1'b0), .INIT_Q1(1'b0),.SRTYPE("ASYNC") ) IDDR_inst6  (.Q0(data_I_R_temp[6 ]),.Q1(data_Q_R_temp[6 ]),.C0(clk),.C1(~clk),.D(data_in[6 ]), .CE(1'b1),.R(1'b0),.S(1'b0) );               
//IDDR2 #(.DDR_ALIGNMENT("C0"),.INIT_Q0(1'b0), .INIT_Q1(1'b0),.SRTYPE("ASYNC") ) IDDR_inst7  (.Q0(data_I_R_temp[7 ]),.Q1(data_Q_R_temp[7 ]),.C0(clk),.C1(~clk),.D(data_in[7 ]), .CE(1'b1),.R(1'b0),.S(1'b0) );               
//IDDR2 #(.DDR_ALIGNMENT("C0"),.INIT_Q0(1'b0), .INIT_Q1(1'b0),.SRTYPE("ASYNC") ) IDDR_inst8  (.Q0(data_I_R_temp[8 ]),.Q1(data_Q_R_temp[8 ]),.C0(clk),.C1(~clk),.D(data_in[8 ]), .CE(1'b1),.R(1'b0),.S(1'b0) );               
//IDDR2 #(.DDR_ALIGNMENT("C0"),.INIT_Q0(1'b0), .INIT_Q1(1'b0),.SRTYPE("ASYNC") ) IDDR_inst9  (.Q0(data_I_R_temp[9 ]),.Q1(data_Q_R_temp[9 ]),.C0(clk),.C1(~clk),.D(data_in[9 ]), .CE(1'b1),.R(1'b0),.S(1'b0) );               
//IDDR2 #(.DDR_ALIGNMENT("C0"),.INIT_Q0(1'b0), .INIT_Q1(1'b0),.SRTYPE("ASYNC") ) IDDR_inst10 (.Q0(data_I_R_temp[10]),.Q1(data_Q_R_temp[10]),.C0(clk),.C1(~clk),.D(data_in[10]), .CE(1'b1),.R(1'b0),.S(1'b0) );               
//IDDR2 #(.DDR_ALIGNMENT("C0"),.INIT_Q0(1'b0), .INIT_Q1(1'b0),.SRTYPE("ASYNC") ) IDDR_inst11 (.Q0(data_I_R_temp[11]),.Q1(data_Q_R_temp[11]),.C0(clk),.C1(~clk),.D(data_in[11]), .CE(1'b1),.R(1'b0),.S(1'b0) );               
IDDR #(.DDR_CLK_EDGE("SAME_EDGE"),.INIT_Q1(1'b0), .INIT_Q2(1'b0),.SRTYPE("ASYNC") ) IDDR_inst0  (.Q1(data_I_R_temp[0 ]),.Q2(data_Q_R_temp[0 ]),.C(clk),.D(data_in[0 ]), .CE(1'b1),.R(1'b0),.S(1'b0) );               
IDDR #(.DDR_CLK_EDGE("SAME_EDGE"),.INIT_Q1(1'b0), .INIT_Q2(1'b0),.SRTYPE("ASYNC") ) IDDR_inst1  (.Q1(data_I_R_temp[1 ]),.Q2(data_Q_R_temp[1 ]),.C(clk),.D(data_in[1 ]), .CE(1'b1),.R(1'b0),.S(1'b0) );               
IDDR #(.DDR_CLK_EDGE("SAME_EDGE"),.INIT_Q1(1'b0), .INIT_Q2(1'b0),.SRTYPE("ASYNC") ) IDDR_inst2  (.Q1(data_I_R_temp[2 ]),.Q2(data_Q_R_temp[2 ]),.C(clk),.D(data_in[2 ]), .CE(1'b1),.R(1'b0),.S(1'b0) );               
IDDR #(.DDR_CLK_EDGE("SAME_EDGE"),.INIT_Q1(1'b0), .INIT_Q2(1'b0),.SRTYPE("ASYNC") ) IDDR_inst3  (.Q1(data_I_R_temp[3 ]),.Q2(data_Q_R_temp[3 ]),.C(clk),.D(data_in[3 ]), .CE(1'b1),.R(1'b0),.S(1'b0) );               
IDDR #(.DDR_CLK_EDGE("SAME_EDGE"),.INIT_Q1(1'b0), .INIT_Q2(1'b0),.SRTYPE("ASYNC") ) IDDR_inst4  (.Q1(data_I_R_temp[4 ]),.Q2(data_Q_R_temp[4 ]),.C(clk),.D(data_in[4 ]), .CE(1'b1),.R(1'b0),.S(1'b0) );               
IDDR #(.DDR_CLK_EDGE("SAME_EDGE"),.INIT_Q1(1'b0), .INIT_Q2(1'b0),.SRTYPE("ASYNC") ) IDDR_inst5  (.Q1(data_I_R_temp[5 ]),.Q2(data_Q_R_temp[5 ]),.C(clk),.D(data_in[5 ]), .CE(1'b1),.R(1'b0),.S(1'b0) );               
IDDR #(.DDR_CLK_EDGE("SAME_EDGE"),.INIT_Q1(1'b0), .INIT_Q2(1'b0),.SRTYPE("ASYNC") ) IDDR_inst6  (.Q1(data_I_R_temp[6 ]),.Q2(data_Q_R_temp[6 ]),.C(clk),.D(data_in[6 ]), .CE(1'b1),.R(1'b0),.S(1'b0) );               
IDDR #(.DDR_CLK_EDGE("SAME_EDGE"),.INIT_Q1(1'b0), .INIT_Q2(1'b0),.SRTYPE("ASYNC") ) IDDR_inst7  (.Q1(data_I_R_temp[7 ]),.Q2(data_Q_R_temp[7 ]),.C(clk),.D(data_in[7 ]), .CE(1'b1),.R(1'b0),.S(1'b0) );               
IDDR #(.DDR_CLK_EDGE("SAME_EDGE"),.INIT_Q1(1'b0), .INIT_Q2(1'b0),.SRTYPE("ASYNC") ) IDDR_inst8  (.Q1(data_I_R_temp[8 ]),.Q2(data_Q_R_temp[8 ]),.C(clk),.D(data_in[8 ]), .CE(1'b1),.R(1'b0),.S(1'b0) );               
IDDR #(.DDR_CLK_EDGE("SAME_EDGE"),.INIT_Q1(1'b0), .INIT_Q2(1'b0),.SRTYPE("ASYNC") ) IDDR_inst9  (.Q1(data_I_R_temp[9 ]),.Q2(data_Q_R_temp[9 ]),.C(clk),.D(data_in[9 ]), .CE(1'b1),.R(1'b0),.S(1'b0) );               
IDDR #(.DDR_CLK_EDGE("SAME_EDGE"),.INIT_Q1(1'b0), .INIT_Q2(1'b0),.SRTYPE("ASYNC") ) IDDR_inst10 (.Q1(data_I_R_temp[10]),.Q2(data_Q_R_temp[10]),.C(clk),.D(data_in[10]), .CE(1'b1),.R(1'b0),.S(1'b0) );               
IDDR #(.DDR_CLK_EDGE("SAME_EDGE"),.INIT_Q1(1'b0), .INIT_Q2(1'b0),.SRTYPE("ASYNC") ) IDDR_inst11 (.Q1(data_I_R_temp[11]),.Q2(data_Q_R_temp[11]),.C(clk),.D(data_in[11]), .CE(1'b1),.R(1'b0),.S(1'b0) );   




ram_dual_8_12bits ram_dual_8_12bits_i (
  .clka(clk), // input clka
  .wea(en_buffer), // input [0 : 0] wea
  .addra(addra), // input [2 : 0] addra
  .dina(data_I_R_temp), // input [11 : 0] dina
  .clkb(clk), // input clkb
  .addrb(addrb), // input [2 : 0] addrb
  .doutb(data_I_R) // output [11 : 0] doutb
);
ram_dual_8_12bits ram_dual_8_12bits_q (
  .clka(clk), // input clka
  .wea(en_buffer), // input [0 : 0] wea
  .addra(addra), // input [2 : 0] addra
  .dina(data_Q_R_temp), // input [11 : 0] dina
  .clkb(clk), // input clkb
  .addrb(addrb), // input [2 : 0] addrb
  .doutb(data_Q_R) // output [11 : 0] doutb
);



endmodule
