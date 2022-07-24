# verilog-65C2424-fsm
A verilog model of the mythical 65C2424 CPU, an upgrade path to the WDC 65C02 with a 24-bit address bus, 24-bit wide A/X/Y registers, and a 16-bit S register 

## Design goals
The main design goal is to show the possibility of a backwards-compatible 65C02 with a 24-bit
address bus and up to 24-bit registers, with no modes, no new flags, and no new address modes, blending in 8/16/24 bit operations seemlessly into the exising opcodes.

The $xF unused opcodes are used as a prefix code to access these new abilities.

Opcode $0F: CPU fills the A register with #$6502{r,a}0, where {r,a} is a nibble containing the maximum address and register sizes.
a = $0 is the standard 16-bit address bus (64K)
a = $1 is 24-bit addresses (16MB)
a = $2 and $03 are not supported, for future upgrades to 32-bit and 48-bit addresses
r = $0 is the standard 8-bit registers
r = $1 is 16-bit registers
r = $2 is 24-bit registers
r = $3 is not supported, for future upgrades to 32-bit registers 

Prefix opcode $1F: A24 does nothing by itself.  Like in the Z80, it's a prefix code that modifies the
subsequent opcode.  When prefixed all ABS / ABS,X / ABS,Y / IND, and IND,X opcodes take a three byte address in the
subsequent three bytes.  E.g. $1F $AD $EF $78 $56 = LDA $5678EF.

Opcode A24 before a JMP or JSR changes those opcodes to use three bytes to specify the address,
with this 24-bit version of JSR pushing three bytes onto the stack: low, high, 3rd.  The matching
24-bit RTS ($1F $60) pops three bytes off the stack low, high, and 3rd.

RTI always pops four bytes: low, high, and 3rd for the IR, then 1 byte for the flags
(But Arlet's code doesn't support IRQ or NMI, so this CPU never pushes those bytes)

Prefix opcode $4F: R16 does nothing by itself.  Like in the Z80, it's a prefix code that modifies the
subsequent opcode.  When prefixed all IMM / ABS / ABS,X / ABS,Y / IND, and IND,X / ZP / (ZP) / (ZP,X) / ZP,X / ZP,Y opcodes load 2 bytes into the destination register, store 2 bytes from the source register, or read 2 bytes from memory.  When repfixed on INA / INX / INY / DEA / DEX / DEY / TAX / TAY / TSX / TXA / TXS / TYA, 16-bits are updated in the target register.  E.g. $4F $A9 $34 $12 = LDA #1234.  R16 PHA / R16 PHX / R16 PHY push two bytes onto the stack.  R16 PLA / R16 PLX / R16 PLY pull two bytes onto the stack.

Prefix opcode $8F: R32 does nothing by itself.  The behavior is similar to R16 except 3 bytes of loaded into the 24-bit registers (except for S, which is never more than 16-bits wide), and 3 bytes are pushed or pulled to/from the stack.  E.g. $8F $A9 $56 $34 $12 = LDA #123456.

Prefix opcodes $5F and $9F combine the above behaviors, allowing for 24-bit addresses and 16-bit or 24-bit register or memory access.

The IRQ, RST, and NMI vectors are $FFFFF7/8/9, $FFFFFA/B/C, and $FFFFFD/E/F.

Without the prefix code, all opcodes are identical to the 65C02.  Historic code without prefix codes using JSR/RTS will use 2-byte/16-bit addresses.

The only non-backward-compatible behaviors are the new interrupt vectors. A new RST handler
could simply JMP ($FFFC), presuming a copy of the historic ROM was addressable at in page $FF.
A new IRQ handler similarly JMP ($FFFE).  The only issue would be legacy interrupt handlers
that assumed the return address was the top two bytes on the stack, rather than three.

Upon RST, the CPU resets to 24-byte addresses and 8-bit registers, loading the first opcode from the RST vector.  If that is not a prefix code, the CPU drops back to 16-bit addresses and 8-bit registers.

## Changes from the original

