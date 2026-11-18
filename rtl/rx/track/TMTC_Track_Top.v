`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/10/26 12:02:08
// Design Name: 
// Module Name: TMTC_Track_Top
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


module TMTC_Track_Top(
    clk,
    rst,
    sample_in_valid,
    sample_in_i,
    sample_in_q,
    Track_enable,
    fcw_preset_valid,
    fcw_preset,
    PLL_C1,
    PLL_C2,
    PLL_C3,
    DDLL_C1,
    DDLL_C2,
    DTTL_mode,
    track_lock,
    track_lock_valid,
    symbol_out_valid,
    symbol_out
    // pll_temp1,
    // pll_temp2,
    // pll_temp3,
    // pll_temp4
    );

input clk;
input rst;
input sample_in_valid;
input [11:0] sample_in_i;
input [11:0] sample_in_q;
input Track_enable;
input fcw_preset_valid;
input [35:0] fcw_preset;
input [19:0] PLL_C1;        // 125
input [19:0] PLL_C2;        // 4315
input [19:0] PLL_C3;        // 295411
input [23:0] DDLL_C1;       // 378
input [23:0] DDLL_C2;       // 17
input [1:0] DTTL_mode;
output reg track_lock;
output reg track_lock_valid;
output symbol_out_valid;
output signed [21:0] symbol_out;
// output [26:0] pll_temp1;
// output [27:0] pll_temp2;
// output [35:0] pll_temp3;
// output [36:0] pll_temp4;

parameter DDLL_PD_period = 12'd1024;
parameter PLL_PD_period = 12'd2048;
parameter OSR = 12'd8;
parameter Gold_Seq_M1_Poly = 10'b1110100110;
parameter Gold_Seq_M2_Poly = 10'b1000000100;
parameter Gold_Seq_M1_init = 10'b0001001011;
parameter Gold_Seq_M2_init = 10'b1100010000;

wire FCW_en;
wire [35:0] FCW;
wire sample_en;
wire [7:0] sample_i;
wire [7:0] sample_q;

wire coherent_out_en;
wire signed [18:0] coherent_out_i;
wire signed [18:0] coherent_out_q;
wire chip_out_en;
wire signed [10:0] chip_out_i;
wire signed [10:0] chip_out_q;

wire               dttl_rst;
wire               dttl_restart_half_phase;
wire               dttl_restart_pulse;
wire               dttl_symbol_valid_raw;
wire signed [21:0] dttl_middle_out;
wire               dttl_pd_en;
wire signed [16:0] dttl_pd_out;
wire               dttl_fcw_update_en;
wire signed [25:0] dttl_fcw_modifying;
wire        [24:0] dttl_fcw_out;
wire        [31:0] dttl_nco_out;
wire               dttl_trig;

wire dttl_debug_event;

assign dttl_debug_event = symbol_out_valid | dttl_pd_en | dttl_fcw_update_en;
assign dttl_restart_half_phase = dttl_rst && !rst && Track_enable;

reg [3:0] lock_count;
reg [3:0] loss_count;
wire [18:0] coherent_abs_i = coherent_out_i[18] ?
    (~coherent_out_i + 1'b1) : coherent_out_i;
wire [18:0] coherent_abs_q = coherent_out_q[18] ?
    (~coherent_out_q + 1'b1) : coherent_out_q;
wire carrier_in_lock = (coherent_abs_i != 19'd0) && (coherent_abs_q <= coherent_abs_i);

always @(posedge clk)
begin
    if (rst || !Track_enable)
    begin
        track_lock       <= 1'b0;
        track_lock_valid <= 1'b0;
        lock_count       <= 4'd0;
        loss_count       <= 4'd0;
    end
    else
    begin
        // 默认清除有效脉冲，仅在锁定状态确认变化时置位一个时钟周期。
        track_lock_valid <= 1'b0;

        if (coherent_out_en)
        begin
            if (carrier_in_lock)
            begin
                loss_count <= 4'd0;

                if (!track_lock)
                begin
                    if (lock_count == 4'd7)
                    begin
                        track_lock       <= 1'b1;
                        track_lock_valid <= 1'b1;
                        lock_count       <= 4'd0;
                    end
                    else
                    begin
                        lock_count <= lock_count + 1'b1;
                    end
                end
            end
            else
            begin
                lock_count <= 4'd0;

                if (track_lock)
                begin
                    if (loss_count == 4'd7)
                    begin
                        track_lock       <= 1'b0;
                        track_lock_valid <= 1'b1;
                        loss_count       <= 4'd0;
                    end
                    else
                    begin
                        loss_count <= loss_count + 1'b1;
                    end
                end
            end
        end
    end
end

PLL_NCO PLL_DDS(
    .clk(clk),
    .rst(rst),
    .sample_in_en(sample_in_valid),
    .sample_in_i(sample_in_i),
    .sample_in_q(sample_in_q),
    .FCW_preset_en(fcw_preset_valid),
    .FCW_preset(fcw_preset),
    .FCW_en(FCW_en),
    .FCW(FCW),
    .sample_out_en(sample_en),
    .sample_out_i(sample_i),
    .sample_out_q(sample_q)
);

DDLL_Module_Top DDLL(
    .clk(clk),
    .rst(rst),
    .Enable(Track_enable),
    .Coherent_length_PD(DDLL_PD_period),
    .Coherent_length_I(PLL_PD_period),
    .Chip_osr(OSR),
    .C1(DDLL_C1),
    .C2(DDLL_C2),
    .Poly1(Gold_Seq_M1_Poly),
    .Poly2(Gold_Seq_M2_Poly),
    .init_Poly1(Gold_Seq_M1_init),
    .init_Poly2(Gold_Seq_M2_init),
    .sample_in_en(sample_en),
    .sample_in_i(sample_i),
    .sample_in_q(sample_q),
    .coherent_out_en(coherent_out_en),
    .coherent_out_i(coherent_out_i),
    .coherent_out_q(coherent_out_q),
    .chip_out_en(chip_out_en),
    .chip_out_i(chip_out_i),
    .chip_out_q(chip_out_q)
);

PLL_PDnLP PLL_PD(
    .clk(clk),
    .rst(rst),
    .signal_en(coherent_out_en),
    .signal_i(coherent_out_i),
    .signal_q(coherent_out_q),
    .C1(PLL_C1),
    .C2(PLL_C2),
    .C3(PLL_C3),
    .FCW_en(FCW_en),
    .FCW_modifying(FCW)
);

// Monitor raw DTTL integrals; only DTTL receives the local reset.
DTTL_Supervisor u_DTTL_Supervisor( 
    .clk(clk),
    .rst(rst),
    .enable(Track_enable),
    .mode(DTTL_mode),
    .symbol_valid(dttl_symbol_valid_raw),
    .entire_in(symbol_out),
    .middle_in(dttl_middle_out),
    .dttl_rst(dttl_rst),
    .restart_pulse(dttl_restart_pulse)
);

assign symbol_out_valid = dttl_symbol_valid_raw && !dttl_rst;

DTTL_Top DTTL(
    .clk(clk),
    .rst(dttl_rst),
    .update_en(chip_out_en && !dttl_rst),
    .restart_half_phase(dttl_restart_half_phase),
    .MODE(DTTL_mode),
    .data_in(chip_out_i),

    .entire_en(dttl_symbol_valid_raw),
    .entire_out(symbol_out),
    .middle_out(dttl_middle_out),

    .PD_en(dttl_pd_en),
    .PD_out(dttl_pd_out),

    .FCW_update_en(dttl_fcw_update_en),
    .FCW_modifying(dttl_fcw_modifying),
    .FCW_out(dttl_fcw_out),
    .NCO_out(dttl_nco_out),
    .trig(dttl_trig)
);
wire        decoded_frame_valid;
wire [15:0] decoded_address;
wire [7:0]  decoded_format;
wire [9:0]  decoded_length;
wire [4095:0] decoded_payload;

telecommand_deframer u_deframer (
    .clk                (clk),
    .rst                (rst | dttl_rst),

    .symbol_valid_i     (symbol_out_valid),
    .symbol_data_i      (symbol_out),

    .rx_ready_o         (),

    // 当前测试先保持可以接收解帧结果。
    .frame_ready_i      (1'b1),
    .frame_valid_o      (decoded_frame_valid),
    .frame_address_o    (decoded_address),
    .frame_format_o     (decoded_format),
    .payload_length_o   (decoded_length),
    .payload_data_o     (decoded_payload),

    .sync_inverted_o    (),
    .frame_error_o      (),
    .frame_error_code_o (),
    .preamble_valid_o   (),
    .preamble_bytes_o   ()
);


endmodule
