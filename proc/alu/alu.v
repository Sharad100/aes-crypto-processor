

module mux2 #(parameter W=1) (
  output [W-1:0] y,
  input          s,
  input  [W-1:0] a,
  input  [W-1:0] b
);
  assign y = s ? b : a;
endmodule

module mux4 #(parameter W=1) (
  output [W-1:0] y,
  input  [1:0]   s,
  input  [W-1:0] a0, input [W-1:0] a1, input [W-1:0] a2, input [W-1:0] a3
);
  wire [W-1:0] t0, t1;
  mux2 #(W) m0(t0, s[0], a0, a1);
  mux2 #(W) m1(t1, s[0], a2, a3);
  mux2 #(W) m2(y,  s[1], t0, t1);
endmodule



module bitwise_and32(output [31:0] y, input [31:0] a, input [31:0] b);
  genvar i;
  generate
    for (i=0; i<32; i=i+1) begin : G_AND
      and g(y[i], a[i], b[i]);
    end
  endgenerate
endmodule

module bitwise_or32(output [31:0] y, input [31:0] a, input [31:0] b);
  genvar i;
  generate
    for (i=0; i<32; i=i+1) begin : G_OR
      or g(y[i], a[i], b[i]);
    end
  endgenerate
endmodule


module or_reduce32(output y, input [31:0] a);
  wire [31:0] lvl0;
  assign lvl0 = a;

  wire [15:0] lvl1;
  wire [7:0]  lvl2;
  wire [3:0]  lvl3;
  wire [1:0]  lvl4;

  genvar i;
  generate
    for (i=0; i<16; i=i+1) begin : R1
      or g(lvl1[i], lvl0[2*i], lvl0[2*i+1]);
    end
    for (i=0; i<8; i=i+1) begin : R2
      or g(lvl2[i], lvl1[2*i], lvl1[2*i+1]);
    end
    for (i=0; i<4; i=i+1) begin : R3
      or g(lvl3[i], lvl2[2*i], lvl2[2*i+1]);
    end
    for (i=0; i<2; i=i+1) begin : R4
      or g(lvl4[i], lvl3[2*i], lvl3[2*i+1]);
    end
  endgenerate

  or g5(y, lvl4[0], lvl4[1]);
endmodule





