module regfile (
	clock,
	ctrl_writeEnable, ctrl_reset, ctrl_writeReg,
	ctrl_readRegA, ctrl_readRegB, data_writeReg,
	data_readRegA, data_readRegB
);

	input clock, ctrl_writeEnable, ctrl_reset;
	input [4:0] ctrl_writeReg, ctrl_readRegA, ctrl_readRegB;
	input [31:0] data_writeReg;

	output [31:0] data_readRegA, data_readRegB;


	wire [31:0] decW, decA, decB;
	assign decW = 32'b1 << ctrl_writeReg;
	assign decA = 32'b1 << ctrl_readRegA;
	assign decB = 32'b1 << ctrl_readRegB;

	
	wire [31:0] q [31:0];

	
	assign q[0] = 32'b0;


	wire we [31:0];
	assign we[0] = 1'b0;

	genvar i;
	generate
		for (i = 1; i < 32; i = i + 1) begin : GEN_WE
			and (we[i], ctrl_writeEnable, decW[i]);
		end
	endgenerate


	generate
		for (i = 1; i < 32; i = i + 1) begin : GEN_REGS
			reg32 r (
				.clk(clock),
				.rst(ctrl_reset),
				.en(we[i]),
				.d(data_writeReg),
				.q(q[i])
			);
		end
	endgenerate


	generate
		for (i = 0; i < 32; i = i + 1) begin : GEN_READ_A
			tristate32 tsa (
				.in(q[i]),
				.en(decA[i]),
				.out(data_readRegA)
			);
		end
	endgenerate

	generate
		for (i = 0; i < 32; i = i + 1) begin : GEN_READ_B
			tristate32 tsb (
				.in(q[i]),
				.en(decB[i]),
				.out(data_readRegB)
			);
		end
	endgenerate

endmodule


module reg32(input clk, input rst, input en, input [31:0] d, output [31:0] q);
	genvar b;
	generate
		for (b = 0; b < 32; b = b + 1) begin : GEN_BITS
			dffe_ref ff(q[b], d[b], clk, en, rst);
		end
	endgenerate
endmodule



module tristate32(input [31:0] in, input en, output [31:0] out);
	assign out = en ? in : 32'bz;
endmodule
