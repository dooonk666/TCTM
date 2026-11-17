`timescale 1ns / 1ps

module AD9361_auto_instructor #(
    parameter integer WORD_COUNT  = 2045,
    parameter integer BOOT_CYCLES = 1000000
)(
    input  wire        clk,
    input  wire        rst,

    input  wire        instruction_finished,

    output reg         instruction_en,
    output reg  [39:0] instruction,
    output reg  [11:0] debug_addr
);

localparam [1:0] S_BOOT = 2'd0;
localparam [1:0] S_SEND = 2'd1;
localparam [1:0] S_WAIT = 2'd2;
localparam [1:0] S_DONE = 2'd3;

(* rom_style = "block" *)
reg [39:0] config_rom [0:WORD_COUNT-1];

reg [1:0]  state;
reg [31:0] boot_counter;

initial begin
    $readmemh("ad9361_config.mem", config_rom);
end

always @(posedge clk) begin
    if (rst) begin
        state          <= S_BOOT;
        boot_counter   <= 32'd0;
        debug_addr     <= 12'd0;
        instruction_en <= 1'b0;
        instruction    <= 40'd0;
    end
    else begin
        instruction_en <= 1'b0;

        case (state)
            S_BOOT: begin
                // 40 MHz 下等待约25 ms，
                // 保证原SPI控制器完成自身20 ms初始化
                if (boot_counter >= BOOT_CYCLES-1) begin
                    boot_counter <= 32'd0;
                    state <= S_SEND;
                end
                else begin
                    boot_counter <= boot_counter + 1'b1;
                end
            end

            S_SEND: begin
                instruction    <= config_rom[debug_addr];
                instruction_en <= 1'b1;
                state          <= S_WAIT;
            end

            S_WAIT: begin
                // 写寄存器、读寄存器或等待指令执行完成
                if (instruction_finished) begin
                    if (debug_addr == WORD_COUNT-1) begin
                        state <= S_DONE;
                    end
                    else begin
                        debug_addr <= debug_addr + 1'b1;
                        state <= S_SEND;
                    end
                end
            end

            S_DONE: begin
                instruction_en <= 1'b0;
            end

            default: state <= S_BOOT;
        endcase
    end
end

endmodule