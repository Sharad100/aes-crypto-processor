module SubBytes_tb;

  reg [127:0] in;
  wire [127:0] sub;

  SubBytes subtest(
      sub, in
  );

  initial begin
    $monitor("Input: %h", in);
    $monitor("Output: %h", sub);
    in = 128'h000102030405060708090A0B0C0D0E0F;
    #10;
    in = 128'h808182838485868788898A8B8C8D8E8F;
    #10;
    $finish;
  end


endmodule
