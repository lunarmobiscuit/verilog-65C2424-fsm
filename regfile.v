/*
 * regfile.v 
 *
 * (C) Arlet Ottens, <arlet@c-scape.nl>
 * 24-bit address and 8/16/24-bit data (C) Luni Libes, <https://www.lunarmobiscuit.com/the-apple-4-or-the-mos-652402/>
 *
 */

module regfile(
    input clk,
    input reg_we,
    input [1:0] reg_src,
    input [1:0] reg_dst,
    input [1:0] reg_idx,
    output [23:0] src,
    output [23:0] idx,
    input [23:0] dst,
    output reg [15:0] S,
    input txs,
    input push,
    input pull,
    input variation );

`include "define.i"

/*
 * register file
 */
reg [23:0] regs[3:0];                    // register file

/* 
 * initial values for easy debugging, not required
 */
initial begin
    regs[SEL_Z] = 0;                    // Z register 
    regs[SEL_X] = 1;                    // X register 
    regs[SEL_Y] = 2;                    // Y register
    regs[SEL_A] = 24'h0;                // A register
    S = 16'hffff;                       // S register
end

/*
 * 1st read port: source register
 *
 */
assign src = regs[reg_src];

/*
 * 2nd read port: index register
 */
assign idx = regs[reg_idx];

/*
 * write port: destination register. 
 */
always @(posedge clk)
    if( reg_we ) begin
        regs[reg_dst] <= dst;
//$display("REG[%s] <= %h", (reg_dst == DST_X) ? "X" : (reg_dst == DST_Y) ? "Y" : (reg_dst == DST_A) ? "A" : "?", dst);
    end

/*
 * update stack pointer
 */
always @(posedge clk)
    if( txs )       S <= src[15:0];
    else if( push ) S <= S - 1;
    else if( pull ) S <= S + 1;

/*
 * store CPU stats in A
 */
always @(posedge clk)
    if( variation ) regs[SEL_A] = {16'h6502, R_16, AB_24, 4'h0};    // 24-bit address bus & 16-bit data bus/registers

endmodule
