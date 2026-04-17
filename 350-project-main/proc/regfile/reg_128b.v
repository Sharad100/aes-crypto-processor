module reg_128b (
    output [127:0] Q,
    input [127:0] D,
    input clk,
    input reset,
    input RW_en
);

  genvar i;

  generate
    for (i = 0; i < 128; i = i + 1) begin : gen_reg
      dffe_ref dff (
          .q  (Q[i]),
          .d  (D[i]),
          .clk(clk),
          .clr(reset),
          .en (RW_en)
      );
    end
  endgenerate

endmodule
