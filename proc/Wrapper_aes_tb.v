`timescale 1ns / 100ps

module Wrapper_aes_tb;

    reg  clk = 0;
    reg  reset = 1;
    reg [127:0] out = 128'h0; 

    Wrapper_aes DUT(.clock(clk), .reset(reset));

    always #5 clk = ~clk;

    initial begin
        @(posedge clk); @(posedge clk);
        reset = 0;
    end

    // Monitor: print every cycle so you can watch vr0 change
    // (comment out if output is too noisy)
    initial $monitor("t=%0t  vr0=%h", $time, DUT.vRegA);

    // Run 200 cycles (way more than the 53-instr program needs)
    integer cycle;
    initial begin
        for (cycle = 0; cycle < 400; cycle = cycle + 1)
            @(posedge clk);

        out = DUT.vRegA;
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
            $display("FAIL: mismatch :” check pipeline, key expansion, or byte ordering");

        $finish;
    end

    // Waveform dump for Vivado or GTKWave
    initial begin
        $dumpfile("aes_test.vcd");
        $dumpvars(0, Wrapper_aes_tb);
    end

endmodule
