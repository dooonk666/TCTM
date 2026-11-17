`timescale 1ns / 1ps
// z=(I+jQ)e^(-jP): Ir=Icos+Qsin, Qr=Qcos-Isin.
// The preceding AGC controls amplitude. The mixer arithmetically shifts the
// full-precision result and saturates it to a symmetric ACQ_WID-bit range.
module mix_freq #(
    parameter integer DATA_WID  = 12,
    parameter integer ROM_WID   = 12,
    parameter integer PHASE_WID = 32,
    parameter integer ROM_AW    = 10,
    parameter integer ACQ_WID   = 3,
    parameter integer MIX_SHIFT = 17
) (
    clk,
    rst,
    din_en,
    din_i,
    din_q,
    fcw_en,
    phase_init_i,
    fcw,
    dout_en,
    dout_i,
    dout_q
);

localparam integer MIX_WID = DATA_WID + ROM_WID + 1;//25

input  wire                         clk;
input  wire                         rst;
input  wire                         din_en;
input  wire signed [DATA_WID-1:0]   din_i;
input  wire signed [DATA_WID-1:0]   din_q;
input  wire                         fcw_en;
input  wire                         phase_init_i;
input  wire signed [PHASE_WID-1:0]  fcw;
output wire                         dout_en;
output wire signed [ACQ_WID-1:0]    dout_i;
output wire signed [ACQ_WID-1:0]    dout_q;

reg [PHASE_WID-1:0] phase_acc;
reg signed [PHASE_WID-1:0] fcw_reg;
reg signed [DATA_WID-1:0] din_i_d1;
reg signed [DATA_WID-1:0] din_q_d1;
reg din_en_d1;

wire signed [ROM_WID-1:0] cos_data;
wire signed [ROM_WID-1:0] sin_data;
wire signed [ROM_WID-1:0] neg_sin_data;
wire [31:0] mult_a_tdata;
wire [31:0] mult_b_tdata;
wire        mult_dout_tvalid;
wire [63:0] mult_dout_tdata;
wire signed [MIX_WID-1:0] mix_i_full;
wire signed [MIX_WID-1:0] mix_q_full;
wire signed [MIX_WID-1:0] mix_i_shift;
wire signed [MIX_WID-1:0] mix_q_shift;
localparam signed [MIX_WID-1:0] ACQ_MAX_VALUE =
    (1 << (ACQ_WID-1)) - 1;
localparam signed [MIX_WID-1:0] ACQ_MIN_VALUE = -ACQ_MAX_VALUE;

wire [9:0] addr = phase_acc[PHASE_WID-1:PHASE_WID-ROM_AW];

cos_w12_d1024 u_cos_rom (
    .clka  (clk),
    .ena   (1'b1),
    .addra (phase_acc[PHASE_WID-1:PHASE_WID-ROM_AW]),
    .douta (cos_data)
);

sin_w12_d1024 u_sin_rom (
    .clka  (clk),
    .ena   (1'b1),
    .addra (phase_acc[PHASE_WID-1:PHASE_WID-ROM_AW]),
    .douta (sin_data)
);

// fcw_en only updates the frequency control word.
always @ (posedge clk or posedge rst)
begin
    if (rst)
        fcw_reg <= {PHASE_WID{1'b0}};
    else if (fcw_en)
        fcw_reg <= fcw;
end

// The phase accumulator advances only for a valid input sample.
always @ (posedge clk or posedge rst)
begin
    if (rst)
        phase_acc <= {PHASE_WID{1'b0}};
    else if (phase_init_i)
        phase_acc <= {PHASE_WID{1'b0}};
    else if (din_en)
        phase_acc <= phase_acc + fcw_reg;
end

always @ (posedge clk or posedge rst)
begin
    if (rst)
    begin
        din_i_d1 <= {DATA_WID{1'b0}};
        din_q_d1 <= {DATA_WID{1'b0}};
        din_en_d1 <= 1'b0;
    end
    else
    begin
        din_en_d1 <= din_en;

        if (din_en)
        begin
            din_i_d1 <= din_i;
            din_q_d1 <= din_q;
        end
    end
end

// Complex Multiplier AXI packing:
//   TDATA[11:0]  = real, TDATA[27:16] = imaginary.
// Multiplying (I+jQ) by (cos-j*sin) gives
//   real = I*cos+Q*sin, imag = Q*cos-I*sin.
assign neg_sin_data = -sin_data;
assign mult_a_tdata = {4'b0, din_q_d1, 4'b0, din_i_d1};
assign mult_b_tdata = {4'b0, neg_sin_data, 4'b0, cos_data};

mult12x12 u_mult12x12 (
    .aclk               (clk),
    .s_axis_a_tvalid    (din_en_d1),
    .s_axis_a_tdata     (mult_a_tdata),
    .s_axis_b_tvalid    (din_en_d1),
    .s_axis_b_tdata     (mult_b_tdata),
    .m_axis_dout_tvalid (mult_dout_tvalid),
    .m_axis_dout_tdata  (mult_dout_tdata)
);

// The IP output width is 25 bits per component and its configured latency is
// six clocks. Real is in [24:0], imaginary is in [56:32].
assign mix_i_full = mult_dout_tdata[24:0];
assign mix_q_full = mult_dout_tdata[56:32];
assign dout_en = mult_dout_tvalid & ~rst;
assign mix_i_shift = mix_i_full >>> MIX_SHIFT;
assign mix_q_shift = mix_q_full >>> MIX_SHIFT;

assign dout_i = (mix_i_shift > ACQ_MAX_VALUE) ? ACQ_MAX_VALUE[ACQ_WID-1:0] :
                (mix_i_shift < ACQ_MIN_VALUE) ? ACQ_MIN_VALUE[ACQ_WID-1:0] :
                                                mix_i_shift[ACQ_WID-1:0];
assign dout_q = (mix_q_shift > ACQ_MAX_VALUE) ? ACQ_MAX_VALUE[ACQ_WID-1:0] :
                (mix_q_shift < ACQ_MIN_VALUE) ? ACQ_MIN_VALUE[ACQ_WID-1:0] :
                                                mix_q_shift[ACQ_WID-1:0];

endmodule
