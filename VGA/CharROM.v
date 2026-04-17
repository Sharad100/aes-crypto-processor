`timescale 1ns / 1ps
// Combinational 8x8 bitmap font ROM for hex characters 0-F.
// Address: {char[3:0], row[2:0]}  Output: 8-bit row bitmap, bit 7 = leftmost pixel.
module CharROM (
    input  [3:0]     char,
    input  [2:0]     row,
    output reg [7:0] bitmap
);
    always @(*) case ({char, row})
        // '0'
        7'h00: bitmap = 8'h3C;  7'h01: bitmap = 8'h66;
        7'h02: bitmap = 8'h66;  7'h03: bitmap = 8'h66;
        7'h04: bitmap = 8'h66;  7'h05: bitmap = 8'h66;
        7'h06: bitmap = 8'h3C;  7'h07: bitmap = 8'h00;
        // '1'
        7'h08: bitmap = 8'h18;  7'h09: bitmap = 8'h38;
        7'h0A: bitmap = 8'h18;  7'h0B: bitmap = 8'h18;
        7'h0C: bitmap = 8'h18;  7'h0D: bitmap = 8'h18;
        7'h0E: bitmap = 8'h7E;  7'h0F: bitmap = 8'h00;
        // '2'
        7'h10: bitmap = 8'h3C;  7'h11: bitmap = 8'h66;
        7'h12: bitmap = 8'h06;  7'h13: bitmap = 8'h1C;
        7'h14: bitmap = 8'h30;  7'h15: bitmap = 8'h66;
        7'h16: bitmap = 8'h7E;  7'h17: bitmap = 8'h00;
        // '3'
        7'h18: bitmap = 8'h3C;  7'h19: bitmap = 8'h66;
        7'h1A: bitmap = 8'h06;  7'h1B: bitmap = 8'h1C;
        7'h1C: bitmap = 8'h06;  7'h1D: bitmap = 8'h66;
        7'h1E: bitmap = 8'h3C;  7'h1F: bitmap = 8'h00;
        // '4'
        7'h20: bitmap = 8'h0C;  7'h21: bitmap = 8'h1C;
        7'h22: bitmap = 8'h3C;  7'h23: bitmap = 8'h6C;
        7'h24: bitmap = 8'h7E;  7'h25: bitmap = 8'h0C;
        7'h26: bitmap = 8'h0C;  7'h27: bitmap = 8'h00;
        // '5'
        7'h28: bitmap = 8'h7E;  7'h29: bitmap = 8'h60;
        7'h2A: bitmap = 8'h7C;  7'h2B: bitmap = 8'h06;
        7'h2C: bitmap = 8'h06;  7'h2D: bitmap = 8'h66;
        7'h2E: bitmap = 8'h3C;  7'h2F: bitmap = 8'h00;
        // '6'
        7'h30: bitmap = 8'h1C;  7'h31: bitmap = 8'h30;
        7'h32: bitmap = 8'h60;  7'h33: bitmap = 8'h7C;
        7'h34: bitmap = 8'h66;  7'h35: bitmap = 8'h66;
        7'h36: bitmap = 8'h3C;  7'h37: bitmap = 8'h00;
        // '7'
        7'h38: bitmap = 8'h7E;  7'h39: bitmap = 8'h66;
        7'h3A: bitmap = 8'h0C;  7'h3B: bitmap = 8'h18;
        7'h3C: bitmap = 8'h18;  7'h3D: bitmap = 8'h18;
        7'h3E: bitmap = 8'h18;  7'h3F: bitmap = 8'h00;
        // '8'
        7'h40: bitmap = 8'h3C;  7'h41: bitmap = 8'h66;
        7'h42: bitmap = 8'h66;  7'h43: bitmap = 8'h3C;
        7'h44: bitmap = 8'h66;  7'h45: bitmap = 8'h66;
        7'h46: bitmap = 8'h3C;  7'h47: bitmap = 8'h00;
        // '9'
        7'h48: bitmap = 8'h3C;  7'h49: bitmap = 8'h66;
        7'h4A: bitmap = 8'h66;  7'h4B: bitmap = 8'h3E;
        7'h4C: bitmap = 8'h06;  7'h4D: bitmap = 8'h0C;
        7'h4E: bitmap = 8'h38;  7'h4F: bitmap = 8'h00;
        // 'A'
        7'h50: bitmap = 8'h18;  7'h51: bitmap = 8'h3C;
        7'h52: bitmap = 8'h66;  7'h53: bitmap = 8'h66;
        7'h54: bitmap = 8'h7E;  7'h55: bitmap = 8'h66;
        7'h56: bitmap = 8'h66;  7'h57: bitmap = 8'h00;
        // 'B'
        7'h58: bitmap = 8'h7C;  7'h59: bitmap = 8'h66;
        7'h5A: bitmap = 8'h66;  7'h5B: bitmap = 8'h7C;
        7'h5C: bitmap = 8'h66;  7'h5D: bitmap = 8'h66;
        7'h5E: bitmap = 8'h7C;  7'h5F: bitmap = 8'h00;
        // 'C'
        7'h60: bitmap = 8'h3C;  7'h61: bitmap = 8'h66;
        7'h62: bitmap = 8'h60;  7'h63: bitmap = 8'h60;
        7'h64: bitmap = 8'h60;  7'h65: bitmap = 8'h66;
        7'h66: bitmap = 8'h3C;  7'h67: bitmap = 8'h00;
        // 'D'
        7'h68: bitmap = 8'h78;  7'h69: bitmap = 8'h6C;
        7'h6A: bitmap = 8'h66;  7'h6B: bitmap = 8'h66;
        7'h6C: bitmap = 8'h66;  7'h6D: bitmap = 8'h6C;
        7'h6E: bitmap = 8'h78;  7'h6F: bitmap = 8'h00;
        // 'E'
        7'h70: bitmap = 8'h7E;  7'h71: bitmap = 8'h60;
        7'h72: bitmap = 8'h60;  7'h73: bitmap = 8'h7C;
        7'h74: bitmap = 8'h60;  7'h75: bitmap = 8'h60;
        7'h76: bitmap = 8'h7E;  7'h77: bitmap = 8'h00;
        // 'F'
        7'h78: bitmap = 8'h7E;  7'h79: bitmap = 8'h60;
        7'h7A: bitmap = 8'h60;  7'h7B: bitmap = 8'h7C;
        7'h7C: bitmap = 8'h60;  7'h7D: bitmap = 8'h60;
        7'h7E: bitmap = 8'h60;  7'h7F: bitmap = 8'h00;
        default: bitmap = 8'h00;
    endcase
endmodule
