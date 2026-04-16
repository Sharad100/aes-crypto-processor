`timescale 1ns / 1ps

module Wrapper_aes_tb;

    reg  clock = 0;
    reg  reset = 1;

    Wrapper_aes DUT(.clock(clock), .reset(reset));

    always #5 clock = ~clock;

    initial begin
        @(posedge clock); @(posedge clock);
        reset = 0;
    end

    // Monitor: print every cycle so you can watch vr0 change
    // (comment out if output is too noisy)
    // initial $monitor("t=%0t  vr0=%h", $time, DUT.vRegA);

    // Run 200 cycles (way more than the 53-instr program needs)
    integer cycle;
    initial begin
        for (cycle = 0; cycle < 200; cycle = cycle + 1)
            @(posedge clock);

        // The processor is stuck in "j 0" by now.
        // Force ctrl_readVecRegA = 0 to read vr0 directly from the regfile.
        // Since the processor drives ctrl_readVecRegA to 0 for AES instructions
        // and the halt loop keeps executing "j 0" (opcode 00001, not AES),
        // we peek through the hierarchy instead.
        $display("=== AES-128 Encryption Result ===");
        $display("vr0 (ciphertext) = %h", DUT.vRegA);
        $display("Expected         = 66e94bd4ef8a2c3b884cfa59ca342b2e");

        if (DUT.vRegA === 128'h66e94bd4ef8a2c3b884cfa59ca342b2e)
            $display("PASS: matches NIST FIPS-197 all-zeros test vector");
        else
            $display("FAIL: mismatch — check pipeline, key expansion, or byte ordering");

        $finish;
    end

    // Waveform dump for Vivado or GTKWave
    initial begin
        $dumpfile("aes_test.vcd");
        $dumpvars(0, Wrapper_aes_tb);
    end

endmodule
