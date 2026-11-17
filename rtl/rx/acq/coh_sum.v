`timescale 1ns / 1ps
// 128 路 PN 符号翻转及七级流水加法树，每拍输出一个 128 点相干积分。
// C[k]=sum(x[128k+n]p[128k+n])，3 bit 输入自然增长 7 bit，输出为 10 bit。
module coh_sum #(
    parameter integer DATA_WID = 3,
    parameter integer LANES    = 128,
    parameter integer ADD_STG  = 7,
    parameter integer COH_WID  = DATA_WID + ADD_STG
) (
    clk,
    rst,
    din_en_i,
    din_i,
    pn_i,
    last_en_i,
    dout_en_o,
    dout_i,
    dout_q,
    last_en_o
);

localparam integer SAMPLE_WID = 2 * DATA_WID;
localparam integer ROW_WID = LANES * SAMPLE_WID;

input  wire                       clk;       // 处理时钟
input  wire                       rst;       // 高有效异步复位
input  wire                       din_en_i;    // 128 点复采样和 PN 同时有效
input  wire [ROW_WID-1:0]         din_i;       // 128 个 I/Q 各 3 bit 复采样
input  wire [LANES-1:0]           pn_i;        // 128 个 PN 负极性标志
input  wire                       last_en_i;   // 当前码相位第 256 个积分块标志
output wire                       dout_en_o;   // 相干积分有效脉冲
output wire signed [COH_WID-1:0]  dout_i;    // 128 点同相相干积分
output wire signed [COH_WID-1:0]  dout_q;    // 128 点正交相干积分
output wire                       last_en_o;   // 与输出对齐的第 256 块标志

reg signed [COH_WID-1:0] si0 [0:127];
reg signed [COH_WID-1:0] sq0 [0:127];
reg signed [COH_WID-1:0] si1 [0:63];
reg signed [COH_WID-1:0] sq1 [0:63];
reg signed [COH_WID-1:0] si2 [0:31];
reg signed [COH_WID-1:0] sq2 [0:31];
reg signed [COH_WID-1:0] si3 [0:15];
reg signed [COH_WID-1:0] sq3 [0:15];
reg signed [COH_WID-1:0] si4 [0:7];
reg signed [COH_WID-1:0] sq4 [0:7];
reg signed [COH_WID-1:0] si5 [0:3];
reg signed [COH_WID-1:0] sq5 [0:3];
reg signed [COH_WID-1:0] si6 [0:1];
reg signed [COH_WID-1:0] sq6 [0:1];
reg signed [COH_WID-1:0] si7;
reg signed [COH_WID-1:0] sq7;
reg [ADD_STG:0] en_pipe;
reg [ADD_STG:0] last_pipe;
integer n;
wire signed [DATA_WID-1:0] lane_i [0:127];
wire signed [DATA_WID-1:0] lane_q [0:127];
genvar g;

generate
    for (g = 0; g < LANES; g = g + 1)
    begin : UNPACK
        assign lane_i[g] = din_i[g*SAMPLE_WID +: DATA_WID];
        assign lane_q[g] = din_i[g*SAMPLE_WID+DATA_WID +: DATA_WID];
    end
endgenerate

always @ ( posedge clk or posedge rst )
begin
    if (rst)
    begin
        en_pipe <= {(ADD_STG+1){1'b0}};
        last_pipe <= {(ADD_STG+1){1'b0}};
        si7 <= {COH_WID{1'b0}};
        sq7 <= {COH_WID{1'b0}};
    end
    else
    begin
        en_pipe <= {en_pipe[ADD_STG-1:0], din_en_i};//valid和data对齐
        last_pipe <= {last_pipe[ADD_STG-1:0], last_en_i & din_en_i};
        if (din_en_i) begin
            for (n = 0; n < LANES; n = n + 1) begin
                if (pn_i[n]) begin
                    si0[n] <= -{{(COH_WID-DATA_WID){lane_i[n][DATA_WID-1]}}, lane_i[n]};//补符号位
                    sq0[n] <= -{{(COH_WID-DATA_WID){lane_q[n][DATA_WID-1]}}, lane_q[n]};
                end
                else begin
                    si0[n] <= {{(COH_WID-DATA_WID){lane_i[n][DATA_WID-1]}}, lane_i[n]};
                    sq0[n] <= {{(COH_WID-DATA_WID){lane_q[n][DATA_WID-1]}}, lane_q[n]};
                end
            end
        end
        for (n = 0; n < 64; n = n + 1) begin
            si1[n] <= si0[2*n] + si0[2*n+1];
            sq1[n] <= sq0[2*n] + sq0[2*n+1];
        end
        for (n = 0; n < 32; n = n + 1) begin
            si2[n] <= si1[2*n] + si1[2*n+1];
            sq2[n] <= sq1[2*n] + sq1[2*n+1];
        end
        for (n = 0; n < 16; n = n + 1) begin
            si3[n] <= si2[2*n] + si2[2*n+1];
            sq3[n] <= sq2[2*n] + sq2[2*n+1];
        end
        for (n = 0; n < 8; n = n + 1) begin
            si4[n] <= si3[2*n] + si3[2*n+1];
            sq4[n] <= sq3[2*n] + sq3[2*n+1];
        end
        for (n = 0; n < 4; n = n + 1)  begin
            si5[n] <= si4[2*n] + si4[2*n+1];
            sq5[n] <= sq4[2*n] + sq4[2*n+1];
        end
        for (n = 0; n < 2; n = n + 1) begin
            si6[n] <= si5[2*n] + si5[2*n+1];
            sq6[n] <= sq5[2*n] + sq5[2*n+1];
        end
        si7 <= si6[0] + si6[1];
        sq7 <= sq6[0] + sq6[1];
    end
end

assign dout_en_o = en_pipe[ADD_STG];
assign last_en_o = last_pipe[ADD_STG];
assign dout_i = si7;
assign dout_q = sq7;

endmodule