module cla8(
  output [7:0] sum,
  output       cout,
  output       c7_in,
  output       Pgroup,
  output       Ggroup,
  input  [7:0] a,
  input  [7:0] b,
  input        cin
);
  wire [7:0] p, g;

  genvar i;
  generate
    for (i=0; i<8; i=i+1) begin : PG8
      xor (p[i], a[i], b[i]);
      and (g[i], a[i], b[i]);
    end
  endgenerate


  wire c1,c2,c3,c4,c5,c6,c7,c8;

  wire t1;
  and (t1, p[0], cin);
  or  (c1, g[0], t1);

  wire t20, t21;
  and (t20, p[1], g[0]);
  and (t21, p[1], p[0], cin);
  or  (c2, g[1], t20, t21);

  wire t30, t31, t32;
  and (t30, p[2], g[1]);
  and (t31, p[2], p[1], g[0]);
  and (t32, p[2], p[1], p[0], cin);
  or  (c3, g[2], t30, t31, t32);

  wire t40, t41, t42, t43;
  and (t40, p[3], g[2]);
  and (t41, p[3], p[2], g[1]);
  and (t42, p[3], p[2], p[1], g[0]);
  and (t43, p[3], p[2], p[1], p[0], cin);
  or  (c4, g[3], t40, t41, t42, t43);

  wire t50, t51, t52, t53, t54;
  and (t50, p[4], g[3]);
  and (t51, p[4], p[3], g[2]);
  and (t52, p[4], p[3], p[2], g[1]);
  and (t53, p[4], p[3], p[2], p[1], g[0]);
  and (t54, p[4], p[3], p[2], p[1], p[0], cin);
  or  (c5, g[4], t50, t51, t52, t53, t54);

  wire t60, t61, t62, t63, t64, t65;
  and (t60, p[5], g[4]);
  and (t61, p[5], p[4], g[3]);
  and (t62, p[5], p[4], p[3], g[2]);
  and (t63, p[5], p[4], p[3], p[2], g[1]);
  and (t64, p[5], p[4], p[3], p[2], p[1], g[0]);
  and (t65, p[5], p[4], p[3], p[2], p[1], p[0], cin);
  or  (c6, g[5], t60, t61, t62, t63, t64, t65);

  wire t70, t71, t72, t73, t74, t75, t76;
  and (t70, p[6], g[5]);
  and (t71, p[6], p[5], g[4]);
  and (t72, p[6], p[5], p[4], g[3]);
  and (t73, p[6], p[5], p[4], p[3], g[2]);
  and (t74, p[6], p[5], p[4], p[3], p[2], g[1]);
  and (t75, p[6], p[5], p[4], p[3], p[2], p[1], g[0]);
  and (t76, p[6], p[5], p[4], p[3], p[2], p[1], p[0], cin);
  or  (c7, g[6], t70, t71, t72, t73, t74, t75, t76);

  wire t80, t81, t82, t83, t84, t85, t86, t87;
  and (t80, p[7], g[6]);
  and (t81, p[7], p[6], g[5]);
  and (t82, p[7], p[6], p[5], g[4]);
  and (t83, p[7], p[6], p[5], p[4], g[3]);
  and (t84, p[7], p[6], p[5], p[4], p[3], g[2]);
  and (t85, p[7], p[6], p[5], p[4], p[3], p[2], g[1]);
  and (t86, p[7], p[6], p[5], p[4], p[3], p[2], p[1], g[0]);
  and (t87, p[7], p[6], p[5], p[4], p[3], p[2], p[1], p[0], cin);
  or  (c8, g[7], t80, t81, t82, t83, t84, t85, t86, t87);

  
  xor (sum[0], p[0], cin);
  xor (sum[1], p[1], c1);
  xor (sum[2], p[2], c2);
  xor (sum[3], p[3], c3);
  xor (sum[4], p[4], c4);
  xor (sum[5], p[5], c5);
  xor (sum[6], p[6], c6);
  xor (sum[7], p[7], c7);

  assign cout  = c8;
  assign c7_in = c7;


  and (Pgroup, p[7], p[6], p[5], p[4], p[3], p[2], p[1], p[0]);


  wire pg6, ppg5, pppg4, ppppg3, pppppg2, ppppppg1, pppppppg0;
  and (pg6,       p[7], g[6]);
  and (ppg5,      p[7], p[6], g[5]);
  and (pppg4,     p[7], p[6], p[5], g[4]);
  and (ppppg3,    p[7], p[6], p[5], p[4], g[3]);
  and (pppppg2,   p[7], p[6], p[5], p[4], p[3], g[2]);
  and (ppppppg1,  p[7], p[6], p[5], p[4], p[3], p[2], g[1]);
  and (pppppppg0, p[7], p[6], p[5], p[4], p[3], p[2], p[1], g[0]);
  or  (Ggroup, g[7], pg6, ppg5, pppg4, ppppg3, pppppg2, ppppppg1, pppppppg0);

endmodule




module cla4_blocks(
  output [4:0] C,
  output       Pgroup,
  output       Ggroup,
  input  [3:0] P,
  input  [3:0] G,
  input        Cin
);
  assign C[0] = Cin;


  wire P0_Cin;
  and (P0_Cin, P[0], Cin);
  or  (C[1],   G[0], P0_Cin);


  wire P1G0, P1P0Cin;
  and (P1G0,     P[1], G[0]);
  and (P1P0Cin,  P[1], P[0], Cin);
  or  (C[2], G[1], P1G0, P1P0Cin);


  wire P2G1, P2P1G0, P2P1P0Cin, P2P1;
  and (P2G1,       P[2], G[1]);
  and (P2P1,       P[2], P[1]);
  and (P2P1G0,     P2P1, G[0]);
  and (P2P1P0Cin,  P2P1, P[0], Cin);
  or  (C[3], G[2], P2G1, P2P1G0, P2P1P0Cin);


  wire P3G2, P3P2G1, P3P2P1G0, P3P2P1P0Cin, P3P2, P3P2P1;
  and (P3G2,        P[3], G[2]);
  and (P3P2,        P[3], P[2]);
  and (P3P2G1,      P3P2, G[1]);
  and (P3P2P1,      P3P2, P[1]);
  and (P3P2P1G0,    P3P2P1, G[0]);
  and (P3P2P1P0Cin, P3P2P1, P[0], Cin);
  or  (C[4], G[3], P3G2, P3P2G1, P3P2P1G0, P3P2P1P0Cin);


  and (Pgroup, P[3], P[2], P[1], P[0]);


  wire P3G2_w, P3P2G1_w, P3P2P1G0_w;
  and (P3G2_w,     P[3], G[2]);
  and (P3P2G1_w,   P[3], P[2], G[1]);
  and (P3P2P1G0_w, P[3], P[2], P[1], G[0]);
  or  (Ggroup, G[3], P3G2_w, P3P2G1_w, P3P2P1G0_w);

endmodule




