`timescale 1ns / 1ps
// Lane zero occupies the low six bits. Two banks of 22 parallel RAMs.
module sample_store #(
    parameter integer DATA_WID = 3,
    parameter integer LANES = 128, //每行复数采样点
    parameter integer LANE_AW = 7,
    parameter integer ROW_AW = 8  //depth = 2^8 = 256
) (
    input wire clk,
    input wire rst,
    input wire clear_en_i,
    input wire wr_bank_i,
    input wire wr_en_i,
    input wire [DATA_WID-1:0] wr_i_i,
    input wire [DATA_WID-1:0] wr_q_i,
    output reg full_en_o,
    input wire rd_bank_i,
    input wire rd_en_i, //存满数据读出0-255，共2046次
    input wire [ROW_AW-1:0] rd_addr_i,
    output reg rd_en_o,
    output reg [ROW_AW-1:0] rd_addr_o,
    output wire [LANES*2*DATA_WID-1:0] rd_data_o
);
localparam integer SAMPLE_WID = 2*DATA_WID;
localparam integer ROW_WID = LANES*SAMPLE_WID; //一行宽768bit
localparam integer RAM_NUM = (ROW_WID+35)/36;
reg [ROW_WID-1:0] row_pack;
reg [ROW_WID-1:0] row_next;
reg [LANE_AW-1:0] lane_count;
reg [ROW_AW-1:0] row_count;
reg rd_bank;
reg rd_en_d1;
reg rd_bank_d1;
reg [ROW_AW-1:0] rd_addr_d1;
wire [RAM_NUM*36-1:0] wr_data;
wire [RAM_NUM*36-1:0] rd_data_a, rd_data_b;
wire row_write;
assign row_write = wr_en_i && !rst && !clear_en_i && (lane_count == LANES-1);
assign wr_data = {{(RAM_NUM*36-ROW_WID){1'b0}},row_next};
assign rd_data_o = rd_bank ? rd_data_b[ROW_WID-1:0] : rd_data_a[ROW_WID-1:0];

// 拼接行 row_pack = {IQ127,...,IQ0};
always @* begin
    row_next = row_pack;
    row_next[lane_count*SAMPLE_WID +: SAMPLE_WID] = {wr_q_i,wr_i_i};
end
always @(posedge clk or posedge rst) begin
    if (rst) begin
        row_pack <= 0;
        lane_count <= 0;
        row_count <= 0;
        full_en_o <= 0;
    end else begin
        full_en_o <= 0;
        if (clear_en_i) begin
            row_pack <= 0;
            lane_count <= 0;
            row_count <= 0;
        end 
        else if (wr_en_i) begin
            row_pack <= row_next;
            if (lane_count == LANES-1) begin //拼满一行使能row_write并写入ram
                lane_count <= 0;
                if (row_count == (1<<ROW_AW)-1) begin
                    row_count <= 0;
                    full_en_o <= 1;
                end 
                else row_count <= row_count + 1'b1;
            end 
            else lane_count <= lane_count + 1'b1;
        end
    end
end
// Port B includes the BRAM output register: two clocks including drain.
always @(posedge clk or posedge rst) begin
    if (rst) begin
        rd_en_o <= 0;
        rd_addr_o <= 0;
        rd_bank <= 0;
        rd_en_d1 <= 0;
        rd_bank_d1 <= 0;
        rd_addr_d1 <= 0;
    end else begin
        rd_en_d1 <= rd_en_i;
        rd_en_o <= rd_en_d1;
        if (rd_en_i) begin
            rd_addr_d1 <= rd_addr_i;
            rd_bank_d1 <= rd_bank_i;
        end
        if (rd_en_d1) begin
            rd_addr_o <= rd_addr_d1;
            rd_bank <= rd_bank_d1;
        end
    end
end
genvar g;
generate for (g=0; g<RAM_NUM; g=g+1) begin : RAM
    ram_w36_d256 u_ram_a (
        .clka(clk), 
        .ena(row_write && !wr_bank_i), 
        .wea(1'b1),
        .addra(row_count), 
        .dina(wr_data[g*36 +: 36]),
        .clkb(clk), 
        .enb(((rd_en_i && !rd_bank_i) || (rd_en_d1 && !rd_bank_d1)) && !rst),
        .addrb(rd_addr_i), 
        .doutb(rd_data_a[g*36 +: 36])
    );
    ram_w36_d256 u_ram_b (
        .clka(clk), 
        .ena(row_write && wr_bank_i), 
        .wea(1'b1),
        .addra(row_count),
        .dina(wr_data[g*36 +: 36]),
        .clkb(clk), 
        .enb(((rd_en_i && rd_bank_i) || (rd_en_d1 && rd_bank_d1)) && !rst),
        .addrb(rd_addr_i), 
        .doutb(rd_data_b[g*36 +: 36])
    );
end endgenerate
endmodule
