`timescale 1ns / 1ps
module fft_ctrl #(
    parameter integer FFT_IN_WID  = 16,
    parameter integer FFT_IP_WID  = 32,
    parameter integer FFT_OUT_CUT = 4,
    parameter integer FFT_OUT_WID = FFT_IN_WID + 8 - FFT_OUT_CUT
)(
    clk,
    rst,
    din_en_i,
    din_i,
    din_q,
    last_en_i,
    ready_en_o,
    dout_en_o,
    dout_i,
    dout_q,
    bin_o,
    last_en_o,
    error_en_o
);
input wire clk;
input wire rst;
input wire din_en_i;
input wire signed [FFT_IN_WID-1:0] din_i;
input wire signed [FFT_IN_WID-1:0] din_q;
input wire last_en_i;
output wire ready_en_o;
output wire dout_en_o;
output wire signed [FFT_OUT_WID-1:0] dout_i;
output wire signed [FFT_OUT_WID-1:0] dout_q;
output wire [7:0] bin_o;
output wire last_en_o;
output wire error_en_o;
reg config_en;
reg config_done;
wire config_ready;
wire data_ready;
wire [2*FFT_IP_WID-1:0] fft_data;
wire [7:0] fft_user;
wire signed [FFT_IP_WID-1:0] fft_i_raw;
wire signed [FFT_IP_WID-1:0] fft_q_raw;
wire signed [FFT_IP_WID-1:0] fft_i_shift;
wire signed [FFT_IP_WID-1:0] fft_q_shift;
wire event_tlast_unexpected;
wire event_tlast_missing;
wire event_status_halt;
wire event_input_halt;
wire event_output_halt;
always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        config_en <= 1'b0;
        config_done <= 1'b0;
    end
    else
    begin
        if(!config_done)
            config_en <= 1'b1;
        if(config_en && config_ready)
        begin
            config_en <= 1'b0;
            config_done <= 1'b1;
        end
    end
end
assign ready_en_o = data_ready & config_done;
assign fft_i_raw = $signed(fft_data[FFT_IP_WID-1:0]);
assign fft_q_raw = $signed(fft_data[2*FFT_IP_WID-1:FFT_IP_WID]);
assign fft_i_shift = fft_i_raw >>> FFT_OUT_CUT;
assign fft_q_shift = fft_q_raw >>> FFT_OUT_CUT;
assign dout_i = fft_i_shift[FFT_OUT_WID-1:0];
assign dout_q = fft_q_shift[FFT_OUT_WID-1:0];
assign bin_o = fft_user;
assign error_en_o = event_tlast_unexpected | event_tlast_missing | event_status_halt | event_input_halt | event_output_halt;
fft_256 u_fft_256(
    .aclk(clk),
    .aresetn(~rst),
    .s_axis_config_tdata(16'h0001),
    .s_axis_config_tvalid(config_en),
    .s_axis_config_tready(config_ready),
    .s_axis_data_tdata({{{(FFT_IP_WID-FFT_IN_WID){din_q[FFT_IN_WID-1]}},din_q},{{(FFT_IP_WID-FFT_IN_WID){din_i[FFT_IN_WID-1]}},din_i}}),
    .s_axis_data_tvalid(din_en_i & config_done),
    .s_axis_data_tready(data_ready),
    .s_axis_data_tlast(last_en_i),
    .m_axis_data_tdata(fft_data),
    .m_axis_data_tuser(fft_user),
    .m_axis_data_tvalid(dout_en_o),
    .m_axis_data_tready(1'b1),
    .m_axis_data_tlast(last_en_o),
    .event_frame_started(),
    .event_tlast_unexpected(event_tlast_unexpected),
    .event_tlast_missing(event_tlast_missing),
    .event_status_channel_halt(event_status_halt),
    .event_data_in_channel_halt(event_input_halt),
    .event_data_out_channel_halt(event_output_halt)
);
endmodule



//`timescale 1ns / 1ps
//// 256 点 Xilinx FFT 流接口封装。FFT 理论增长 8 bit，输出统一右移 FFT_OUT_CUT 位。
//module fft_ctrl #(
//    parameter integer FFT_IN_WID  = 16,
//    parameter integer FFT_IP_WID  = 32,
//    parameter integer FFT_OUT_CUT = 4,
//    parameter integer FFT_OUT_WID = FFT_IN_WID + 8 - FFT_OUT_CUT
//) (
//    clk,
//    rst,
//    din_en_i,
//    din_i,
//    din_q,
//    last_en_i,
//    ready_en_o,
//    dout_en_o,
//    dout_i,
//    dout_q,
//    bin_o,
//    last_en_o,
//    error_en_o
//);

