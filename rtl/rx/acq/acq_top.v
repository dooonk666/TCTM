`timescale 1ns / 1ps
// three-stage acquisition top.
// A producer writes one 32768-sample frequency block while a consumer scans
// the opposite bank over 2046 code phases. Stage boundaries wait for the last
// scan result before the next stage frequency can be selected.
module acq_top #(
    parameter integer ADC_WID         = 12,
    parameter integer FIR_WID         = 12,
    parameter integer ACQ_WID         = 3,
    parameter integer COH_WID         = ACQ_WID + 7,//10
    parameter integer POWER_CUT       = 3,
    parameter integer POWER_WID       = 2*(COH_WID+1-POWER_CUT)+1+7,//24
    parameter integer FFT_INPUT_CUT   = 4,
    parameter integer FFT_OUTPUT_CUT  = 4,
    parameter integer FFT_IN_WID      = 2*COH_WID-FFT_INPUT_CUT,
    parameter integer FFT_OUT_WID     = FFT_IN_WID+8-FFT_OUTPUT_CUT,
    parameter integer ROW_WID         = 128*2*ACQ_WID,
    parameter integer SUM_WID         = POWER_WID+11,
    parameter integer COARSE_NUM      = 39,
    parameter [POWER_WID-1:0] POWER_THRESHOLD = 782
) (
    input  wire                      clk,
    input  wire                      rst,
    input  wire                      start_en_i,
    input  wire                      din_en,
    input  wire signed [ADC_WID-1:0] din_i,
    input  wire signed [ADC_WID-1:0] din_q,
    output wire                      din_ready_en_o,
    output wire                      busy_en_o,
    output wire                      done_en_o,
    output wire                      success_en_o,
    output reg [10:0]                code_phase_o,
    output reg signed [19:0]         coarse_freq_o,
    output reg signed [31:0]         residual_freq_o,
    output reg signed [31:0]         cfo_estimate_o,
    output reg [POWER_WID-1:0]       peak_power_o,
    output wire signed [31:0]        tracking_fcw_o,
    output wire                      tracking_fcw_valid_o,
    output wire                      pn0_valid_o,
    output wire                      fft_error_en_o,
    output wire                     track_sample_valid_o,//fir_o
    output wire signed [FIR_WID-1:0] track_sample_i_o,
    output wire signed [FIR_WID-1:0] track_sample_q_o,
    output wire [34:0]              dbg_par_product_o,
    output wire [SUM_WID-1:0]       dbg_sum_pipe_o,
    output wire                     dbg_stat_done_o,
    output wire                     dbg_stat_success_o
);

localparam integer STORE_SAMPLE_NUM = 32768;
localparam integer RES_MULT_LATENCY = 3;
// Power and FFT results are produced by different pipelines. This small FIFO
// associates the power/code metadata with each FFT-frame peak.
reg [POWER_WID-1:0] meta_power [0:15];//power of 2046 codephase
reg [10:0] meta_code [0:15];
reg [4:0] meta_wr, meta_rd;// 元数据 FIFO：对齐同一码相位的功率与 FFT 结果，送入统计模块。
wire meta_last = (meta_code[meta_rd[3:0]] == 11'd2045);
wire [POWER_WID-1:0] stat_power_i = meta_power[meta_rd[3:0]];
// Ping-pong store and phase-scan path.
wire store_full;
reg scan_active;
reg read_en;
reg scan_bank;
reg [7:0] row_addr;
reg [10:0] code_phase;
reg pn_init;
reg stat_clear;
wire store_rd_en;
wire [7:0] store_row;
wire [ROW_WID-1:0] store_data;
reg [ROW_WID-1:0] store_data_d1;
reg store_last_d1;

wire pn_en;
wire [127:0] pn_data;
wire coh_en, coh_last;
wire signed [COH_WID-1:0] coh_i, coh_q;
wire power_en;
wire [POWER_WID-1:0] phase_power;
wire square_en, square_last;
wire signed [FFT_IN_WID-1:0] square_i, square_q;
wire fft_ready, fft_en, fft_last;
wire signed [FFT_OUT_WID-1:0] fft_i, fft_q;
wire [7:0] fft_bin;
wire peak_en;
wire [FFT_OUT_WID:0] fft_peak_value;
wire [7:0] fft_peak_bin;
wire stat_done, stat_success;
assign dbg_stat_done_o = stat_done;
assign dbg_stat_success_o = stat_success;
wire [POWER_WID-1:0] stat_max;
wire [10:0] stat_code;
wire [7:0] stat_bin;
wire [SUM_WID-1:0] stat_sum;
// Stage controller interface.
wire ctrl_capture_start;
wire ctrl_capture_bank;
wire [5:0] ctrl_capture_freq;
wire ctrl_scan_start;
wire ctrl_scan_bank;
wire [5:0] ctrl_scan_freq;
wire ctrl_math_start;
wire [5:0] ctrl_final_freq;
wire [10:0] ctrl_final_code;
wire [7:0] ctrl_final_bin;
wire [POWER_WID-1:0] ctrl_final_max;
wire [SUM_WID-1:0] ctrl_final_sum;
wire [1:0] ctrl_stage;
wire ctrl_overflow;
reg final_math_done;

// Front-end and capture path.
wire fir_en;
wire fir_valid_en;
wire signed [FIR_WID-1:0] fir_i, fir_q;
wire ds_en;
wire signed [FIR_WID-1:0] ds_i, ds_q;
reg capture_en;
reg capture_start_pending;
reg [14:0] capture_sample_count;
reg capture_bank;
reg [5:0] capture_freq;
reg fcw_en;
reg phase_init;
reg store_clear;
wire signed [31:0] capture_fcw;
wire signed [19:0] capture_freq_hz_unused;
wire mix_en;
wire signed [ACQ_WID-1:0] mix_i, mix_q;



assign track_sample_valid_o = fir_valid_en;
assign track_sample_i_o = fir_i;
assign track_sample_q_o = fir_q;





// Final residual-frequency hardware.
wire signed [8:0] final_signed_bin =
    (ctrl_final_bin >= 8'd128) ?
    ($signed({1'b0,ctrl_final_bin}) - 9'sd256) :
     $signed({1'b0,ctrl_final_bin});
wire signed [31:0] residual_product;
wire signed [31:0] residual_scaled = residual_product >>> 15;
reg [RES_MULT_LATENCY-1:0] residual_valid_pipe;
wire signed [31:0] final_coarse_fcw;
wire signed [19:0] final_coarse_hz;

acq_freq_lut u_capture_freq_lut (
    .index_i   (ctrl_capture_start ? ctrl_capture_freq : capture_freq),
    .fcw_o     (capture_fcw),
    .freq_hz_o (capture_freq_hz_unused)
);

acq_freq_lut u_final_freq_lut (
    .index_i   (ctrl_final_freq),
    .fcw_o     (final_coarse_fcw),
    .freq_hz_o (final_coarse_hz)
);

wire final_bank_first_2x = (ctrl_stage == 2'd2) && capture_en && ds_en &&
                            (capture_sample_count == 15'd0);// 当前阶段写入采样 bank 的第一个样本。

acq_track_handoff u_track_handoff (
    .clk                    (clk),
    .rst                    (rst),
    .sample_8x_valid_i      (fir_valid_en),// 滤波后采样有效信号。
    .final_bank_first_2x_i  (final_bank_first_2x),
    .result_valid_i         (final_math_done),
    .result_success_i       (success_en_o),
    .code_phase_2x_i        (ctrl_final_code),
    .coarse_fcw_2x_i        (final_coarse_fcw),
    .residual_bin_i         (final_signed_bin),
    .pn0_valid_o            (pn0_valid_o),
    .tracking_fcw_valid_o   (tracking_fcw_valid_o),
    .tracking_fcw_o         (tracking_fcw_o)
);

//Fs_fft = 2*Rchip/128
//2*fd = fft_bin*Fs_fft/256
//fd = fft_bin*Rchip/32768
//residual_freq_hz = fft_bin*3069000/2^15
//residual_fcw_8x
//    = fd/(8*Rchip)*2^32
//    = fft_bin*2^14
mult_9x23 u_residual_mult (
    .CLK (clk),
    .A   (final_signed_bin),
    .B   (23'sd3069000),
    .P   (residual_product)
);

acq_ctrl #(
    .POWER_WID  (POWER_WID),
    .SUM_WID    (SUM_WID),
    .COARSE_NUM (COARSE_NUM)
) u_acq_ctrl (
    .clk                (clk),
    .rst                (rst),
    .start_i            (start_en_i),
    .store_full_i       (store_full),
    .scan_done_i        (stat_done),
    .scan_success_i     (stat_success),
    .scan_max_i         (stat_max),
    .scan_code_i        (stat_code),
    .scan_bin_i         (stat_bin),
    .scan_sum_i         (stat_sum),
    .final_math_done_i  (final_math_done),
    .capture_start_o    (ctrl_capture_start),
    .capture_bank_o     (ctrl_capture_bank),
    .capture_freq_o     (ctrl_capture_freq),
    .scan_start_o       (ctrl_scan_start),
    .scan_bank_o        (ctrl_scan_bank),
    .scan_freq_o        (ctrl_scan_freq),
    .final_math_start_o (ctrl_math_start),
    .final_freq_o       (ctrl_final_freq),
    .final_code_o       (ctrl_final_code),
    .final_bin_o        (ctrl_final_bin),
    .final_max_o        (ctrl_final_max),
    .final_sum_o        (ctrl_final_sum),
    .stage_o            (ctrl_stage),
    .busy_o             (busy_en_o),
    .done_o             (done_en_o),
    .success_o          (success_en_o),
    .overflow_o         (ctrl_overflow)
);

// Capture, scan and final-result sequencing. All arithmetic IP latency is
// represented by explicit valid pipelines or by the IP's AXI valid signal.
always @(posedge clk or posedge rst)
begin
    if (rst)
    begin
        capture_en <= 1'b0;
        capture_start_pending <= 1'b0;
        capture_sample_count <= 15'd0;
        capture_bank <= 1'b0;
        capture_freq <= 6'd0;
        fcw_en <= 1'b0;
        phase_init <= 1'b0;
        store_clear <= 1'b0;
        scan_active <= 1'b0;
        read_en <= 1'b0;
        scan_bank <= 1'b0;
        row_addr <= 8'd0;
        code_phase <= 11'd0;
        pn_init <= 1'b0;
        stat_clear <= 1'b0;
        store_data_d1 <= {ROW_WID{1'b0}};
        store_last_d1 <= 1'b0;
        meta_wr <= 5'd0;
        meta_rd <= 5'd0;
        residual_valid_pipe <= {RES_MULT_LATENCY{1'b0}};
        final_math_done <= 1'b0;
        code_phase_o <= 11'd0;
        coarse_freq_o <= 20'sd0;
        residual_freq_o <= 32'sd0;
        cfo_estimate_o <= 32'sd0;
        peak_power_o <= {POWER_WID{1'b0}};
    end
    else
    begin
        fcw_en <= 1'b0;
        phase_init <= 1'b0;
        store_clear <= 1'b0;
        pn_init <= 1'b0;
        stat_clear <= 1'b0;
        final_math_done <= 1'b0;
        residual_valid_pipe <= {residual_valid_pipe[RES_MULT_LATENCY-2:0],
                                ctrl_math_start};

        if (ctrl_capture_start)
        begin
            capture_en <= 1'b0;
            capture_start_pending <= 1'b1;
            capture_sample_count <= 15'd0;
            capture_bank <= ctrl_capture_bank;
            capture_freq <= ctrl_capture_freq;
            fcw_en <= 1'b1;
            phase_init <= 1'b1;
            store_clear <= 1'b1;
        end
        else if (capture_start_pending)
        begin
            capture_start_pending <= 1'b0;
            capture_en <= 1'b1;
        end

        if (capture_en && ds_en)
        begin
            if (capture_sample_count == STORE_SAMPLE_NUM-1)
                capture_en <= 1'b0;
            else
                capture_sample_count <= capture_sample_count + 1'b1;
        end

        if (ctrl_scan_start)
        begin
            scan_active <= 1'b1;
            scan_bank <= ctrl_scan_bank;
            row_addr <= 8'd0;
            code_phase <= 11'd0;
            read_en <= 1'b1;
            pn_init <= 1'b1;
            stat_clear <= 1'b1;
            meta_wr <= 5'd0;
            meta_rd <= 5'd0;
        end

        if (read_en && fft_ready)
        begin
            if (row_addr == 8'd255)
                read_en <= 1'b0;
            else
                row_addr <= row_addr + 1'b1;
        end

        if (square_last && scan_active)
        begin
            if (code_phase == 11'd2045)
            begin
                scan_active <= 1'b0;
                read_en <= 1'b0;
            end
            else
            begin
                code_phase <= code_phase + 1'b1;
                row_addr <= 8'd0;
                read_en <= 1'b1;
            end
        end

        if (store_rd_en)
        begin
            store_data_d1 <= store_data;
            store_last_d1 <= (store_row == 8'd255);
        end
        if (power_en)
        begin
            meta_power[meta_wr[3:0]] <= phase_power;
            meta_code[meta_wr[3:0]] <= code_phase;
            meta_wr <= meta_wr + 1'b1;
        end
        if (peak_en)
            meta_rd <= meta_rd + 1'b1;

        if (residual_valid_pipe[RES_MULT_LATENCY-1])
        begin
            coarse_freq_o <= final_coarse_hz;
            residual_freq_o <= residual_scaled;
            cfo_estimate_o <= {{12{final_coarse_hz[19]}},final_coarse_hz} +
                              residual_scaled;
            code_phase_o <= ctrl_final_code + 1'b1;
            peak_power_o <= ctrl_final_max;
            final_math_done <= 1'b1;
        end
    end
end
acq_frontend_filter #(
.ADC_WID(ADC_WID),
.DATA_WID(FIR_WID)
) u_filter (
    .clk(clk),
    .rst(rst),
    .din_en(din_en),
    .din_i(din_i),
    .din_q(din_q),
    .ready_en_o(din_ready_en_o),
    .dout_en_o(fir_en),
    .dout_i(fir_i),
    .dout_q(fir_q),
    .dout_valid_en(fir_valid_en)
);

downsample #(.DATA_WID(FIR_WID)) u_downsample (
    .clk(clk),
    .rst(rst),
    .din_en(fir_valid_en),
    .din_i(fir_i),
    .din_q(fir_q),
    .dout_en_o(ds_en),
    .dout_i(ds_i),
    .dout_q(ds_q)
);

mix_freq #(
.DATA_WID(FIR_WID),
.ACQ_WID(ACQ_WID)
) u_mix_freq (
    .clk(clk),
    .rst(rst),
    .din_en(ds_en && capture_en),
    .din_i(ds_i),
    .din_q(ds_q),
    .fcw_en(fcw_en),
    .phase_init_i(phase_init),
    .fcw(capture_fcw),
    .dout_en(mix_en),
    .dout_i(mix_i),
    .dout_q(mix_q)
);

sample_store #(
.DATA_WID(ACQ_WID)
) u_store (
    .clk(clk),.rst(rst),.clear_en_i(store_clear),
    .wr_bank_i(capture_bank),.wr_en_i(mix_en),.wr_i_i(mix_i),.wr_q_i(mix_q),
    .full_en_o(store_full),.rd_bank_i(scan_bank),
    .rd_en_i(read_en && fft_ready),.rd_addr_i(row_addr),
    .rd_en_o(store_rd_en),.rd_addr_o(store_row),.rd_data_o(store_data)
);

pn_code u_pn (
    .clk(clk),
    .rst(rst),
    .init_i(pn_init),
    .din_en_i(store_rd_en),
    .row_addr_i(store_row),
    .code_phase_i(code_phase),
    .dout_en_o(pn_en),
    .pn_o(pn_data)
);

coh_sum #(.DATA_WID(ACQ_WID),.COH_WID(COH_WID)) u_coh (
    .clk(clk),.rst(rst),.din_en_i(pn_en),.din_i(store_data_d1),.pn_i(pn_data),
    .last_en_i(store_last_d1),.dout_en_o(coh_en),.dout_i(coh_i),
    .dout_q(coh_q),.last_en_o(coh_last)
);

power_acc #(
.COH_WID(COH_WID),
.POWER_CUT(POWER_CUT),
.POWER_WID(POWER_WID)
) codephase_power (
    .clk(clk),
    .rst(rst),
    .clear_en_i(stat_clear),
    .din_en_i(coh_en),
    .din_i(coh_i),
    .din_q(coh_q),
    .last_en_i(coh_last),
    .dout_en_o(power_en),
    .power_o(phase_power)
);

complex_square #(.COH_WID(COH_WID),.FFT_CUT(FFT_INPUT_CUT),.FFT_WID(FFT_IN_WID)) u_square (
    .clk(clk),.rst(rst),.din_en_i(coh_en),.din_i(coh_i),.din_q(coh_q),
    .last_en_i(coh_last),.dout_en_o(square_en),.dout_i(square_i),
    .dout_q(square_q),.last_en_o(square_last)
);

fft_ctrl #(
.FFT_IN_WID(FFT_IN_WID),
.FFT_OUT_CUT(FFT_OUTPUT_CUT),
.FFT_OUT_WID(FFT_OUT_WID)
) u_fft (
    .clk(clk),
    .rst(rst),
    .din_en_i(square_en),
    .din_i(square_i),
    .din_q(square_q),
    .last_en_i(square_last),
    .ready_en_o(fft_ready),
    .dout_en_o(fft_en),
    .dout_i(fft_i),
    .dout_q(fft_q),
    .bin_o(fft_bin),
    .last_en_o(fft_last),
    .error_en_o(fft_error_en_o)
);

fft_peak #(.DATA_WID(FFT_OUT_WID)) fft_peak (
    .clk(clk),.rst(rst),.din_en_i(fft_en),.din_i(fft_i),.din_q(fft_q),
    .bin_i(fft_bin),.last_en_i(fft_last),.dout_en_o(peak_en),
    .peak_o(fft_peak_value),.peak_bin_o(fft_peak_bin)
);

acq_statistics_v2 #(
    .POWER_WID(POWER_WID),.SUM_WID(SUM_WID),.POWER_THRESHOLD(POWER_THRESHOLD)
) u_stat (
    .clk(clk),
    .rst(rst),
    .clear_i(stat_clear),
    .valid_i(peak_en),
    .power_i(stat_power_i),
    .code_i(meta_code[meta_rd[3:0]]),
    .bin_i(fft_peak_bin),
    .last_i(meta_last),
    .done_o(stat_done),
    .success_o(stat_success),
    .max_o(stat_max),
    .code_o(stat_code),
    .bin_o(stat_bin),
    .sum_o(stat_sum),
    .dbg_par_product_o(dbg_par_product_o),
    .dbg_sum_pipe_o(dbg_sum_pipe_o)
);

endmodule
