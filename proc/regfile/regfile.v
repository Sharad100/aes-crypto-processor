module regfile (
    clock,
    ctrl_writeEnable,
    ctrl_reset,
    ctrl_writeReg,
    ctrl_readRegA,
    ctrl_readRegB,
    data_writeReg,
    data_readRegA,
    data_readRegB,
    ctrl_writeVecEnable,
    ctrl_writeVecReg,
    ctrl_readVecRegA,
    ctrl_readVecRegB,
    data_readVecRegA,
    data_readVecRegB,
    data_writeVecReg
);

  input clock, ctrl_writeEnable, ctrl_writeVecEnable, ctrl_reset;
  input [4:0] ctrl_writeReg, ctrl_readRegA, ctrl_readRegB;
  input [2:0] ctrl_writeVecReg, ctrl_readVecRegA, ctrl_readVecRegB;
  input [127:0] data_writeVecReg;
  input [31:0] data_writeReg;

  output [31:0] data_readRegA, data_readRegB;
  output [127:0] data_readVecRegA, data_readVecRegB;

  // 32b bus, 1-hot by definition
  // These will trigger tri-state buffers or write-enables
  wire [31:0] in_decoderA, in_decoderB, in_decoderWE;
  wire [7:0] in_vec_decoderA, in_vec_decoderB, in_vec_decoderWE;

  wire [127:0] vec_Q[7:0];
  wire [31:0] Q[31:0];

  // These first two don't need an enable, always on.
  decoder32 read_enable_A (
      .out(in_decoderA),
      .select(ctrl_readRegA),
      .enable(1'b1)
  );
  decoder32 read_enable_B (
      .out(in_decoderB),
      .select(ctrl_readRegB),
      .enable(1'b1)
  );
  decoder32 write_select (
      .out(in_decoderWE),
      .select(ctrl_writeReg),
      .enable(ctrl_writeEnable)
  );

  decoder8 read_enable_vec_A (
      .out(in_vec_decoderA),
      .select(ctrl_readVecRegA),
      .enable(1'b1)
  );

  decoder8 read_enable_vec_B (
      .out(in_vec_decoderB),
      .select(ctrl_readVecRegB),
      .enable(1'b1)
  );

  decoder8 vec_write_select (
      .out(in_vec_decoderWE),
      .select(ctrl_writeVecReg),
      .enable(ctrl_writeVecEnable)
  );


  reg_32b r0 (
      .Q(Q[0]),
      .D(32'b0),
      .clk(clock),
      .reset(1'b0),
      .RW_en(1'b1)
  );
  // r0 is short-circuited to constant 0 instead of wasting a register
  assign data_readRegA = in_decoderA[0] ? Q[0] : 32'hZ;
  assign data_readRegB = in_decoderB[0] ? Q[0] : 32'hz;

  // Generating registers here
  genvar int_regs;
  generate
    // This might need to be reversed? 0-31 or 31-0?
    for (int_regs = 1; int_regs < 32; int_regs = int_regs + 1) begin : gen_int_regs
      reg_32b reg32 (
          .Q(Q[int_regs]),
          .D(data_writeReg),
          .clk(clock),
          .reset(ctrl_reset),
          .RW_en(in_decoderWE[int_regs])
      );
      assign data_readRegA = in_decoderA[int_regs] ? Q[int_regs] : 32'hZ;
      assign data_readRegB = in_decoderB[int_regs] ? Q[int_regs] : 32'hZ;
    end
  endgenerate


  genvar vec_regs;
  generate
    for (vec_regs = 0; vec_regs < 8; vec_regs = vec_regs + 1) begin : gen_vec_regs
      reg_128b reg128 (
          .Q(vec_Q[vec_regs]),
          .D(data_writeVecReg),
          .clk(clock),
          .reset(ctrl_reset),
          .RW_en(in_vec_decoderWE[vec_regs])
      );
      assign data_readVecRegA = in_vec_decoderA[vec_regs] ? vec_Q[vec_regs] : 128'hZ;
      assign data_readVecRegB = in_vec_decoderB[vec_regs] ? vec_Q[vec_regs] : 128'hZ;
    end
  endgenerate
endmodule
