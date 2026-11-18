`timescale 1ns / 1ps
// 每两个相干积分结果相加，截去 POWER_CUT 位后，累加 128 组功率。
// P=sum((floor((I0+I1)/2^POWER_CUT))^2+(floor((Q0+Q1)/2^POWER_CUT))^2)。
module power_acc #(
    parameter integer COH_WID   = 10,
    parameter integer POWER_CUT = 3,
    parameter integer PAIR_NUM  = 128,
    parameter integer PAIR_AW   = 7,
    parameter integer POWER_WID = 2 * (COH_WID + 1 - POWER_CUT) + 1 + PAIR_AW
) (
    clk,
    rst,
    clear_en_i,
    din_en_i,
    din_i,
    din_q,
    last_en_i,
    dout_en_o,
    power_o
);

localparam integer LOW_WID = COH_WID + 1;//11
localparam integer POWER_DATA_WID = LOW_WID - POWER_CUT;//11-3=8
localparam integer SQUARE_WID = 2 * POWER_DATA_WID;//16
localparam integer MULT_LATENCY = 3;

input  wire                         clk;         // 工作时钟
input  wire                         rst;         // 高有效异步复位
input  wire                         clear_en_i;  // 清空当前频点统计状态
input  wire                         din_en_i;    // 相干积分结果有效
input  wire signed [COH_WID-1:0]    din_i;       // 当前同相支路积分值
input  wire signed [COH_WID-1:0]    din_q;       // 当前正交支路积分值
input  wire                         last_en_i;   // 第 256 个积分结果标志
output reg                          dout_en_o;   // 当前频点功率输出有效
output reg [POWER_WID-1:0]          power_o;     // 128 组合并功率累加值


reg                         pair_flag;
reg signed [COH_WID-1:0]    hold_i;
reg signed [COH_WID-1:0]    hold_q;

reg [POWER_WID-1:0]         power_sum;//功率累加值

// I0+I1/Q0+Q1：先寄存一拍，再送入乘法器。
reg signed [LOW_WID-1:0] pair_i_full;
reg signed [LOW_WID-1:0] pair_q_full;
reg                      pair_add_valid;
reg                      pair_add_last;

wire signed [POWER_DATA_WID-1:0] pair_i_cut;
wire signed [POWER_DATA_WID-1:0] pair_q_cut;

wire [SQUARE_WID-1:0] pair_i_square;
wire [SQUARE_WID-1:0] pair_q_square;
reg  [SQUARE_WID:0]   pair_power;
reg                     pair_power_valid;
reg                     pair_power_last;

// mult_8x8 为三级流水线，有效信号和末尾标志与乘积同步延迟。
reg [MULT_LATENCY-1:0] pair_valid_d;
reg [MULT_LATENCY-1:0] pair_last_d;

// 算术右移，保留符号位
assign pair_i_cut = pair_i_full >>> POWER_CUT;

assign pair_q_cut = pair_q_full >>> POWER_CUT;

mult_8x8 u_mult_i_square (
    .CLK (clk),
    .A   (pair_i_cut),
    .B   (pair_i_cut),
    .P   (pair_i_square)
);

mult_8x8 u_mult_q_square (
    .CLK (clk),
    .A   (pair_q_cut),
    .B   (pair_q_cut),
    .P   (pair_q_square)
);

// Pipeline-valid strobes are registered independently with one assignment on
// each mutually exclusive path.
always @(posedge clk or posedge rst)
begin
    if (rst || clear_en_i)
    begin
        pair_add_valid <= 1'b0;
        pair_add_last <= 1'b0;
        pair_power_valid <= 1'b0;
        pair_power_last <= 1'b0;
        dout_en_o <= 1'b0;
    end
    else
    begin
        if (din_en_i && pair_flag)
            pair_add_valid <= 1'b1;
        else
            pair_add_valid <= 1'b0;

        if (din_en_i && pair_flag && last_en_i)
            pair_add_last <= 1'b1;
        else
            pair_add_last <= 1'b0;

        if (pair_valid_d[MULT_LATENCY-1])
            pair_power_valid <= 1'b1;
        else
            pair_power_valid <= 1'b0;

        if (pair_valid_d[MULT_LATENCY-1] &&
            pair_last_d[MULT_LATENCY-1])
            pair_power_last <= 1'b1;
        else
            pair_power_last <= 1'b0;

        if (pair_power_valid && pair_power_last)
            dout_en_o <= 1'b1;
        else
            dout_en_o <= 1'b0;
    end
end

always @(posedge clk or posedge rst)
begin
    if(rst) begin
        pair_flag <= 1'b0;
        hold_i <= 'sd0;
        hold_q <= 'sd0;
        pair_i_full <= 'sd0;
        pair_q_full <= 'sd0;
        pair_valid_d <= {MULT_LATENCY{1'b0}};
        pair_last_d <= {MULT_LATENCY{1'b0}};
        pair_power <= 'd0;
        power_sum <= 'd0;
        power_o <= 'd0;
    end
    else if(clear_en_i)  begin
        pair_flag <= 1'b0;
        hold_i <= 'sd0;
        hold_q <= 'sd0;
        pair_i_full <= 'sd0;
        pair_q_full <= 'sd0;
        pair_valid_d <= {MULT_LATENCY{1'b0}};
        pair_last_d <= {MULT_LATENCY{1'b0}};
        pair_power <= 'd0;
        power_sum <= 'd0;
    end
    else begin
        pair_valid_d <= {pair_valid_d[MULT_LATENCY-2:0], pair_add_valid};
        pair_last_d <= {pair_last_d[MULT_LATENCY-2:0], pair_add_valid && pair_add_last};

        if(pair_valid_d[MULT_LATENCY-1]) begin
            pair_power <= {1'b0, pair_i_square} + {1'b0, pair_q_square};
        end

        if(pair_power_valid) begin
            if(pair_power_last) begin
                power_o <= power_sum + pair_power;
                power_sum <= 'd0;
            end
            else begin
                power_sum <= power_sum + pair_power;
            end
        end

        if(din_en_i) begin
            if(!pair_flag) begin
                hold_i <= din_i;//缓存一组积分结果I0
                hold_q <= din_q;
                pair_flag <= 1'b1;
            end

            else begin
                pair_flag <= 1'b0;
                pair_i_full <= {hold_i[COH_WID-1], hold_i} + {din_i[COH_WID-1], din_i}; //I0+I1;I2+I3
                pair_q_full <= {hold_q[COH_WID-1], hold_q} + {din_q[COH_WID-1], din_q};
            end
        end
    end
end

endmodule
