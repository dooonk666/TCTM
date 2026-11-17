`timescale 1ns / 1ps
// 双路 FIR 前端
// y[n]=sum(h_q[k]x[n-k])/2^COEF_FRAC
module acq_frontend_filter #(
    parameter integer ADC_WID      = 12,
    parameter integer FIR_OUT_WID  = 23,
    parameter integer DATA_WID     = 12,
    parameter integer COEF_FRAC    = 10
) (
    input  wire                      clk            ,       // 120 MHz 捕获处理时钟
    input  wire                      rst            ,       // 高有效异步复位
    input  wire                      din_en       ,    // ADC 复采样有效脉冲
    input  wire signed [ADC_WID-1:0] din_i          ,     // ADC 同相 12 bit 有符号采样
    input  wire signed [ADC_WID-1:0] din_q          ,     // ADC 正交 12 bit 有符号采样
    output wire                      ready_en_o     ,  // ADC 输入端始终可送出有效采样
    output wire                      dout_en_o      ,   // 缩放后 FIR 结果有效脉冲
    output wire signed [DATA_WID-1:0] dout_i        ,   // FIR 后I路
    output wire signed [DATA_WID-1:0] dout_q        ,   // FIR 后Q路
    output wire                       dout_valid_en     //对齐真正有效数据，忽略初始化输出
);


wire fir_i_ready;
wire fir_q_ready;
wire fir_i_valid;
wire fir_q_valid;
localparam integer AXIS_IN_WID  = 16;
localparam integer AXIS_OUT_WID = 24;
wire [AXIS_OUT_WID-1:0] fir_i_data;
wire [AXIS_OUT_WID-1:0] fir_q_data;
wire sample_en;
wire signed [FIR_OUT_WID-1:0] fir_i_full;
wire signed [FIR_OUT_WID-1:0] fir_q_full;
wire signed [FIR_OUT_WID-1:0] fir_i_scaled;
wire signed [FIR_OUT_WID-1:0] fir_q_scaled;

assign ready_en_o = 1'b1;
assign sample_en = din_en & ~rst;
assign dout_en_o = fir_i_valid & fir_q_valid;
assign fir_i_full = fir_i_data[FIR_OUT_WID-1:0];
assign fir_q_full = fir_q_data[FIR_OUT_WID-1:0];
assign fir_i_scaled = fir_i_full >>> COEF_FRAC;
assign fir_q_scaled = fir_q_full >>> COEF_FRAC;
assign dout_i = fir_i_scaled[DATA_WID-1:0];
assign dout_q = fir_q_scaled[DATA_WID-1:0];
reg [1:0] cnt;

always@(posedge clk )begin
    if(rst)begin
        cnt <= 0;
    end
    else if(dout_en_o && cnt <3)begin
        cnt<=cnt+1;
    end
end

assign dout_valid_en = (cnt == 3) && dout_en_o;
fir_recv u_fir_i (
    .aclk               (clk),
    .s_axis_data_tvalid (sample_en),
    .s_axis_data_tready (fir_i_ready),
    .s_axis_data_tdata  ({{(AXIS_IN_WID-ADC_WID){din_i[ADC_WID-1]}}, din_i}), //[15:0]
    .m_axis_data_tvalid (fir_i_valid),
    .m_axis_data_tdata  (fir_i_data) //[23:0]
);

fir_recv u_fir_q (
    .aclk               (clk),
    .s_axis_data_tvalid (sample_en),
    .s_axis_data_tready (fir_q_ready),
    .s_axis_data_tdata  ({{(AXIS_IN_WID-ADC_WID){din_q[ADC_WID-1]}}, din_q}),
    .m_axis_data_tvalid (fir_q_valid),
    .m_axis_data_tdata  (fir_q_data)
);

endmodule
