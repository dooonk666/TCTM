`timescale 1ns / 1ps
//
// 星地遥控帧解帧器（协议 3.1）
//
// 输入是已经完成位同步/字节组帧后的 8 bit 字节流，字节按协议书中的
// 从左到右顺序到达：同步头、地址、格式字节、遥控数据、帧结束字。
// 同步头接受 EB90 以及每一位取反后的 146F。这里只对同步头做取反
// 容错，帧内其它字段仍按接收到的原始字节输出。
//
// payload_data_o[7:0] 是第 0 个数据字节，最多保存 512 字节。
// frame_valid_o 为 ready/valid 风格，可在 frame_ready_i=0 时保持。
//
module telecommand_deframer #(
    parameter [15:0] EXPECTED_ADDRESS = 16'hB42E,
    parameter        CHECK_ADDRESS    = 1'b1,
    parameter [63:0] FRAME_TAIL       = 64'hC5C5C5C5C5C5C579
) (
    input  wire         clk,
    input  wire         rst,

    input  wire         rx_valid_i,
    input  wire [7:0]   rx_data_i,
    output wire         rx_ready_o,

    output reg          frame_valid_o,
    input  wire         frame_ready_i,
    output reg  [15:0]  frame_address_o,
    output reg  [7:0]   frame_format_o,
    output reg  [9:0]   payload_length_o,
    output reg  [4095:0] payload_data_o,
    output reg          sync_inverted_o,

    output reg          frame_error_o,
    // 1: 地址错误；2: 格式字节错误；3: 帧结束字错误
    output reg  [2:0]   frame_error_code_o
);

    localparam [2:0] ST_SEARCH = 3'd0;
    localparam [2:0] ST_ADDR   = 3'd1;
    localparam [2:0] ST_FORMAT = 3'd2;
    localparam [2:0] ST_DATA   = 3'd3;
    localparam [2:0] ST_TAIL   = 3'd4;
    localparam [2:0] ST_HOLD   = 3'd5;

    reg [2:0]  state;
    reg [15:0] sync_shift;
    reg [15:0] address_shift;
    reg [7:0]  format_byte;
    reg [9:0]  payload_count;
    reg [9:0]  payload_length;
    reg [2:0]  addr_count;
    reg [2:0]  tail_count;
    reg [63:0] tail_shift;

    wire accept_byte = rx_valid_i && rx_ready_o;
    wire [15:0] sync_candidate = {sync_shift[7:0], rx_data_i};
    wire [15:0] sync_xor = sync_candidate ^ 16'hEB90;
    wire sync_is_valid = (sync_xor == 16'h0000) || (sync_xor == 16'hFFFF);

    assign rx_ready_o = (state != ST_HOLD);

    // 3.1.1 直控：72 bit；3.1.2 间接遥控：32/64/128/256/512 byte。
    function [9:0] format_to_length;
        input [7:0] fmt;
        begin
            case (fmt)
                8'h39: format_to_length = 10'd9;
                8'h5A: format_to_length = 10'd32;
                8'h69: format_to_length = 10'd64;
                8'h96: format_to_length = 10'd128;
                8'hA5: format_to_length = 10'd256;
                8'hC9: format_to_length = 10'd512;
                default: format_to_length = 10'd0;
            endcase
        end
    endfunction

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state              <= ST_SEARCH;
            sync_shift         <= 16'd0;
            address_shift      <= 16'd0;
            format_byte        <= 8'd0;
            payload_count      <= 10'd0;
            payload_length     <= 10'd0;
            addr_count         <= 3'd0;
            tail_count         <= 3'd0;
            tail_shift         <= 64'd0;
            frame_valid_o      <= 1'b0;
            frame_address_o    <= 16'd0;
            frame_format_o     <= 8'd0;
            payload_length_o   <= 10'd0;
            sync_inverted_o    <= 1'b0;
            frame_error_o      <= 1'b0;
            frame_error_code_o <= 3'd0;
        end else begin
            frame_error_o <= 1'b0;

            if (state == ST_HOLD) begin
                if (frame_ready_i) begin
                    frame_valid_o <= 1'b0;
                    state <= ST_SEARCH;
                end
            end else if (accept_byte) begin
                case (state)
                    ST_SEARCH: begin
                        sync_shift <= sync_candidate;
                        if (sync_is_valid) begin
                            state           <= ST_ADDR;
                            addr_count      <= 3'd0;
                            address_shift   <= 16'd0;
                            sync_inverted_o <= (sync_xor == 16'hFFFF);
                        end
                    end

                    ST_ADDR: begin
                        if (addr_count == 3'd0) begin
                            address_shift[15:8] <= rx_data_i;
                            addr_count <= 3'd1;
                        end else begin
                            address_shift[7:0] <= rx_data_i;
                            addr_count <= 3'd0;
                            if (CHECK_ADDRESS && ({address_shift[15:8], rx_data_i} != EXPECTED_ADDRESS)) begin
                                frame_error_o      <= 1'b1;
                                frame_error_code_o <= 3'd1;
                                state              <= ST_SEARCH;
                            end else begin
                                state <= ST_FORMAT;
                            end
                        end
                    end

                    ST_FORMAT: begin
                        format_byte    <= rx_data_i;
                        payload_length <= format_to_length(rx_data_i);
                        if (format_to_length(rx_data_i) == 10'd0) begin
                            frame_error_o      <= 1'b1;
                            frame_error_code_o <= 3'd2;
                            state              <= ST_SEARCH;
                        end else begin
                            payload_count <= 10'd0;
                            tail_count    <= 3'd0;
                            tail_shift    <= 64'd0;
                            state         <= ST_DATA;
                        end
                    end

                    ST_DATA: begin
                        payload_data_o[(payload_count * 8) +: 8] <= rx_data_i;
                        if (payload_count == payload_length - 1'b1) begin
                            payload_count <= payload_count;
                            tail_count    <= 3'd0;
                            tail_shift    <= 64'd0;
                            state         <= ST_TAIL;
                        end else begin
                            payload_count <= payload_count + 1'b1;
                        end
                    end

                    ST_TAIL: begin
                        tail_shift <= {tail_shift[55:0], rx_data_i};
                        if (tail_count == 3'd7) begin
                            if ({tail_shift[55:0], rx_data_i} == FRAME_TAIL) begin
                                frame_address_o  <= address_shift;
                                frame_format_o   <= format_byte;
                                payload_length_o <= payload_length;
                                frame_valid_o    <= 1'b1;
                                state             <= ST_HOLD;
                            end else begin
                                frame_error_o      <= 1'b1;
                                frame_error_code_o <= 3'd3;
                                state              <= ST_SEARCH;
                            end
                        end else begin
                            tail_count <= tail_count + 1'b1;
                        end
                    end

                    default: state <= ST_SEARCH;
                endcase
            end
        end
    end
endmodule
