`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/08/31 18:23:53
// Design Name: 
// Module Name: AD9361_instructor
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


module AD9361_instructor(
    input clk,
    input rst,
    input rfd,
    input rx_en,
    input [7:0] rx_data,
    output reg dout_en,
    output wire [39:0] dout
    );
    
    parameter buffer_width = 40;
    parameter [39:0] HEAD = 40'hAD93611ACF;
    parameter [39:0] TAIL = 40'hAD9361DEAD;
    reg [buffer_width-1:0] received_buffer;
    reg [2:0] input_counter;
    
    reg rx_en_d1;
    
    reg [39:0] fifo_in;
    reg fifo_in_en;
    reg fifo_out_en;
    wire fifo_in_en_final;
    reg input_permission,input_permission_d1;
    wire [39:0] fifo_out;
    wire full, empty, almost_empty;
    
    assign fifo_in_en_final = fifo_in_en & input_permission;
   
    always @(posedge clk)begin
        if(rst)begin
            rx_en_d1 <= 1'b0;
            input_permission_d1 <= 1'b0;
        end
        else begin
            rx_en_d1 <= rx_en;
            input_permission_d1 <= input_permission;
        end
    end
   
   always @(posedge clk)begin
      if(rst==1'b1)begin
         received_buffer <= {buffer_width{1'b0}};
      end
      else if(rx_en==1'b1)begin
         received_buffer <= {received_buffer[buffer_width-9:0],rx_data};
      end
      else begin
         received_buffer <= received_buffer;
      end
   end
   
   always @(posedge clk)begin
      if(rst==1'b1)begin
         input_counter <= 3'd7;
      end
      else if((received_buffer==HEAD)&&(rx_en_d1))begin
         input_counter <= 3'd0;
      end
      else if(rx_en)begin
         if(input_counter==3'd5)begin
            input_counter <= 3'd1;
         end
         else if(input_counter<3'd5)begin
            input_counter <= input_counter + 1'b1;
         end
         else begin
            input_counter <= input_counter;
         end
      end
   end
    
    always @(posedge clk)begin
        if(rst)begin
            input_permission <= 1'b1;
        end
        else if((received_buffer==TAIL))begin
            input_permission <= 1'b0;
        end
        else begin
            input_permission <= input_permission;
        end
    end
    
    always @(posedge clk)begin
        if(rst)begin
            fifo_in_en <= 1'b0;
            fifo_in <= 40'd0;
        end
        else if((input_counter==3'd5)&&(rx_en_d1==1'b1))begin
            fifo_in_en <= 1'b1;
            fifo_in <= received_buffer;
        end
        else begin
            fifo_in_en <= 1'b0;
            fifo_in <= fifo_in;
        end
    end
    
    always @(posedge clk)begin
        if(rst)begin
            fifo_out_en <= 1'b0;
        end
        else if((input_permission_d1==1'b1)&&(input_permission==1'b0))begin
            fifo_out_en <= 1'b1;
        end
        else if((rfd==1'b1)&&(empty==1'b0))begin
            fifo_out_en <= 1'b1;
        end
        else begin
            fifo_out_en <= 1'b0;
        end
    end
    
    always @(posedge clk)begin
        if(rst)begin
            dout_en <= 1'b0;
        end
        else begin
            dout_en <= fifo_out_en;
        end
    end
    
    assign dout = fifo_out;
    
    fifo_generator_0 instruction_buffer (
    .clk(clk),                    // input wire clk
    .srst(rst),                  // input wire srst
    .din(fifo_in),                    // input wire [39 : 0] din
    .wr_en(fifo_in_en_final),                // input wire wr_en
    .rd_en(fifo_out_en),                // input wire rd_en
    .dout(fifo_out),                  // output wire [39 : 0] dout
    .full(full),                  // output wire full
    .empty(empty),                // output wire empty
    .almost_empty(almost_empty)  // output wire almost_empty
    );
    
    wire [40:0] probe0;
    assign probe0[0]=fifo_in_en_final;
    assign probe0[40:1]=fifo_in;
    
    INSTR_OB INSTR_OB (
	.clk(clk), // input wire clk
	.probe0(probe0) // input wire [40:0] probe0
);
    
endmodule
