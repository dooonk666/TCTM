`timescale 1ns / 1ps
// Acquisition-to-tracking handoff.
// sample_8x_valid_i is the valid of the 8-sample/chip stream consumed by
// DDLL/PLL.  The module timestamps the first 2x sample of the final capture,
// predicts the next PN phase-zero sample after acquisition processing, and
// supplies the carrier FCW for an NCO clock-enabled at the 8x sample rate.
// 把捕获模块算出的码相位转换成跟踪模块所需的 PN=0 时刻，
// 当实时 8 倍采样计数器到达该位置时输出一次 pn0_valid_o。
//A_8x=(a_8x+4*code_index) mod 8184
module acq_track_handoff (
    input  wire                    clk,
    input  wire                    rst,
    input  wire                    sample_8x_valid_i,
    input  wire                    final_bank_first_2x_i,//第三阶段输入bank第一个数标志
    input  wire                    result_valid_i, //捕获两阶段结果计算完成
    input  wire                    result_success_i, //par通过
    input  wire [10:0]             code_phase_2x_i, //bank第一个数到pn=0距离
    input  wire signed [31:0]      coarse_fcw_2x_i,
    input  wire signed [8:0]       residual_bin_i,
    output reg                     pn0_valid_o, //单脉冲周期
    output reg                     tracking_fcw_valid_o,
    output reg signed [31:0]       tracking_fcw_o
);

localparam [13:0] PN_PERIOD_8X = 14'd8184;
localparam [12:0] PN_LAST_8X   = 13'd8183;

// live_phase_8x is the modulo-8184 index assigned to the next accepted 8x
// sample.  The final 2x output is registered from the preceding 8x sample,
// hence final_bank_first_2x_i timestamps live_phase_8x-1.
reg [12:0] live_phase_8x; //实时计数器
reg [12:0] final_bank_start_8x;
reg        pn0_armed;

// 捕获结果经过两级运算：第一级做加法，第二级做取模和频率合成。//A_8x=(a_8x+4*code_index) mod 8184
// valid/success 。
reg        result_valid_d1;
reg        result_success_d1;
reg        result_valid_d2;
reg        result_success_d2;

// 第一级计算结果和随数据保存的频率控制字。
reg [13:0] pn0_phase_sum;
reg signed [31:0] coarse_fcw_8x_saved;
reg signed [31:0] residual_fcw_8x_saved;

// 第二级运算得到的最终目标相位和跟踪频率控制字。
reg [12:0] target_pn0_phase_8x;
reg signed [31:0] calculated_tracking_fcw;

wire [13:0] offset_to_zero_8x = {1'b0,code_phase_2x_i,2'b00};//a_8x = code_phase_2x_i*4

// The acquisition NCO runs on the 2x stream at 6.138 MHz.  The tracking NCO
// runs on the 8x stream at 24.552 MHz, so its coarse FCW is divided by four.
// One signed FFT bin is 3069000/32768 Hz, which is exactly 2^14 FCW units at
// 24.552 MHz; therefore no divider or multiplier is required here.
wire signed [31:0] residual_bin_ext ={{23{residual_bin_i[8]}},residual_bin_i};
wire signed [31:0] coarse_fcw_8x = $signed(coarse_fcw_2x_i) >>> 2;//R_8chip=2*R_4
wire signed [31:0] residual_fcw_8x = residual_bin_ext <<< 14;

// Single-cycle handoff strobes use mutually exclusive set/clear paths.
always @(posedge clk or posedge rst)
begin
    if (rst)
    begin
        pn0_valid_o <= 1'b0;
        tracking_fcw_valid_o <= 1'b0;
    end
    else
    begin
        if (!result_valid_d2 && pn0_armed && sample_8x_valid_i &&
            (live_phase_8x == target_pn0_phase_8x))
            pn0_valid_o <= 1'b1;
        else
            pn0_valid_o <= 1'b0;

        if (result_valid_d2 && result_success_d2)
            tracking_fcw_valid_o <= 1'b1;
        else
            tracking_fcw_valid_o <= 1'b0;
    end
end

always @(posedge clk or posedge rst)
begin
    if (rst)
    begin
        live_phase_8x <= 13'd0;
        final_bank_start_8x <= 13'd0;
        pn0_armed <= 1'b0;
        result_valid_d1 <= 1'b0;
        result_success_d1 <= 1'b0;
        pn0_phase_sum <= 14'd0;
        coarse_fcw_8x_saved <= 32'sd0;
        residual_fcw_8x_saved <= 32'sd0;
        result_valid_d2 <= 1'b0;
        result_success_d2 <= 1'b0;
        target_pn0_phase_8x <= 13'd0;
        calculated_tracking_fcw <= 32'sd0;
        tracking_fcw_o <= 32'sd0;
    end
    else
    begin
        result_valid_d1 <= result_valid_i;
        result_success_d1 <= result_success_i;
        result_valid_d2 <= result_valid_d1;
        result_success_d2 <= result_success_d1;

        if (result_valid_i)
        begin
            pn0_phase_sum <= {1'b0,final_bank_start_8x} + offset_to_zero_8x; //a+code_index
            coarse_fcw_8x_saved <= coarse_fcw_8x;
            residual_fcw_8x_saved <= residual_fcw_8x;
        end

        if (result_valid_d1)
        begin
            target_pn0_phase_8x <= (pn0_phase_sum >= PN_PERIOD_8X) ?// (A+index)mod 2046*4
                pn0_phase_sum - PN_PERIOD_8X : pn0_phase_sum[12:0];
            calculated_tracking_fcw <= coarse_fcw_8x_saved + residual_fcw_8x_saved;
        end

        if (sample_8x_valid_i)
        begin
            if (live_phase_8x == PN_LAST_8X)
                live_phase_8x <= 13'd0;
            else
                live_phase_8x <= live_phase_8x + 1'b1;
        end

        if (final_bank_first_2x_i)
            final_bank_start_8x <=(live_phase_8x == 13'd0) ? PN_LAST_8X : live_phase_8x - 1'b1; //记录最终bank第一个数据位置
            //ds_en 对应的是上一拍由 fir_valid_en 选中的8倍采样；这期间 live_phase_8x 已经加一，所以要减一才能得到当前写入 bank 的2倍采样所对应的8倍相位

        if (result_valid_d2)
        begin
            tracking_fcw_o <= calculated_tracking_fcw;
            if (result_success_d2)
                pn0_armed <= 1'b1;
            else
                pn0_armed <= 1'b0;
        end
        // live_phase_8x is the phase of the sample accepted on this edge.
        // Once armed, pulse exactly once when that sample reaches PN phase 0.
        else if (pn0_armed && sample_8x_valid_i &&
                 (live_phase_8x == target_pn0_phase_8x))
        begin
            pn0_armed <= 1'b0;
        end
    end
end

endmodule
