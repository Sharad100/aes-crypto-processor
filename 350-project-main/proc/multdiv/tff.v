module tff (
    output q,
    input T,
    input clk,
    input en,
    input clr
);


wire dff_out;
wire not_dff_out;
wire t0;
wire t1;
wire t2;
wire not_T;

not(not_dff_out, dff_out);
not(not_T, T);

and(t0, T, not_dff_out);
and(t1, not_T, dff_out);
or(t2,t0,t1);


dffe_ref dff0(.q(dff_out), .d(t2), .clk(clk), .en(en), .clr(clr));

assign q = dff_out;

endmodule

