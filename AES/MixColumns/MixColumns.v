// AES MixColumns
// State is [127:0], byte k occupies bits [127-8k -: 8]
// Column i (0-indexed) contains bytes at:
//   a0 = [127-32*i -: 8]  (top row)
//   a1 = [119-32*i -: 8]
//   a2 = [111-32*i -: 8]
//   a3 = [103-32*i -: 8]  (bottom row)
//
// MixColumns matrix (GF(2^8) arithmetic):
//   b0 = 2*a0 ^ 3*a1 ^   a2 ^   a3
//   b1 =   a0 ^ 2*a1 ^ 3*a2 ^   a3
//   b2 =   a0 ^   a1 ^ 2*a2 ^ 3*a3
//   b3 = 3*a0 ^   a1 ^   a2 ^ 2*a3

module MixColumns (
    input  [127:0] state_in,
    output [127:0] state_out
);

    // GF(2^8) multiply by 2: left shift, XOR 0x1b if MSB was 1
    function [7:0] mb2;
        input [7:0] x;
        mb2 = x[7] ? ((x << 1) ^ 8'h1b) : (x << 1);
    endfunction

    // GF(2^8) multiply by 3: mb2(x) ^ x
    function [7:0] mb3;
        input [7:0] x;
        mb3 = mb2(x) ^ x;
    endfunction

    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : mix_col
            assign state_out[127-32*i -: 8] = mb2(state_in[127-32*i -: 8]) ^ mb3(state_in[119-32*i -: 8]) ^     state_in[111-32*i -: 8]  ^     state_in[103-32*i -: 8];
            assign state_out[119-32*i -: 8] =     state_in[127-32*i -: 8]  ^ mb2(state_in[119-32*i -: 8]) ^ mb3(state_in[111-32*i -: 8]) ^     state_in[103-32*i -: 8];
            assign state_out[111-32*i -: 8] =     state_in[127-32*i -: 8]  ^     state_in[119-32*i -: 8]  ^ mb2(state_in[111-32*i -: 8]) ^ mb3(state_in[103-32*i -: 8]);
            assign state_out[103-32*i -: 8] = mb3(state_in[127-32*i -: 8]) ^     state_in[119-32*i -: 8]  ^     state_in[111-32*i -: 8]  ^ mb2(state_in[103-32*i -: 8]);
        end
    endgenerate

endmodule
