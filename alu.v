/*
 * alu.v 
 *
 * (C) Arlet Ottens, <arlet@c-scape.nl>
 * 24-bit address and 8/16/24-bit data (C) Luni Libes, <https://www.lunarmobiscuit.com/the-apple-4-or-the-mos-652402/>
 *
 */

module alu(
    input [8:0] alu_op,             // alu_op = control[10:2] = decode[15:7]
    input [23:0] R,
    input [15:0] S,
    input [7:0] DI,
    input [7:0] DR,
    input [7:0] D3,
    input [7:0] D4,
    input C,
    input [1:0] RWDTH,
    output reg [23:0] alu_out,
    output reg alu_C,
    output alu_Z,
    output reg alu_N,
    output reg alu_V );

`include "define.i"

wire shift = alu_op[8];             // SR column, 2'b msb  // SR = shift register
wire right = alu_op[7];             // SR column, 2'b lsb
reg [23:0] alu_ai;
reg [23:0] alu_bi;
reg alu_ci;
reg alu_si;
assign alu_Z = (alu_out == 8'b00);
reg [23:0] MEM;                     // @@@ redo as a wire intead of a register
reg [23:0] R_IN;                    // @@@ redo as a wire intead of a register

always @* begin
    /* 
     * use register width to determine inputs
     */
    case( RWDTH )
        R_08: R_IN = { 16'h0000, R[7:0] };
        R_16: R_IN = { 8'h00, R[15:0] };
        default: R_IN = R;
    endcase
    case( RWDTH )
        R_24: MEM = { DR, D3, D4 };
        R_16: MEM = { 8'h00, DR, D3 };
        default: MEM = { 8'h00, 8'h00, DR };
    endcase

    /* 
     * determine ALU A input.
     */
    casez( alu_op[6:4] )                // 9'b SR__A__B__C  // A = ALU A input register
        3'b0?0: alu_ai = R_IN;          // input from register file
        3'b0?1: alu_ai = MEM;           // input from data bus 
        3'b100: alu_ai = R_IN | MEM;    // ORA between register and memory
        3'b101: alu_ai = R_IN & MEM;    // AND between register and memory 
        3'b110: alu_ai = R_IN ^ MEM;    // EOR between register and memory 
        3'b111: alu_ai = S;             // stack pointer (for TSX)
    endcase
    
    /*
     * determine ALU B input
     */
    casez( alu_op[3:2] )            // 9'b SR__A__B__C  // B = ALU B input register
        2'b00: alu_bi = 0;          // for LDA, logic operations and INC
        2'b01: alu_bi = MEM;        // for ADC
        2'b10: alu_bi = ~0;         // for DEC
        2'b11: alu_bi = ~MEM;       // for SBC/CMP
    endcase

    /*
     * determine ALU carry input
     */
    casez( alu_op[1:0] )            // 9'b SR__A__B__C  // C = ALU carry input register
        2'b00: alu_ci = 0;          // no carry
        2'b01: alu_ci = 1;          // carry=1 for INC
        2'b10: alu_ci = C;          // for ADC/SBC
        2'b11: alu_ci = 0;          // for rotate
    endcase

    /*
     * add it all up. If we don't need addition, then the B/C inputs
     * should be kept at 0.
     */

    {alu_C, alu_out} = alu_ai + alu_bi + alu_ci;

    /* 
     * determine shift input for rotate instructions
     */
    alu_si = C & alu_op[0];         // 9'b SR__A__B__C  // C = carry input

    /* 
     * shift/rotate the result if necessary. Note that there's 
     * a trick to replace alu_out with DI input when shift=0, 
     * but right=1. This allows ALU bypass for PLA/PLX/PLY.
     */

    if( shift )
        if( right )
            {alu_out, alu_C} = {alu_si, alu_out};
        else
            {alu_C, alu_out} = {alu_out, alu_si};
    else if( right )
        alu_out = DI;

    /* 
     * these can't be assigned with the variable width ALU
     * assign these after all other calulations
     */
    alu_N = (RWDTH == R_24) ? alu_out[23] : (RWDTH == R_16) ? alu_out[15] : alu_out[7];
    alu_V = (RWDTH == R_24) ? (alu_ai[23] ^  alu_bi[23] ^ alu_C ^ alu_N) :
             (RWDTH == R_16) ? (alu_ai[15] ^  alu_bi[15] ^ alu_C ^ alu_N) :
              (alu_ai[7] ^  alu_bi[7] ^ alu_C ^ alu_N); 
end

endmodule
