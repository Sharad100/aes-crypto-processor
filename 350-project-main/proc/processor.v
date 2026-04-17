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
 */

module processor(
    clock,                          
    reset,                          

    address_imem,                   
    q_imem,                         

    address_dmem,                   
    data,                           
    wren,                           
    q_dmem,                         

    ctrl_writeEnable,               
    ctrl_writeReg,                  
    ctrl_readRegA,                  
    ctrl_readRegB,                  
    data_writeReg,                  
    data_readRegA,                  
    data_readRegB                   
);
	input clock, reset;
	
    output [31:0] address_imem;
	input [31:0] q_imem;

	output [31:0] address_dmem, data;
	output wren;
	input [31:0] q_dmem;

	output ctrl_writeEnable;
	output [4:0] ctrl_writeReg, ctrl_readRegA, ctrl_readRegB;
	output [31:0] data_writeReg;
	input [31:0] data_readRegA, data_readRegB;

    wire on = 1'b1;
    wire negedge_clk;
    not inv_clk(negedge_clk, clock);

    wire [31:0] PC, PC_next, PC_plus1;
    wire pc_cout, pc_ovf;
    addsub pc_adder(PC_plus1, pc_cout, pc_ovf, PC, 32'b1, 1'b0);

    reg32 pc_reg(.clk(negedge_clk), .rst(reset), .en(~md_stall & ~lw_use_stall & ~jr_raw_stall), .d(PC_next), .q(PC));
    assign address_imem = PC;

    wire [31:0] FD_IR, FD_PC;
    wire        FD_flush, FD_stall;
    wire        FD_en = ~FD_stall;

    reg32 fd_latch   (.clk(negedge_clk), .rst(reset), .en(FD_en),
                      .d(FD_flush ? 32'b0 : q_imem), .q(FD_IR));
    reg32 fd_pc_latch(.clk(negedge_clk), .rst(reset), .en(FD_en),
                      .d(PC), .q(FD_PC));

    wire [4:0] FD_opcode = FD_IR[31:27];
    wire [4:0] FD_rd     = FD_IR[26:22];
    wire [4:0] FD_rs     = FD_IR[21:17];
    wire [4:0] FD_rt     = FD_IR[16:12];

    wire FD_isR   = ~|FD_opcode;
    wire FD_isSW  = ~FD_opcode[4] & ~FD_opcode[3] &  FD_opcode[2] &  FD_opcode[1] &  FD_opcode[0];
    wire FD_isBNE = ~FD_opcode[4] & ~FD_opcode[3] & ~FD_opcode[2] &  FD_opcode[1] & ~FD_opcode[0];
    wire FD_isBLT = ~FD_opcode[4] & ~FD_opcode[3] &  FD_opcode[2] &  FD_opcode[1] & ~FD_opcode[0];
    wire FD_isJR  = ~FD_opcode[4] & ~FD_opcode[3] &  FD_opcode[2] & ~FD_opcode[1] & ~FD_opcode[0];
    wire FD_isBEX =  FD_opcode[4] & ~FD_opcode[3] &  FD_opcode[2] &  FD_opcode[1] & ~FD_opcode[0];
    wire FD_isJ   = ~FD_opcode[4] & ~FD_opcode[3] & ~FD_opcode[2] & ~FD_opcode[1] &  FD_opcode[0];
    wire FD_isJAL = ~FD_opcode[4] & ~FD_opcode[3] & ~FD_opcode[2] &  FD_opcode[1] &  FD_opcode[0];
    wire FD_isBranch = FD_isBNE | FD_isBLT;
    wire FD_isJump   = FD_isJ | FD_isJAL | FD_isJR;

    wire [26:0] FD_T = FD_IR[26:0];

    wire [4:0] FD_jr_reg = FD_rd;
    wire jr_byp_XD = FD_isJR & XM_writes & ~XM_isLW_bp & (|FD_jr_reg) & (XM_rd_bp == FD_jr_reg);
    wire jr_byp_MD = FD_isJR & MW_writes_bp & (|FD_jr_reg) & (MW_rd_bp == FD_jr_reg) & ~jr_byp_XD;
    wire [31:0] jr_target_val = jr_byp_XD ? XM_bypass_val :
                                jr_byp_MD ? MW_bypass_val  :
                                            data_readRegA;
    wire [31:0] jump_target_D = FD_isJR ? jr_target_val : {5'b0, FD_T};

    assign ctrl_readRegA = FD_isBEX                ? 5'b11110 :
                           (FD_isBranch | FD_isJR) ? FD_rd    :
                           FD_rs;

    assign ctrl_readRegB = FD_isBranch         ? FD_rs :
                           (FD_isSW | FD_isJR) ? FD_rd :
                           FD_isR              ? FD_rt : 5'b0;

    wire [31:0] DX_IR, DX_A, DX_B, DX_PC;
    wire        DX_flush;
    wire md_stall;

    wire dx_we = (~md_stall | md_capture) & ~lw_use_stall;
    wire [31:0] dx_ir_in = (DX_flush | md_capture | jr_raw_stall) ? 32'b0 : FD_IR;

    wire dx_ab_we_a, dx_ab_we_b;
    wire [31:0] dx_a_in, dx_b_in;

    reg32 dx_ir_latch(.clk(negedge_clk), .rst(reset), .en(dx_we),      .d(dx_ir_in), .q(DX_IR));
    reg32 dx_a_latch (.clk(negedge_clk), .rst(reset), .en(dx_ab_we_a), .d(dx_a_in),  .q(DX_A));
    reg32 dx_b_latch (.clk(negedge_clk), .rst(reset), .en(dx_ab_we_b), .d(dx_b_in),  .q(DX_B));
    reg32 dx_pc_latch(.clk(negedge_clk), .rst(reset), .en(dx_we),      .d(FD_PC),    .q(DX_PC));

    wire [4:0]  DX_opcode = DX_IR[31:27];
    wire [4:0]  DX_rd     = DX_IR[26:22];
    wire [4:0]  DX_rs     = DX_IR[21:17];
    wire [4:0]  DX_rt     = DX_IR[16:12];
    wire [4:0]  DX_shamt  = DX_IR[11:7];
    wire [4:0]  DX_aluop  = DX_IR[6:2];
    wire [16:0] DX_imm17  = DX_IR[16:0];
    wire [26:0] DX_T      = DX_IR[26:0];

    wire [31:0] DX_imm_sext = {{15{DX_imm17[16]}}, DX_imm17};

    wire DX_isR    = ~|DX_opcode;
    wire DX_isADDI = ~DX_opcode[4] & ~DX_opcode[3] &  DX_opcode[2] & ~DX_opcode[1] &  DX_opcode[0];
    wire DX_isSW   = ~DX_opcode[4] & ~DX_opcode[3] &  DX_opcode[2] &  DX_opcode[1] &  DX_opcode[0];
    wire DX_isLW   = ~DX_opcode[4] &  DX_opcode[3] & ~DX_opcode[2] & ~DX_opcode[1] & ~DX_opcode[0];
    wire DX_isJ    = ~DX_opcode[4] & ~DX_opcode[3] & ~DX_opcode[2] & ~DX_opcode[1] &  DX_opcode[0];
    wire DX_isJAL  = ~DX_opcode[4] & ~DX_opcode[3] & ~DX_opcode[2] &  DX_opcode[1] &  DX_opcode[0];
    wire DX_isJR   = ~DX_opcode[4] & ~DX_opcode[3] &  DX_opcode[2] & ~DX_opcode[1] & ~DX_opcode[0];
    wire DX_isBNE  = ~DX_opcode[4] & ~DX_opcode[3] & ~DX_opcode[2] &  DX_opcode[1] & ~DX_opcode[0];
    wire DX_isBLT  = ~DX_opcode[4] & ~DX_opcode[3] &  DX_opcode[2] &  DX_opcode[1] & ~DX_opcode[0];
    wire DX_isBEX  =  DX_opcode[4] & ~DX_opcode[3] &  DX_opcode[2] &  DX_opcode[1] & ~DX_opcode[0];
    wire DX_isSETX =  DX_opcode[4] & ~DX_opcode[3] &  DX_opcode[2] & ~DX_opcode[1] &  DX_opcode[0];

    wire DX_isADD  = DX_isR & (~|DX_aluop);
    wire DX_isSUB  = DX_isR & (~DX_aluop[4] & ~DX_aluop[3] & ~DX_aluop[2] & ~DX_aluop[1] &  DX_aluop[0]);
    wire DX_isMUL  = DX_isR & (~DX_aluop[4] & ~DX_aluop[3] &  DX_aluop[2] &  DX_aluop[1] & ~DX_aluop[0]);
    wire DX_isDIV  = DX_isR & (~DX_aluop[4] & ~DX_aluop[3] &  DX_aluop[2] &  DX_aluop[1] &  DX_aluop[0]);
    wire DX_isMD   = DX_isMUL | DX_isDIV;

    wire [4:0] XM_rd_raw_bp = XM_IR[26:22];
    wire [4:0] XM_opcode_bp = XM_IR[31:27];
    wire XM_isR_bp    = ~|XM_opcode_bp;
    wire XM_isADDI_bp = ~XM_opcode_bp[4] & ~XM_opcode_bp[3] &  XM_opcode_bp[2] & ~XM_opcode_bp[1] &  XM_opcode_bp[0];
    wire XM_isLW_bp   = ~XM_opcode_bp[4] &  XM_opcode_bp[3] & ~XM_opcode_bp[2] & ~XM_opcode_bp[1] & ~XM_opcode_bp[0];
    wire XM_isJAL_bp  = ~XM_opcode_bp[4] & ~XM_opcode_bp[3] & ~XM_opcode_bp[2] &  XM_opcode_bp[1] &  XM_opcode_bp[0];
    wire XM_isSETX_bp =  XM_opcode_bp[4] & ~XM_opcode_bp[3] &  XM_opcode_bp[2] & ~XM_opcode_bp[1] &  XM_opcode_bp[0];
    wire XM_writes    = XM_isR_bp | XM_isADDI_bp | XM_isLW_bp | XM_isJAL_bp | XM_isSETX_bp;

    wire [4:0] XM_rd_bp = XM_any_ovf   ? 5'b11110 :
                          XM_isJAL_bp  ? 5'd31    :
                          XM_isSETX_bp ? 5'd30    : XM_rd_raw_bp;

    wire [31:0] XM_bypass_val = XM_any_ovf ? XM_OVF_VAL : XM_O;

    wire [4:0] MW_rd_raw_bp = MW_IR[26:22];
    wire [4:0] MW_opcode_bp = MW_IR[31:27];
    wire MW_isR_bp    = ~|MW_opcode_bp;
    wire MW_isADDI_bp = ~MW_opcode_bp[4] & ~MW_opcode_bp[3] &  MW_opcode_bp[2] & ~MW_opcode_bp[1] &  MW_opcode_bp[0];
    wire MW_isLW_bp   = ~MW_opcode_bp[4] &  MW_opcode_bp[3] & ~MW_opcode_bp[2] & ~MW_opcode_bp[1] & ~MW_opcode_bp[0];
    wire MW_isJAL_bp  = ~MW_opcode_bp[4] & ~MW_opcode_bp[3] & ~MW_opcode_bp[2] &  MW_opcode_bp[1] &  MW_opcode_bp[0];
    wire MW_isSETX_bp =  MW_opcode_bp[4] & ~MW_opcode_bp[3] &  MW_opcode_bp[2] & ~MW_opcode_bp[1] &  MW_opcode_bp[0];
    wire MW_writes_bp = MW_isR_bp | MW_isADDI_bp | MW_isLW_bp | MW_isJAL_bp | MW_isSETX_bp;
    wire MW_any_ovf_bp = MW_any_ovf;

    wire [4:0] MW_rd_bp = MW_any_ovf_bp ? 5'b11110 :
                          MW_isJAL_bp   ? 5'd31    :
                          MW_isSETX_bp  ? 5'd30    : MW_rd_raw_bp;

    wire [31:0] MW_bypass_val = MW_D;

    wire [4:0] DX_srcA = DX_isBEX                 ? 5'b11110 :
                         (DX_isBNE | DX_isBLT | DX_isJR) ? DX_rd    :
                         DX_rs;

    wire [4:0] DX_srcB = (DX_isBNE | DX_isBLT) ? DX_rs :
                         (DX_isSW | DX_isJR)    ? DX_rd :
                         DX_isR                 ? DX_rt : 5'b0;

    wire byp_XD_A = XM_writes & ~XM_isLW_bp & (|DX_srcA) & (XM_rd_bp == DX_srcA);
    wire byp_XD_B = XM_writes & ~XM_isLW_bp & (|DX_srcB) & (XM_rd_bp == DX_srcB);

    wire byp_MD_A = MW_writes_bp & (|DX_srcA) & (MW_rd_bp == DX_srcA) & ~byp_XD_A;
    wire byp_MD_B = MW_writes_bp & (|DX_srcB) & (MW_rd_bp == DX_srcB) & ~byp_XD_B;

    wire [31:0] alu_A_bypassed = byp_XD_A ? XM_bypass_val :
                                 byp_MD_A ? MW_bypass_val  :
                                            DX_A;

    wire [31:0] alu_B_bypassed = byp_XD_B ? XM_bypass_val :
                                 byp_MD_B ? MW_bypass_val  :
                                            DX_B;

    assign dx_ab_we_a = dx_we | (lw_use_stall & byp_MD_A);
    assign dx_ab_we_b = dx_we | (lw_use_stall & byp_MD_B);
    assign dx_a_in    = (lw_use_stall & byp_MD_A) ? MW_bypass_val : data_readRegA;
    assign dx_b_in    = (lw_use_stall & byp_MD_B) ? MW_bypass_val : data_readRegB;

    wire [31:0] alu_B_in   = (DX_isADDI | DX_isSW | DX_isLW)
                               ? DX_imm_sext : alu_B_bypassed;
    wire [4:0] alu_opcode = (DX_isBNE | DX_isBLT) ? 5'b00001 :
                         DX_isR                ? DX_aluop  : 5'b00000;

    wire [31:0] alu_result;
    wire alu_ne, alu_lt, alu_ovf;

    alu ALU(
        .data_operandA  (alu_A_bypassed),
        .data_operandB  (alu_B_in),
        .ctrl_ALUopcode (alu_opcode),
        .ctrl_shiftamt  (DX_shamt),
        .data_result    (alu_result),
        .isNotEqual     (alu_ne),
        .isLessThan     (alu_lt),
        .overflow       (alu_ovf)
    );

    wire [31:0] md_result;
    wire        md_ready, md_exception;

    wire [1:0] md_state, md_state_next;
    wire md_inactive  = (md_state == 2'b00);
    wire md_pulse = (md_state == 2'b01);
    wire md_busy  = (md_state == 2'b10);

    assign md_state_next = md_inactive  ? ((DX_isMD & ~lw_use_stall) ? 2'b01 : 2'b00) :
                           md_pulse ? 2'b10                       :
                           md_busy  ? (md_ready ? 2'b00 : 2'b10) :
                                      2'b00;

    reg1 md_s0(.clk(negedge_clk), .rst(reset), .en(on), .d(md_state_next[0]), .q(md_state[0]));
    reg1 md_s1(.clk(negedge_clk), .rst(reset), .en(on), .d(md_state_next[1]), .q(md_state[1]));

    wire md_capture = md_busy & md_ready;

    wire md_latch_en = md_inactive & DX_isMD & ~lw_use_stall;
    wire [31:0] md_operandA, md_operandB;
    reg32 md_a_reg(.clk(negedge_clk), .rst(reset), .en(md_latch_en), .d(alu_A_bypassed), .q(md_operandA));
    reg32 md_b_reg(.clk(negedge_clk), .rst(reset), .en(md_latch_en), .d(alu_B_bypassed), .q(md_operandB));

    multdiv MD(
        .data_operandA (md_operandA),
        .data_operandB (md_operandB),
        .ctrl_MULT     (DX_isMUL & md_pulse),
        .ctrl_DIV      (DX_isDIV & md_pulse),
        .clock         (clock),
        .data_result   (md_result),
        .data_exception(md_exception),
        .data_resultRDY(md_ready)
    );

    assign md_stall = (md_inactive & DX_isMD & ~lw_use_stall) | md_pulse | md_busy;

    wire lw_use_stall = XM_isLW_bp & (
        (|DX_srcA & (XM_rd_bp == DX_srcA)) |
        (|DX_srcB & (XM_rd_bp == DX_srcB))
    );

    wire [4:0] DX_rd_raw = DX_IR[26:22];
    wire DX_writes = DX_isR | DX_isADDI | DX_isLW | DX_isJAL | DX_isSETX;
    wire jr_raw_stall = FD_isJR & (
        (DX_writes & (|FD_jr_reg) & (DX_rd_raw == FD_jr_reg)) |
        (XM_isLW_bp & (|FD_jr_reg) & (XM_rd_bp == FD_jr_reg))
    );

    assign FD_stall = md_stall | lw_use_stall | jr_raw_stall;

    wire ovf_add    = DX_isADD & alu_ovf;
    wire ovf_addi   = DX_isADDI & alu_ovf;
    wire ovf_sub    = DX_isSUB & alu_ovf;
    wire ovf_mul_ex = DX_isMUL & md_capture & md_exception;
    wire ovf_div_ex = DX_isDIV & md_capture & md_exception;
    wire any_ovf    = ovf_add | ovf_addi | ovf_sub | ovf_mul_ex | ovf_div_ex;

    wire [31:0] status_val = ovf_add    ? 32'd1 :
                             ovf_addi   ? 32'd2 :
                             ovf_sub    ? 32'd3 :
                             ovf_mul_ex ? 32'd4 :
                             ovf_div_ex ? 32'd5 : 32'b0;

    wire [31:0] dx_pc_p1, branch_target;
    wire bc, bov, br_cout, br_ovf;
    addsub dx_pc_adder(dx_pc_p1,      bc,      bov,    DX_PC,    32'b1,       1'b0);
    addsub br_adder   (branch_target, br_cout, br_ovf, dx_pc_p1, DX_imm_sext, 1'b0);

    wire bne_taken = DX_isBNE & alu_ne;
    wire blt_taken = DX_isBLT & alu_lt;
    wire bex_taken = DX_isBEX & (|alu_A_bypassed);
    wire take_branch_X = bne_taken | blt_taken | bex_taken;
    wire [31:0] branch_target_X = bex_taken ? {5'b0, DX_T} : branch_target;

    assign PC_next = take_branch_X ? branch_target_X :
                     FD_isJump     ? jump_target_D   :
                                     PC_plus1;

    assign FD_flush = take_branch_X | FD_isJump;
    assign DX_flush = take_branch_X;

    wire inject_xm_nop = (md_stall & ~md_capture) | lw_use_stall;

    wire [31:0] ex_result = md_capture  ? md_result      :
                             DX_isSETX  ? {5'b0, DX_T}  :
                             DX_isJAL   ? dx_pc_p1       :
                                          alu_result;

    wire [31:0] XM_OVF_VAL, MW_OVF_VAL;
    wire        XM_any_ovf,  MW_any_ovf;
    reg32 xm_ovfval_latch(.clk(negedge_clk), .rst(reset), .en(on), .d(status_val), .q(XM_OVF_VAL));
    reg1  xm_ovf_latch   (.clk(negedge_clk), .rst(reset), .en(on), .d(any_ovf),    .q(XM_any_ovf));

    wire [31:0] XM_IR, XM_O, XM_B;
    wire [31:0] xm_ir_in = inject_xm_nop ? 32'b0 : DX_IR;
    reg32 xm_ir_latch(.clk(negedge_clk), .rst(reset), .en(on), .d(xm_ir_in),       .q(XM_IR));
    reg32 xm_o_latch (.clk(negedge_clk), .rst(reset), .en(on), .d(ex_result),      .q(XM_O));
    reg32 xm_b_latch (.clk(negedge_clk), .rst(reset), .en(on), .d(alu_B_bypassed), .q(XM_B));

    wire XM_isSW = ~XM_opcode_bp[4] & ~XM_opcode_bp[3] & XM_opcode_bp[2] & XM_opcode_bp[1] & XM_opcode_bp[0];
    wire XM_isLW = ~XM_opcode_bp[4] &  XM_opcode_bp[3] & ~XM_opcode_bp[2] & ~XM_opcode_bp[1] & ~XM_opcode_bp[0];

    wire [4:0] XM_sw_src  = XM_IR[26:22];
    wire [4:0] MW_opcode_mx = MW_IR[31:27];
    wire MW_isLW_mx = ~MW_opcode_mx[4] & MW_opcode_mx[3] & ~MW_opcode_mx[2] & ~MW_opcode_mx[1] & ~MW_opcode_mx[0];
    wire [4:0] MW_rd_mx  = MW_IR[26:22];
    wire byp_MX_sw = XM_isSW & MW_isLW_mx & (|XM_sw_src) & (MW_rd_mx == XM_sw_src);

    assign address_dmem = XM_O;
    assign data         = byp_MX_sw ? MW_O : XM_B;
    assign wren         = XM_isSW;

    wire [31:0] MW_IR, MW_O;
    wire [31:0] MW_D_raw = XM_isLW ? q_dmem : XM_O;

    reg32 mw_ir_latch    (.clk(negedge_clk), .rst(reset), .en(on), .d(XM_IR),      .q(MW_IR));
    reg32 mw_o_latch     (.clk(negedge_clk), .rst(reset), .en(on), .d(MW_D_raw),   .q(MW_O));
    reg32 mw_ovfval_latch(.clk(negedge_clk), .rst(reset), .en(on), .d(XM_OVF_VAL), .q(MW_OVF_VAL));
    reg1  mw_ovf_latch   (.clk(negedge_clk), .rst(reset), .en(on), .d(XM_any_ovf), .q(MW_any_ovf));

    wire [4:0] MW_opcode  = MW_IR[31:27];
    wire [4:0] MW_rd_raw  = MW_IR[26:22];

    wire MW_isR    = ~|MW_opcode;
    wire MW_isADDI = ~MW_opcode[4] & ~MW_opcode[3] &  MW_opcode[2] & ~MW_opcode[1] &  MW_opcode[0];
    wire MW_isLW   = ~MW_opcode[4] &  MW_opcode[3] & ~MW_opcode[2] & ~MW_opcode[1] & ~MW_opcode[0];
    wire MW_isJAL  = ~MW_opcode[4] & ~MW_opcode[3] & ~MW_opcode[2] &  MW_opcode[1] &  MW_opcode[0];
    wire MW_isSETX =  MW_opcode[4] & ~MW_opcode[3] &  MW_opcode[2] & ~MW_opcode[1] &  MW_opcode[0];

    wire [4:0] MW_rd = MW_any_ovf ? 5'b11110 : 
                       MW_isJAL   ? 5'd31    :
                       MW_isSETX  ? 5'd30    : MW_rd_raw;
    wire [31:0] MW_D  = MW_any_ovf ? MW_OVF_VAL : MW_O;

    assign ctrl_writeEnable = MW_isR | MW_isADDI | MW_isLW | MW_isJAL | MW_isSETX;
    assign ctrl_writeReg    = MW_rd;
    assign data_writeReg    = MW_D;

endmodule


module reg1(clk, rst, en, d, q);
    input  clk, rst, en, d;
    output q;
    dffe_ref ff(.q(q), .d(d), .clk(clk), .en(en), .clr(rst));
endmodule