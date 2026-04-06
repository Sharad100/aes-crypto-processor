module i_SubBytes_tb;

  reg [127:0] in;
  wire [127:0] sub;

  i_SubBytes subtest(
      sub, in
  );

  initial begin
    $monitor("Input: %h", in);
    $monitor("Output: %h", sub);
    in = 128'h637c777bf26b6fc53001672bfed7ab76;
    #10;
    in = 128'hcd0c13ec5f974417c4a77e3d645d1973;
    #10;
    $finish;
  end


endmodule
