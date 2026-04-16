`timescale 1ns/100ps
module KeyExpansion_tb;

  reg [127:0] in;
  reg en;
  wire [1407:0] out;

  KeyExpansion kexp (
      out,
      in,
      en
  );

  initial begin
    $monitor("Input: %h", in);
    $monitor("Output: %08h %08h %016h %016h %016h %016h %04h %04h", out[1407:1280], out[1279:1152],
             out[1151:896], out[895:640], out[639:384], out[383:128], out[127:64], out[63:0]);
    en = 1'b0;
    in = 12'h0;
    #10000;
    $finish;
  end
  always @(in) begin 
  begin

    en <= 1'b1;
    in = 128'h0;
    #10;
    en <= 1'b0;
    in = 128'h1;
    #10;
    in = 128'h2;
    en <= 1'b1;
  end
  end
  endmodule
