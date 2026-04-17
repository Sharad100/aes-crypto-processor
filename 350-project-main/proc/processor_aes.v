/**
 * processor_aes.v — 5-stage pipelined processor with AES custom instructions.
 *
 * AES instruction set (all R-type encoded):
 *   Opcode  Mnemonic  Operation
 *   10000   ake       vrd = vrs XOR vrt          (AddRoundKey, generic)
 *   10001   asb       vrd = SubBytes(vrs)
 *   10010   asr       vrd = ShiftRows(vrs)
 *   10011   amc       vrd = MixColumns(vrs)
 *   10100   ark       vrd = vrs XOR vrt          (AddRoundKey, alias)
 *   11001   asbi      vrd = InvSubBytes(vrs)
 *   11010   asri      vrd = InvShiftRows(vrs)
 *   11011   amci      vrd = InvMixColumns(vrs)
 *   11100   akx       KeyExpand(vrs)->key_bank; vrd = key_bank[0]
 *   11101   lrk       vrd = key_bank[IR[16:12]]  (load round key by index)
 *
 * Instruction field encoding (R-type):
 *   [31:27] opcode  [24:22] vrd  [19:17] vrs  [14:12] vrt
 *   For lrk: [16:12] = 5-bit round-key index (0–10)
 *
 * Vector registers: vr0–vr7 (3-bit address, 128-bit wide), in regfile.
 * Key bank: 11 × 128-bit internal registers (written only by akx).
 *
 * Hazards:
 *   - akx_lrk_stall: lrk in DX while akx in XM → stall 1 cycle.
 *   - Bypass: akx in MW while lrk in DX → forward MW_kexp to lrk.
 *   - Vector XM→DX and MW→DX bypass for all other AES instructions.
 */

