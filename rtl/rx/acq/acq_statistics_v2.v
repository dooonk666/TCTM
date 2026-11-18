`timescale 1ns / 1ps
// One-bin statistics for 2046 phases. PAR threshold is evaluated without a
// divider: max*2046 > 2*(sum-max). mult_24x11 has four clocks latency.
module acq_statistics_v2 #(
    parameter integer POWER_WID = 24,
    parameter integer SUM_WID   = POWER_WID + 11,
    parameter [POWER_WID-1:0] POWER_THRESHOLD = 782
) (
    input  wire                    clk,
    input  wire                    rst,
    input  wire                    clear_i,
    input  wire                    valid_i,
    input  wire [POWER_WID-1:0]    power_i,
    input  wire [10:0]             code_i,
    input  wire [7:0]              bin_i,
    input  wire                    last_i,
    output reg                     done_o,
    output reg                     success_o,
    output reg [POWER_WID-1:0]     max_o,
    output reg [10:0]              code_o,
    output reg [7:0]               bin_o,
    output reg [SUM_WID-1:0]       sum_o
);
// Keep this equal to mult_24x11.xci C_LATENCY/PipeStages.
localparam integer MULT_LATENCY = 4;
wire [POWER_WID-1:0] final_max = (power_i > max_o) ? power_i : max_o;
wire [34:0] par_product; //24+11=35
reg [SUM_WID-1:0] sum_pipe [0:MULT_LATENCY-1];
reg [POWER_WID-1:0] max_pipe [0:MULT_LATENCY-1];
reg [MULT_LATENCY-1:0] valid_pipe;
integer k;

mult_24x11 u_mult_24x11 (
    .CLK (clk),
    .A   (final_max),
    .B   (11'd2046),
    .P   (par_product)
);

always @(posedge clk or posedge rst)
begin
    if (rst || clear_i)
    begin
        done_o <= 1'b0;
        success_o <= 1'b0;
        max_o <= {POWER_WID{1'b0}};
        code_o <= 11'd0;
        bin_o <= 8'd0;
        sum_o <= {SUM_WID{1'b0}};
        valid_pipe <= {MULT_LATENCY{1'b0}};
        for (k=0; k<MULT_LATENCY; k=k+1)
        begin
            sum_pipe[k] <= {SUM_WID{1'b0}};
            max_pipe[k] <= {POWER_WID{1'b0}};
        end
    end
    else
    begin
        if (valid_pipe[MULT_LATENCY-1])
            done_o <= 1'b1;
        else
            done_o <= 1'b0;

        valid_pipe <= {valid_pipe[MULT_LATENCY-2:0], valid_i && last_i};
        for (k=1; k<MULT_LATENCY; k=k+1)
        begin
            sum_pipe[k] <= sum_pipe[k-1];
            max_pipe[k] <= max_pipe[k-1];
        end
        if (valid_i)
        begin
            sum_o <= sum_o + power_i;
            if (power_i > max_o)
            begin
                max_o <= power_i;
                code_o <= code_i;
                bin_o <= bin_i;
            end
            if (last_i)
            begin
                sum_pipe[0] <= sum_o + power_i;
                max_pipe[0] <= final_max;
            end
        end
        if (valid_pipe[MULT_LATENCY-1])
        begin
            success_o <= ({1'b0,par_product} >=// par=peak/mean = peak*2046/sum ;par>=2
                          {(sum_pipe[MULT_LATENCY-1] -
                            max_pipe[MULT_LATENCY-1]),1'b0}) &&
                         (max_pipe[MULT_LATENCY-1] > POWER_THRESHOLD);//par>2 &&power>threshold
        end
    end
end
endmodule
