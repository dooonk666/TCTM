// PROPOSAL ONLY: control fixes for rec_top. Not used by project compile.do.
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/10/28 16:07:19
// Design Name: 
// Module Name: rec_top
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


module rec_top(
    input clk,
    input rst,
    input rx_adc_en,
    input signed [11:0] rx_adc_i,
    input signed [11:0] rx_adc_q,
    input wire [1:0] DTTL_mode,
    input wire [19:0] PLL_C1,
    input wire [19:0] PLL_C2,
    input wire [19:0] PLL_C3,
    output wire [2:0]  dbg_rx_state,
    output wire        dbg_start,
    output wire        dbg_acq_busy,
    output wire        dbg_acq_done,
    output wire        dbg_acq_success,
    output wire        dbg_fft_error,
    output wire [10:0] dbg_code_phase,
    output wire        dbg_pn0_valid,
    output wire [34:0] dbg_par_product,
    output wire [34:0] dbg_sum_pipe,
    output wire        dbg_ctrl_done
    );

    parameter integer ADC_WID         = 12;
    parameter integer FIR_WID         = 12;
    parameter integer ACQ_WID         = 3;
    parameter integer COH_WID         = ACQ_WID + 7;//10
    parameter integer POWER_CUT       = 3;
    parameter integer POWER_WID       = 2*(COH_WID+1-POWER_CUT)+1+7;//24
    parameter integer FFT_INPUT_CUT   = 4;
    parameter integer FFT_OUTPUT_CUT  = 4;
    parameter integer FFT_IN_WID      = 2*COH_WID-FFT_INPUT_CUT;
    parameter integer FFT_OUT_WID     = FFT_IN_WID+8-FFT_OUTPUT_CUT;
    parameter integer ROW_WID         = 128*2*ACQ_WID;
    parameter integer SUM_WID         = POWER_WID+11;
    parameter integer COARSE_NUM      = 39;
    parameter [POWER_WID-1:0] POWER_THRESHOLD = 782;

    reg                       start_en_i;
    wire                      acq_din_ready_en_o;
    wire                      acq_busy_en_o;
    wire                      acq_done_en_o;
    wire                      acq_success_en_o;
    wire                      acq_stat_done_en_o;
    wire                      acq_stat_success_en_o;
    wire [10:0]               acq_code_phase_o;
    wire signed [19:0]        acq_coarse_freq_o;
    wire signed [31:0]        acq_residual_freq_o;
    wire signed [31:0]        acq_cfo_estimate_o;
    wire [POWER_WID-1:0]      acq_peak_power_o;
    wire signed [31:0]        acq_tracking_fcw_o;
    wire                      acq_tracking_fcw_valid_o;
    wire                      acq_pn0_valid_o;
    wire                      acq_fft_error_en_o;
    wire                      acq_track_sample_valid_o;//fir_o
    wire signed [FIR_WID-1:0] acq_track_sample_i_o;
    wire signed [FIR_WID-1:0] acq_track_sample_q_o;


    
    reg Track_enable;
    reg fcw_preset_valid;
    reg [35:0] fcw_preset;
    reg [23:0] DDLL_C1;       // 378
    reg [23:0] DDLL_C2;       // 17
    wire track_lock;
    wire track_lock_valid;
    wire track_symbol_out_valid;
    wire signed [21:0] track_symbol_out;
    reg [2:0] rx_state;
    reg [2:0] rx_state_next;
    reg       fcw_received;
    

    assign dbg_start    = start_en_i;
    assign dbg_acq_busy = acq_busy_en_o;
    assign dbg_rx_state         = rx_state;
    assign dbg_acq_done         = acq_stat_done_en_o;
    assign dbg_acq_success      = acq_stat_success_en_o;
    assign dbg_ctrl_done        = acq_done_en_o;
    assign dbg_fft_error        = acq_fft_error_en_o;
    assign dbg_code_phase       = acq_code_phase_o;
    assign dbg_pn0_valid        = acq_pn0_valid_o;
    
        // 跟踪模块控制。
    // 接收机状态定义。
    // Control states. Keep RX_TRACK=2 for existing waveform/testbench labels.
    localparam [2:0] RX_IDLE     = 3'd0;
    localparam [2:0] RX_ACQ      = 3'd1;
    localparam [2:0] RX_TRACK    = 3'd2;
    localparam [2:0] RX_WAIT_FCW = 3'd3;
    wire track_rst;
    reg [1:0]track_reset_cnt;
    always @(posedge clk or posedge rst) begin
        if (rst)
            track_reset_cnt <= 2'b0;
        else if (rx_state != RX_IDLE)
            track_reset_cnt <= 2'b0;
        else if (track_reset_cnt < 2'd3)
            track_reset_cnt <= track_reset_cnt + 1'b1;
    end
    
    assign track_rst = rst | (rx_state == RX_IDLE);

    acq_top u_acq_top(
        .clk(clk),
        .rst(rst),
        
        .start_en_i(start_en_i),
        .din_en(rx_adc_en),
        .din_i(rx_adc_i),
        .din_q(rx_adc_q),
        .din_ready_en_o(acq_din_ready_en_o),
        
        .busy_en_o(acq_busy_en_o),
        .done_en_o(acq_done_en_o),
        .success_en_o(acq_success_en_o),
        .code_phase_o(acq_code_phase_o),
        .coarse_freq_o(acq_coarse_freq_o),
        .residual_freq_o(acq_residual_freq_o),
        .cfo_estimate_o(acq_cfo_estimate_o),
        .peak_power_o(acq_peak_power_o),
        .tracking_fcw_o(acq_tracking_fcw_o),
        .tracking_fcw_valid_o(acq_tracking_fcw_valid_o),
        .pn0_valid_o(acq_pn0_valid_o),
        .fft_error_en_o(acq_fft_error_en_o),
        .track_sample_valid_o(acq_track_sample_valid_o),
        .track_sample_i_o(acq_track_sample_i_o),
        .track_sample_q_o(acq_track_sample_q_o),
        .dbg_par_product_o(dbg_par_product),
        .dbg_sum_pipe_o(dbg_sum_pipe),
        .dbg_stat_done_o(acq_stat_done_en_o),
        .dbg_stat_success_o(acq_stat_success_en_o)
    );
    
    TMTC_Track_Top u_TMTC_Track_Top(
        .clk(clk),
        .rst(track_rst),
        .sample_in_valid(acq_track_sample_valid_o),
        .sample_in_i(acq_track_sample_i_o),
        .sample_in_q(acq_track_sample_q_o),
        
        .Track_enable(Track_enable),
        .fcw_preset_valid(fcw_preset_valid),
        .fcw_preset(fcw_preset),
        .PLL_C1(PLL_C1),
        .PLL_C2(PLL_C2),
        .PLL_C3(PLL_C3),
        .DDLL_C1(DDLL_C1),
        .DDLL_C2(DDLL_C2),
        .DTTL_mode(DTTL_mode),
        
        .track_lock(track_lock),
        .track_lock_valid(track_lock_valid),
        .symbol_out_valid(track_symbol_out_valid),
        .symbol_out(track_symbol_out)
    );


    localparam [23:0] DDLL_C1_VALUE = 24'd378;
    localparam [23:0] DDLL_C2_VALUE = 24'd17;


    // Capture only the first FCW belonging to an acquisition/handoff session.
    wire accept_acq_fcw =
        ((rx_state == RX_ACQ) || (rx_state == RX_WAIT_FCW)) &&
        !fcw_received && acq_tracking_fcw_valid_o;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            fcw_preset       <= 36'd0;
            fcw_preset_valid <= 1'b0;
            fcw_received     <= 1'b0;
        end 
        else begin
            // This edge also starts the new acquisition in u_acq_top.
            if (start_en_i) begin
                fcw_received <= 1'b0;
                fcw_preset_valid <= 1'b0;
            end else if (accept_acq_fcw) begin
                fcw_preset       <= {acq_tracking_fcw_o, 4'b0000};
                fcw_preset_valid <= 1'b1;
                fcw_received     <= 1'b1;
            end
            else  fcw_preset_valid <= 1'b0;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rx_state  <= RX_IDLE;
            DDLL_C1   <= DDLL_C1_VALUE;
            DDLL_C2   <= DDLL_C2_VALUE;
        end else begin
            rx_state <= rx_state_next;
        end
    end

    always @(*) begin
        start_en_i   = 1'b0;
        Track_enable = 1'b0;
        rx_state_next = rx_state;

        // Holding RX_IDLE during reset must not assert its normal start output.
        if (rst) begin
            rx_state_next = RX_IDLE;
        end else begin
            case (rx_state)
                RX_IDLE: begin
                    if(track_reset_cnt == 2'd3) begin
                        start_en_i = 1'b1;
                        rx_state_next = RX_ACQ;
                    end
                    else begin
                        start_en_i = 1'b0;
                        rx_state_next = RX_IDLE;
                    end
                end
                RX_ACQ: begin
                    if (acq_done_en_o) begin
                        if (acq_success_en_o)
                            rx_state_next = RX_WAIT_FCW;
                        else
                            rx_state_next = RX_IDLE;
                    end
                end

                RX_WAIT_FCW: begin
                    // Handles an FCW received either before or after done.
                    if (acq_pn0_valid_o)
                        rx_state_next = RX_TRACK;
                end

//                RX_SETTLE: begin
//                    // Allows PLL_NCO to latch FCW and update NCO_incr.
//                    rx_state_next = RX_TRACK;
//                end

                RX_TRACK: begin
                    Track_enable = 1'b1;
                    if (!track_lock_valid || track_lock)
                        rx_state_next = RX_TRACK;
                    else
                        rx_state_next = RX_IDLE;
                end

                default: rx_state_next = RX_IDLE;
            endcase
        end
    end
endmodule
