`timescale 1ns / 1ps
// 每帧 FFT 使用 Robertson 近似幅度查找峰值：
// M=max(|I|,|Q|)+min(|I|,|Q|)/2。
module fft_peak #(
    parameter integer DATA_WID = 20,
    parameter integer MAG_WID  = DATA_WID + 1
) (
    clk,
    rst,
    din_en_i,
    din_i,
    din_q,
    bin_i,
    last_en_i,
    dout_en_o,
    peak_o,
    peak_bin_o
);

input  wire                         clk;         // 捕获处理时钟
input  wire                         rst;         // 高有效异步复位
input  wire                         din_en_i;    // FFT 输出有效脉冲
input  wire signed [DATA_WID-1:0]   din_i;       // FFT 同相截位输出
input  wire signed [DATA_WID-1:0]   din_q;       // FFT 正交截位输出
input  wire [7:0]                   bin_i;       // FFT 输出频点编号
input  wire                         last_en_i;   // 当前 FFT 帧最后一点标志
output reg                          dout_en_o;   // 当前帧峰值结果有效脉冲
output reg [MAG_WID-1:0]            peak_o;      // 当前帧 Robertson 峰值
output reg [7:0]                    peak_bin_o;  // 当前帧峰值对应频点

// 第一级：绝对值。
reg [DATA_WID-1:0] abs_i_s1;
reg [DATA_WID-1:0] abs_q_s1;
reg                valid_s1;
reg                last_s1;
reg [7:0]          bin_s1;

// 第二级：最大值和最小值选择。
reg [DATA_WID-1:0] max_abs_s2;
reg [DATA_WID-1:0] min_abs_s2;
reg                valid_s2;
reg                last_s2;
reg [7:0]          bin_s2;

// 第三级：Robertson 近似幅度。
reg [MAG_WID-1:0]  magnitude_s3;
reg                valid_s3;
reg                last_s3;
reg [7:0]          bin_s3;

reg [MAG_WID-1:0]  frame_peak;
reg [7:0]          frame_bin;

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        abs_i_s1 <= {DATA_WID{1'b0}};
        abs_q_s1 <= {DATA_WID{1'b0}};
        valid_s1 <= 1'b0;
        last_s1 <= 1'b0;
        bin_s1 <= 8'd0;

        max_abs_s2 <= {DATA_WID{1'b0}};
        min_abs_s2 <= {DATA_WID{1'b0}};
        valid_s2 <= 1'b0;
        last_s2 <= 1'b0;
        bin_s2 <= 8'd0;

        magnitude_s3 <= {MAG_WID{1'b0}};
        valid_s3 <= 1'b0;
        last_s3 <= 1'b0;
        bin_s3 <= 8'd0;

        frame_peak <= {MAG_WID{1'b0}};
        frame_bin <= 8'd0;
        dout_en_o <= 1'b0;
        peak_o <= {MAG_WID{1'b0}};
        peak_bin_o <= 8'd0;
    end
    else
    begin
        // 控制信号和频点编号逐级跟随对应数据。
        valid_s1 <= din_en_i;
        last_s1 <= din_en_i && last_en_i;
        bin_s1 <= bin_i;

        valid_s2 <= valid_s1;
        last_s2 <= last_s1;
        bin_s2 <= bin_s1;

        valid_s3 <= valid_s2;
        last_s3 <= last_s2;
        bin_s3 <= bin_s2;

        if(valid_s3 && last_s3)
            dout_en_o <= 1'b1;
        else
            dout_en_o <= 1'b0;

        if(din_en_i)
        begin
            abs_i_s1 <= din_i[DATA_WID-1] ? (~din_i + 1'b1) : din_i;
            abs_q_s1 <= din_q[DATA_WID-1] ? (~din_q + 1'b1) : din_q;
        end

        if(valid_s1)
        begin
            if(abs_i_s1 >= abs_q_s1)
            begin
                max_abs_s2 <= abs_i_s1;
                min_abs_s2 <= abs_q_s1;
            end
            else
            begin
                max_abs_s2 <= abs_q_s1;
                min_abs_s2 <= abs_i_s1;
            end
        end

        if(valid_s2)
        begin
            magnitude_s3 <= {1'b0, max_abs_s2}
                          + {{2{1'b0}}, min_abs_s2[DATA_WID-1:1]};
        end

        if(valid_s3)
        begin
            if(magnitude_s3 > frame_peak)
            begin
                frame_peak <= magnitude_s3;
                frame_bin <= bin_s3;
            end

            if(last_s3)
            begin
                if(magnitude_s3 > frame_peak)
                begin
                    peak_o <= magnitude_s3;
                    peak_bin_o <= bin_s3;
                end
                else
                begin
                    peak_o <= frame_peak;
                    peak_bin_o <= frame_bin;
                end
                frame_peak <= {MAG_WID{1'b0}};
                frame_bin <= 8'd0;
            end
        end
    end
end

endmodule
