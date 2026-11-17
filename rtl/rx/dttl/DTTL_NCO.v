`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: DTTL_NCO
// Description:
//   32-bit DTTL phase accumulator.
//   FCW is updated by a signed correction from the loop filter.
//   The overflow signal is combinational so the integrator can close the
//   current symbol on the same clock edge as the NCO overflow.
//////////////////////////////////////////////////////////////////////////////////

module DTTL_NCO(
    clk,
    rst,
    restart_half_phase,
    update_en,
    FCW_basic,
    FCW_modifying_en,
    FCW_modifying,
    trig,
    FCW_out,
    NCO_out
);

parameter NCO_WIDTH = 32;
parameter FCW_WIDTH = 25;
// fcw修正量的位宽
parameter FCW_MOD_WIDTH = 26;

input clk;
input rst;
input restart_half_phase;
input update_en;
input [FCW_WIDTH-1:0] FCW_basic;
input FCW_modifying_en;
input signed [FCW_MOD_WIDTH-1:0] FCW_modifying; //26

output trig;
output [FCW_WIDTH-1:0] FCW_out;
output [NCO_WIDTH-1:0] NCO_out;

reg [FCW_WIDTH-1:0] FCW;
reg [NCO_WIDTH-1:0] NCO;

wire [NCO_WIDTH-1:0] FCW_ext;
// 多一位是为了在加法时检测溢出
wire [NCO_WIDTH:0] NCO_sum;

wire signed [FCW_MOD_WIDTH:0] FCW_sum;


// nco = nco+fcw 所以要前面补0 做到位宽一致
assign FCW_ext = {{(NCO_WIDTH-FCW_WIDTH){1'b0}}, FCW};
assign NCO_sum = {1'b0, NCO} + {1'b0, FCW_ext};

// 当前这个采样在本次时钟边沿是否发生NCO溢出
assign trig = update_en & NCO_sum[NCO_WIDTH];

// 取最高位拼接 27位相加
assign FCW_sum =
    $signed({{(FCW_MOD_WIDTH+1-FCW_WIDTH){1'b0}}, FCW}) +
    $signed({FCW_modifying[FCW_MOD_WIDTH-1], FCW_modifying});


// FCW更新
always @(posedge clk) begin
    if(rst)
        FCW <= FCW_basic;
    else if(FCW_modifying_en) begin
        FCW <= FCW_sum[FCW_WIDTH-1:0];
    end
end


always @(posedge clk) begin
    if (rst) begin
        if (restart_half_phase)
            // 32位时等于32'h80000001：半周期初相
            NCO <= {1'b1, {(NCO_WIDTH-2){1'b0}}, 1'b1};
        else
            // 全局复位：保持原来的初相1
            NCO <= {{(NCO_WIDTH-1){1'b0}}, 1'b1};
    end
    else if (update_en) begin
        NCO <= NCO_sum[NCO_WIDTH-1:0];
    end
end

assign FCW_out = FCW;
assign NCO_out = NCO;

endmodule
