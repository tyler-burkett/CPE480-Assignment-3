// basic sizes of things
`define WORD        [15:0]
`define HALFWORD    [7:0]
`define OPcode1     [15:11]
`define OPcode2     [7:3]
`define REG1        [10:8]
`define REG2        [2:0]
`define IMM8        [7:0]
`define STATE       [5:0]
`define TYPEDREG    [16:0]
`define REGSIZE     [7:0]
`define MEMSIZE     [65535:0]
`define REGNUM      [2:0]




// opcode values, also state numbers
`define OPno        5'b00000
`define OPpre       5'b00001
`define OPjp8       5'b00011
`define OPsys       5'b00010
`define OPcf8       5'b00110
`define OPci8       5'b00111
`define OPjnz8      5'b00101
`define OPjz8       5'b00100
`define OPa2r       5'b01100
`define OPr2a       5'b01101
`define OPlf        5'b01111
`define OPli        5'b01110
`define OPst        5'b01010
`define OPjr        5'b01001
`define OPadd       5'b11000
`define OPsub       5'b11001
`define OPmul       5'b11011
`define OPdiv       5'b11010
`define OPand       5'b11110
`define OPor        5'b11111
`define OPxor       5'b11101
`define OPnot       5'b11100
`define OPsh        5'b10100
`define OPslt       5'b10101
`define OPcvt       5'b10111


//state numbers only
`define Start       5'b01000
`define Start1      5'b10000
`define Start2      5'b10001


//Module stuff
`define ALU     	5'b1xxxx

//Accumulator values
`define acc0        3'b000
`define acc1        3'b001

//boolean values
`define true        1'b1
`define false       1'b0

// Floating point Verilog modules for CPE480
// Created February 19, 2019 by Henry Dietz, http://aggregate.org/hankd
// Distributed under CC BY 4.0, https://creativecommons.org/licenses/by/4.0/

// Field definitions
`define	INT	signed [15:0]	// integer size
`define FLOAT	[15:0]	// half-precision float size
`define FSIGN	[15]	// sign bit
`define FEXP	[14:7]	// exponent
`define FFRAC	[6:0]	// fractional part (leading 1 implied)

// Constants
`define	FZERO	16'b0	  // float 0
`define F32767  16'h46ff  // closest approx to 32767, actually 32640
`define F32768  16'hc700  // -32768

// Count leading zeros, 16-bit (5-bit result) d=lead0s(s)
module lead0s(d, s);
output wire [4:0] d;
input wire `WORD s;
wire [4:0] t;
wire [7:0] s8;
wire [3:0] s4;
wire [1:0] s2;
assign t[4] = 0;
assign {t[3],s8} = ((|s[15:8]) ? {1'b0,s[15:8]} : {1'b1,s[7:0]});
assign {t[2],s4} = ((|s8[7:4]) ? {1'b0,s8[7:4]} : {1'b1,s8[3:0]});
assign {t[1],s2} = ((|s4[3:2]) ? {1'b0,s4[3:2]} : {1'b1,s4[1:0]});
assign t[0] = !s2[1];
assign d = (s ? t : 16);
endmodule

