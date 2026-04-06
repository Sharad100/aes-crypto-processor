module SubBytes (
    output [127:0] sub_out,
    input  [127:0] sub_in
);

  genvar i;
  generate
    for (i = 0; i < 127; i = i + 8) begin : gen_sbox
      sbox sub (
          .out(sub_out[i+:8]),
          .in (sub_in[i+:8])
      );
    end
  endgenerate
endmodule