//input  wire                           clk;       // 捕获处理时钟
//input  wire                           rst;       // 高有效异步复位
//input  wire                           din_en_i;    // 复平方输入有效脉冲
//input  wire signed [FFT_IN_WID-1:0]   din_i;     // FFT 同相 16 bit 输入
//input  wire signed [FFT_IN_WID-1:0]   din_q;     // FFT 正交 16 bit 输入
//input  wire                           last_en_i;   // 一帧第 256 个输入标志
//output wire                           ready_en_o;  // FFT 可接收输入标志
//output wire                           dout_en_o;   // FFT 输出有效脉冲
//output wire signed [FFT_OUT_WID-1:0]  dout_i;    // 截位后 FFT 同相输出
//output wire signed [FFT_OUT_WID-1:0]  dout_q;    // 截位后 FFT 正交输出
//output wire [7:0]                     bin_o;       // FFT IP 给出的频点编号
//output wire                           last_en_o;   // 一帧第 256 个输出标志
//output wire                           error_en_o;  // FFT AXI 帧错误汇总标志

//reg config_en;
//reg config_done;
//wire config_ready;
//wire data_ready;
//wire [2*FFT_IP_WID-1:0] fft_data;
//wire [7:0] fft_user;
//wire signed [FFT_IP_WID-1:0] fft_i_cut;
//wire signed [FFT_IP_WID-1:0] fft_q_cut;
//wire event_frame_started;
//wire event_tlast_unexpected;
//wire event_tlast_missing;
//wire event_status_halt;
//wire event_input_halt;
//wire event_output_halt;

//always @ ( posedge clk or posedge rst )
//begin
//    if (rst)
//    begin
//        config_en <= 1'b0;
//        config_done <= 1'b0;
//    end
//    else
//    begin
//        if (!config_done)
//            config_en <= 1'b1;
//        if (config_en && config_ready)
//        begin
//            config_en <= 1'b0;
//            config_done <= 1'b1;
//        end
//    end
//end

//assign ready_en_o = data_ready & config_done;
//assign fft_i_cut = $signed(fft_data[FFT_IP_WID-1:0]) >>> FFT_OUT_CUT;
//assign fft_q_cut = $signed(fft_data[2*FFT_IP_WID-1:FFT_IP_WID]) >>> FFT_OUT_CUT;
//assign dout_i = fft_i_cut[FFT_OUT_WID-1:0];
//assign dout_q = fft_q_cut[FFT_OUT_WID-1:0];
//assign bin_o = fft_user;
//assign error_en_o = event_tlast_unexpected | event_tlast_missing |
//                    event_status_halt | event_input_halt | event_output_halt;

//fft_256 u_fft_256 (
//    .aclk                        (clk),
//    .aresetn                     (~rst),
//    .s_axis_config_tdata         (16'h0001),
//    .s_axis_config_tvalid        (config_en),
//    .s_axis_config_tready        (config_ready),
//    .s_axis_data_tdata           ({{(FFT_IP_WID-FFT_IN_WID){din_q[FFT_IN_WID-1]}}, din_q,
//                                   {(FFT_IP_WID-FFT_IN_WID){din_i[FFT_IN_WID-1]}}, din_i}),
//    .s_axis_data_tvalid          (din_en_i & config_done),
//    .s_axis_data_tready          (data_ready),
//    .s_axis_data_tlast           (last_en_i),
//    .m_axis_data_tdata           (fft_data),
//    .m_axis_data_tuser           (fft_user),
//    .m_axis_data_tvalid          (dout_en_o),
//    .m_axis_data_tready          (1'b1),
//    .m_axis_data_tlast           (last_en_o),
//    .event_frame_started         (event_frame_started),
//    .event_tlast_unexpected      (event_tlast_unexpected),
//    .event_tlast_missing         (event_tlast_missing),
//    .event_status_channel_halt   (event_status_halt),
//    .event_data_in_channel_halt  (event_input_halt),
//    .event_data_out_channel_halt (event_output_halt)
//);

//endmodule
