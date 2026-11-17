`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    10:41:42 04/05/2018 
// Design Name: 
// Module Name:    rx_module 
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
module rx_module(
   input clk,
   input rst,
   input [31:0] nominal_clock_frequency,
   input [31:0] nominal_baud_rate,
   input rx_in,
   output reg dout_en,
   output reg [7:0] dout,
   output reg rdy,
   wire [1:0]state_ob,
   wire [31:0]sample_cnt_ob
   );

   reg [31:0] clock_frequency_buffer;
   reg [31:0] baud_rate_buffer;
   reg [31:0] calculation_temp;
   reg [31:0] overasmple_rate;
   
   reg [15:0] anti_jitter_buffer;
   reg [4:0] anti_jitter_sum;
   localparam [1:0] IDLE = 2'd0;
   localparam [1:0] EDGE_DETECTED = 2'd1;
   localparam [1:0] BIT_RECEIVING = 2'd2;
   localparam [1:0] TERMINATION = 2'd3;
   reg [1:0] state;
   reg [31:0] sample_cnt;
   reg [2:0] bit_cnt;
   
   
   
   assign sample_cnt_ob = sample_cnt;
   assign state_ob      = state;
// **************************** Parameter Configuration **************************
   always @(posedge clk or posedge rst)begin
      if(rst==1'b1)begin
         clock_frequency_buffer <= 32'd0;
         baud_rate_buffer <= 32'd0;
      end
      else begin
         clock_frequency_buffer <= nominal_clock_frequency;
         baud_rate_buffer <= nominal_baud_rate;
      end
   end

   always @(posedge clk or posedge rst)begin    // oversample rate calculation
      if(rst==1'b1)begin
         rdy <= 1'b0;
         calculation_temp <= 32'd0;
         overasmple_rate <= 32'd0;
      end
      else if((clock_frequency_buffer!=nominal_clock_frequency)||(baud_rate_buffer!=nominal_baud_rate))begin
         rdy <= 1'b0;
         calculation_temp <= nominal_clock_frequency - nominal_baud_rate;
         overasmple_rate <= 1'b1;
      end
      else if(calculation_temp>=nominal_baud_rate)begin
         rdy <= 1'b0;
         calculation_temp <= calculation_temp - nominal_baud_rate;
         overasmple_rate <= overasmple_rate + 1'b1;
      end
      else begin
         rdy <= 1'b1;
         calculation_temp <= calculation_temp;
         overasmple_rate <= overasmple_rate;
      end
   end
   
// ******************************* Receiving Process *****************************
   always @(posedge clk or posedge rst)begin
      if(rst==1'b1)begin
         anti_jitter_buffer <= 16'hFFFF;
      end
      else begin
         anti_jitter_buffer <= {anti_jitter_buffer[14:0],rx_in};
      end
   end
   
   always @(posedge clk or posedge rst)begin
      if(rst==1'b1)begin
         anti_jitter_sum <= 5'd16;
      end
      else begin
         anti_jitter_sum <= anti_jitter_buffer[0]+anti_jitter_buffer[1]+anti_jitter_buffer[2]+anti_jitter_buffer[3]+anti_jitter_buffer[4]+anti_jitter_buffer[5]+anti_jitter_buffer[6]+anti_jitter_buffer[7]+anti_jitter_buffer[8]+anti_jitter_buffer[9]+anti_jitter_buffer[10]+anti_jitter_buffer[11]+anti_jitter_buffer[12]+anti_jitter_buffer[13]+anti_jitter_buffer[14]+anti_jitter_buffer[15];
      end
   end
   
   
   always @(posedge clk or posedge rst)begin
      if(rst==1'b1)begin
         state <= IDLE;
         sample_cnt <= 32'd0;
         bit_cnt <= 3'd0;
      end
      else if(rdy==1'b1)begin
         case(state)
            IDLE:begin
//               if(anti_jitter_buffer==16'hFF00)begin
               if((anti_jitter_sum>=6)&&(anti_jitter_sum<=10)&&(anti_jitter_buffer[0]==1'b0))begin
                  state <= EDGE_DETECTED;
                  sample_cnt <= 32'd0;
                  bit_cnt <= 3'd0;
               end
               else begin
                  state <= IDLE;
                  sample_cnt <= 32'd0;
                  bit_cnt <= 3'd0;
               end
            end
            
            EDGE_DETECTED:begin
               if(sample_cnt=={overasmple_rate[31],overasmple_rate[31:1]})begin  // start bit check, and optimal sample time determined
                  if(anti_jitter_buffer[8]==1'b0)begin
                     state <= BIT_RECEIVING;
                     sample_cnt <= 32'd0;
                     bit_cnt <= 3'd0;
                  end
                  else begin
                     state <= IDLE;
                     sample_cnt <= 32'd0;
                     bit_cnt <= 3'd0;
                  end
               end
               else begin
                  state <= EDGE_DETECTED;
                  sample_cnt <= sample_cnt + 1'b1;
                  bit_cnt <= 3'd0;
               end
            end
            
            BIT_RECEIVING:begin
               if(sample_cnt==overasmple_rate)begin
                  if(bit_cnt==3'd7)begin
                     state <= TERMINATION;
                     sample_cnt <= 32'd0;
                     bit_cnt <= 3'd0;
                  end
                  else begin
                     state <= BIT_RECEIVING;
                     sample_cnt <= 32'd0;
                     bit_cnt <= bit_cnt + 1'b1;
                  end
               end
               else begin
                  state <= BIT_RECEIVING;
                  sample_cnt <= sample_cnt + 1'b1;
                  bit_cnt <= bit_cnt;
               end
            end
            
            TERMINATION:begin
               if(sample_cnt==overasmple_rate)begin
                  state <= IDLE;
                  sample_cnt <= 32'd0;
                  bit_cnt <= 3'd0;
               end
               else begin
                  state <= TERMINATION;
                  sample_cnt <= sample_cnt + 1'b1;
                  bit_cnt <= 3'd0;
               end
            end
         endcase
      end
      else begin
         state <= IDLE;
      end
   end
   
   always @(posedge clk or posedge rst)begin
      if(rst==1'b1)begin
         dout <= 8'd0;
      end
      else if(state==BIT_RECEIVING)begin
         if(sample_cnt==overasmple_rate)begin
            case(bit_cnt)
               3'd0:begin
                  dout[0] <= anti_jitter_buffer[8];
               end
               
               3'd1:begin
                  dout[1] <= anti_jitter_buffer[8];
               end
               
               3'd2:begin
                  dout[2] <= anti_jitter_buffer[8];
               end
               
               3'd3:begin
                  dout[3] <= anti_jitter_buffer[8];
               end
               
               3'd4:begin
                  dout[4] <= anti_jitter_buffer[8];
               end
               
               3'd5:begin
                  dout[5] <= anti_jitter_buffer[8];
               end
               
               3'd6:begin
                  dout[6] <= anti_jitter_buffer[8];
               end
               
               default:begin
                  dout[7] <= anti_jitter_buffer[8];
               end
            endcase
         end
      end
      else begin
         dout <= dout;
      end
   end
   
   always @(posedge clk or posedge rst)begin
      if(rst==1'b1)begin
         dout_en <= 1'b0;
      end
      else if(state==TERMINATION)begin
         if((sample_cnt==overasmple_rate)&&(anti_jitter_buffer[8]==1'b1))begin
            dout_en <= 1'b1;
         end
         else begin
            dout_en <= 1'b0;
         end
      end
      else begin
         dout_en <= 1'b0;
      end
   end
   
endmodule
