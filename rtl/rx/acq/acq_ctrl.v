`timescale 1ns / 1ps
// Three-stage acquisition scheduler.§¿??§Õ??ram\???ram
module acq_ctrl #(
    parameter integer POWER_WID  = 30,
    parameter integer SUM_WID    = 41,
    parameter integer COARSE_NUM = 41
) (
    input  wire                     clk,
    input  wire                     rst,
    input  wire                     start_i,//????1clk????ctrl_run???????????????????????¡¤?????????????????????
    input  wire                     store_full_i,
    input  wire                     scan_done_i,
    input  wire                     scan_success_i,
    input  wire [POWER_WID-1:0]     scan_max_i,
    input  wire [10:0]              scan_code_i,
    input  wire [7:0]               scan_bin_i,
    input  wire [SUM_WID-1:0]       scan_sum_i,
    input  wire                     final_math_done_i,
    output reg                      capture_start_o,
    output reg                      capture_bank_o,
    output reg [5:0]                capture_freq_o, //??????
    output reg                      scan_start_o,  
    output reg                      scan_bank_o,
    output reg [5:0]                scan_freq_o,   //ram??????
    output reg                      final_math_start_o,
    output reg [5:0]                final_freq_o,
    output reg [10:0]               final_code_o,
    output reg [7:0]                final_bin_o,
    output reg [POWER_WID-1:0]      final_max_o,
    output reg [SUM_WID-1:0]        final_sum_o,
    output reg [1:0]                stage_o,
    output reg                      busy_o,
    output reg                      done_o,
    output reg                      success_o,
    output reg                      overflow_o
);

localparam [1:0] STAGE_COARSE = 2'd0; //????39??????????????¦Ë????PAR?????????
localparam [1:0] STAGE_SECOND = 2'd1; //????????3???
localparam [1:0] STAGE_FINAL  = 2'd2;  //2046??¦Ë????

localparam [1:0] CTRL_IDLE    = 2'd0;
localparam [1:0] CTRL_RUN     = 2'd1;
localparam [1:0] CTRL_MATH    = 2'd2;
localparam [1:0] CTRL_DONE    = 2'd3;

reg [1:0] ctrl_state;
reg [1:0] capture_pos;
reg [5:0] coarse_capture_pos;
reg [1:0] process_pos;
reg [5:0] coarse_process_pos;
reg       wr_bank;
reg       rd_bank;
reg       scan_busy;
reg [1:0] bank_full;
reg [5:0] bank_freq [0:1];
reg       best_valid;
reg [POWER_WID-1:0] best_power;
reg [5:0] best_freq;

wire current_better;
wire [5:0] selected_freq;
wire stage_capture_last;
wire stage_process_last;
wire result_available;
wire capture_start_event;
wire scan_start_event;
wire final_math_start_event;

assign current_better = scan_success_i &&
                        (!best_valid || (scan_max_i > best_power)); //par????§Ø??????????????
assign selected_freq = current_better ? scan_freq_o : best_freq;
assign result_available = best_valid || scan_success_i;
assign stage_capture_last =
    (stage_o == STAGE_COARSE) ? (coarse_capture_pos == COARSE_NUM-1) :
    (stage_o == STAGE_SECOND) ? (capture_pos == 2'd2) : 1'b1;
assign stage_process_last =
    (stage_o == STAGE_COARSE) ? (coarse_process_pos == COARSE_NUM-1) :
    (stage_o == STAGE_SECOND) ? (process_pos == 2'd2) : 1'b1;

// One-cycle output strobes. Each register is assigned exactly once on every
// path; the state machine below only updates the associated payload/state.
assign capture_start_event =
    ((ctrl_state == CTRL_IDLE) && start_i) ||
    ((ctrl_state == CTRL_RUN) && store_full_i && !stage_capture_last) ||
    ((ctrl_state == CTRL_RUN) && scan_done_i && stage_process_last &&
     result_available &&
     (((stage_o == STAGE_COARSE) && (selected_freq != 0) &&
       (selected_freq != COARSE_NUM-1)) ||
      (stage_o == STAGE_SECOND)));

assign scan_start_event =
    ((ctrl_state == CTRL_RUN) && store_full_i && !scan_busy) ||
    ((ctrl_state == CTRL_RUN) && scan_done_i && !stage_process_last &&
     (bank_full[~rd_bank] ||
      (store_full_i && (wr_bank != rd_bank))));

assign final_math_start_event =
    (ctrl_state == CTRL_RUN) && scan_done_i && stage_process_last &&
    result_available && (stage_o == STAGE_FINAL);

always @(posedge clk or posedge rst)
begin
    if (rst)
    begin
        capture_start_o <= 1'b0;
        scan_start_o <= 1'b0;
        final_math_start_o <= 1'b0;
        done_o <= 1'b0;
    end
    else
    begin
        if (capture_start_event)
            capture_start_o <= 1'b1;
        else
            capture_start_o <= 1'b0;

        if (scan_start_event)
            scan_start_o <= 1'b1;
        else
            scan_start_o <= 1'b0;

        if (final_math_start_event)
            final_math_start_o <= 1'b1;
        else
            final_math_start_o <= 1'b0;

        if (ctrl_state == CTRL_DONE)
            done_o <= 1'b1;
        else
            done_o <= 1'b0;
    end
end

always @(posedge clk or posedge rst)
begin
    if (rst)
    begin
        ctrl_state <= CTRL_IDLE;
        stage_o <= STAGE_COARSE;
        capture_pos <= 2'd0;
        coarse_capture_pos <= 6'd0;
        process_pos <= 2'd0;
        coarse_process_pos <= 6'd0;
        wr_bank <= 1'b0;
        rd_bank <= 1'b0;
        scan_busy <= 1'b0;
        bank_full <= 2'b00;
        bank_freq[0] <= 6'd0;
        bank_freq[1] <= 6'd0;
        best_valid <= 1'b0;
        best_power <= {POWER_WID{1'b0}};
        best_freq <= 6'd0;
        capture_bank_o <= 1'b0;
        capture_freq_o <= 6'd0;
        scan_bank_o <= 1'b0;
        scan_freq_o <= 6'd0;
        final_freq_o <= 6'd0;
        final_code_o <= 11'd0;
        final_bin_o <= 8'd0;
        final_max_o <= {POWER_WID{1'b0}};
        final_sum_o <= {SUM_WID{1'b0}};
        busy_o <= 1'b0;
        success_o <= 1'b0;
        overflow_o <= 1'b0;
    end
    else begin
        case (ctrl_state)
            CTRL_IDLE:
            begin
                busy_o <= 1'b0;
                if (start_i)
                begin
                    ctrl_state <= CTRL_RUN;
                    stage_o <= STAGE_COARSE;
                    capture_pos <= 2'd0;
                    coarse_capture_pos <= 6'd0;
                    process_pos <= 2'd0;
                    coarse_process_pos <= 6'd0;
                    wr_bank <= 1'b0;
                    bank_full <= 2'b00;
                    bank_freq[0] <= 6'd0;
                    best_valid <= 1'b0;
                    best_power <= {POWER_WID{1'b0}};
                    success_o <= 1'b0;
                    overflow_o <= 1'b0;
                    busy_o <= 1'b1;
                    capture_bank_o <= 1'b0;
                    capture_freq_o <= 6'd0;
                end
            end
            CTRL_RUN://???????§Õ????? RAM????????????????RAM??????????????¦Ë????????????????§Ý???????? RAM??????????¦Â??
            begin
                if (store_full_i) //§Õ??????bank_full,??????
                begin
                    if (bank_full[wr_bank])begin
                        overflow_o <= 1'b1;//?????ï…??????????
                    end
                    bank_full[wr_bank] <= 1'b1; //?????
                    if (!scan_busy) //??????????ram
                    begin
                        rd_bank <= wr_bank;
                        scan_bank_o <= wr_bank;
                        scan_freq_o <= bank_freq[wr_bank];
                        scan_busy <= 1'b1;
                    end
                    if (!stage_capture_last)//???????¦Ä???????????????bank
                    begin
                        wr_bank <= ~wr_bank;
                        capture_bank_o <= ~wr_bank;
                        if (stage_o == STAGE_COARSE)
                        begin
                            coarse_capture_pos <= coarse_capture_pos + 1'b1;
                            capture_freq_o <= coarse_capture_pos + 1'b1;
                            bank_freq[~wr_bank] <= coarse_capture_pos + 1'b1;
                        end
                        else
                        begin
                            capture_pos <= capture_pos + 1'b1; //???????0-39
                            capture_freq_o <= capture_freq_o + 1'b1;
                            bank_freq[~wr_bank] <= capture_freq_o + 1'b1;
                        end
                    end
                end

                if (scan_done_i)//??????scan bank???????????
                begin
                    bank_full[rd_bank] <= 1'b0;
                    scan_busy <= 1'b0;
                    if (current_better)//????????????
                    begin
                        best_valid <= 1'b1;
                        best_power <= scan_max_i;
                        best_freq <= scan_freq_o;
                    end
                    if (stage_process_last)
                    begin
                        if (!best_valid && !scan_success_i)
                        begin
                            success_o <= 1'b0;
                            ctrl_state <= CTRL_DONE;
                        end
                        else if (stage_o == STAGE_COARSE)
                        begin
                            if ((selected_freq == 0) ||
                                (selected_freq == COARSE_NUM-1))
                            begin
                                success_o <= 1'b0;
                                ctrl_state <= CTRL_DONE;
                            end
                            else
                            begin
                                stage_o <= STAGE_SECOND;
                                capture_pos <= 2'd0;
                                process_pos <= 2'd0;
                                best_valid <= 1'b0;
                                best_power <= {POWER_WID{1'b0}};
                                wr_bank <= rd_bank;
                                capture_bank_o <= rd_bank;
                                capture_freq_o <= selected_freq - 1'b1;
                                bank_freq[rd_bank] <= selected_freq - 1'b1;
                            end
                        end
                        else if (stage_o == STAGE_SECOND)
                        begin
                            stage_o <= STAGE_FINAL;
                            capture_pos <= 2'd0;
                            process_pos <= 2'd0;
                            best_valid <= 1'b0;
                            best_power <= {POWER_WID{1'b0}};
                            wr_bank <= rd_bank;
                            capture_bank_o <= rd_bank;
                            capture_freq_o <= selected_freq;
                            bank_freq[rd_bank] <= selected_freq;
                        end
                        else
                        begin
                            final_freq_o <= scan_freq_o;
                            final_code_o <= scan_code_i;
                            final_bin_o <= scan_bin_i;
                            final_max_o <= scan_max_i;
                            final_sum_o <= scan_sum_i;
                            success_o <= scan_success_i;
                            ctrl_state <= CTRL_MATH;
                        end
                    end
                    else
                    begin
                        if (stage_o == STAGE_COARSE)
                            coarse_process_pos <= coarse_process_pos + 1'b1;
                        else
                            process_pos <= process_pos + 1'b1;
                        if (bank_full[~rd_bank])
                        begin
                            rd_bank <= ~rd_bank;
                            scan_bank_o <= ~rd_bank;
                            scan_freq_o <= bank_freq[~rd_bank];
                            scan_busy <= 1'b1;
                        end
                        else if (store_full_i && (wr_bank != rd_bank))
                        begin
                            rd_bank <= wr_bank;
                            scan_bank_o <= wr_bank;
                            scan_freq_o <= bank_freq[wr_bank];
                            scan_busy <= 1'b1;
                        end
                    end
                end
            end
            CTRL_MATH:
                if (final_math_done_i)
                    ctrl_state <= CTRL_DONE;
            CTRL_DONE:
            begin
                busy_o <= 1'b0;
                ctrl_state <= CTRL_IDLE;
            end
            default:
                ctrl_state <= CTRL_IDLE;
        endcase
    end
end
endmodule
