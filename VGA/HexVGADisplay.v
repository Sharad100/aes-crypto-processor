`timescale 1ns / 1ps
// VGA display module that renders a 128-bit value as 32 hex digits.
// Mirrors VGAController architecture (PLL -> VGATimingGenerator -> pixel logic).
// Two rows of 16 characters each; 2x scaled 8x8 font = 16x16 px per character.
// Text is white normally; switches to green when done=1.
module HexVGADisplay (
    input         clk,        // 100 MHz system clock
    input         reset,
    input [127:0] value,      // 128-bit value displayed as 32 hex digits
    input         done,       // high = decryption complete; changes text color to green
    output        hSync,
    output        vSync,
    output [3:0]  VGA_R,
    output [3:0]  VGA_G,
    output [3:0]  VGA_B
);

    // VGA timing (640x480, standard parameters)
    wire        active, screenEnd;
    wire [9:0]  x;
    wire [8:0]  y;
    VGATimingGenerator #(.HEIGHT(480), .WIDTH(640)) Display (
        .clk25(clk), .reset(reset),
        .screenEnd(screenEnd), .active(active),
        .hSync(hSync), .vSync(vSync),
        .x(x), .y(y)
    );

    // Layout: 2x scaled 8x8 font -> 16x16 px per character
    // Row 0 (upper 64 bits): 16 chars starting at (START_X, ROW0_Y)
    // Row 1 (lower 64 bits): 16 chars starting at (START_X, ROW1_Y)
    localparam SCALE    = 2;
    localparam CHAR_W   = 8 * SCALE;          // 16 px wide
    localparam CHAR_H   = 8 * SCALE;          // 16 px tall
    localparam NCHARS   = 16;
    localparam DISP_W   = NCHARS * CHAR_W;    // 256 px total width
    localparam START_X  = (640 - DISP_W) / 2; // 192: centered
    localparam ROW0_Y   = 208;
    localparam ROW1_Y   = ROW0_Y + CHAR_H + 8; // 8 px gap between rows

    // Active display region guards
    wire in_x    = (x >= START_X)  && (x < START_X + DISP_W);
    wire in_row0 = in_x && (y >= ROW0_Y) && (y < ROW0_Y + CHAR_H);
    wire in_row1 = in_x && (y >= ROW1_Y) && (y < ROW1_Y + CHAR_H);

    // Pixel offsets within the display block (guarded to avoid underflow)
    wire [9:0] x_off   = in_x    ? (x - (START_X))  : 10'd0;
    wire [8:0] y_off0  = in_row0 ? (y - (ROW0_Y))    :  9'd0;
    wire [8:0] y_off1  = in_row1 ? (y - (ROW1_Y))    :  9'd0;

    // Which character column (0-15) and pixel within character
    wire [3:0] char_col    = x_off[7:4];   // x_off / CHAR_W  (CHAR_W=16=2^4)
    wire [3:0] px_in_char  = x_off[3:0];   // x_off % CHAR_W
    wire [2:0] font_col    = px_in_char[3:1]; // font col 0-7 (divide by SCALE=2)
    wire [2:0] font_row0   = y_off0[3:1];     // font row 0-7 for display row 0
    wire [2:0] font_row1   = y_off1[3:1];     // font row 0-7 for display row 1

    // Nibble extraction.
    // value[127:0]: nibble 0 (MSN) at bits[127:124], nibble 31 (LSN) at bits[3:0].
    // Row 0 shows nibbles 0-15  -> base index = 127 - char_col*4
    // Row 1 shows nibbles 16-31 -> base index = 63  - char_col*4
    wire [6:0] char_col7  = {3'b0, char_col};
    wire [6:0] base_r0    = 7'd127 - (char_col7 << 2);
    wire [6:0] base_r1    = 7'd63  - (char_col7 << 2);

    wire [3:0] char_code_r0 = value[base_r0 -: 4];
    wire [3:0] char_code_r1 = value[base_r1 -: 4];

    // CharROM lookups (combinational)
    wire [7:0] bitmap_r0, bitmap_r1;
    CharROM font0 (.char(char_code_r0), .row(font_row0), .bitmap(bitmap_r0));
    CharROM font1 (.char(char_code_r1), .row(font_row1), .bitmap(bitmap_r1));

    // Pixel lit when the corresponding bitmap bit is set (bit 7 = leftmost)
    wire pixel_r0 = in_row0 && bitmap_r0[7 - font_col];
    wire pixel_r1 = in_row1 && bitmap_r1[7 - font_col];
    wire text_on  = pixel_r0 || pixel_r1;

    // Colors: dark-blue background; white text normally, green when done
    localparam [11:0] BG_COLOR   = 12'h002; // dark navy
    localparam [11:0] TEXT_WHITE = 12'hFFF;
    localparam [11:0] TEXT_GREEN = 12'h0F0;

    wire [11:0] text_color = done ? TEXT_GREEN : TEXT_WHITE;
    wire [11:0] colorOut   = !active  ? 12'h000 :
                              text_on ? text_color : BG_COLOR;

    assign {VGA_R, VGA_G, VGA_B} = colorOut;
endmodule
