`timescale 1ns / 100ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench for Data_Buffer_Xclk
//////////////////////////////////////////////////////////////////////////////////

module tb_Data_Buffer_Xclk;

    reg clk;
    reg rst;
    reg clk_R;
    reg [11:0] ad_din_i;
    reg [11:0] ad_din_q;

    wire dout_en;
    wire [11:0] dout_i;
    wire [11:0] dout_q;

    Data_Buffer_Xclk u_Data_Buffer_Xclk (
        .clk       (clk),
        .rst       (rst),
        .clk_R     (clk_R),
        .ad_din_i  (ad_din_i),
        .ad_din_q  (ad_din_q),
        .dout_en   (dout_en),
        .dout_i    (dout_i),
        .dout_q    (dout_q)
    );

    always #5 clk = ~clk;
    always #25 clk_R = ~clk_R;

    initial begin
        clk = 1'b1; clk_R = 1'b1;
        rst = 1'b1;
        ad_din_i = 12'd0;
        ad_din_q = 12'd0;
        #2;
        #500;
        rst = 1'b0;

        #500;
    end

always @(posedge clk_R)begin
    ad_din_i <= ad_din_i + 1;
    ad_din_q <= ad_din_q - 1;
end

endmodule