`timescale 1ns/100ps
module counter_tb;

    reg clock = 0;
    wire en = 1;
    wire[4:0] counter;
    reg clr = 0;

    counter_mod32 tester_counter(clock, en, clr, counter);
    always #5 clock = ~clock; // 10ns period clock

    // Monitor counter
    always @(posedge clock) begin
        $display("Time=%0t | Counter=%b", $time, counter);
    end

    // Run simulation
    initial begin
        $dumpfile("counter.vcd");
        $dumpvars(0, counter_tb);
        #1000; 
        $finish;
    end



endmodule