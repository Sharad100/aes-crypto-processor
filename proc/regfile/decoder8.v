
module decoder8 (
    out,
    select,
    enable
);
  input [2:0] select;
  input enable;
  output [7:0] out;

  assign out = enable << select;
endmodule
