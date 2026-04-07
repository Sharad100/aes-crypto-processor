// AES Inverse MixColumns
// State is [127:0], byte k occupies bits [127-8k -: 8]
// Column i (0-indexed) contains bytes at:
//   a0 = [127-32*i -: 8]  (top row)
//   a1 = [119-32*i -: 8]
//   a2 = [111-32*i -: 8]
//   a3 = [103-32*i -: 8]  (bottom row)
//
// InvMixColumns matrix (GF(2^8) arithmetic):
//   b0 = 14*a0 ^ 11*a1 ^ 13*a2 ^  9*a3
//   b1 =  9*a0 ^ 14*a1 ^ 11*a2 ^ 13*a3
//   b2 = 13*a0 ^  9*a1 ^ 14*a2 ^ 11*a3
//   b3 = 11*a0 ^ 13*a1 ^  9*a2 ^ 14*a3

module i_MixColumns (
    input  [127:0] state_in,
    output [127:0] state_out
);

    // GF(2^8) multiply by 2
    function [7:0] mb2;
        input [7:0] x;
        mb2 = x[7] ? ((x << 1) ^ 8'h1b) : (x << 1);
    endfunction

    // GF(2^8) multiply by 4
    function [7:0] mb4;
        input [7:0] x;
        mb4 = mb2(mb2(x));
    endfunction

    // GF(2^8) multiply by 8
    function [7:0] mb8;
        input [7:0] x;
        mb8 = mb2(mb4(x));
    endfunction

    // 9  = 8 + 1
    function [7:0] mb9;
        input [7:0] x;
        mb9 = mb8(x) ^ x;
    endfunction

    // 11 = 8 + 2 + 1
    function [7:0] mb11;
        input [7:0] x;
        mb11 = mb8(x) ^ mb2(x) ^ x;
    endfunction

    // 13 = 8 + 4 + 1
    function [7:0] mb13;
        input [7:0] x;
        mb13 = mb8(x) ^ mb4(x) ^ x;
    endfunction

    // 14 = 8 + 4 + 2
    function [7:0] mb14;
        input [7:0] x;
        mb14 = mb8(x) ^ mb4(x) ^ mb2(x);
    endfunction

    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : inv_mix_col
            assign state_out[127-32*i -: 8] = mb14(state_in[127-32*i -: 8]) ^ mb11(state_in[119-32*i -: 8]) ^ mb13(state_in[111-32*i -: 8]) ^  mb9(state_in[103-32*i -: 8]);
            assign state_out[119-32*i -: 8] =  mb9(state_in[127-32*i -: 8]) ^ mb14(state_in[119-32*i -: 8]) ^ mb11(state_in[111-32*i -: 8]) ^ mb13(state_in[103-32*i -: 8]);
            assign state_out[111-32*i -: 8] = mb13(state_in[127-32*i -: 8]) ^  mb9(state_in[119-32*i -: 8]) ^ mb14(state_in[111-32*i -: 8]) ^ mb11(state_in[103-32*i -: 8]);
            assign state_out[103-32*i -: 8] = mb11(state_in[127-32*i -: 8]) ^ mb13(state_in[119-32*i -: 8]) ^  mb9(state_in[111-32*i -: 8]) ^ mb14(state_in[103-32*i -: 8]);
        end
    endgenerate

endmodule