module processor_aes(
    clock, reset,
    address_imem, q_imem,
    address_dmem, data, wren, q_dmem,
    ctrl_writeEnable, ctrl_writeReg, ctrl_readRegA, ctrl_readRegB,
    data_writeReg, data_readRegA, data_readRegB,
    ctrl_writeVecEnable, ctrl_writeVecReg,
    ctrl_readVecRegA, ctrl_readVecRegB,
    data_writeVecReg, data_readVecRegA, data_readVecRegB
);
    input  clock, reset;

    output [31:0] address_imem;
    input  [31:0] q_imem;

    output [31:0] address_dmem, data;
    output        wren;
    input  [31:0] q_dmem;

    output        ctrl_writeEnable;
    output [4:0]  ctrl_writeReg, ctrl_readRegA, ctrl_readRegB;
    output [31:0] data_writeReg;
    input  [31:0] data_readRegA, data_readRegB;

    output         ctrl_writeVecEnable;
    output [2:0]   ctrl_writeVecReg, ctrl_readVecRegA, ctrl_readVecRegB;
    output [127:0] data_writeVecReg;
    input  [127:0] data_readVecRegA, data_readVecRegB;

    wire on = 1'b1;
    wire negedge_clk;
    not inv_clk(negedge_clk, clock);

    // =========================================================
    // IF stage
    // =========================================================
    wire [31:0] PC, PC_next, PC_plus1;
    wire pc_cout, pc_ovf;
    addsub pc_adder(PC_plus1, pc_cout, pc_ovf, PC, 32'b1, 1'b0);

    reg32 pc_reg(
        .clk(negedge_clk), .rst(reset),
        .en(~md_stall & ~lw_use_stall & ~jr_raw_stall & ~akx_lrk_stall),
        .d(PC_next), .q(PC));
    assign address_imem = PC;

    // =========================================================
    // FD latch
    // =========================================================
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

    wire FD_isR      = ~|FD_opcode;
    wire FD_isSW     = ~FD_opcode[4] & ~FD_opcode[3] &  FD_opcode[2] &  FD_opcode[1] &  FD_opcode[0];
    wire FD_isBNE    = ~FD_opcode[4] & ~FD_opcode[3] & ~FD_opcode[2] &  FD_opcode[1] & ~FD_opcode[0];
    wire FD_isBLT    = ~FD_opcode[4] & ~FD_opcode[3] &  FD_opcode[2] &  FD_opcode[1] & ~FD_opcode[0];
    wire FD_isJR     = ~FD_opcode[4] & ~FD_opcode[3] &  FD_opcode[2] & ~FD_opcode[1] & ~FD_opcode[0];
    wire FD_isBEX    =  FD_opcode[4] & ~FD_opcode[3] &  FD_opcode[2] &  FD_opcode[1] & ~FD_opcode[0];
    wire FD_isJ      = ~FD_opcode[4] & ~FD_opcode[3] & ~FD_opcode[2] & ~FD_opcode[1] &  FD_opcode[0];
    wire FD_isJAL    = ~FD_opcode[4] & ~FD_opcode[3] & ~FD_opcode[2] &  FD_opcode[1] &  FD_opcode[0];
    wire FD_isBranch = FD_isBNE | FD_isBLT;
    wire FD_isJump   = FD_isJ | FD_isJAL | FD_isJR;

    wire FD_isAES = (FD_opcode == 5'b10000) | (FD_opcode == 5'b10001) |
                    (FD_opcode == 5'b10010) | (FD_opcode == 5'b10011) |
                    (FD_opcode == 5'b10100) | (FD_opcode == 5'b11001) |
                    (FD_opcode == 5'b11010) | (FD_opcode == 5'b11011) |
                    (FD_opcode == 5'b11100) | (FD_opcode == 5'b11101);

    wire [26:0] FD_T = FD_IR[26:0];

    wire [4:0] FD_jr_reg = FD_rd;
    wire jr_byp_XD = FD_isJR & XM_writes & ~XM_isLW_bp & (|FD_jr_reg) & (XM_rd_bp == FD_jr_reg);
    wire jr_byp_MD = FD_isJR & MW_writes_bp & (|FD_jr_reg) & (MW_rd_bp == FD_jr_reg) & ~jr_byp_XD;
    wire [31:0] jr_target_val = jr_byp_XD ? XM_bypass_val :
                                jr_byp_MD ? MW_bypass_val  :
                                            data_readRegA;
    wire [31:0] jump_target_D = FD_isJR ? jr_target_val : {5'b0, FD_T};

    // AES instructions do not read scalar registers
    assign ctrl_readRegA = FD_isAES                ? 5'b0     :
                           FD_isBEX                ? 5'b11110 :
                           (FD_isBranch | FD_isJR) ? FD_rd    :
                           FD_rs;

    assign ctrl_readRegB = FD_isAES               ? 5'b0  :
                           FD_isBranch            ? FD_rs :
                           (FD_isSW | FD_isJR)   ? FD_rd :
                           FD_isR                ? FD_rt : 5'b0;

    // Vector register reads driven from FD
    assign ctrl_readVecRegA = FD_IR[19:17];  // vrs[2:0]
    assign ctrl_readVecRegB = FD_IR[14:12];  // vrt[2:0]

    // =========================================================
    // DX latch
    // =========================================================
    wire [31:0] DX_IR, DX_A, DX_B, DX_PC;
    wire        DX_flush;
    wire md_stall;

    wire dx_we = (~md_stall | md_capture) & ~lw_use_stall & ~akx_lrk_stall;
    wire [31:0] dx_ir_in = (DX_flush | md_capture | jr_raw_stall) ? 32'b0 : FD_IR;

    wire dx_ab_we_a, dx_ab_we_b;
    wire [31:0] dx_a_in, dx_b_in;

    reg32 dx_ir_latch(.clk(negedge_clk), .rst(reset), .en(dx_we),      .d(dx_ir_in), .q(DX_IR));
    reg32 dx_a_latch (.clk(negedge_clk), .rst(reset), .en(dx_ab_we_a), .d(dx_a_in),  .q(DX_A));
    reg32 dx_b_latch (.clk(negedge_clk), .rst(reset), .en(dx_ab_we_b), .d(dx_b_in),  .q(DX_B));
    reg32 dx_pc_latch(.clk(negedge_clk), .rst(reset), .en(dx_we),      .d(FD_PC),    .q(DX_PC));

    // Vector operand latches
    wire [127:0] DX_vecA, DX_vecB;
    reg128 dx_veca_latch(.clk(negedge_clk), .rst(reset), .en(dx_we),
                         .d(data_readVecRegA), .q(DX_vecA));
    reg128 dx_vecb_latch(.clk(negedge_clk), .rst(reset), .en(dx_we),
                         .d(data_readVecRegB), .q(DX_vecB));

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

    // AES instruction decode
    wire DX_isAKE  = (DX_opcode == 5'b10000);
    wire DX_isASB  = (DX_opcode == 5'b10001);
    wire DX_isASR  = (DX_opcode == 5'b10010);
    wire DX_isAMC  = (DX_opcode == 5'b10011);
    wire DX_isARK  = (DX_opcode == 5'b10100);
    wire DX_isASBI = (DX_opcode == 5'b11001);
    wire DX_isASRI = (DX_opcode == 5'b11010);
    wire DX_isAMCI = (DX_opcode == 5'b11011);
    wire DX_isAKX  = (DX_opcode == 5'b11100);
    wire DX_isLRK  = (DX_opcode == 5'b11101);
    wire DX_isAES  = DX_isAKE | DX_isASB | DX_isASR | DX_isAMC | DX_isARK |
                     DX_isASBI | DX_isASRI | DX_isAMCI | DX_isAKX | DX_isLRK;

    // =========================================================
    // Scalar bypass logic
    // =========================================================
    wire [4:0] XM_rd_raw_bp  = XM_IR[26:22];
    wire [4:0] XM_opcode_bp  = XM_IR[31:27];
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

    wire [4:0] MW_rd_raw_bp  = MW_IR[26:22];
    wire [4:0] MW_opcode_bp  = MW_IR[31:27];
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

    // AES suppresses scalar source addresses to avoid false stalls
    wire [4:0] DX_srcA = DX_isAES                         ? 5'b0     :
                         DX_isBEX                         ? 5'b11110 :
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
                                 byp_MD_A ? MW_bypass_val  : DX_A;
    wire [31:0] alu_B_bypassed = byp_XD_B ? XM_bypass_val :
                                 byp_MD_B ? MW_bypass_val  : DX_B;

    assign dx_ab_we_a = dx_we | (lw_use_stall & byp_MD_A);
    assign dx_ab_we_b = dx_we | (lw_use_stall & byp_MD_B);
    assign dx_a_in    = (lw_use_stall & byp_MD_A) ? MW_bypass_val : data_readRegA;
    assign dx_b_in    = (lw_use_stall & byp_MD_B) ? MW_bypass_val : data_readRegB;

    // =========================================================
    // Vector bypass logic (XM→DX and MW→DX)
    // =========================================================
    wire XM_isAES_bp = (XM_opcode_bp == 5'b10000) | (XM_opcode_bp == 5'b10001) |
                       (XM_opcode_bp == 5'b10010) | (XM_opcode_bp == 5'b10011) |
                       (XM_opcode_bp == 5'b10100) | (XM_opcode_bp == 5'b11001) |
                       (XM_opcode_bp == 5'b11010) | (XM_opcode_bp == 5'b11011) |
                       (XM_opcode_bp == 5'b11100) | (XM_opcode_bp == 5'b11101);

    wire MW_isAES_bp = (MW_opcode_bp == 5'b10000) | (MW_opcode_bp == 5'b10001) |
                       (MW_opcode_bp == 5'b10010) | (MW_opcode_bp == 5'b10011) |
                       (MW_opcode_bp == 5'b10100) | (MW_opcode_bp == 5'b11001) |
                       (MW_opcode_bp == 5'b11010) | (MW_opcode_bp == 5'b11011) |
                       (MW_opcode_bp == 5'b11100) | (MW_opcode_bp == 5'b11101);

    wire [2:0] DX_vsA   = DX_IR[19:17];
    wire [2:0] DX_vsB   = DX_IR[14:12];
    wire [2:0] XM_vd_bp = XM_IR[24:22];
    wire [2:0] MW_vd_bp = MW_IR[24:22];

    // lrk and akx use key bank, not vector regs as input; only bypass for other AES ops
    wire DX_isAES_vec = DX_isAES & ~DX_isLRK;  // uses vector reg inputs

    wire vec_byp_XD_A = XM_isAES_bp & DX_isAES_vec & (XM_vd_bp == DX_vsA);
    wire vec_byp_XD_B = XM_isAES_bp & DX_isAES_vec & (XM_vd_bp == DX_vsB);
    wire vec_byp_MD_A = MW_isAES_bp & DX_isAES_vec & (MW_vd_bp == DX_vsA) & ~vec_byp_XD_A;
    wire vec_byp_MD_B = MW_isAES_bp & DX_isAES_vec & (MW_vd_bp == DX_vsB) & ~vec_byp_XD_B;

    wire [127:0] aes_A = vec_byp_XD_A ? XM_vec :
                         vec_byp_MD_A ? MW_vec  : DX_vecA;

    wire [127:0] aes_B = vec_byp_XD_B ? XM_vec :
                         vec_byp_MD_B ? MW_vec  : DX_vecB;

    // =========================================================
    // ALU
    // =========================================================
    wire [31:0] alu_B_in   = (DX_isADDI | DX_isSW | DX_isLW)
                               ? DX_imm_sext : alu_B_bypassed;
    wire [4:0]  alu_opcode = (DX_isBNE | DX_isBLT) ? 5'b00001 :
                              DX_isR               ? DX_aluop  : 5'b00000;

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

    // =========================================================
    // Multiply / Divide
    // =========================================================
    wire [31:0] md_result;
    wire        md_ready, md_exception;

    wire [1:0] md_state, md_state_next;
    wire md_inactive = (md_state == 2'b00);
    wire md_pulse    = (md_state == 2'b01);
    wire md_busy     = (md_state == 2'b10);

    assign md_state_next = md_inactive ? ((DX_isMD & ~lw_use_stall) ? 2'b01 : 2'b00) :
                           md_pulse    ? 2'b10 :
                           md_busy     ? (md_ready ? 2'b00 : 2'b10) : 2'b00;

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
    wire lw_use_stall;
    assign lw_use_stall = XM_isLW_bp & (
        (|DX_srcA & (XM_rd_bp == DX_srcA)) |
        (|DX_srcB & (XM_rd_bp == DX_srcB))
    );

    wire [4:0] DX_rd_raw = DX_IR[26:22];
    wire DX_writes = DX_isR | DX_isADDI | DX_isLW | DX_isJAL | DX_isSETX;
    wire jr_raw_stall;
    assign jr_raw_stall = FD_isJR & (
        (DX_writes & (|FD_jr_reg) & (DX_rd_raw == FD_jr_reg)) |
        (XM_isLW_bp & (|FD_jr_reg) & (XM_rd_bp == FD_jr_reg))
    );

    // akx→lrk stall: lrk in DX while akx is still in XM (key bank not written yet)
    wire XM_isAKX_bp;
    assign XM_isAKX_bp     = (XM_opcode_bp == 5'b11100);
    wire akx_lrk_stall;
    assign akx_lrk_stall   = XM_isAKX_bp & DX_isLRK;

    assign FD_stall = md_stall | lw_use_stall | jr_raw_stall | akx_lrk_stall;

    // =========================================================
    // Overflow / exception
    // =========================================================
    wire ovf_add    = DX_isADD  & alu_ovf;
    wire ovf_addi   = DX_isADDI & alu_ovf;
    wire ovf_sub    = DX_isSUB  & alu_ovf;
    wire ovf_mul_ex = DX_isMUL  & md_capture & md_exception;
    wire ovf_div_ex = DX_isDIV  & md_capture & md_exception;
    wire any_ovf    = ovf_add | ovf_addi | ovf_sub | ovf_mul_ex | ovf_div_ex;

    wire [31:0] status_val = ovf_add    ? 32'd1 :
                             ovf_addi   ? 32'd2 :
                             ovf_sub    ? 32'd3 :
                             ovf_mul_ex ? 32'd4 :
                             ovf_div_ex ? 32'd5 : 32'b0;

    // =========================================================
    // Branch / jump logic
    // =========================================================
    wire [31:0] dx_pc_p1, branch_target;
    wire bc, bov, br_cout, br_ovf;
    addsub dx_pc_adder(dx_pc_p1,      bc,      bov,    DX_PC,    32'b1,       1'b0);
    addsub br_adder   (branch_target, br_cout, br_ovf, dx_pc_p1, DX_imm_sext, 1'b0);

    wire bne_taken = DX_isBNE & alu_ne;
    wire blt_taken = DX_isBLT & alu_lt;
    wire bex_taken = DX_isBEX & (|alu_A_bypassed);
    wire take_branch_X    = bne_taken | blt_taken | bex_taken;
    wire [31:0] branch_target_X = bex_taken ? {5'b0, DX_T} : branch_target;

    assign PC_next = take_branch_X ? branch_target_X :
                     FD_isJump     ? jump_target_D   :
                                     PC_plus1;

    assign FD_flush = take_branch_X | FD_isJump;
    assign DX_flush = take_branch_X;

    // =========================================================
    // AES combinational execution units
    // =========================================================
    wire [127:0] subb_out, shr_out, mixc_out, ark_out;
    wire [127:0] isubb_out, ishr_out, imixc_out;

    SubBytes    U_SUBB (.sub_out(subb_out),   .sub_in(aes_A));
    ShiftRows   U_SHR  (.state_out(shr_out),  .state_in(aes_A));
    MixColumns  U_MIXC (.state_out(mixc_out), .state_in(aes_A));
    AddRoundKey U_ARK  (.plaintext(aes_A),    .key(aes_B),      .ciphertext(ark_out));
    i_SubBytes  U_ISBB (.sub_out(isubb_out),  .sub_in(aes_A));
    i_ShiftRows U_ISHR (.state_out(ishr_out), .state_in(aes_A));
    i_MixColumns U_IMC (.state_out(imixc_out),.state_in(aes_A));

    // =========================================================
    // Key expansion (akx instruction)
    // =========================================================
    wire [1407:0] kexp_out;
    KeyExpansion KEXP(.input_key(aes_A), .round_keys(kexp_out));

    // Pipeline the 1408-bit key expansion result through XM and MW stages
    // so it arrives at key_bank write in MW.
    wire [127:0] XM_kexp [0:10];
    wire [127:0] MW_kexp [0:10];

    genvar kx;
    generate
        for (kx = 0; kx <= 10; kx = kx + 1) begin : KEXP_PIPE
            reg128 xm_kl(.clk(negedge_clk), .rst(reset), .en(on),
                         .d(kexp_out[1407-128*kx -: 128]),
                         .q(XM_kexp[kx]));
            reg128 mw_kl(.clk(negedge_clk), .rst(reset), .en(on),
                         .d(XM_kexp[kx]),
                         .q(MW_kexp[kx]));
        end
    endgenerate

    // Committed key bank — 11 × 128-bit, written when akx reaches MW
    wire [127:0] key_bank [0:10];
    wire [4:0]   MW_opcode_main = MW_IR[31:27];
    wire         MW_isAKX       = (MW_opcode_main == 5'b11100);

    generate
        for (kx = 0; kx <= 10; kx = kx + 1) begin : KEY_BANK
            reg128 kb(.clk(negedge_clk), .rst(reset), .en(MW_isAKX),
                      .d(MW_kexp[kx]),
                      .q(key_bank[kx]));
        end
    endgenerate

    // lrk: select round key from committed bank or bypass from MW_kexp
    wire [4:0] DX_ridx = DX_IR[16:12];

    wire [127:0] lrk_committed;
    assign lrk_committed = (DX_ridx == 5'd0)  ? key_bank[0]  :
                           (DX_ridx == 5'd1)  ? key_bank[1]  :
                           (DX_ridx == 5'd2)  ? key_bank[2]  :
                           (DX_ridx == 5'd3)  ? key_bank[3]  :
                           (DX_ridx == 5'd4)  ? key_bank[4]  :
                           (DX_ridx == 5'd5)  ? key_bank[5]  :
                           (DX_ridx == 5'd6)  ? key_bank[6]  :
                           (DX_ridx == 5'd7)  ? key_bank[7]  :
                           (DX_ridx == 5'd8)  ? key_bank[8]  :
                           (DX_ridx == 5'd9)  ? key_bank[9]  :
                           (DX_ridx == 5'd10) ? key_bank[10] : 128'b0;

    wire [127:0] lrk_bypass_val;
    assign lrk_bypass_val = (DX_ridx == 5'd0)  ? MW_kexp[0]  :
                            (DX_ridx == 5'd1)  ? MW_kexp[1]  :
                            (DX_ridx == 5'd2)  ? MW_kexp[2]  :
                            (DX_ridx == 5'd3)  ? MW_kexp[3]  :
                            (DX_ridx == 5'd4)  ? MW_kexp[4]  :
                            (DX_ridx == 5'd5)  ? MW_kexp[5]  :
                            (DX_ridx == 5'd6)  ? MW_kexp[6]  :
                            (DX_ridx == 5'd7)  ? MW_kexp[7]  :
                            (DX_ridx == 5'd8)  ? MW_kexp[8]  :
                            (DX_ridx == 5'd9)  ? MW_kexp[9]  :
                            (DX_ridx == 5'd10) ? MW_kexp[10] : 128'b0;

    // Use MW bypass when akx is in MW and lrk is in DX (1 cycle after akx_lrk_stall resolves)
    wire [127:0] lrk_result = (MW_isAKX & DX_isLRK) ? lrk_bypass_val : lrk_committed;

    // =========================================================
    // AES result mux
    // =========================================================
    wire [127:0] aes_result = DX_isASB              ? subb_out   :
                              DX_isASR              ? shr_out    :
                              DX_isAMC              ? mixc_out   :
                              (DX_isAKE | DX_isARK) ? ark_out    :
                              DX_isASBI             ? isubb_out  :
                              DX_isASRI             ? ishr_out   :
                              DX_isAMCI             ? imixc_out  :
                              DX_isAKX              ? kexp_out[1407:1280] : // K0 → vrd
                              DX_isLRK              ? lrk_result : 128'b0;

    // =========================================================
    // XM latch
    // =========================================================
    wire inject_xm_nop = (md_stall & ~md_capture) | lw_use_stall | akx_lrk_stall;

    wire [31:0] ex_result = md_capture ? md_result     :
                            DX_isSETX  ? {5'b0, DX_T}  :
                            DX_isJAL   ? dx_pc_p1       :
                                         alu_result;

    wire [31:0]  XM_OVF_VAL, MW_OVF_VAL;
    wire         XM_any_ovf,  MW_any_ovf;
    reg32 xm_ovfval_latch(.clk(negedge_clk), .rst(reset), .en(on), .d(status_val), .q(XM_OVF_VAL));
    reg1  xm_ovf_latch   (.clk(negedge_clk), .rst(reset), .en(on), .d(any_ovf),    .q(XM_any_ovf));

    wire [31:0]  XM_IR, XM_O, XM_B;
    wire [127:0] XM_vec;
    wire [31:0] xm_ir_in = inject_xm_nop ? 32'b0 : DX_IR;
    reg32  xm_ir_latch (.clk(negedge_clk), .rst(reset), .en(on), .d(xm_ir_in),       .q(XM_IR));
    reg32  xm_o_latch  (.clk(negedge_clk), .rst(reset), .en(on), .d(ex_result),       .q(XM_O));
    reg32  xm_b_latch  (.clk(negedge_clk), .rst(reset), .en(on), .d(alu_B_bypassed),  .q(XM_B));
    reg128 xm_vec_latch(.clk(negedge_clk), .rst(reset), .en(on), .d(aes_result),      .q(XM_vec));

    wire XM_isSW = ~XM_opcode_bp[4] & ~XM_opcode_bp[3] &  XM_opcode_bp[2] &  XM_opcode_bp[1] &  XM_opcode_bp[0];
    wire XM_isLW = ~XM_opcode_bp[4] &  XM_opcode_bp[3] & ~XM_opcode_bp[2] & ~XM_opcode_bp[1] & ~XM_opcode_bp[0];

    wire [4:0] XM_sw_src    = XM_IR[26:22];
    wire [4:0] MW_opcode_mx = MW_IR[31:27];
    wire MW_isLW_mx = ~MW_opcode_mx[4] & MW_opcode_mx[3] & ~MW_opcode_mx[2] & ~MW_opcode_mx[1] & ~MW_opcode_mx[0];
    wire [4:0] MW_rd_mx = MW_IR[26:22];
    wire byp_MX_sw = XM_isSW & MW_isLW_mx & (|XM_sw_src) & (MW_rd_mx == XM_sw_src);

    assign address_dmem = XM_O;
    assign data         = byp_MX_sw ? MW_O : XM_B;
    assign wren         = XM_isSW;

    // =========================================================
    // MW latch
    // =========================================================
    wire [31:0]  MW_IR, MW_O;
    wire [127:0] MW_vec;
    wire [31:0]  MW_D_raw = XM_isLW ? q_dmem : XM_O;

    reg32  mw_ir_latch    (.clk(negedge_clk), .rst(reset), .en(on), .d(XM_IR),      .q(MW_IR));
    reg32  mw_o_latch     (.clk(negedge_clk), .rst(reset), .en(on), .d(MW_D_raw),   .q(MW_O));
    reg32  mw_ovfval_latch(.clk(negedge_clk), .rst(reset), .en(on), .d(XM_OVF_VAL),.q(MW_OVF_VAL));
    reg1   mw_ovf_latch   (.clk(negedge_clk), .rst(reset), .en(on), .d(XM_any_ovf),.q(MW_any_ovf));
    reg128 mw_vec_latch   (.clk(negedge_clk), .rst(reset), .en(on), .d(XM_vec),    .q(MW_vec));

    wire [4:0] MW_opcode = MW_IR[31:27];
    wire [4:0] MW_rd_raw = MW_IR[26:22];

    wire MW_isR    = ~|MW_opcode;
    wire MW_isADDI = ~MW_opcode[4] & ~MW_opcode[3] &  MW_opcode[2] & ~MW_opcode[1] &  MW_opcode[0];
    wire MW_isLW   = ~MW_opcode[4] &  MW_opcode[3] & ~MW_opcode[2] & ~MW_opcode[1] & ~MW_opcode[0];
    wire MW_isJAL  = ~MW_opcode[4] & ~MW_opcode[3] & ~MW_opcode[2] &  MW_opcode[1] &  MW_opcode[0];
    wire MW_isSETX =  MW_opcode[4] & ~MW_opcode[3] &  MW_opcode[2] & ~MW_opcode[1] &  MW_opcode[0];

    wire MW_isAES = (MW_opcode == 5'b10000) | (MW_opcode == 5'b10001) |
                    (MW_opcode == 5'b10010) | (MW_opcode == 5'b10011) |
                    (MW_opcode == 5'b10100) | (MW_opcode == 5'b11001) |
                    (MW_opcode == 5'b11010) | (MW_opcode == 5'b11011) |
                    (MW_opcode == 5'b11100) | (MW_opcode == 5'b11101);

    wire [4:0] MW_rd = MW_any_ovf ? 5'b11110 :
                       MW_isJAL   ? 5'd31    :
                       MW_isSETX  ? 5'd30    : MW_rd_raw;
    wire [31:0] MW_D = MW_any_ovf ? MW_OVF_VAL : MW_O;

    // Scalar writeback
    assign ctrl_writeEnable = MW_isR | MW_isADDI | MW_isLW | MW_isJAL | MW_isSETX;
    assign ctrl_writeReg    = MW_rd;
    assign data_writeReg    = MW_D;

    // Vector writeback (all AES instructions including akx write vrd)
    assign ctrl_writeVecEnable = MW_isAES | MW_isADDI ;
    assign ctrl_writeVecReg    = MW_IR[24:22];
    assign data_writeVecReg    = MW_isAES ? MW_vec : {96'b0, MW_D};

endmodule


// =========================================================
// reg32 — 32-bit D flip-flop with enable and synchronous clear
// =========================================================
module reg32(clk, rst, en, d, q);
    input         clk, rst, en;
    input  [31:0] d;
    output [31:0] q;
    genvar b;
    generate
        for (b = 0; b < 32; b = b + 1) begin : GEN_BITS
            dffe_ref ff(.q(q[b]), .d(d[b]), .clk(clk), .en(en), .clr(rst));
        end
    endgenerate
endmodule

// =========================================================
// reg1 — 1-bit D flip-flop with enable and synchronous clear
// =========================================================
module reg1(clk, rst, en, d, q);
    input  clk, rst, en, d;
    output q;
    dffe_ref ff(.q(q), .d(d), .clk(clk), .en(en), .clr(rst));
endmodule

// =========================================================
// reg128 — 128-bit register with enable and synchronous clear
// =========================================================
module reg128(clk, rst, en, d, q);
    input          clk, rst, en;
    input  [127:0] d;
    output [127:0] q;
    genvar i;
    generate
        for (i = 0; i < 128; i = i + 1) begin : ff
            dffe_ref dff(.q(q[i]), .d(d[i]), .clk(clk), .en(en), .clr(rst));
        end
    endgenerate
endmodule
