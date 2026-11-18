`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: DTTL_Integrator
// Description:
//   Entire / Middle two-branch integrator.
//   MODE1/2/3 use Middle delays of 767/384/192 samples.
//   A circular delay memory is used instead of shifting 767 registers every clk.
//////////////////////////////////////////////////////////////////////////////////

module DTTL_Integrator(
    clk,
    rst,
    update_en,
    trig,
    MODE,
    data_in,
    entire_en,
    entire_out,
    middle_out
);

parameter INPUT_WIDTH = 11;
parameter ACC_WIDTH = 22;
parameter MEM_ADDR_WIDTH = 10;       // 2^10 = 1024 > 767

input clk;
input rst;
input update_en;
input trig;
input [1:0] MODE;
input signed [INPUT_WIDTH-1:0] data_in;

output reg entire_en;
output reg signed [ACC_WIDTH-1:0] entire_out;
output reg signed [ACC_WIDTH-1:0] middle_out;
//bram
wire ram_en;
wire signed [INPUT_WIDTH-1:0] middle_rd;

// 保存与BRAM读出数据对应的当前样本和控制信号
reg signed [INPUT_WIDTH-1:0] data_d;
reg valid_d;
reg trig_d;
reg middle_valid_d;

assign ram_en = update_en && !rst;

// 环形缓存

reg [MEM_ADDR_WIDTH-1:0] w_pos;
reg [MEM_ADDR_WIDTH:0] sample_count;

reg signed [ACC_WIDTH-1:0] entire_acc;
reg signed [ACC_WIDTH-1:0] middle_acc;

wire [MEM_ADDR_WIDTH-1:0] middle_delay;
wire [MEM_ADDR_WIDTH-1:0] r_pos;
wire signed [INPUT_WIDTH-1:0] middle_data;

wire signed [ACC_WIDTH-1:0] data_ext;
wire signed [ACC_WIDTH-1:0] middle_ext;
wire signed [ACC_WIDTH:0] entire_sum;
wire signed [ACC_WIDTH:0] middle_sum;


// MODE1 / MODE2 / MODE3
assign middle_delay = (MODE == 2'd2) ? 10'd384 : (MODE == 2'd3) ? 10'd192 : 10'd767;

// w_pos指向“当前输入样本将写入的位置”
// 因此 w_pos-middle_delay 对应 x(i-middle_delay) 就sap_cnt超过一半时才开始算
assign r_pos = w_pos - middle_delay;
// 当前样本不到middle_delay个样本时，middle_data输出0
assign middle_data = middle_valid_d ? middle_rd : {INPUT_WIDTH{1'b0}};

// 扩展到22位 data_in前面补符号位，middle_data前面补符号位 
assign data_ext = {{(ACC_WIDTH-INPUT_WIDTH){data_d[INPUT_WIDTH-1]}}, data_d};
assign middle_ext = {{(ACC_WIDTH-INPUT_WIDTH){middle_data[INPUT_WIDTH-1]}}, middle_data};

// 补到23位 防止累加溢出
assign entire_sum = {entire_acc[ACC_WIDTH-1], entire_acc} + {data_ext[ACC_WIDTH-1], data_ext};
assign middle_sum = {middle_acc[ACC_WIDTH-1], middle_acc} + {middle_ext[ACC_WIDTH-1], middle_ext};


// Middle延迟存储 每次rst w_pos和sample_count清零 就重新开始存储
always @(posedge clk) begin
    if(rst) begin
        w_pos <= 0;
        sample_count <= 0;

        data_d <= 0;
        trig_d <= 0;
        valid_d <= 0;
        middle_valid_d <= 0;
    end
    else begin
        valid_d <= update_en;
        trig_d <= update_en && trig;

        middle_valid_d <= update_en && (sample_count >= middle_delay);

        if(update_en) begin
            data_d <= data_in;
            w_pos <= w_pos + 1'b1;
            if(sample_count < (1<<MEM_ADDR_WIDTH)) sample_count <= sample_count + 1'b1;
        end
    end
end


// 有效信号：只在有效输入样本触发符号结束时拉高
always @(posedge clk) begin
    if(rst)
        entire_en <= 1'b0;
    else
        entire_en <= valid_d && trig_d;
end


// Entire / Middle积分
always @(posedge clk) begin
    if(rst) begin
        entire_acc <= {ACC_WIDTH{1'b0}};
        middle_acc <= {ACC_WIDTH{1'b0}};
        entire_out <= {ACC_WIDTH{1'b0}};
        middle_out <= {ACC_WIDTH{1'b0}};
    end
    else begin
        if(valid_d) begin
            // 当前输入样本先进入积分，再根据NCO溢出结束当前符号
            if(trig_d) begin
                entire_out <= entire_sum;
                middle_out <= middle_sum;
                entire_acc <= {ACC_WIDTH{1'b0}};
                middle_acc <= {ACC_WIDTH{1'b0}};
            end
            else begin
                entire_acc <= entire_sum;
                middle_acc <= middle_sum;
            end
        end
    end
end


dttl_delay_bram bram_delay(
    .clka(clk),    // input wire clka
    .ena(ram_en),      // input wire ena
    .wea(1'b1),      // input wire [0 : 0] wea
    .addra(w_pos),  // input wire [9 : 0] addra
    .dina(data_in),    // input wire [10 : 0] dina
        
    .clkb(clk),    // input wire clkb
    .enb(ram_en),      // input wire enb
    .addrb(r_pos),  // input wire [9 : 0] addrb
    .doutb(middle_rd)  // output wire [10 : 0] doutb
);


endmodule