// Float set-less-than, 16-bit (1-bit result) torf=a<b
module fslt(torf, a, b);
output wire torf;
input wire `FLOAT a, b;
assign torf = (a `FSIGN && !(b `FSIGN)) ||
	      (a `FSIGN && b `FSIGN && (a[14:0] > b[14:0])) ||
	      (!(a `FSIGN) && !(b `FSIGN) && (a[14:0] < b[14:0]));
endmodule

// Floating-point addition, 16-bit r=a+b
module fadd(r, a, b);
output wire `FLOAT r;
input wire `FLOAT a, b;
wire `FLOAT s;
wire [8:0] sexp, sman, sfrac;
wire [7:0] texp, taman, tbman;
wire [4:0] slead;
wire ssign, aegt, amgt, eqsgn;
assign r = ((a == 0) ? b : ((b == 0) ? a : s));
assign aegt = (a `FEXP > b `FEXP);
assign texp = (aegt ? (a `FEXP) : (b `FEXP));
assign taman = (aegt ? {1'b1, (a `FFRAC)} : ({1'b1, (a `FFRAC)} >> (texp - a `FEXP)));
assign tbman = (aegt ? ({1'b1, (b `FFRAC)} >> (texp - b `FEXP)) : {1'b1, (b `FFRAC)});
assign eqsgn = (a `FSIGN == b `FSIGN);
assign amgt = (taman > tbman);
assign sman = (eqsgn ? (taman + tbman) : (amgt ? (taman - tbman) : (tbman - taman)));
lead0s m0(slead, {sman, 7'b0});
assign ssign = (amgt ? (a `FSIGN) : (b `FSIGN));
assign sfrac = sman << slead;
assign sexp = (texp + 1) - slead;
assign s = (sman ? (sexp ? {ssign, sexp[7:0], sfrac[7:1]} : 0) : 0);
endmodule

// Floating-point multiply, 16-bit r=a*b
module fmul(r, a, b);
output wire `FLOAT r;
input wire `FLOAT a, b;
wire [15:0] m; // double the bits in a fraction, we need high bits
wire [7:0] e;
wire s;
assign s = (a `FSIGN ^ b `FSIGN);
assign m = ({1'b1, (a `FFRAC)} * {1'b1, (b `FFRAC)});
assign e = (((a `FEXP) + (b `FEXP)) -127 + m[15]);
assign r = (((a == 0) || (b == 0)) ? 0 : (m[15] ? {s, e, m[14:8]} : {s, e, m[13:7]}));
endmodule

// Floating-point reciprocal, 16-bit r=1.0/a
// Note: requires initialized inverse fraction lookup table
module frecip(r, a);
output wire `FLOAT r;
input wire `FLOAT a;
reg [6:0] look[127:0];
initial $readmemh3(look);
assign r `FSIGN = a `FSIGN;
assign r `FEXP = 253 + (!(a `FFRAC)) - a `FEXP;
assign r `FFRAC = look[a `FFRAC];
endmodule

// Floating-point shift, 16 bit
// Shift +left,-right by integer
module fshift(r, f, i);
output wire `FLOAT r;
input wire `FLOAT f;
input wire `INT i;
assign r `FFRAC = f `FFRAC;
assign r `FSIGN = f `FSIGN;
assign r `FEXP = (f ? (f `FEXP + i) : 0);
endmodule

// Integer to float conversion, 16 bit
module i2f(f, i);
output wire `FLOAT f;
input wire `INT i;
wire [4:0] lead;
wire `WORD pos;
assign pos = (i[15] ? (-i) : i);
lead0s m0(lead, pos);
assign f `FFRAC = (i ? ({pos, 8'b0} >> (16 - lead)) : 0);
assign f `FSIGN = i[15];
assign f `FEXP = (i ? (128 + (14 - lead)) : 0);
endmodule

// Float to integer conversion, 16 bit
// Note: out-of-range values go to -32768 or 32767
module f2i(i, f);
output wire `INT i;
input wire `FLOAT f;
wire `FLOAT ui;
wire tiny, big;
fslt m0(tiny, f, `F32768);
fslt m1(big, `F32767, f);
assign ui = {1'b1, f `FFRAC, 16'b0} >> ((128+22) - f `FEXP);
assign i = (tiny ? 0 : (big ? 32767 : (f `FSIGN ? (-ui) : ui)));
endmodule


// ALU0 - First phase of the ALU
// Outputs
//	 	outVal is the output of the first phase alu
// 		out1 is the value of the first register used in the instruction.
// 		out2 is the value of the second register used in the isntruction.
// 		oreg1 is the first register used in the alu
// 		oreg2 is the second register used in the alu
// 		oop is the opcode of the instruction
//		otyp is the type of the numbers
// Inputs
// 		in1 is the value of the first register used in the instruction.
// 		in2 is the value of the second register used in the isntruction.
// 		ireg1 is the first register used in the alu.
// 		ireg2 is the second register used in the alu.
// 		iop is the opcode of the instruction.
// 		typ is the type of number used in the operation.
module ALU0(outVal, out1, out2, oreg1, oreg2, oop, otyp, in1, in2, ireg1, ireg2, iop, typ, stall);
	input [4:0] iop;
	input typ; //0->integer arithmetic, 1->floating point arithmetic
	//$acc should always be in1 and $r should be in2.
	input signed `WORD in1, in2;
	input reg `REGID ireg1, ireg2;
	output signed `WORD out1, out2;
	output reg `TYPEDREG outVal;
	output reg `REGID oreg1, oreg2;	
	output [4:0] oop;
	output otyp;
	
	reg [4:0] lastOp;
	reg lastType;
	reg signed `WORD lastIn1, lastIn2;
	reg `REGID lastReg1, lastReg2;
	reg `TYPEDREG lastVal;
	
	assign oop = lastOp;
	assign oreg1 = lastReg1;
	assign oreg2 = lastReg2;
	assign out1 = lastIn1;
	assign out2 = lastIn2;
	assign otyp = lastType;
	assign outVal = lastVal;
	
	wire signed `WORD recr, addr, subr, shr, mulr, sltr;
	wire signed `WORD outand, outor, outnot, outxor, outslt;
	wire signed `WORD cvti, cvtf;

	//Assign the bitwise operations.
	assign outand = in1 & in2;
	assign outor = in1 | in2;
	assign outxor = in1 ^ in2;
	assign outnot = ~in2;
	assign outslt = in1 < in2;
	//Instantiate the floating point modules.
	fadd fa(addr, in1, in2);
	//Use fadd with the negated version of in2.
	//Negate by flipping the top bit of the float.
	fadd fsu(subr, in1, {~in2[15], in2[14:0]});
	fmul fm(mulr, in1, in2);
	frecip fr(recr, in2);
	fshift fs(shr, in1, in2);
	fslt fsl(sltr, in1, in2);
	i2f icvt(cvti, in2);
	f2i fcvt(cvtf, in2);
	always @(posedge clk) begin #1
		if (!stall) begin
			case(iop)
				`OPadd: begin
					case(typ)
						0: begin lastVal <= {typ, in1 + in2}; end
						1: begin lastVal <= {typ, addr}; end
					endcase
				end
				`OPsub: begin
					case(typ)
						0: begin lastVal <= {typ, in1 - in2}; end
						1: begin lastVal <= {typ, subr}; end
					endcase
				end
				`OPmul: begin
					case(typ)
						0: begin lastVal <= {typ, in1 * in2}; end
						1: begin lastVal <= {typ, mulr}; end
					endcase
				end
				`OPdiv: begin
					case(typ)
						0: begin lastVal <= {typ, in1 / in2;} end
						1: begin lastVal <= {typ, recr}; end // Only perform the first half of the fp division here.
					endcase
				end
				`OPand: begin lastVal <= {typ, outand}; end
				`OPor:  begin lastVal <= {typ, outor}; end
				`OPxor: begin lastVal <= {typ, outxor}; end
				`OPnot: begin lastVal <= {typ, outnot}; end
			//Positive indicates left shift.
				`OPsh:  begin
					case(typ)
						0:  begin lastVal <= {typ, in1 << in2}; end
						1:  begin lastVal <= {typ, shr}; end
					endcase
				end
				`OPslt: begin
					case(typ)
						0:  begin lastVal <= {typ, outslt}; end
						1:  begin lastVal <= {typ, sltr}; end
					endcase
				end
				`OPcvt: begin
					case(typ)
						0:  begin lastVal <= {!typ, cvti}; end
						1:  begin lastVal <= {!typ, cvtf}; end
					endcase
				end			
				default: lastVal <= 16'b0;
			endcase
			
			lastOp <= iop;
			lastReg1 <= ireg1;
			lastReg2 <= ireg2;
			lastIn1 <= in1;
			lastIn2 <= in2;
			lastType <= typ;
		end
	end
endmodule

// ALU1 - second phase of the ALU
// Outputs
//	 	outVal is the output of the second phase alu
// 		out1 is the value of the first register used in the instruction.
// 		out2 is the value of the second register used in the isntruction.
// 		oreg1 is the first register used in the alu
// 		oreg2 is the second register used in the alu
// 		oop is the opcode of the instruction
//		otyp is the type of the numbers
// Inputs
// 		inVal is the value received from ALU part 1.
// 		in1 is the value of the first register used in the instruction.
// 		in2 is the value of the second register used in the isntruction.
// 		ireg1 is the first register used in the alu.
// 		ireg2 is the second register used in the alu.
// 		iop is the opcode of the instruction.
// 		typ is the type of number used in the operation.
module ALU1(outVal, out1, out2, oreg1, oreg2, oop, otyp, inVal, in1, in2, ireg1, ireg2, iop, typ, stall);
	input [4:0] iop;
	input typ; //0->integer arithmetic, 1->floating point arithmetic
	//$acc should always be in1 and $r should be in2.
	input signed `WORD in1, in2;
	input reg `REGID ireg1, ireg2;
	input reg `TYPEDREG inVal;
	output signed `WORD out1, out2;
	output reg `TYPEDREG outVal;
	output reg `REGID oreg1, oreg2;	
	output [4:0] oop;
	output otyp;
	
	reg [4:0] lastOp;
	reg lastType;
	reg signed `WORD lastIn1, lastIn2;
	reg `REGID lastReg1, lastReg2;
	reg `TYPEDREG lastVal;
	
	assign oop = lastOp;
	assign oreg1 = lastReg1;
	assign oreg2 = lastReg2;
	assign out1 = lastIn1;
	assign out2 = lastIn2;
	assign otyp = lastType;
	assign outVal = lastVal;
	
	wire signed `WORD divr;

	fmul fd(divr, in1, inVal);
	
	always @(posedge clk) begin #1
		if (!stall) begin
			case(iop)
				`OPdiv: begin
					case(typ)
						0: begin lastVal <= inVal; end
						1: begin lastVal <= {typ, divr}; end
					endcase
				end
				default: outVal <= inVal;
			endcase
			
			lastOp <= iop;
			lastReg1 <= ireg1;
			lastReg2 <= ireg2;
			lastIn1 <= in1;
			lastIn2 <= in2;
			lastType <= typ;
		end
	end
endmodule


module tacky_processor(halt, reset, clk);

//stage 0 regs & memory
reg `WORD next_pc, pc, pc_inc, instruction;
reg `WORD instruction_mem `MEMSIZE;

//stage 1 regs
reg `TYPEDREG regfile `REGSIZE;
reg `HALFWORD pre;
reg `WORD imm_to_ALUMEM;
reg `TYPEDREG acc0_val, acc1_val, r1_val, r2_val;
reg `Word ins_to_ALUMEM;

//stage 2 regs & memory
reg `WORD data_mem `MEMSIZE;
reg `WORD ins_to_ALU2;
reg `TYPEDREG data1_to_ALU2, data2_to_ALU2;

//stage 3 regs
reg `WORD ins_to_WB;
reg `TYPEDREG data1_to_WB, data2_to_WB;
reg `TYPEDREG ALU1_result, ALU2_result;

//stage 4 regs
reg `TYPEDREG reg1_val, reg2_val;
reg `REGNUM reg1_load, reg2_load;
reg reg1_load_flag, reg2_load_flag, jump_flag;
reg `WORD pc_next;


always@(posedge reset) begin
    $readmemh0(regfile);
    $readmemh1(instruction_mem);
    $readmemh2(data_mem);
end

//stage 0: instruction fetch
always@(posedge clk) begin
    pc <= next_pc;
    instruction <= instruction[pc]
    pc_inc <= (jump_flag) ? pc_next : pc_inc + 1;
end

//stage 1: register read
always@(posedge clk) begin
    if(instruction `Opcode1 == `OPpre) pre <= instruction `IMM8;
    imm_to_ALUMEM <= {pre, instruction `IMM8};
    acc0_val <= regfile[0];
    acc1_val <= regfile[1];
    r1_val <= regfile`REG1;
    r2_val <= regfile`REG2;
    ins_to_ALUMEM <= instruction;
end

//stage 2: ALU/MEM
always@(posedge clk) begin

    ins_to_ALU2 <= ins_to_ALUMEM;
end
//stage 3: ALU2
always@(posedge clk) begin

    ins_to_WB <= ins_to_ALU2;
    data1_to_WB <= data1_to_ALU2;
    data2_to_WB <= data2_to_ALU2;
end

//stage 4: writeback
always@(posedge clk) begin
    //Opcode1 >= sh -> ALU op
    //Opcode1 >= jr -> 2 OP/Word
    //Opcode1 <= jr -> 1 OP/Word
    //reg1_load <= ins_to_WB `REG1
    //reg2_load <= ins_to_WB `REG2
    
    //First instruction logic WB
    if(ins_to_WB `Opcode1 >= `OPsh || ins_to_WB `Opcode1 == `OPr2a) begin
        reg1_load <= `acc0;
        reg1_val  <= ALU1_result;
        reg1_flag <= `true;
    end
    else if (ins_to_WB `Opcode1 == `OPlf || ins_to_WB `Opcode1 == `OPli) begin
        reg1_load <= ins_to_WB `REG1;
        reg1_val  <= data_to_WB;
        reg1_flag <= `true;
    end
    else if (ins_to_WB `Opcode1 == `OPa2r) begin
        reg1_load <= ins_to_WB `REG1;
        reg1_val  <= ALU1_result;
        reg1_flag <= `true;
    end
    else begin
        reg1_flag <= `false;
        reg2_flag <= `false;
    end
    
    //Second instruction logic WB (if present)
    if(ins_to_WB `Opcode1 >= `OPjr)  begin
        if(ins_to_WB `Opcode2 >= `OPsh || ins_to_WB `Opcode2== `OPr2a) begin
            reg2_load <= `acc1;
            reg2_val  <= ALU2_result;
            reg2_flag <= `true;
        end
        else if (ins_to_WB `Opcode2 == `OPlf || ins_to_WB `Opcode2 == `OPli) begin
            reg2_load <= ins_to_WB `REG2;
            reg2_val  <= data_to_WB;
            reg2_flag <= `true;
        end
        else if (ins_to_WB `Opcode2 == `OPa2r) begin
            reg2_load <= ins_to_WB `REG2;
            reg2_val  <= ALU2_result;
            reg2_flag <= `true;
        end
        else begin
            reg2_flag <= `false;
        end
    end
    
    //jump instruciton logic WB
    
    

end

endmodule
