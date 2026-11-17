`timescale 1ns / 1ps
// 相干积分复平方去除 BPSK 符号。
// (I+jQ)^2=(I^2-Q^2)+j(2IQ)
// cmpy_mult10x10 直接计算 (I+jQ)*(I+jQ)，内部流水线延迟为 6 拍。
module complex_square #(
    parameter integer COH_WID = 10,
    parameter integer FFT_CUT = 4,
    parameter integer FFT_WID = 2 * COH_WID + 1 - FFT_CUT
)(
    input  wire                         clk,
    input  wire                         rst,
    input  wire                         din_en_i,
    input  wire signed [COH_WID-1:0]    din_i,
    input  wire signed [COH_WID-1:0]    din_q,
    input  wire                         last_en_i,
    output reg                          dout_en_o,
    output reg signed [FFT_WID-1:0]     dout_i,
    output reg signed [FFT_WID-1:0]     dout_q,
    output reg                          last_en_o
);

localparam integer CMPY_LATENCY = 6;
localparam integer CMPY_OUT_WID = 21;

// Complex Multiplier AXI 数据按 16 bit 边界打包：
// 实部位于 [9:0]，虚部位于 [25:16]，其余位进行符号扩展。
wire [31:0] cmpy_input;
wire        cmpy_dout_valid;
wire [47:0] cmpy_dout_data;
wire signed [CMPY_OUT_WID-1:0] cmpy_dout_i;
wire signed [CMPY_OUT_WID-1:0] cmpy_dout_q;

reg [CMPY_LATENCY-1:0] last_pipe;

assign cmpy_input = {
    {(16-COH_WID){din_q[COH_WID-1]}}, din_q,
    {(16-COH_WID){din_i[COH_WID-1]}}, din_i
};

assign cmpy_dout_i = $signed(cmpy_dout_data[20:0]);
assign cmpy_dout_q = $signed(cmpy_dout_data[44:24]);

cmpy_mult10x10 u_cmpy_square (
    .aclk               (clk),
    .s_axis_a_tvalid    (din_en_i),
    .s_axis_a_tdata     (cmpy_input),
    .s_axis_b_tvalid    (din_en_i),
    .s_axis_b_tdata     (cmpy_input),
    .m_axis_dout_tvalid (cmpy_dout_valid),
    .m_axis_dout_tdata  (cmpy_dout_data)
);

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        last_pipe <= {CMPY_LATENCY{1'b0}};
        dout_en_o <= 1'b0;
        last_en_o <= 1'b0;
        dout_i <= 'sd0;
        dout_q <= 'sd0;
    end
    else
    begin
        last_pipe <= {last_pipe[CMPY_LATENCY-2:0],
                      din_en_i && last_en_i};
        dout_en_o <= cmpy_dout_valid;
        last_en_o <= cmpy_dout_valid && last_pipe[CMPY_LATENCY-1];

        if(cmpy_dout_valid)
        begin
            dout_i <= cmpy_dout_i >>> FFT_CUT;
            dout_q <= cmpy_dout_q >>> FFT_CUT;
        end
    end
end

endmodule
