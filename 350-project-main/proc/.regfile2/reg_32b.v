module reg_32b (
    output [31:0] Q,
    input [31:0] D,
    input clk,
    reset,
    RW_en
);

  genvar i;
  generate
    for (i = 0; i < 32; i = i + 1) begin : gen_reg
      dffe_ref dff (
          .q  (Q[i]),
          .d  (D[i]),
          .clk(clk),
          .en (RW_en),
          .clr(reset)
      );
    end
  endgenerate

endmodule
