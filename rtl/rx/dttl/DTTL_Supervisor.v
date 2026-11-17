`timescale 1ns / 1ps

module DTTL_Supervisor #(
    parameter [28:0] MIN_SUM_MAG= 29'd0
)(
    input wire clk,
    input wire rst,
    input wire enable,
    input wire [1:0] mode,

    input wire symbol_valid,
    input wire [21:0] entire_in,
    input wire [21:0] middle_in,

    output wire dttl_rst,
    output reg restart_pulse
);

reg [5:0] cnt = 0;
reg restart_pulse_d1;

reg [28:0] entire_sum;
reg [28:0] middle_sum;
wire [21:0] entire_abs;
wire [21:0] middle_abs;

assign entire_abs = entire_in[21]?(~entire_in + 22'd1):entire_in;
assign middle_abs = middle_in[21]?(~middle_in + 22'd1):middle_in;
// Divider Generator requires at least two reset clock cycles.
assign dttl_rst = rst || !enable || restart_pulse || restart_pulse_d1;

always @(posedge clk) begin
    if (rst || !enable)
        restart_pulse_d1 <= 1'b0;
    else
        restart_pulse_d1 <= restart_pulse;
end

wire isbad_window;

assign isbad_window =
    ((entire_sum + middle_sum) > MIN_SUM_MAG) &&
    ((middle_sum << 1) >
    (entire_sum + (entire_sum << 1)));

always @(posedge clk) begin
    if (dttl_rst) begin
        entire_sum <= 29'd0;
        middle_sum <= 29'd0;
        cnt        <= 6'd0;
    end
    else if (cnt == 6'd32) begin
        if (symbol_valid) begin
            // 当前输入作为下一组的第1笔。
            entire_sum <= {7'd0, entire_abs};
            middle_sum <= {7'd0, middle_abs};
            cnt        <= 6'd1;
        end
        else begin
            entire_sum <= 29'd0;
            middle_sum <= 29'd0;
            cnt        <= 6'd0;
        end
    end
    else if (symbol_valid) begin
        entire_sum <= entire_sum + {7'd0, entire_abs};
        middle_sum <= middle_sum + {7'd0, middle_abs};
        cnt        <= cnt + 1'b1;
    end
end


always@(posedge clk) begin
    if(dttl_rst) restart_pulse <= 1'b0;
    else begin
        if(isbad_window && (cnt == 6'd32)) restart_pulse <= 1'b1;
        else restart_pulse <= 1'b0;
    end
end


endmodule