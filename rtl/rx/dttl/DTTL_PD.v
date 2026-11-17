`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: DTTL_PD
// Description:
//   DTTL phase detector.
//   PD = -PD_sign * Middle/ref, output in signed Q15.
//
// Divider Generator configuration:
//   Algorithm Type      : Radix2
//   Operating Sign      : Signed
//   Dividend Width      : 38
//   Divisor Width       : 23
//   Remainder Type      : Remainder
//   Clocks per Division : see the div_gen_0 IP configuration
//   Flow Control        : Non Blocking
//   Latency             : Automatic
//////////////////////////////////////////////////////////////////////////////////

module DTTL_PD(
    clk,
    rst,
    entire_en,
    entire_in,
    middle_in,
    PD_en,
    PD_out
);

parameter ENTIRE_WIDTH = 22;
parameter MIDDLE_WIDTH = 22;
parameter PD_WIDTH = 17;
parameter LOOP_FRAC = 15;

input clk;
input rst;
input entire_en;
input signed [ENTIRE_WIDTH-1:0] entire_in;
input signed [MIDDLE_WIDTH-1:0] middle_in;

output reg PD_en;
output reg signed [PD_WIDTH-1:0] PD_out;

reg signed [ENTIRE_WIDTH-1:0] entire_last;
reg have_last;
reg [ENTIRE_WIDTH-1:0] ref_magnitude;

// reg signed [1:0] PD_sign;
// reg middle_sign;
wire signed [37:0] middle_numerator;
wire signed [37:0] pd_numerator;

/* Divider input:
 * 38-bit signed dividend -> AXI TDATA padded to 40 bits
 * 23-bit signed divisor  -> AXI TDATA padded to 24 bits
 */
reg div_input_valid;
reg [23:0] div_divisor_data;

reg [39:0] div_dividend_data;

// The board project's fully pipelined div_gen_0 accepts one pair of operands
// per clock and has no input TREADY ports. Pulse both TVALIDs together.

/* Remainder output:
 * quotient 38 bit -> padded to 40 bit
 * remainder 23 bit -> padded to 24 bit
 * total AXI TDATA = 64 bit
 */
wire div_output_valid;
wire [63:0] div_output_data;
wire div_by_0_flag;

wire signed [37:0] div_quotient;
wire signed [22:0] div_remainder;

// Saturate before narrowing the signed Q15 quotient. For PD_WIDTH=17,
// the representable integer range is -65536..65535 (Q15: -2..just below +2).
localparam signed [PD_WIDTH-1:0] PD_MAX =
    {1'b0, {(PD_WIDTH-1){1'b1}}};
localparam signed [PD_WIDTH-1:0] PD_MIN =
    {1'b1, {(PD_WIDTH-1){1'b0}}};
localparam signed [37:0] PD_MAX_EXT =
    {{(38-PD_WIDTH){1'b0}}, PD_MAX};
localparam signed [37:0] PD_MIN_EXT =
    {{(38-PD_WIDTH){1'b1}}, PD_MIN};

assign div_quotient  = div_output_data[61:24];
assign div_remainder = div_output_data[22:0];

wire [ENTIRE_WIDTH-1:0] entire_abs;
wire [MIDDLE_WIDTH-1:0] middle_abs;
wire [ENTIRE_WIDTH-1:0] ref_next;
wire [ENTIRE_WIDTH-1:0] ref_half;

wire sign_change;
wire [37:0] numerator_round;

// reg signed [39:0] pd_res;


assign entire_abs =
    entire_in[ENTIRE_WIDTH-1] ?
    (~entire_in + {{(ENTIRE_WIDTH-1){1'b0}},1'b1}) :
    entire_in;

assign middle_abs =
    middle_in[MIDDLE_WIDTH-1] ?
    (~middle_in + {{(MIDDLE_WIDTH-1){1'b0}},1'b1}) :
    middle_in;

assign ref_next =
    (entire_abs > ref_magnitude) ?
    entire_abs :
    ref_magnitude;

assign ref_half =
    {1'b0,ref_next[ENTIRE_WIDTH-1:1]};

assign sign_change =
        ((entire_last >= 0) && (entire_in < 0))
    || ((entire_last < 0)  && (entire_in >= 0));

/* round(|Middle| / ref * 2^15)
 *
 * max |Middle| is about 2^21.
 * After <<15 the largest term is about 2^36.
 * numerator_round is therefore safely represented by 38 bits.
 */
assign numerator_round =
    ({16'd0,middle_abs} << LOOP_FRAC)
    +
    {{16{1'b0}},ref_half};


/* Integer quotient is already Q15 because the dividend was pre-scaled
 * by 2^15 before entering the divider.
 */
// always @(*) begin

//     pd_res = $signed({2'b00,div_quotient});

//     if(middle_sign)
//         pd_res = -pd_res;

//     if(PD_sign == 2'sd1)
//         pd_res = -pd_res;
//     else if(PD_sign == 2'sd0)
//         pd_res = 40'sd0;

// end
// 恢复 Middle 的正负号
assign middle_numerator =
    middle_in[MIDDLE_WIDTH-1] ?
    -$signed(numerator_round) :
     $signed(numerator_round);

// PD = -PD_sign * Middle/ref
// 正 -> 负：PD_sign=+1，因此分子取负
// 负 -> 正：PD_sign=-1，因此分子保持
// 无翻转：后面的时序逻辑直接送零分子
assign pd_numerator =
    (!entire_last[ENTIRE_WIDTH-1] &&
      entire_in[ENTIRE_WIDTH-1]) ?
    -middle_numerator :
     middle_numerator;


// 输入操作数准备：每个有效符号都发起一次除法
always @(posedge clk) begin
    if(rst) begin
        entire_last      <= {ENTIRE_WIDTH{1'b0}};
        have_last        <= 1'b0;
        ref_magnitude    <= {ENTIRE_WIDTH{1'b0}};

        div_input_valid  <= 1'b0;
        div_dividend_data <= 40'd0;
        div_divisor_data  <= 24'd1;
    end
    else begin
        // 与下面寄存的分子、分母对应
        div_input_valid <= entire_en;

        if(entire_en) begin
            entire_last <= entire_in;
            have_last   <= 1'b1;

            if(entire_abs > ref_magnitude)
                ref_magnitude <= entire_abs;

            // 分母不能为零。
            // 没有有效幅度时用1，配合零分子得到零PD。
            if(ref_next != 0)
                div_divisor_data <= {2'b00, ref_next};
            else
                div_divisor_data <= 24'd1;

            // 默认：首个符号、无翻转、零幅度均输出有效零PD
            div_dividend_data <= 40'd0;

            // 确实发生翻转时，计算带符号的归一化PD
            if(have_last &&
               sign_change &&
               entire_in != 0 &&
               ref_next != 0) begin

                // 38位有符号分子，符号扩展为40位AXI数据
                div_dividend_data <= {
                    {2{pd_numerator[37]}},
                    pd_numerator
                };
            end
        end
    end
end


// 输出有效：参考老师DDLL_PD的写法
always @(posedge clk) begin
    if(rst)
        PD_en <= 1'b0;
    else
        PD_en <= div_output_valid;
end


// 输出数据与PD_en同拍更新
always @(posedge clk) begin
    if(rst)
        PD_out <= {PD_WIDTH{1'b0}};
    else if(div_output_valid) begin
        if(div_by_0_flag)
            PD_out <= {PD_WIDTH{1'b0}};
        else if(div_quotient > PD_MAX_EXT)
            PD_out <= PD_MAX;
        else if(div_quotient < PD_MIN_EXT)
            PD_out <= PD_MIN;
        else
            PD_out <= div_quotient[PD_WIDTH-1:0];
    end
end



// always @(posedge clk) begin

//     if(rst) begin

//         entire_last   <= {ENTIRE_WIDTH{1'b0}};
//         have_last     <= 1'b0;
//         ref_magnitude <= {ENTIRE_WIDTH{1'b0}};

//         PD_sign     <= 2'sd0;
//         middle_sign <= 1'b0;

//         div_input_valid   <= 1'b0;
//         div_divisor_data  <= 24'd0;

//         div_dividend_data  <= 40'd0;

//         PD_en  <= 1'b0;
//         PD_out <= {PD_WIDTH{1'b0}};

//     end
//     else begin

//         /* Input and output valid signals are one-clock pulses. */
//         PD_en <= 1'b0;
//         div_input_valid <= 1'b0;


//         if(entire_en) begin

//             if(entire_abs > ref_magnitude)
//                 ref_magnitude <= entire_abs;

//             if(!have_last ||
//                !sign_change ||
//                entire_in == 0 ||
//                ref_next == 0) begin

//                 PD_out <= {PD_WIDTH{1'b0}};

//             end
//             else begin

//                 if((entire_last >= 0) && (entire_in < 0))
//                     PD_sign <= 2'sd1;
//                 else
//                     PD_sign <= -2'sd1;

//                 middle_sign <= middle_in[MIDDLE_WIDTH-1];

//                 /* 38-bit dividend, padded to 40-bit AXI TDATA */
//                 div_dividend_data <= {2'b00,numerator_round};

//                 /* 23-bit signed divisor = {0,ref_next},
//                  * padded to 24-bit AXI TDATA
//                  */
//                 div_divisor_data <= {2'b00,ref_next};

//                 div_input_valid <= 1'b1;

//             end

//             entire_last <= entire_in;
//             have_last   <= 1'b1;

//         end


//         if(div_output_valid) begin
//             PD_out <= pd_res[PD_WIDTH-1:0];
//             PD_en <= 1'b1;
//         end

//     end

// end


div_gen_0 dttl_divider_inst(
    .aclk(clk),
    .aresetn(~rst),
    .s_axis_divisor_tvalid(div_input_valid),
    .s_axis_divisor_tdata(div_divisor_data),

    .s_axis_dividend_tvalid(div_input_valid),
    .s_axis_dividend_tdata(div_dividend_data),
    .m_axis_dout_tuser(div_by_0_flag),   // 新增
    .m_axis_dout_tvalid(div_output_valid),
    .m_axis_dout_tdata(div_output_data)
);

endmodule
