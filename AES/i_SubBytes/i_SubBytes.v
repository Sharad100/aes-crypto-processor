module i_SubBytes (
    output [127:0] sub_out,
    input  [127:0] sub_in
);

  genvar i;
  generate
    for (i = 0; i < 127; i = i + 8) begin : gen_inv_sbox
      i_sbox isub (
          .out(sub_out[i+:8]),
          .in (sub_in[i+:8])
      );
    end
  endgenerate
endmodule
