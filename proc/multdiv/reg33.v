module reg33(input clk, input rst, input en, input [32:0] d, output [32:0] q);
    genvar b;
    generate
        for (b = 0; b < 33; b = b + 1) begin : GEN_BITS
            dffe_ref ff(q[b], d[b], clk, en, rst);
        end
    endgenerate
endmodule