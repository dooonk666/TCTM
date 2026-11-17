`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: DTTL_Top
// Description:
//   DTTL top level:
//       NCO -> Entire/Middle Integrator -> PD -> Loop Filter -> NCO
//
//   MODE:
//       1 : 2 ksym/s, nominal_osr = 1534.5
//       2 : 4 ksym/s, nominal_osr = 767.25
//       3 : 8 ksym/s, nominal_osr = 383.625
//////////////////////////////////////////////////////////////////////////////////

module DTTL_Top(
    clk,
    rst,
    restart_half_phase,
    update_en,
    MODE,
    data_in,

    entire_en,
    entire_out,
    middle_out,

    PD_en,
    PD_out,

    FCW_update_en,
    FCW_modifying,
    FCW_out,
    NCO_out,
    trig
);

parameter INPUT_WIDTH = 11;
parameter ACC_WIDTH = 22;
parameter PD_WIDTH = 17;
parameter FCW_WIDTH = 25;
parameter NCO_WIDTH = 32;

parameter CEQ_WIDTH = 23;
parameter FCW_MOD_WIDTH = 26;

input clk;
input rst;
input restart_half_phase;
input update_en;
input [1:0] MODE;
input signed [INPUT_WIDTH-1:0] data_in;

output entire_en;
output signed [ACC_WIDTH-1:0] entire_out;
output signed [ACC_WIDTH-1:0] middle_out;

output PD_en;
output signed [PD_WIDTH-1:0] PD_out;

output FCW_update_en;
output signed [FCW_MOD_WIDTH-1:0] FCW_modifying;
output [FCW_WIDTH-1:0] FCW_out;
output [NCO_WIDTH-1:0] NCO_out;
output trig;

wire [FCW_WIDTH-1:0] FCW_basic;
wire signed [CEQ_WIDTH-1:0] Ceq;


// 初始FCW
assign FCW_basic =
    (MODE == 2'd2) ? 25'd5597872 :
    (MODE == 2'd3) ? 25'd11195744 :
                     25'd2798936;


// Ceq = C2*Kf/(2*pi)，Q4
// MODE1:  6843.8094  -> 109501
// MODE2: 27375.2378  -> 438004
// MODE3:109500.9510  -> 1752015
assign Ceq =
    (MODE == 2'd2) ? 23'sd438004 :
    (MODE == 2'd3) ? 23'sd1752015 :
                     23'sd109501;

wire integrator_entire_en;
reg first_symbol_seen;

always @(posedge clk) begin
    if (rst)
        first_symbol_seen <= 1'b0;
    else if (integrator_entire_en)
        first_symbol_seen <= 1'b1;
end

// 第一笔积分可能只有半个符号，屏蔽；从第二笔开始输出。
// 全局复位后也同样丢弃第一笔。
assign entire_en = integrator_entire_en && first_symbol_seen;
// ============================================================================
// NCO
// ============================================================================

DTTL_NCO #(
    .NCO_WIDTH(NCO_WIDTH),
    .FCW_WIDTH(FCW_WIDTH),
    .FCW_MOD_WIDTH(FCW_MOD_WIDTH)
)
DTTL_NCO_inst(
    .clk(clk),
    .rst(rst),
    .restart_half_phase(restart_half_phase),
    .update_en(update_en),

    .FCW_basic(FCW_basic),
    .FCW_modifying_en(FCW_update_en),
    .FCW_modifying(FCW_modifying),

    .trig(trig),
    .FCW_out(FCW_out),
    .NCO_out(NCO_out)
);


// ============================================================================
// Entire / Middle integrator
// ============================================================================

DTTL_Integrator #(
    .INPUT_WIDTH(INPUT_WIDTH),
    .ACC_WIDTH(ACC_WIDTH),
    .MEM_ADDR_WIDTH(10)
)
DTTL_Integrator_inst(
    .clk(clk),
    .rst(rst),
    .update_en(update_en),
    .trig(trig),
    .MODE(MODE),
    .data_in(data_in),

    .entire_en(integrator_entire_en),
    .entire_out(entire_out),
    .middle_out(middle_out)
);


// ============================================================================
// Phase detector
// ============================================================================

DTTL_PD #(
    .ENTIRE_WIDTH(ACC_WIDTH),
    .MIDDLE_WIDTH(ACC_WIDTH),
    .PD_WIDTH(PD_WIDTH),
    .LOOP_FRAC(15)
)
DTTL_PD_inst(
    .clk(clk),
    .rst(rst),

    .entire_en(entire_en),
    .entire_in(entire_out),
    .middle_in(middle_out),

    .PD_en(PD_en),
    .PD_out(PD_out)
);


// ============================================================================
// First-order loop filter
// ============================================================================

DTTL_Loop_Filter #(
    .PD_WIDTH(PD_WIDTH),
    .CEQ_WIDTH(CEQ_WIDTH),
    .FCW_MOD_WIDTH(FCW_MOD_WIDTH),
    .LOOP_FRAC(15),
    .CEQ_FRAC(4)
)
DTTL_Loop_Filter_inst(
    .clk(clk),
    .rst(rst),

    .PD_en(PD_en),
    .PD_in(PD_out),
    .Ceq(Ceq),

    .FCW_en(FCW_update_en),
    .FCW_modifying(FCW_modifying)
);

endmodule
