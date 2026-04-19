`timescale 1ns / 100ps
// Top-level integrating the AES processor pipeline with HexVGADisplay.
// The last value written to TARGET_VEC_REG is latched and shown on screen.
// Set TARGET_VEC_REG to whichever vector register holds your decrypted output.
// In your assembly program, write the result to that register last (e.g. vr0).
// The `done` output of the processor (r1 != 0) switches text color to green.
module AES_VGA_Top (
    input  clk_100mhz, BTNC,
    input [15:0] LED,
    // VGA outputs
    output VGA_HS, VGA_VS,
    output [3:0] VGA_R, VGA_G, VGA_B
);

wire clock, clock25;
    assign reset = BTNC;
  clk_wiz_0 pll (
      .clk_out1(clock),
      .clk_out2(clock25),  // 25 MHz output clock
      .reset(reset),
      .locked(locked),
      .clk_in1(clk_100mhz)
  );
    
    // Change to match whichever vector register stores the decrypted result
    localparam [2:0] TARGET_VEC_REG = 3'd0;

    // Instruction file (without .mem extension)
    localparam INSTR_FILE = "./aes_test_no_dec";

    // ----------------------------------------------------------------
    // Wires matching Wrapper_aes
    // ----------------------------------------------------------------
    wire        rwe, mwe;
    wire [4:0]  rd, rs1, rs2;
    wire [31:0] instAddr, instData,
                rData, regA, regB,
                memAddr, memDataIn, memDataOut;

    wire        vrwe;
    wire [2:0]  vrd, vrs1, vrs2;
    wire [127:0] vrData, vRegA, vRegB;

    // ----------------------------------------------------------------
    // AES processor, memories, register file (identical to Wrapper_aes)
    // ----------------------------------------------------------------
    processor_aes CPU (
        .clock            (clock),
        .reset            (reset),
        .address_imem     (instAddr),
        .q_imem           (instData),
        .ctrl_writeEnable (rwe),
        .ctrl_writeReg    (rd),
        .ctrl_readRegA    (rs1),
        .ctrl_readRegB    (rs2),
        .data_writeReg    (rData),
        .data_readRegA    (regA),
        .data_readRegB    (regB),
        .wren             (mwe),
        .address_dmem     (memAddr),
        .data             (memDataIn),
        .q_dmem           (memDataOut),
        .ctrl_writeVecEnable (vrwe),
        .ctrl_writeVecReg    (vrd),
        .ctrl_readVecRegA    (vrs1),
        .ctrl_readVecRegB    (vrs2),
        .data_writeVecReg    (vrData),
        .data_readVecRegA    (vRegA),
        .data_readVecRegB    (vRegB)
    );

    ROM #(.MEMFILE({INSTR_FILE, ".mem"})) InstMem (
        .clk(clock), .addr(instAddr[11:0]), .dataOut(instData)
    );

    regfile RegisterFile (
        .clock               (clock),
        .ctrl_reset          (reset),
        .ctrl_writeEnable    (rwe),
        .ctrl_writeReg       (rd),
        .ctrl_readRegA       (rs1),
        .ctrl_readRegB       (rs2),
        .data_writeReg       (rData),
        .data_readRegA       (regA),
        .data_readRegB       (regB),
        .ctrl_writeVecEnable (vrwe),
        .ctrl_writeVecReg    (vrd),
        .ctrl_readVecRegA    (vrs1),
        .ctrl_readVecRegB    (vrs2),
        .data_writeVecReg    (vrData),
        .data_readVecRegA    (vRegA),
        .data_readVecRegB    (vRegB)
    );

    RAM ProcMem (
        .clk(clock), .wEn(mwe),
        .addr(memAddr[11:0]), .dataIn(memDataIn), .dataOut(memDataOut)
    );

    // ----------------------------------------------------------------
    // Latch the decrypted output whenever TARGET_VEC_REG is written.
    // This captures the result even after the CPU has moved on.
    // ----------------------------------------------------------------
    reg [127:0] display_reg;
    reg         done_flag;

    always @(posedge clock) begin
        if (reset) begin
            display_reg <= 128'h0;
            done_flag   <= 1'b0;
        end else if (vrwe & vrd == TARGET_VEC_REG) begin//vrwe & (vrd == TARGET_VEC_REG)) begin
            display_reg <= vrData;
            done_flag   <= 1'b1;
        end
    end

    // ----------------------------------------------------------------
    // VGA display
    // ----------------------------------------------------------------
    HexVGADisplay vga (
        .clk   (clock25),
        .reset (reset),
        .value (display_reg),
        .done  (done_flag),
        .hSync (VGA_HS),
        .vSync (VGA_VS),
        .VGA_R (VGA_R),
        .VGA_G (VGA_G),
        .VGA_B (VGA_B)
    );

endmodule
