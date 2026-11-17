`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/10/12 18:27:00
// Design Name: 
// Module Name: Gold_Code_Generator
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module Gold_Code_Generator(
    clk,
    rst,
    trigger,
    Poly1,
    Poly2,
    init_Poly1,
    init_Poly2,
    PN_out
);

parameter M_LENGTH = 10;

input clk;
input rst;
input trigger;
input [M_LENGTH-1:0] Poly1;
input [M_LENGTH-1:0] Poly2;
input [M_LENGTH-1:0] init_Poly1;
input [M_LENGTH-1:0] init_Poly2;
output PN_out;

wire M1_out;
wire M2_out;
reg [M_LENGTH-1:0] pn_index;
localparam [M_LENGTH-1:0] LAST_CHIP = (1 << M_LENGTH) - 2;
wire restart = trigger && (pn_index == LAST_CHIP);

// The transmitted MATLAB vector repeats after 2^M_LENGTH-1 chips.
always @(posedge clk) begin
    if(rst) pn_index <= {M_LENGTH{1'b0}};
    else if(trigger) begin
        if(restart) pn_index <= {M_LENGTH{1'b0}};
        else pn_index <= pn_index + 1'b1;
    end
end

M_Sequence_Generator#(
    .ORDER(M_LENGTH)) 
M_1(
    .clk(clk),
    .rst(rst),
    .restart(restart),
    .Poly(Poly1),
    .init_state(init_Poly1),
    .trigger(trigger),
    .M_seq_out(M1_out)
);

M_Sequence_Generator#(
    .ORDER(M_LENGTH)) 
M_2(
    .clk(clk),
    .rst(rst),
    .restart(restart),
    .Poly(Poly2),
    .init_state(init_Poly2),
    .trigger(trigger),
    .M_seq_out(M2_out)
);

assign PN_out = M1_out ^ M2_out;

endmodule

module M_Sequence_Generator(
    clk,
    rst,
    restart,
    Poly,
    init_state,
    trigger,
    M_seq_out
);

parameter ORDER = 10;

input clk;
input rst;
input restart;
input [ORDER-1:0] Poly;
input [ORDER-1:0] init_state;
input trigger;
output M_seq_out;

reg [ORDER-1:0] M_reg;
wire [ORDER-1:0] M_reg_comp_temp;
wire M_reg_comp;

genvar i;
generate
    for(i=0;i<ORDER;i=i+1)begin:combination
        // Poly is the table's reverse-phase coefficient mask. Its top bit
        // denotes x^ORDER; MATLAB feedback uses the remaining coefficients.
        assign M_reg_comp_temp[i] = (i == ORDER-1) ? 1'b0 :
                                    (Poly[i] ? M_reg[i] : 1'b0);
    end
endgenerate

assign M_reg_comp = ^M_reg_comp_temp;

always @(posedge clk) begin
    if(rst || restart) M_reg[ORDER-1] <= init_state[ORDER-1];
    else if(trigger) M_reg[ORDER-1] <= M_reg_comp;
end

always @(posedge clk) begin
    if(rst || restart) M_reg[ORDER-2:0] <= init_state[ORDER-2:0];
    else if(trigger) M_reg[ORDER-2:0] <= M_reg[ORDER-1:1];
end

assign M_seq_out = M_reg[0];
endmodule
