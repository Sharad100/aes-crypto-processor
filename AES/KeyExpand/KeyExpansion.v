module KeyExpansion (
    // 10 rounds + 1: 11 128bit keys
    output reg [1407:0] round_keys,
    // Hard-coded AES128
    input [127:0] input_key,
    input en
);

  reg [31:0] intermediate;
  reg [31:0] previous;
  reg [31:0] next;
  reg [31:0] temp;
  //  reg [31:0] RotWord;
  reg [31:0] four_ago;
  // reg [31:0] SubWord;
  reg [31:0] rci;
  reg [7:0] sub0, sub1, sub2, sub3;


  integer i;
  always @( posedge en) begin
    round_keys = input_key;
    for (i = 4; i < 44; i = i+1) begin
    previous = round_keys[31:0];
    intermediate = previous;
    if (i % 4 == 0) begin
      intermediate = SubWord(RotWord(previous)) ^ rconv(i/4);
    end
      next = round_keys[127:96] ^intermediate;
      round_keys = round_keys << 32;
      round_keys = {round_keys[1407:32], next};
    end
  end



//  always @(*) begin
//    // W_i = K_i for i < N
//    round_keys[1407:1280] = input_key;
//    // W_i = W_i-N XOR (SubWord(RotWord(W_i-1)) XOR (rconi/N)
//    for (i = 0; i < 44; i = i - 1) begin
//      four_ago = round_keys[((47-i)*32)-128+:32];
//      previous = round_keys[(32*(44-i))-128+:32];
//      intermediate = previous;
//      if (i % 4 == 0) begin
//        rci = rconv(i / 4);
//        intermediate = SubWord(RotWord(previous)) ^ rci;
//      end
//      next = (four_ago ^ intermediate);
//      round_keys[(32*(43-i))+:32] = next;
//    end
//  end
//
  function automatic [31:0] RotWord;
    input [31:0] word;
    begin
      RotWord[31:24] = word[7:0];
      RotWord[23:16] = word[31:24];
      RotWord[15:8]  = word[23:16];
      RotWord[7:0]   = word[15:8];
    end
  endfunction

  function automatic [31:0] SubWord;
    input [31:0] word;
    begin
      SubWord[31:24] = sub(word[31:24]);
      SubWord[23:16] = sub(word[23:16]);
      SubWord[15:8]  = sub(word[15:8]);
      SubWord[7:0]   = sub(word[7:0]);
    end
  endfunction


  function automatic [31:0] rconv;
    input [31:0] in;
    begin
      case (in)
        4'd1: rconv = 32'h00000001;
        4'd2: rconv = 32'h00000002;
        4'd3: rconv = 32'h00000004;
        4'd4: rconv = 32'h00000008;
        4'd5: rconv = 32'h00000010;
        4'd6: rconv = 32'h00000020;
        4'd7: rconv = 32'h00000040;
        4'd8: rconv = 32'h00000080;
        4'd9: rconv = 32'h0000001b;
        4'd10: rconv = 32'h00000036;
        default: rconv = 32'h0000000;
      endcase
    end
  endfunction

  function automatic [7:0] sub(input [7:0] in);
    begin
      case (in)
        default: sub = 8'h63;
        8'h00:   sub = 8'h63;
        8'h01:   sub = 8'h7C;
        8'h02:   sub = 8'h77;
        8'h03:   sub = 8'h7B;
        8'h04:   sub = 8'hF2;
        8'h05:   sub = 8'h6B;
        8'h06:   sub = 8'h6F;
        8'h07:   sub = 8'hC5;
        8'h08:   sub = 8'h30;
        8'h09:   sub = 8'h01;
        8'h0A:   sub = 8'h67;
        8'h0B:   sub = 8'h2B;
        8'h0C:   sub = 8'hFE;
        8'h0D:   sub = 8'hD7;
        8'h0E:   sub = 8'hAB;
        8'h0F:   sub = 8'h76;
        8'h10:   sub = 8'hCA;
        8'h11:   sub = 8'h82;
        8'h12:   sub = 8'hC9;
        8'h13:   sub = 8'h7D;
        8'h14:   sub = 8'hFA;
        8'h15:   sub = 8'h59;
        8'h16:   sub = 8'h47;
        8'h17:   sub = 8'hF0;
        8'h18:   sub = 8'hAD;
        8'h19:   sub = 8'hD4;
        8'h1A:   sub = 8'hA2;
        8'h1B:   sub = 8'hAF;
        8'h1C:   sub = 8'h9C;
        8'h1D:   sub = 8'hA4;
        8'h1E:   sub = 8'h72;
        8'h1F:   sub = 8'hC0;
        8'h20:   sub = 8'hB7;
        8'h21:   sub = 8'hFD;
        8'h22:   sub = 8'h93;
        8'h23:   sub = 8'h26;
        8'h24:   sub = 8'h36;
        8'h25:   sub = 8'h3F;
        8'h26:   sub = 8'hF7;
        8'h27:   sub = 8'hCC;
        8'h28:   sub = 8'h34;
        8'h29:   sub = 8'hA5;
        8'h2A:   sub = 8'hE5;
        8'h2B:   sub = 8'hF1;
        8'h2C:   sub = 8'h71;
        8'h2D:   sub = 8'hD8;
        8'h2E:   sub = 8'h31;
        8'h2F:   sub = 8'h15;
        8'h30:   sub = 8'h04;
        8'h31:   sub = 8'hC7;
        8'h32:   sub = 8'h23;
        8'h33:   sub = 8'hC3;
        8'h34:   sub = 8'h18;
        8'h35:   sub = 8'h96;
        8'h36:   sub = 8'h05;
        8'h37:   sub = 8'h9A;
        8'h38:   sub = 8'h07;
        8'h39:   sub = 8'h12;
        8'h3A:   sub = 8'h80;
        8'h3B:   sub = 8'hE2;
        8'h3C:   sub = 8'hEB;
        8'h3D:   sub = 8'h27;
        8'h3E:   sub = 8'hB2;
        8'h3F:   sub = 8'h75;
        8'h40:   sub = 8'h09;
        8'h41:   sub = 8'h83;
        8'h42:   sub = 8'h2C;
        8'h43:   sub = 8'h1A;
        8'h44:   sub = 8'h1B;
        8'h45:   sub = 8'h6E;
        8'h46:   sub = 8'h5A;
        8'h47:   sub = 8'hA0;
        8'h48:   sub = 8'h52;
        8'h49:   sub = 8'h3B;
        8'h4A:   sub = 8'hD6;
        8'h4B:   sub = 8'hB3;
        8'h4C:   sub = 8'h29;
        8'h4D:   sub = 8'hE3;
        8'h4E:   sub = 8'h2F;
        8'h4F:   sub = 8'h84;
        8'h50:   sub = 8'h53;
        8'h51:   sub = 8'hD1;
        8'h52:   sub = 8'h00;
        8'h53:   sub = 8'hED;
        8'h54:   sub = 8'h20;
        8'h55:   sub = 8'hFC;
        8'h56:   sub = 8'hB1;
        8'h57:   sub = 8'h5B;
        8'h58:   sub = 8'h6A;
        8'h59:   sub = 8'hCB;
        8'h5A:   sub = 8'hBE;
        8'h5B:   sub = 8'h39;
        8'h5C:   sub = 8'h4A;
        8'h5D:   sub = 8'h4C;
        8'h5E:   sub = 8'h58;
        8'h5F:   sub = 8'hCF;
        8'h60:   sub = 8'hD0;
        8'h61:   sub = 8'hEF;
        8'h62:   sub = 8'hAA;
        8'h63:   sub = 8'hFB;
        8'h64:   sub = 8'h43;
        8'h65:   sub = 8'h4D;
        8'h66:   sub = 8'h33;
        8'h67:   sub = 8'h85;
        8'h68:   sub = 8'h45;
        8'h69:   sub = 8'hF9;
        8'h6A:   sub = 8'h02;
        8'h6B:   sub = 8'h7F;
        8'h6C:   sub = 8'h50;
        8'h6D:   sub = 8'h3C;
        8'h6E:   sub = 8'h9F;
        8'h6F:   sub = 8'hA8;
        8'h70:   sub = 8'h51;
        8'h71:   sub = 8'hA3;
        8'h72:   sub = 8'h40;
        8'h73:   sub = 8'h8F;
        8'h74:   sub = 8'h92;
        8'h75:   sub = 8'h9D;
        8'h76:   sub = 8'h38;
        8'h77:   sub = 8'hF5;
        8'h78:   sub = 8'hBC;
        8'h79:   sub = 8'hB6;
        8'h7A:   sub = 8'hDA;
        8'h7B:   sub = 8'h21;
        8'h7C:   sub = 8'h10;
        8'h7D:   sub = 8'hFF;
        8'h7E:   sub = 8'hF3;
        8'h7F:   sub = 8'hD2;
        8'h80:   sub = 8'hCD;
        8'h81:   sub = 8'h0C;
        8'h82:   sub = 8'h13;
        8'h83:   sub = 8'hEC;
        8'h84:   sub = 8'h5F;
        8'h85:   sub = 8'h97;
        8'h86:   sub = 8'h44;
        8'h87:   sub = 8'h17;
        8'h88:   sub = 8'hC4;
        8'h89:   sub = 8'hA7;
        8'h8A:   sub = 8'h7E;
        8'h8B:   sub = 8'h3D;
        8'h8C:   sub = 8'h64;
        8'h8D:   sub = 8'h5D;
        8'h8E:   sub = 8'h19;
        8'h8F:   sub = 8'h73;
        8'h90:   sub = 8'h60;
        8'h91:   sub = 8'h81;
        8'h92:   sub = 8'h4F;
        8'h93:   sub = 8'hDC;
        8'h94:   sub = 8'h22;
        8'h95:   sub = 8'h2A;
        8'h96:   sub = 8'h90;
        8'h97:   sub = 8'h88;
        8'h98:   sub = 8'h46;
        8'h99:   sub = 8'hEE;
        8'h9A:   sub = 8'hB8;
        8'h9B:   sub = 8'h14;
        8'h9C:   sub = 8'hDE;
        8'h9D:   sub = 8'h5E;
        8'h9E:   sub = 8'h0B;
        8'h9F:   sub = 8'hDB;
        8'hA0:   sub = 8'hE0;
        8'hA1:   sub = 8'h32;
        8'hA2:   sub = 8'h3A;
        8'hA3:   sub = 8'h0A;
        8'hA4:   sub = 8'h49;
        8'hA5:   sub = 8'h06;
        8'hA6:   sub = 8'h24;
        8'hA7:   sub = 8'h5C;
        8'hA8:   sub = 8'hC2;
        8'hA9:   sub = 8'hD3;
        8'hAA:   sub = 8'hAC;
        8'hAB:   sub = 8'h62;
        8'hAC:   sub = 8'h91;
        8'hAD:   sub = 8'h95;
        8'hAE:   sub = 8'hE4;
        8'hAF:   sub = 8'h79;
        8'hB0:   sub = 8'hE7;
        8'hB1:   sub = 8'hC8;
        8'hB2:   sub = 8'h37;
        8'hB3:   sub = 8'h6D;
        8'hB4:   sub = 8'h8D;
        8'hB5:   sub = 8'hD5;
        8'hB6:   sub = 8'h4E;
        8'hB7:   sub = 8'hA9;
        8'hB8:   sub = 8'h6C;
        8'hB9:   sub = 8'h56;
        8'hBA:   sub = 8'hF4;
        8'hBB:   sub = 8'hEA;
        8'hBC:   sub = 8'h65;
        8'hBD:   sub = 8'h7A;
        8'hBE:   sub = 8'hAE;
        8'hBF:   sub = 8'h08;
        8'hC0:   sub = 8'hBA;
        8'hC1:   sub = 8'h78;
        8'hC2:   sub = 8'h25;
        8'hC3:   sub = 8'h2E;
        8'hC4:   sub = 8'h1C;
        8'hC5:   sub = 8'hA6;
        8'hC6:   sub = 8'hB4;
        8'hC7:   sub = 8'hC6;
        8'hC8:   sub = 8'hE8;
        8'hC9:   sub = 8'hDD;
        8'hCA:   sub = 8'h74;
        8'hCB:   sub = 8'h1F;
        8'hCC:   sub = 8'h4B;
        8'hCD:   sub = 8'hBD;
        8'hCE:   sub = 8'h8B;
        8'hCF:   sub = 8'h8A;
        8'hD0:   sub = 8'h70;
        8'hD1:   sub = 8'h3E;
        8'hD2:   sub = 8'hB5;
        8'hD3:   sub = 8'h66;
        8'hD4:   sub = 8'h48;
        8'hD5:   sub = 8'h03;
        8'hD6:   sub = 8'hF6;
        8'hD7:   sub = 8'h0E;
        8'hD8:   sub = 8'h61;
        8'hD9:   sub = 8'h35;
        8'hDA:   sub = 8'h57;
        8'hDB:   sub = 8'hB9;
        8'hDC:   sub = 8'h86;
        8'hDD:   sub = 8'hC1;
        8'hDE:   sub = 8'h1D;
        8'hDF:   sub = 8'h9E;
        8'hE0:   sub = 8'hE1;
        8'hE1:   sub = 8'hF8;
        8'hE2:   sub = 8'h98;
        8'hE3:   sub = 8'h11;
        8'hE4:   sub = 8'h69;
        8'hE5:   sub = 8'hD9;
        8'hE6:   sub = 8'h8E;
        8'hE7:   sub = 8'h94;
        8'hE8:   sub = 8'h9B;
        8'hE9:   sub = 8'h1E;
        8'hEA:   sub = 8'h87;
        8'hEB:   sub = 8'hE9;
        8'hEC:   sub = 8'hCE;
        8'hED:   sub = 8'h55;
        8'hEE:   sub = 8'h28;
        8'hEF:   sub = 8'hDF;
        8'hF0:   sub = 8'h8C;
        8'hF1:   sub = 8'hA1;
        8'hF2:   sub = 8'h89;
        8'hF3:   sub = 8'h0D;
        8'hF4:   sub = 8'hBF;
        8'hF5:   sub = 8'hE6;
        8'hF6:   sub = 8'h42;
        8'hF7:   sub = 8'h68;
        8'hF8:   sub = 8'h41;
        8'hF9:   sub = 8'h99;
        8'hFA:   sub = 8'h2D;
        8'hFB:   sub = 8'h0F;
        8'hFC:   sub = 8'hB0;
        8'hFD:   sub = 8'h54;
        8'hFE:   sub = 8'hBB;
        8'hFF:   sub = 8'h16;

      endcase
    end
  endfunction

endmodule