PC (the program counter) is extended from 16-bits to 24-bits 
AB (the address bus) is extended from 16-bits to 24-bits
D3 (a new data register) is added to allow loading three-byte addresses
D4 (a new data register) is added to allow loading three-byte data

One new decode line is added for pushing the third byte for the long JSR
One new decode line is added for pushing/pulling multiple bytes to/from the stack

A handful of new states were added to the finite state machine that process the opcodes.  For the 24-bit addresses, these new states handling loading extra bytes for ABS addresses, three-byte JMP/JSR, and three-byte RTS/RTI.  For the wider registers, one extra state is added for looping on a new counter to count down the proper number of bytes.

## Building with and without the testbed

main.v, ram.v, ram.hex, and vec.hex are the testbed, using the SIM macro to enable simulations.
E.g. iverilog -D SIM -o test *.v; vvp test

ram.hex is 128K, loaded from $000000-$01ffff.  Accessing RAM above $020000 returns x's.
vec.hex are the NMI, RST, and IRQ vectors, loaded at $FFFFF0-$FFFFFF (each is three bytes)

Use macro ONEXIT to dump the contents of RAM 16-bytes prior to the RST vector and 16-bites starting
at the RST vector before and after running the simulation.  16-bytes so that you can use those
bytes as storage in your test to check the results.

The opcode HLT (#$db) will end the simulation.

## Built upon verilog-65C2402-fsm

This variation is built upon my 65C2402, which only grows the address bus while leaving the registers alone.
The threads from verilog-65C24T8-fsm are *not* included in this variation.


# Based on Arlet Ottens's verilog-65C02-fsm
## (Arlet's notes follow)
A verilog model of the 65C02 CPU. The code is rewritten from scratch.

* Assumes synchronous memory
* Uses finite state machine rather than microcode for control
* Designed for simplicity, size and speed
* Reduced cycle count eliminates all unnecessary cycles

## Design goals
The main design goal is to provide an easy understand implementation that has good performance

## Code
Code is far from complete.  Right now it's in a 'proof of concept' stage where the address
generation and ALU are done in a quick and dirty fashion to test some new ideas. Once I'm happy
with the overall design, I can do some optimizations. 

* cpu.v module is the top level. 

Code has been tested with Verilator. 

## Status

* All CMOS/NMOS 6502 instructions added (except for NOPs as undefined, Rockwell/WDC extensions)
* Model passes Klaus Dormann's test suite for 6502 (with BCD *disabled*)
* BCD not yet supported
* SYNC, RST supported
* IRQ, RDY, NMI not yet supported

### Cycle counts
For purpose of minimizing design and performance improvement, I did not keep the original cycle
count. All of the so-called dead cycles have been removed.
(65C2424 has more cycles for prefixed opcodes, and counts below *include* A24 prefix)

| Instruction type | Cycles | 24-addr | 16-reg | 24-reg |
| :--------------: | :----: | :-----: | :----: | :----: |
| Implied PHx/PLx  |   2    |         |        |        |
| RTS              |   4    |   6     |        |        |
| RTI              |   5    |   7     |        |        |
| BRK              |   7    |         |        |        |
| Other implied    |   1    |         |        |        |
| JMP Absolute     |   3    |   5     |        |        |
| JMP (Indirect)   |   5    |   8     |        |        |
| JSR Absolute     |   5    |   7     |        |        |
| branch           |   2    |         |        |        |
| Immediate        |   2    |         |   4    |   5    |
| Zero page        |   3    |         |   5    |   6    |
| Zero page, X     |   3    |         |   5    |   6    |
| Zero page, Y     |   3    |         |   5    |   6    |
| Absolute         |   4    |   6     |   7    |   8    |
| Absolute, X      |   4    |   6     |   7    |   8    |
| Absolute, Y      |   4    |   6     |   7    |   8    |
| (Zero page)      |   5    |         |   7    |   8    |
| (Zero page), Y   |   5    |         |   7    |   8    |
| (Zero page, X)   |   5    |         |   7    |   8    |

Add 1 cycle for any read-modify-write. There is no extra cycle for taken branches, page overflows, or for X/Y offset calculations.

Have fun. 
