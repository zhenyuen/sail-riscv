/*
	Authored 2018-2019, Ryan Voo.

	All rights reserved.
	Redistribution and use in source and binary forms, with or without
	modification, are permitted provided that the following conditions
	are met:

	*	Redistributions of source code must retain the above
		copyright notice, this list of conditions and the following
		disclaimer.

	*	Redistributions in binary form must reproduce the above
		copyright notice, this list of conditions and the following
		disclaimer in the documentation and/or other materials
		provided with the distribution.

	*	Neither the name of the author nor the names of its
		contributors may be used to endorse or promote products
		derived from this software without specific prior written
		permission.

	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
	"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
	LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
	FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
	COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
	INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
	BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
	LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
	CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
	LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
	ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
	POSSIBILITY OF SUCH DAMAGE.
*/



`include "../include/rv32i-defines.v"
`include "../include/sail-core-defines.v"



/*
 *	Description:
 *
 *		This module implements the ALU for the RV32I.
 */



/*
 *	Not all instructions are fed to the ALU. As a result, the ALUctl
 *	field is only unique across the instructions that are actually
 *	fed to the ALU.
 */
module alu(clk, ALUctl, A, B, ALUOut, Branch_Enable);
	input clk;
	input [6:0]		ALUctl;
	input [31:0]		A;
	input [31:0]		B;
	output reg [31:0]	ALUOut;
	output reg		Branch_Enable;

	/*
	 *	This uses Yosys's support for nonzero initial values:
	 *
	 *		https://github.com/YosysHQ/yosys/commit/0793f1b196df536975a044a4ce53025c81d00c7f
	 *
	 *	Rather than using this simulation construct (`initial`),
	 *	the design should instead use a reset signal going to
	 *	modules in the design.
	 */

	wire carry_out;
	wire [31:0] dsp_add_out;
	wire [31:0] dsp_sub_out;



	// Registers
	reg [31:16]     sr_fill_r;
	reg [31:0]      sr_1_r;
	reg [31:0]      sr_2_r;
	reg [31:0]      sr_4_r;
	reg [31:0]      sr_8_r;
	reg [31:0]      sl_1_r;
	reg [31:0]      sl_2_r;
	reg [31:0]      sl_4_r;
	reg [31:0]      sl_8_r;

	DSPAdd add(
		.input1(A),
		.input2(B),
		.out(dsp_add_out)
	);

	DSPSub sub(
		.clk(clk),
		.input1(A),
		.input2(B),
		.out(dsp_sub_out),
		.carry_out(carry_out)
	);

	initial begin
		ALUOut = 32'b0;
		Branch_Enable = 1'b0;
	end

	always @(ALUctl, A, B) begin

		sr_fill_r = 16'b0;
		sr_1_r = 32'b0;
		sr_2_r = 32'b0;
		sr_4_r = 32'b0;
		sr_8_r = 32'b0;

		sl_1_r = 32'b0; // Shift left
		sl_2_r = 32'b0;
		sl_4_r = 32'b0;
		sl_8_r = 32'b0;



		case (ALUctl[3:0])
			/*
			 *	AND (the fields also match ANDI and LUI)
			 */
			`kSAIL_MICROARCHITECTURE_ALUCTL_3to0_AND:	ALUOut = A & B;

			/*
			 *	OR (the fields also match ORI)
			 */
			`kSAIL_MICROARCHITECTURE_ALUCTL_3to0_OR:	ALUOut = A | B;

			/*
			 *	ADD (the fields also match AUIPC, all loads, all stores, and ADDI)
			 */
			`kSAIL_MICROARCHITECTURE_ALUCTL_3to0_ADD: 	ALUOut = dsp_add_out;
														
			/*
			 *	SUBTRACT (the fields also matches all branches)
			 */
			`kSAIL_MICROARCHITECTURE_ALUCTL_3to0_SUB:	ALUOut = dsp_sub_out;

			/*
			 *	SLT (the fields also matches all the other SLT variants)
			 */
			`kSAIL_MICROARCHITECTURE_ALUCTL_3to0_SLT:	ALUOut = dsp_sub_out[31] ? 32'b1 : 32'b0;

			/*
			 *	SRL (the fields also matches the other SRL variants)
			 */
			`kSAIL_MICROARCHITECTURE_ALUCTL_3to0_SRL:	begin // ALUOut = A >> B[4:0];
				if (B[0] == 1'b1)
					sr_1_r = {sr_fill_r[31], A[31:1]};
				else
					sr_1_r = A;

				if (B[1] == 1'b1)
					sr_2_r = {sr_fill_r[31:30], sr_1_r[31:2]};
				else
					sr_2_r = sr_1_r;

				if (B[2] == 1'b1)
					sr_4_r = {sr_fill_r[31:28], sr_2_r[31:4]};
				else
					sr_4_r = sr_2_r;

				if (B[3] == 1'b1)
					sr_8_r = {sr_fill_r[31:24], sr_4_r[31:8]};
				else
					sr_8_r = sr_4_r;

				if (B[4] == 1'b1)
					ALUOut = {sr_fill_r[31:16], sr_8_r[31:16]};
				else
					ALUOut = sr_8_r;
			end


			/*
			 *	SRA (the fields also matches the other SRA variants)
			 */
			`kSAIL_MICROARCHITECTURE_ALUCTL_3to0_SRA:	begin // ALUOut = $signed(A) >>> B[4:0];
				// Arithmetic shift? Fill with 1's if MSB set
				if (A[31] == 1'b1)
					sr_fill_r = 16'b1111111111111111;
				else
					sr_fill_r = 16'b0000000000000000;

				if (B[0] == 1'b1)
					sr_1_r = {sr_fill_r[31], A[31:1]};
				else
					sr_1_r = A;

				if (B[1] == 1'b1)
					sr_2_r = {sr_fill_r[31:30], sr_1_r[31:2]};
				else
					sr_2_r = sr_1_r;

				if (B[2] == 1'b1)
					sr_4_r = {sr_fill_r[31:28], sr_2_r[31:4]};
				else
					sr_4_r = sr_2_r;

				if (B[3] == 1'b1)
					sr_8_r = {sr_fill_r[31:24], sr_4_r[31:8]};
				else
					sr_8_r = sr_4_r;

				if (B[4] == 1'b1)
					ALUOut = {sr_fill_r[31:16], sr_8_r[31:16]};
				else
					ALUOut = sr_8_r;
			end


			/*
			 *	SLL (the fields also match the other SLL variants)
			 */
			`kSAIL_MICROARCHITECTURE_ALUCTL_3to0_SLL:	begin // ALUOut = A << B[4:0];
				if (B[0] == 1'b1)
					sl_1_r = {A[30:0],1'b0};
				else
					sl_1_r = A;

				if (B[1] == 1'b1)
					sl_2_r = {sl_1_r[29:0],2'b00};
				else
					sl_2_r = sl_1_r;

				if (B[2] == 1'b1)
					sl_4_r = {sl_2_r[27:0],4'b0000};
				else
					sl_4_r = sl_2_r;

				if (B[3] == 1'b1)
					sl_8_r = {sl_4_r[23:0],8'b00000000};
				else
					sl_8_r = sl_4_r;

				if (B[4] == 1'b1)
					ALUOut = {sl_8_r[15:0],16'b0000000000000000};
				else
					ALUOut = sl_8_r;
			end
			
			
			/*
			 *	XOR (the fields also match other XOR variants)
			 */
			`kSAIL_MICROARCHITECTURE_ALUCTL_3to0_XOR:	ALUOut = A ^ B;

			/*
			 *	CSRRW  only
			 */
			`kSAIL_MICROARCHITECTURE_ALUCTL_3to0_CSRRW:	ALUOut = A;

			/*
			 *	CSRRS only
			 */
			`kSAIL_MICROARCHITECTURE_ALUCTL_3to0_CSRRS:	ALUOut = A | B;

			/*
			 *	CSRRC only
			 */
			`kSAIL_MICROARCHITECTURE_ALUCTL_3to0_CSRRC:	ALUOut = (~A) & B;

			/*
			 *	Should never happen.
			 */
			default:	ALUOut = 0;
		endcase
	end

	always @(ALUctl, ALUOut, A, B) begin
		case (ALUctl[6:4])
			`kSAIL_MICROARCHITECTURE_ALUCTL_6to4_BEQ:	Branch_Enable = (ALUOut == 0);
			`kSAIL_MICROARCHITECTURE_ALUCTL_6to4_BNE:	Branch_Enable = !(ALUOut == 0);
			`kSAIL_MICROARCHITECTURE_ALUCTL_6to4_BLT:	Branch_Enable = (ALUOut[31]); // ($signed(A) < $signed(B));
			`kSAIL_MICROARCHITECTURE_ALUCTL_6to4_BGE:	Branch_Enable = (~ALUOut[31]); // ($signed(A) >= $signed(B));
			`kSAIL_MICROARCHITECTURE_ALUCTL_6to4_BLTU:	Branch_Enable = (~carry_out); // ($unsigned(A) < $unsigned(B));
			`kSAIL_MICROARCHITECTURE_ALUCTL_6to4_BGEU:	Branch_Enable = carry_out; // ($unsigned(A) >= $unsigned(B));

			default:	Branch_Enable = 1'b0;
		endcase
	end
endmodule