module addsub(
  output [31:0] sum,
  output        cout,
  output        overflow,
  input  [31:0] a,
  input  [31:0] b,
  input         sub
);

  wire [31:0] b2;
  genvar i;
  generate
    for (i=0; i<32; i=i+1) begin : BX
      xor xb(b2[i], b[i], sub);
    end
  endgenerate


  wire [3:0] Pblk, Gblk;
  wire [4:0] CintoBlk;
  wire P_all, G_all; 
  cla4_blocks blk_carries(
    .C(CintoBlk),
    .Pgroup(P_all),
    .Ggroup(G_all),
    .P(Pblk),
    .G(Gblk),
    .Cin(sub)
  );


  wire [3:0] c7_in_blk;
  wire [3:0] cout_blk;

  generate
    for (i=0; i<4; i=i+1) begin : BLK8
      cla8 u8(
        .sum   (sum[8*i+7:8*i]),
        .cout  (cout_blk[i]),
        .c7_in (c7_in_blk[i]),
        .Pgroup(Pblk[i]),
        .Ggroup(Gblk[i]),
        .a     (a [8*i+7:8*i]),
        .b     (b2[8*i+7:8*i]),
        .cin   (CintoBlk[i])
      );
    end
  endgenerate

  assign cout = CintoBlk[4];

 
  xor xov(overflow, c7_in_blk[3], cout_blk[3]);
endmodule

module sll(
    output [31:0] data_result,
    input  [31:0] data_operandA,
    input  [4:0]  ctrl_shiftamt
    
);
    wire [31:0] s1, s2, s3, s4;
    assign s1 = ctrl_shiftamt[0] ? {data_operandA[30:0], 1'b0} : data_operandA;
    assign s2 = ctrl_shiftamt[1] ? {s1[29:0], 2'b00} : s1;
    assign s3 = ctrl_shiftamt[2] ? {s2[27:0], 4'b0000} : s2;
    assign s4 = ctrl_shiftamt[3] ? {s3[23:0], 8'b00000000} : s3;
    assign data_result = ctrl_shiftamt[4] ? {s4[15:0], 16'b0000000000000000} : s4;

endmodule


module sra(
    output [31:0] data_result,
    input  [31:0] data_operandA,
    input  [4:0]  ctrl_shiftamt
    
);
    wire [31:0] s1, s2, s3, s4;

    assign s1 = ctrl_shiftamt[0] ? {data_operandA[31], data_operandA[31:1]} : data_operandA;
    assign s2 = ctrl_shiftamt[1] ? {{2{s1[31]}}, s1[31:2]} : s1;
    assign s3 = ctrl_shiftamt[2] ? {{4{s2[31]}}, s2[31:4]}: s2;
    assign s4 = ctrl_shiftamt[3] ? {{8{s3[31]}}, s3[31:8]}: s3;
    assign data_result = ctrl_shiftamt[4] ? {{16{s4[31]}}, s4[31:16]}: s4;

endmodule



module alu(
  input  [31:0] data_operandA,
  input  [31:0] data_operandB,
  input  [4:0]  ctrl_ALUopcode,
  input  [4:0]  ctrl_shiftamt,
  output [31:0] data_result,
  output        isNotEqual,
  output        isLessThan,
  output        overflow
);


  wire [31:0] add_sum, sub_sum;
  wire        add_cout, sub_cout;
  wire        add_ovf,  sub_ovf;

  addsub addU(add_sum, add_cout, add_ovf, data_operandA, data_operandB, 1'b0);
  addsub subU(sub_sum, sub_cout, sub_ovf, data_operandA, data_operandB, 1'b1);


  wire [31:0] and_out, or_out;
  bitwise_and32 andU(and_out, data_operandA, data_operandB);
  bitwise_or32  orU (or_out,  data_operandA, data_operandB);


  wire [31:0] sll_out, sra_out;
  sll sllU(sll_out, data_operandA, ctrl_shiftamt);
  sra sraU(sra_out, data_operandA, ctrl_shiftamt);


  wire [31:0] group0_out, group1_out, final_out;
  mux4 #(32) sel0(group0_out, ctrl_ALUopcode[1:0], add_sum, sub_sum, and_out, or_out);
  mux2 #(32) sel1(group1_out, ctrl_ALUopcode[0],   sll_out, sra_out);
  mux2 #(32) sel2(final_out,  ctrl_ALUopcode[2],   group0_out, group1_out);

  assign data_result = final_out;

  wire neq_any;
  or_reduce32 neqU(neq_any, sub_sum);
  assign isNotEqual = neq_any;

  xor ltU(isLessThan, sub_sum[31], sub_ovf);

  wire ovf_sel;
  mux2 #(1) ovU({ovf_sel}, ctrl_ALUopcode[0], {add_ovf}, {sub_ovf});
  assign overflow = ovf_sel;

endmodule
