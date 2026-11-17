`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/08/31 15:48:49
// Design Name: 
// Module Name: AD9361_SPI_wrrd_control
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


module AD9361_SPI_wrrd_control(
    input clk,
    input rst,
    input instruction_in_en,
    input [39:0] instruction_in,
    output reg instruction_finished,
    //Comm
    output reg RST_9361_n,
    output reg EN_9361,
    output EN_AGC_9361,
    output reg TXNRX_9361,
    output SPI_ENB_9361,
    output SPI_DI_9361,
    output SPI_CLK_9361,
    input  SPI_DO_9361,
    output [3:0] CONTROL_I_9361,
    input  [7:0] CONTROL_O_9361,
    output reg ad9361_finish=0
    );
    
    parameter [15:0] NUM_OF_CLK_FOR_1_MS = 16'd40000;
    localparam INI_STATE = 6'b000001;
    localparam IDLE_STATE = 6'b000010;
    localparam WAIT_STATE = 6'b000100;
    localparam WRITE_STATE = 6'b001000;
    localparam READ_STATE = 6'b010000;
    localparam FINISH_STATE = 6'b100000;
    
    localparam [7:0] WRITE_INSTRUCTION = 8'h11;
    localparam [7:0] WAIT_INSTRUCTION = 8'h44;
    localparam [7:0] READ_INSTRUCTION = 8'h22;
    localparam [7:0] FINISH_INSTRUCTION = 8'h88;
    
    reg [4:0] STATE;
    reg [15:0] counter_ms;
    reg [15:0] num_of_ms;
    reg [15:0] counter_num_of_ms;
    reg init_finished;
    reg wr_n, rd_n;
    reg [9:0] SPI_word_addr;
    reg [7:0] SPI_word_in;
    wire [7:0] SPI_word_out;
    wire flag_finish;
    
    assign EN_AGC_9361 = 1'b1;
    assign CONTROL_I_9361 = 4'b0000;
    
    always @(posedge clk)begin
        if(rst)begin
            STATE <= INI_STATE;
            init_finished <= 1'b0;
            instruction_finished <= 1'b0;
        end
        else begin
            case(STATE)
                INI_STATE:begin
                    STATE <= WAIT_STATE;
                    init_finished <= 1'b0;
                end
                
                IDLE_STATE:begin
                    instruction_finished <= 1'b0;
                    if(instruction_in_en)begin
                        case(instruction_in[39:32])
                            WRITE_INSTRUCTION:begin
                                STATE <= WRITE_STATE;
                            end
                            WAIT_INSTRUCTION:begin
                                STATE <= WAIT_STATE;
                            end
                            FINISH_INSTRUCTION:begin
                                STATE <= FINISH_STATE;
                            end
                            default:begin
                                STATE <= READ_STATE;
                            end
                        endcase
                    end
                end
                
                WAIT_STATE:begin
                    if((counter_ms==NUM_OF_CLK_FOR_1_MS)&&(counter_num_of_ms==num_of_ms))begin
                        STATE <= IDLE_STATE;
                        init_finished <= 1'b1;
                        instruction_finished <= init_finished;
                    end
                    else begin
                        STATE <= WAIT_STATE;
                        instruction_finished <= 1'b0;
                    end
                end
                
                WRITE_STATE:begin
                    if(flag_finish)begin
                        instruction_finished <= 1'b1;
                        STATE <= IDLE_STATE;
                    end
                    else begin
                        instruction_finished <= 1'b0;
                        STATE <= WRITE_STATE;
                    end
                end
                
                READ_STATE:begin
                    if(flag_finish)begin
                        instruction_finished <= 1'b1;
                        STATE <= IDLE_STATE;
                    end
                    else begin
                        instruction_finished <= 1'b0;
                        STATE <= READ_STATE;
                    end
                end
                
                FINISH_STATE:begin
                    STATE <= FINISH_STATE;
                end
                
                default:begin
                    instruction_finished <= 1'b0;
                    STATE <= INI_STATE;
                end
            endcase
        end
    end
    
    always @(posedge clk)begin
        if(rst)begin
            RST_9361_n <= 1'b0;
            EN_9361 <= 1'b1;
            TXNRX_9361 <= 1'b1;
        end
        else if(STATE==INI_STATE)begin
            RST_9361_n <= 1'b1;
            EN_9361 <= 1'b1;
            TXNRX_9361 <= 1'b1;
        end
        else begin
            RST_9361_n <= RST_9361_n;
            EN_9361 <= 1'b1;
            TXNRX_9361 <= 1'b1;
        end
    end
    
    always @(posedge clk)begin
        if(rst)begin
            wr_n <= 1'b1;
            rd_n <= 1'b1;
            SPI_word_in <= 8'd0;
            SPI_word_addr <= 10'd0;
            num_of_ms <= 16'd20;
            ad9361_finish <= 1'b0;
        end
        else if(STATE==IDLE_STATE)begin
            if(instruction_in_en)begin
                case(instruction_in[39:32])
                    WRITE_INSTRUCTION:begin
                        wr_n <= 1'b0;
                        rd_n <= 1'b1;
                        SPI_word_addr <= instruction_in[25:16];
                        SPI_word_in <= instruction_in[15:8];
                    end
                    READ_INSTRUCTION:begin
                        wr_n <= 1'b1;
                        rd_n <= 1'b0;
                        SPI_word_addr <= instruction_in[25:16];
                        SPI_word_in <= SPI_word_in;
                    end
                    default:begin
                        wr_n <= 1'b1;
                        rd_n <= 1'b1;
                        SPI_word_in <= SPI_word_in;
                        SPI_word_addr <= SPI_word_addr;
                        num_of_ms <= instruction_in[15:0];
                    end
                    FINISH_INSTRUCTION:begin
                        ad9361_finish <= 1'b1;
                    end
                endcase
            end
        end
        else begin
            wr_n <= 1'b1;
            rd_n <= 1'b1;
            SPI_word_in <= SPI_word_in;
            SPI_word_addr <= SPI_word_addr;
        end
    end
    
    always @(posedge clk)begin
        if(rst)begin
            counter_ms <= 16'd0;
            counter_num_of_ms <= 16'd0;
        end
        else if(STATE==WAIT_STATE)begin
            if(counter_ms==NUM_OF_CLK_FOR_1_MS)begin
                if(counter_num_of_ms==num_of_ms)begin
                    counter_ms <= 16'd0;
                    counter_num_of_ms <= 16'd0;
                end
                else begin
                    counter_ms <= 16'd0;
                    counter_num_of_ms <= counter_num_of_ms + 1'b1;
                end
            end
            else begin
                counter_ms <= counter_ms + 1'b1;
            end
        end
        else begin
            counter_ms <= 16'd0;
            counter_num_of_ms <= 16'd0;
        end
    end
    
    ad9361_wr_rd ad9361_wr_rd_inst (
    .clk(clk), 
    .rst(rst), 
    .wr_n(wr_n), 
    .rd_n(rd_n), 
    .addr_9361(SPI_word_addr), 
    .data_in(SPI_word_in), 
    .data_out(SPI_word_out), 
    .flag_finish(flag_finish), 
    .scs_n(SPI_ENB_9361), 
    .sclk(SPI_CLK_9361), 
    .mosi(SPI_DI_9361), 
    .miso(SPI_DO_9361)
    );
    
endmodule
