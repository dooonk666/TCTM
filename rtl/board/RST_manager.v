`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/06/24 17:45:52
// Design Name: 
// Module Name: RST_manager
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


module RST_manager(
    input clk,
    input ad9361_finish,
    input LOCKED,
	input system_soft_reset,
    output reg rst_AD9361,
    output reg rst_clk,
	output reg rst_Transmitter,
	output reg rst_Receiver
    );
    
    reg [15:0] cnt = 16'd0;
    
    always @(posedge clk)begin
        case(cnt)
            16'd0:begin
                cnt<=cnt+1;
                rst_AD9361 <= 1'b1;
                rst_clk <= 1'b1;
                rst_Transmitter <= 1'b1;
                rst_Receiver <= 1'b1;
            end
            
            16'd1000:begin
                cnt<=cnt+1;
                rst_AD9361 <= 1'b0;
            end
            
            16'd2000:begin
                if(ad9361_finish)begin
                    cnt<=cnt+1;
                end
                else begin
                    cnt<=cnt;
                end
            end
            
            16'd3000:begin
                cnt<=cnt+1;
                rst_clk<=1'b0;
            end
            
            16'd4000:begin
                if(LOCKED)begin
                    cnt <= cnt + 1'b1;
                    rst_Transmitter <= 1'b0;
                    rst_Receiver <= 1'b0;
                end
            end
            
            16'd5000:begin
                if(system_soft_reset)begin
                    cnt <= 16'd0;
                end
                else begin
                    cnt <= cnt;
                end
            end
            
            default:begin
                cnt <= cnt + 1'b1;
            end
        endcase
    end
    
endmodule
