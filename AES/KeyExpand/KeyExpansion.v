// AES-128 Key Expansion — purely combinational (fully unrolled)
// Input:  input_key [127:0]  — master key, big-endian (byte 0 at [127:120])
// Output: round_keys [1407:0]
//         K0=[1407:1280]  K1=[1279:1152]  ...  K10=[127:0]

module KeyExpansion (
    output reg [1407:0] round_keys,
    input      [127:0]  input_key
);
    reg [31:0] W [0:43];
    integer    i;

    always @(*) begin
        W[0] = input_key[127:96];
        W[1] = input_key[95:64];
        W[2] = input_key[63:32];
        W[3] = input_key[31:0];

        for (i = 4; i < 44; i = i + 1) begin
            if (i % 4 == 0)
                W[i] = W[i-4] ^ SubWord(RotWord(W[i-1])) ^ Rcon(i/4);
            else
                W[i] = W[i-4] ^ W[i-1];
        end

        // Pack: K_r = {W[4r], W[4r+1], W[4r+2], W[4r+3]}
        // K0 at [1407:1280], K10 at [127:0]
        for (i = 0; i <= 10; i = i + 1)
            round_keys[(10-i)*128 +: 128] = {W[4*i], W[4*i+1], W[4*i+2], W[4*i+3]};
    end

    // Rotate left by one byte: {a,b,c,d} -> {b,c,d,a}
    function [31:0] RotWord;
        input [31:0] w;
        RotWord = {w[23:0], w[31:24]};
    endfunction

    // Apply S-box to each of the four bytes
    function [31:0] SubWord;
        input [31:0] w;
        SubWord = {sbox8(w[31:24]), sbox8(w[23:16]), sbox8(w[15:8]), sbox8(w[7:0])};
    endfunction

    // Round constant: Rcon[r] = {rc, 0, 0, 0} where rc is GF(2^8) power of x
    function [31:0] Rcon;
        input integer r;
        case (r)
            1:  Rcon = 32'h01000000;
            2:  Rcon = 32'h02000000;
            3:  Rcon = 32'h04000000;
            4:  Rcon = 32'h08000000;
            5:  Rcon = 32'h10000000;
            6:  Rcon = 32'h20000000;
            7:  Rcon = 32'h40000000;
            8:  Rcon = 32'h80000000;
            9:  Rcon = 32'h1b000000;
            10: Rcon = 32'h36000000;
            default: Rcon = 32'h00000000;
        endcase
    endfunction

    // AES forward S-box (NIST FIPS-197)
    function [7:0] sbox8;
        input [7:0] in;
        case (in)
            8'h00: sbox8 = 8'h63; 8'h01: sbox8 = 8'h7C; 8'h02: sbox8 = 8'h77; 8'h03: sbox8 = 8'h7B;
            8'h04: sbox8 = 8'hF2; 8'h05: sbox8 = 8'h6B; 8'h06: sbox8 = 8'h6F; 8'h07: sbox8 = 8'hC5;
            8'h08: sbox8 = 8'h30; 8'h09: sbox8 = 8'h01; 8'h0A: sbox8 = 8'h67; 8'h0B: sbox8 = 8'h2B;
            8'h0C: sbox8 = 8'hFE; 8'h0D: sbox8 = 8'hD7; 8'h0E: sbox8 = 8'hAB; 8'h0F: sbox8 = 8'h76;
            8'h10: sbox8 = 8'hCA; 8'h11: sbox8 = 8'h82; 8'h12: sbox8 = 8'hC9; 8'h13: sbox8 = 8'h7D;
            8'h14: sbox8 = 8'hFA; 8'h15: sbox8 = 8'h59; 8'h16: sbox8 = 8'h47; 8'h17: sbox8 = 8'hF0;
            8'h18: sbox8 = 8'hAD; 8'h19: sbox8 = 8'hD4; 8'h1A: sbox8 = 8'hA2; 8'h1B: sbox8 = 8'hAF;
            8'h1C: sbox8 = 8'h9C; 8'h1D: sbox8 = 8'hA4; 8'h1E: sbox8 = 8'h72; 8'h1F: sbox8 = 8'hC0;
            8'h20: sbox8 = 8'hB7; 8'h21: sbox8 = 8'hFD; 8'h22: sbox8 = 8'h93; 8'h23: sbox8 = 8'h26;
            8'h24: sbox8 = 8'h36; 8'h25: sbox8 = 8'h3F; 8'h26: sbox8 = 8'hF7; 8'h27: sbox8 = 8'hCC;
            8'h28: sbox8 = 8'h34; 8'h29: sbox8 = 8'hA5; 8'h2A: sbox8 = 8'hE5; 8'h2B: sbox8 = 8'hF1;
            8'h2C: sbox8 = 8'h71; 8'h2D: sbox8 = 8'hD8; 8'h2E: sbox8 = 8'h31; 8'h2F: sbox8 = 8'h15;
            8'h30: sbox8 = 8'h04; 8'h31: sbox8 = 8'hC7; 8'h32: sbox8 = 8'h23; 8'h33: sbox8 = 8'hC3;
            8'h34: sbox8 = 8'h18; 8'h35: sbox8 = 8'h96; 8'h36: sbox8 = 8'h05; 8'h37: sbox8 = 8'h9A;
            8'h38: sbox8 = 8'h07; 8'h39: sbox8 = 8'h12; 8'h3A: sbox8 = 8'h80; 8'h3B: sbox8 = 8'hE2;
            8'h3C: sbox8 = 8'hEB; 8'h3D: sbox8 = 8'h27; 8'h3E: sbox8 = 8'hB2; 8'h3F: sbox8 = 8'h75;
            8'h40: sbox8 = 8'h09; 8'h41: sbox8 = 8'h83; 8'h42: sbox8 = 8'h2C; 8'h43: sbox8 = 8'h1A;
            8'h44: sbox8 = 8'h1B; 8'h45: sbox8 = 8'h6E; 8'h46: sbox8 = 8'h5A; 8'h47: sbox8 = 8'hA0;
            8'h48: sbox8 = 8'h52; 8'h49: sbox8 = 8'h3B; 8'h4A: sbox8 = 8'hD6; 8'h4B: sbox8 = 8'hB3;
            8'h4C: sbox8 = 8'h29; 8'h4D: sbox8 = 8'hE3; 8'h4E: sbox8 = 8'h2F; 8'h4F: sbox8 = 8'h84;
            8'h50: sbox8 = 8'h53; 8'h51: sbox8 = 8'hD1; 8'h52: sbox8 = 8'h00; 8'h53: sbox8 = 8'hED;
            8'h54: sbox8 = 8'h20; 8'h55: sbox8 = 8'hFC; 8'h56: sbox8 = 8'hB1; 8'h57: sbox8 = 8'h5B;
            8'h58: sbox8 = 8'h6A; 8'h59: sbox8 = 8'hCB; 8'h5A: sbox8 = 8'hBE; 8'h5B: sbox8 = 8'h39;
            8'h5C: sbox8 = 8'h4A; 8'h5D: sbox8 = 8'h4C; 8'h5E: sbox8 = 8'h58; 8'h5F: sbox8 = 8'hCF;
            8'h60: sbox8 = 8'hD0; 8'h61: sbox8 = 8'hEF; 8'h62: sbox8 = 8'hAA; 8'h63: sbox8 = 8'hFB;
            8'h64: sbox8 = 8'h43; 8'h65: sbox8 = 8'h4D; 8'h66: sbox8 = 8'h33; 8'h67: sbox8 = 8'h85;
            8'h68: sbox8 = 8'h45; 8'h69: sbox8 = 8'hF9; 8'h6A: sbox8 = 8'h02; 8'h6B: sbox8 = 8'h7F;
            8'h6C: sbox8 = 8'h50; 8'h6D: sbox8 = 8'h3C; 8'h6E: sbox8 = 8'h9F; 8'h6F: sbox8 = 8'hA8;
            8'h70: sbox8 = 8'h51; 8'h71: sbox8 = 8'hA3; 8'h72: sbox8 = 8'h40; 8'h73: sbox8 = 8'h8F;
            8'h74: sbox8 = 8'h92; 8'h75: sbox8 = 8'h9D; 8'h76: sbox8 = 8'h38; 8'h77: sbox8 = 8'hF5;
            8'h78: sbox8 = 8'hBC; 8'h79: sbox8 = 8'hB6; 8'h7A: sbox8 = 8'hDA; 8'h7B: sbox8 = 8'h21;
            8'h7C: sbox8 = 8'h10; 8'h7D: sbox8 = 8'hFF; 8'h7E: sbox8 = 8'hF3; 8'h7F: sbox8 = 8'hD2;
            8'h80: sbox8 = 8'hCD; 8'h81: sbox8 = 8'h0C; 8'h82: sbox8 = 8'h13; 8'h83: sbox8 = 8'hEC;
            8'h84: sbox8 = 8'h5F; 8'h85: sbox8 = 8'h97; 8'h86: sbox8 = 8'h44; 8'h87: sbox8 = 8'h17;
            8'h88: sbox8 = 8'hC4; 8'h89: sbox8 = 8'hA7; 8'h8A: sbox8 = 8'h7E; 8'h8B: sbox8 = 8'h3D;
            8'h8C: sbox8 = 8'h64; 8'h8D: sbox8 = 8'h5D; 8'h8E: sbox8 = 8'h19; 8'h8F: sbox8 = 8'h73;
            8'h90: sbox8 = 8'h60; 8'h91: sbox8 = 8'h81; 8'h92: sbox8 = 8'h4F; 8'h93: sbox8 = 8'hDC;
            8'h94: sbox8 = 8'h22; 8'h95: sbox8 = 8'h2A; 8'h96: sbox8 = 8'h90; 8'h97: sbox8 = 8'h88;
            8'h98: sbox8 = 8'h46; 8'h99: sbox8 = 8'hEE; 8'h9A: sbox8 = 8'hB8; 8'h9B: sbox8 = 8'h14;
            8'h9C: sbox8 = 8'hDE; 8'h9D: sbox8 = 8'h5E; 8'h9E: sbox8 = 8'h0B; 8'h9F: sbox8 = 8'hDB;
            8'hA0: sbox8 = 8'hE0; 8'hA1: sbox8 = 8'h32; 8'hA2: sbox8 = 8'h3A; 8'hA3: sbox8 = 8'h0A;
            8'hA4: sbox8 = 8'h49; 8'hA5: sbox8 = 8'h06; 8'hA6: sbox8 = 8'h24; 8'hA7: sbox8 = 8'h5C;
            8'hA8: sbox8 = 8'hC2; 8'hA9: sbox8 = 8'hD3; 8'hAA: sbox8 = 8'hAC; 8'hAB: sbox8 = 8'h62;
            8'hAC: sbox8 = 8'h91; 8'hAD: sbox8 = 8'h95; 8'hAE: sbox8 = 8'hE4; 8'hAF: sbox8 = 8'h79;
            8'hB0: sbox8 = 8'hE7; 8'hB1: sbox8 = 8'hC8; 8'hB2: sbox8 = 8'h37; 8'hB3: sbox8 = 8'h6D;
            8'hB4: sbox8 = 8'h8D; 8'hB5: sbox8 = 8'hD5; 8'hB6: sbox8 = 8'h4E; 8'hB7: sbox8 = 8'hA9;
            8'hB8: sbox8 = 8'h6C; 8'hB9: sbox8 = 8'h56; 8'hBA: sbox8 = 8'hF4; 8'hBB: sbox8 = 8'hEA;
            8'hBC: sbox8 = 8'h65; 8'hBD: sbox8 = 8'h7A; 8'hBE: sbox8 = 8'hAE; 8'hBF: sbox8 = 8'h08;
            8'hC0: sbox8 = 8'hBA; 8'hC1: sbox8 = 8'h78; 8'hC2: sbox8 = 8'h25; 8'hC3: sbox8 = 8'h2E;
            8'hC4: sbox8 = 8'h1C; 8'hC5: sbox8 = 8'hA6; 8'hC6: sbox8 = 8'hB4; 8'hC7: sbox8 = 8'hC6;
            8'hC8: sbox8 = 8'hE8; 8'hC9: sbox8 = 8'hDD; 8'hCA: sbox8 = 8'h74; 8'hCB: sbox8 = 8'h1F;
            8'hCC: sbox8 = 8'h4B; 8'hCD: sbox8 = 8'hBD; 8'hCE: sbox8 = 8'h8B; 8'hCF: sbox8 = 8'h8A;
            8'hD0: sbox8 = 8'h70; 8'hD1: sbox8 = 8'h3E; 8'hD2: sbox8 = 8'hB5; 8'hD3: sbox8 = 8'h66;
            8'hD4: sbox8 = 8'h48; 8'hD5: sbox8 = 8'h03; 8'hD6: sbox8 = 8'hF6; 8'hD7: sbox8 = 8'h0E;
            8'hD8: sbox8 = 8'h61; 8'hD9: sbox8 = 8'h35; 8'hDA: sbox8 = 8'h57; 8'hDB: sbox8 = 8'hB9;
            8'hDC: sbox8 = 8'h86; 8'hDD: sbox8 = 8'hC1; 8'hDE: sbox8 = 8'h1D; 8'hDF: sbox8 = 8'h9E;
            8'hE0: sbox8 = 8'hE1; 8'hE1: sbox8 = 8'hF8; 8'hE2: sbox8 = 8'h98; 8'hE3: sbox8 = 8'h11;
            8'hE4: sbox8 = 8'h69; 8'hE5: sbox8 = 8'hD9; 8'hE6: sbox8 = 8'h8E; 8'hE7: sbox8 = 8'h94;
            8'hE8: sbox8 = 8'h9B; 8'hE9: sbox8 = 8'h1E; 8'hEA: sbox8 = 8'h87; 8'hEB: sbox8 = 8'hE9;
            8'hEC: sbox8 = 8'hCE; 8'hED: sbox8 = 8'h55; 8'hEE: sbox8 = 8'h28; 8'hEF: sbox8 = 8'hDF;
            8'hF0: sbox8 = 8'h8C; 8'hF1: sbox8 = 8'hA1; 8'hF2: sbox8 = 8'h89; 8'hF3: sbox8 = 8'h0D;
            8'hF4: sbox8 = 8'hBF; 8'hF5: sbox8 = 8'hE6; 8'hF6: sbox8 = 8'h42; 8'hF7: sbox8 = 8'h68;
            8'hF8: sbox8 = 8'h41; 8'hF9: sbox8 = 8'h99; 8'hFA: sbox8 = 8'h2D; 8'hFB: sbox8 = 8'h0F;
            8'hFC: sbox8 = 8'hB0; 8'hFD: sbox8 = 8'h54; 8'hFE: sbox8 = 8'hBB; 8'hFF: sbox8 = 8'h16;
            default: sbox8 = 8'h63;
        endcase
    endfunction

endmodule
