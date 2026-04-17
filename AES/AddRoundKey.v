module AddRoundKey (
    input  [127:0] plaintext,
    input  [127:0] key,
    output [127:0] ciphertext
);
  assign ciphertext = plaintext ^ key;
endmodule
