/**
 * READ THIS DESCRIPTION!
 *
 * This is your processor module that will contain the bulk of your code submission. You are to implement
 * a 5-stage pipelined processor in this module, accounting for hazards and implementing bypasses as
 * necessary.
 *
 * Ultimately, your processor will be tested by a master skeleton, so the
 * testbench can see which controls signal you active when. Therefore, there needs to be a way to
 * "inject" imem, dmem, and regfile interfaces from some external controller module. The skeleton
 * file, Wrapper.v, acts as a small wrapper around your processor for this purpose. Refer to Wrapper.v
 * for more details.
 *
 * As a result, this module will NOT contain the RegFile nor the memory modules. Study the inputs 
 * very carefully - the RegFile-related I/Os are merely signals to be sent to the RegFile instantiated
 * in your Wrapper module. This is the same for your memory elements. 
 *
 *
 
module processor(
    // Control signals
    clock,                          // I: The master clock
    reset,                          // I: A reset signal

    // Imem
    address_imem,                   // O: The address of the data to get from imem
    q_imem,                         // I: The data from imem

    // Dmem
    address_dmem,                   // O: The address of the data to get or put from/to dmem
    data,                           // O: The data to write to dmem
    wren,                           // O: Write enable for dmem
    q_dmem,                         // I: The data from dmem

    // Regfile
    ctrl_writeEnable,               // O: Write enable for RegFile
    ctrl_writeReg,                  // O: Register to write to in RegFile
    ctrl_readRegA,                  // O: Register to read from port A of RegFile
    ctrl_readRegB,                  // O: Register to read from port B of RegFile
    data_writeReg,                  // O: Data to write to for RegFile
    data_readRegA,                  // I: Data from port A of RegFile
    data_readRegB                   // I: Data from port B of RegFile
	 
	);

	// Control signals
	input clock, reset;
	
	// Imem
    output [31:0] address_imem;
	input [31:0] q_imem;

	// Dmem
	output [31:0] address_dmem, data;
	output wren;
	input [31:0] q_dmem;

	// Regfile
	output ctrl_writeEnable;
	output [4:0] ctrl_writeReg, ctrl_readRegA, ctrl_readRegB;
	output [31:0] data_writeReg;
	input [31:0] data_readRegA, data_readRegB;

    wire on = 1'b1;

    // Inverted clock to make pipeline latches trigger on negedge
    wire negedge_clk;
    not inv_clk(negedge_clk, clock);

    // =========================================================
    // FETCH — PC register (posedge clock, rising edge)
    // =========================================================
    wire [31:0] PC, PC_plus1;
    wire        pc_cout, pc_ovf;

    addsub pc_adder(PC_plus1, pc_cout, pc_ovf, PC, 32'b1, 1'b0);

 
    reg32 pc_reg(.clk(clock), .rst(reset), .en(on), .d(PC_plus1), .q(PC));

    assign address_imem = PC;

    // =========================================================
    // FD LATCH — gets ROM output on falling edge
    // =========================================================
    wire [31:0] FD_IR;
    reg32 fd_latch(.clk(negedge_clk), .rst(reset), .en(on), .d(q_imem), .q(FD_IR));

    // =========================================================
    // DECODE
    // =========================================================
    wire [4:0] FD_opcode = FD_IR[31:27];
    wire [4:0] FD_rs     = FD_IR[21:17];
    wire [4:0] FD_rt     = FD_IR[16:12];

    // R-type: opcode == 5'b00000
    wire FD_isR;
    nor fd_isR_gate(FD_isR, FD_opcode[4], FD_opcode[3], FD_opcode[2], FD_opcode[1], FD_opcode[0]);

    assign ctrl_readRegA = FD_rs;
    assign ctrl_readRegB = FD_isR ? FD_rt : 5'b0;

    // =========================================================
    // DX LATCH — captures instruction + regfile outputs on falling edge
    // =========================================================
    wire [31:0] DX_IR, DX_A, DX_B;
    reg32 dx_ir_latch(.clk(negedge_clk), .rst(reset), .en(on), .d(FD_IR),         .q(DX_IR));
    reg32 dx_a_latch (.clk(negedge_clk), .rst(reset), .en(on), .d(data_readRegA), .q(DX_A));
    reg32 dx_b_latch (.clk(negedge_clk), .rst(reset), .en(on), .d(data_readRegB), .q(DX_B));

    // =========================================================
    // STAGE 3: EXECUTE
    // =========================================================
    wire [4:0]  DX_opcode = DX_IR[31:27];
    wire [4:0]  DX_shamt  = DX_IR[11:7];
    wire [4:0]  DX_aluop  = DX_IR[6:2];
    wire [16:0] DX_imm17  = DX_IR[16:0];

    // Sign-extend 17-bit immediate to 32 bits
    wire [31:0] DX_imm_sext;
    assign DX_imm_sext[16:0]  = DX_imm17;
    assign DX_imm_sext[31:17] = {15{DX_imm17[16]}};


    wire DX_isR;
    nor dx_isR_gate(DX_isR, DX_opcode[4], DX_opcode[3], DX_opcode[2], DX_opcode[1], DX_opcode[0]);

    // addi detect: opcode == 5'b00101
    wire DX_isI, dx_n4, dx_n3, dx_n1;
    not(dx_n4, DX_opcode[4]);
    not(dx_n3, DX_opcode[3]);
    not(dx_n1, DX_opcode[1]);
    and(DX_isI, dx_n4, dx_n3, DX_opcode[2], dx_n1, DX_opcode[0]);

    // R-type -> register B, addi -> sign-extended immediate
    wire [31:0] alu_B;
    assign alu_B = DX_isR ? DX_B : DX_imm_sext;


    wire [4:0] alu_opcode;
    assign alu_opcode = DX_isR ? DX_aluop : 5'b00000;

    wire [31:0] alu_result;
    wire        alu_ne, alu_lt, alu_ovf;

    alu ALU(
        .data_operandA  (DX_A),
        .data_operandB  (alu_B),
        .ctrl_ALUopcode (alu_opcode),
        .ctrl_shiftamt  (DX_shamt),
        .data_result    (alu_result),
        .isNotEqual     (alu_ne),
        .isLessThan     (alu_lt),
        .overflow       (alu_ovf)
    );

    // =========================================================
    // XM LATCH — captures ALU result + IR on falling edge
    // =========================================================
    wire [31:0] XM_IR, XM_O;
    reg32 xm_ir_latch(.clk(negedge_clk), .rst(reset), .en(on), .d(DX_IR),      .q(XM_IR));
    reg32 xm_o_latch (.clk(negedge_clk), .rst(reset), .en(on), .d(alu_result), .q(XM_O));

    // =========================================================
    // STAGE 4: MEMORY 
    // =========================================================
    assign address_dmem = XM_O;
    assign data         = 32'b0;
    assign wren         = 1'b0;

    // =========================================================
    // MW LATCH 
    // =========================================================
    wire [31:0] MW_IR, MW_O;
    reg32 mw_ir_latch(.clk(negedge_clk), .rst(reset), .en(on), .d(XM_IR), .q(MW_IR));
    reg32 mw_o_latch (.clk(negedge_clk), .rst(reset), .en(on), .d(XM_O),  .q(MW_O));

    // =========================================================
    // STAGE 5: WRITEBACK
    // =========================================================
    wire [4:0] MW_opcode = MW_IR[31:27];
    wire [4:0] MW_rd     = MW_IR[26:22];


    wire MW_isR;
    nor mw_isR_gate(MW_isR, MW_opcode[4], MW_opcode[3], MW_opcode[2], MW_opcode[1], MW_opcode[0]);

    
    wire MW_isI, mw_n4, mw_n3, mw_n1;
    not(mw_n4, MW_opcode[4]);
    not(mw_n3, MW_opcode[3]);
    not(mw_n1, MW_opcode[1]);
    and(MW_isI, mw_n4, mw_n3, MW_opcode[2], mw_n1, MW_opcode[0]);

    // Write enable = R-type OR addi
    or(ctrl_writeEnable, MW_isR, MW_isI);

    assign ctrl_writeReg = MW_rd;
    assign data_writeReg = MW_O;

endmodule
*/
