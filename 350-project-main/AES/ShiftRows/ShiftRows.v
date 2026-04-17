// AES ShiftRows
// State is [127:0], byte k occupies bits [127-8k -: 8]
// AES state (column-major):
//   Col:   0    1    2    3
//   Row 0: s0   s4   s8   s12
//   Row 1: s1   s5   s9   s13
//   Row 2: s2   s6   s10  s14
//   Row 3: s3   s7   s11  s15
// ShiftRows cyclically left-shifts row r by r bytes.

module ShiftRows (
    input  [127:0] state_in,
    output [127:0] state_out
);

    // Row 0: no shift
    assign state_out[127-:8] = state_in[127-:8];  // s0  -> s0
    assign state_out[95-:8]  = state_in[95-:8];   // s4  -> s4
    assign state_out[63-:8]  = state_in[63-:8];   // s8  -> s8
    assign state_out[31-:8]  = state_in[31-:8];   // s12 -> s12

    // Row 1: left shift by 1  [s1,s5,s9,s13] -> [s5,s9,s13,s1]
    assign state_out[119-:8] = state_in[87-:8];   // s5  -> col0
    assign state_out[87-:8]  = state_in[55-:8];   // s9  -> col1
    assign state_out[55-:8]  = state_in[23-:8];   // s13 -> col2
    assign state_out[23-:8]  = state_in[119-:8];  // s1  -> col3

    // Row 2: left shift by 2  [s2,s6,s10,s14] -> [s10,s14,s2,s6]
    assign state_out[111-:8] = state_in[47-:8];   // s10 -> col0
    assign state_out[79-:8]  = state_in[15-:8];   // s14 -> col1
    assign state_out[47-:8]  = state_in[111-:8];  // s2  -> col2
    assign state_out[15-:8]  = state_in[79-:8];   // s6  -> col3

    // Row 3: left shift by 3  [s3,s7,s11,s15] -> [s15,s3,s7,s11]
    assign state_out[103-:8] = state_in[7-:8];    // s15 -> col0
    assign state_out[71-:8]  = state_in[103-:8];  // s3  -> col1
    assign state_out[39-:8]  = state_in[71-:8];   // s7  -> col2
    assign state_out[7-:8]   = state_in[39-:8];   // s11 -> col3

endmodule
