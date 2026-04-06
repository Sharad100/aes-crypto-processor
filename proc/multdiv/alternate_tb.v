`timescale 1ns/1ps

module alternate_tb;

    // Inputs
    reg [31:0] data_operandA;
    reg [31:0] data_operandB;
    reg ctrl_MULT;
    reg ctrl_DIV;
    reg clock;

    // Outputs
    wire [31:0] data_result;
    wire data_exception;
    wire data_resultRDY;

    // Instantiate the Unit Under Test (UUT)
    multdiv uut (
        .data_operandA(data_operandA),
        .data_operandB(data_operandB),
        .ctrl_MULT(ctrl_MULT),
        .ctrl_DIV(ctrl_DIV),
        .clock(clock),
        .data_result(data_result),
        .data_exception(data_exception),
        .data_resultRDY(data_resultRDY)
    );

    // Clock generation
    initial begin
        clock = 0;
        forever #5 clock = ~clock; // 10ns period (100MHz)
    end

    // Test counter
    integer test_num = 0;
    integer expected_result;
    
   // Monitor signals every clock cycle
    always @(posedge clock) begin
        $display("Time=%0t | ctrl_MULT=%b | start_mult=%b | counter=%d | mult_active=%b | mult_done=%b | resultRDY=%b", 
                $time, ctrl_MULT, uut.start_mult, uut.counter, uut.mult_active, uut.mult_done, data_resultRDY);
        $display("         | product_high=%h | product_low=%h | result=%d", 
                uut.product_high, uut.product_low, $signed(data_result));
    end

    // Test stimulus
    initial begin
        // Initialize
        $display("\n=== Starting Multiplication Tests ===\n");
        data_operandA = 0;
        data_operandB = 0;
        ctrl_MULT = 0;
        ctrl_DIV = 0;
        
        // Wait for a few cycles
        repeat(3) @(posedge clock);

        // Test 1: Simple positive multiplication
        test_num = 1;
        $display("\n--- Test %0d: 5 * 3 = 15 ---", test_num);
        data_operandA = 32'd5;
        data_operandB = 32'd3;
        expected_result = 15;
        ctrl_MULT = 1;
        @(posedge clock);
        ctrl_MULT = 0;
        
        // Wait for result
        wait(data_resultRDY == 1);
        @(posedge clock);
        check_result(expected_result);
        repeat(5) @(posedge clock);

        // Test 2: Negative * Positive
        test_num = 2;
        $display("\n--- Test %0d: -6 * 5 = -30 ---", test_num);
        data_operandA = -32'd6;
        data_operandB = 32'd5;
        expected_result = -30;
        ctrl_MULT = 1;
        @(posedge clock);
        ctrl_MULT = 0;
        
        wait(data_resultRDY == 1);
        @(posedge clock);
        check_result(expected_result);
        repeat(5) @(posedge clock);

        // Test 3: Negative * Negative
        test_num = 3;
        $display("\n--- Test %0d: -4 * -7 = 28 ---", test_num);
        data_operandA = -32'd4;
        data_operandB = -32'd7;
        expected_result = 28;
        ctrl_MULT = 1;
        @(posedge clock);
        ctrl_MULT = 0;
        
        wait(data_resultRDY == 1);
        @(posedge clock);
        check_result(expected_result);
        repeat(5) @(posedge clock);

        // Test 4: Zero multiplication
        test_num = 4;
        $display("\n--- Test %0d: 100 * 0 = 0 ---", test_num);
        data_operandA = 32'd100;
        data_operandB = 32'd0;
        expected_result = 0;
        ctrl_MULT = 1;
        @(posedge clock);
        ctrl_MULT = 0;
        
        wait(data_resultRDY == 1);
        @(posedge clock);
        check_result(expected_result);
        repeat(5) @(posedge clock);

        // Test 5: Large numbers
        test_num = 5;
        $display("\n--- Test %0d: 1000 * 2000 = 2000000 ---", test_num);
        data_operandA = 32'd1000;
        data_operandB = 32'd2000;
        expected_result = 2000000;
        ctrl_MULT = 1;
        @(posedge clock);
        ctrl_MULT = 0;
        
        wait(data_resultRDY == 1);
        @(posedge clock);
        check_result(expected_result);
        repeat(5) @(posedge clock);

        // Test 6: Power of 2
        test_num = 6;
        $display("\n--- Test %0d: 16 * 32 = 512 ---", test_num);
        data_operandA = 32'd16;
        data_operandB = 32'd32;
        expected_result = 512;
        ctrl_MULT = 1;
        @(posedge clock);
        ctrl_MULT = 0;
        
        wait(data_resultRDY == 1);
        @(posedge clock);
        check_result(expected_result);
        repeat(5) @(posedge clock);

        // Test 7: The example from your slide (5 * -6 = -30)
        test_num = 7;
        $display("\n--- Test %0d: 5 * -6 = -30 (from slide) ---", test_num);
        data_operandA = 32'd5;
        data_operandB = -32'd6;
        expected_result = -30;
        ctrl_MULT = 1;
        @(posedge clock);
        ctrl_MULT = 0;
        
        wait(data_resultRDY == 1);
        @(posedge clock);
        check_result(expected_result);
        repeat(5) @(posedge clock);

        // Test 8: Overflow test (optional - should set exception)
        test_num = 8;
        $display("\n--- Test %0d: Overflow test ---", test_num);
        data_operandA = 32'h40000000; // Large positive
        data_operandB = 32'd4;
        ctrl_MULT = 1;
        @(posedge clock);
        ctrl_MULT = 0;
        
        wait(data_resultRDY == 1);
        @(posedge clock);
        $display("Result: %d, Exception: %b (should be 1 for overflow)", $signed(data_result), data_exception);
        repeat(5) @(posedge clock);

        $display("\n=== All Tests Complete ===\n");
        $finish;
    end

    // Task to check result
    task check_result;
        input integer expected;
        begin
            if ($signed(data_result) == expected) begin
                $display("✓ PASS: Got %d (expected %d)", $signed(data_result), expected);
            end else begin
                $display("✗ FAIL: Got %d (expected %d)", $signed(data_result), expected);
            end
            if (data_exception) begin
                $display("  [Exception flag is set]");
            end
        end
    endtask

    // Timeout watchdog
    initial begin
        #100000; // 100us timeout
        $display("\n!!! TIMEOUT - Simulation ran too long !!!\n");
        $finish;
    end

    // Optional: Generate VCD file for waveform viewing
    initial begin
        $dumpfile("alternate.vcd");
        $dumpvars(0, alternate_tb);
    end

endmodule