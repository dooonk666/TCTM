`timescale 1ns / 1ps
// FIR 输出四抽一，得到每码片两个采样点
module downsample #(
    parameter integer DATA_WID = 12
) (
    clk,
    rst,
    din_en,
    din_i,
    din_q,
    dout_en_o,
    dout_i,
    dout_q
);

input  wire                       clk;      // 捕获处理时钟
input  wire                       rst;      // 高有效异步复位
input  wire                       din_en;   // FIR 输出采样有效脉冲
input  wire signed [DATA_WID-1:0] din_i;    // FIR 后同相采样
input  wire signed [DATA_WID-1:0] din_q;    // FIR 后正交采样
output reg                        dout_en_o;  // 二倍码速率采样有效脉冲
output reg signed [DATA_WID-1:0]  dout_i;   // 抽取后的同相采样
output reg signed [DATA_WID-1:0]  dout_q;   // 抽取后的正交采样

reg [1:0] deci_count;

always @ ( posedge clk or posedge rst )
begin
    if (rst)
    begin
        deci_count <= 2'd0;
        dout_en_o <= 1'b0;
        dout_i <= {DATA_WID{1'b0}};
        dout_q <= {DATA_WID{1'b0}};
    end
    else
    begin
        dout_en_o <= 1'b0;
        if (din_en)
        begin
            if (deci_count == 2'd0)
            begin
                dout_en_o <= 1'b1;
                dout_i <= din_i;
                dout_q <= din_q;
            end
            deci_count <= deci_count + 2'd1;
        end
    end
end

endmodule
