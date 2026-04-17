`timescale 1ns / 100ps
/**
 * Wrapper_aes.v — Wrapper.v extended to connect processor_aes
 * with the vector register file ports.
 *
 * Adds wiring for:
 *   - ctrl_writeVecEnable / ctrl_writeVecReg (3-bit)
 *   - ctrl_readVecRegA / ctrl_readVecRegB    (3-bit)
 *   - data_writeVecReg / data_readVecRegA / data_readVecRegB (128-bit)
 */

module Wrapper_aes (clock, reset);
    input clock, reset;

    // Scalar register file wires
    wire        rwe, mwe;
    wire [4:0]  rd, rs1, rs2;
    wire [31:0] instAddr, instData,
                rData, regA, regB,
                memAddr, memDataIn, memDataOut;

    // Vector register file wires
    wire        vrwe;
    wire [2:0]  vrd, vrs1, vrs2;
    wire [127:0] vrData, vRegA, vRegB;

    // Path to assembled instruction memory (without .mem extension)
    localparam INSTR_FILE = "./aes_test";

    // Main Processing Unit
    processor_aes CPU(
        .clock   (clock),
        .reset   (reset),

        // ROM
        .address_imem (instAddr),
        .q_imem       (instData),

        // Scalar regfile
        .ctrl_writeEnable (rwe),
        .ctrl_writeReg    (rd),
        .ctrl_readRegA    (rs1),
        .ctrl_readRegB    (rs2),
        .data_writeReg    (rData),
        .data_readRegA    (regA),
        .data_readRegB    (regB),

        // RAM
        .wren         (mwe),
        .address_dmem (memAddr),
        .data         (memDataIn),
        .q_dmem       (memDataOut),

        // Vector regfile
        .ctrl_writeVecEnable (vrwe),
        .ctrl_writeVecReg    (vrd),
        .ctrl_readVecRegA    (vrs1),
        .ctrl_readVecRegB    (vrs2),
        .data_writeVecReg    (vrData),
        .data_readVecRegA    (vRegA),
        .data_readVecRegB    (vRegB)
    );

    // Instruction Memory (ROM)
    ROM #(.MEMFILE({INSTR_FILE, ".mem"}))
    InstMem(
        .clk     (clock),
        .addr    (instAddr[11:0]),
        .dataOut (instData)
    );

    // Register File (scalar + vector)
    regfile RegisterFile(
        .clock              (clock),
        .ctrl_reset         (reset),

        // Scalar ports
        .ctrl_writeEnable   (rwe),
        .ctrl_writeReg      (rd),
        .ctrl_readRegA      (rs1),
        .ctrl_readRegB      (rs2),
        .data_writeReg      (rData),
        .data_readRegA      (regA),
        .data_readRegB      (regB),

        // Vector ports
        .ctrl_writeVecEnable(vrwe),
        .ctrl_writeVecReg   (vrd),
        .ctrl_readVecRegA   (vrs1),
        .ctrl_readVecRegB   (vrs2),
        .data_writeVecReg   (vrData),
        .data_readVecRegA   (vRegA),
        .data_readVecRegB   (vRegB)
    );

    // Processor Memory (RAM)
    RAM ProcMem(
        .clk     (clock),
        .wEn     (mwe),
        .addr    (memAddr[11:0]),
        .dataIn  (memDataIn),
        .dataOut (memDataOut)
    );

endmodule
