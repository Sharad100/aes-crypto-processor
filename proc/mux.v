module mux_2 #(parameter WIDTH = 32) (out, select, in0, in1);
    input select;
    input [WIDTH-1:0] in0, in1;
    output [WIDTH-1:0] out;
    assign out = select ? in1 : in0;
endmodule

module mux_4 #(parameter WIDTH = 32)
    (out, select, in0, in1, in2, in3);

    input  [1:0] select;
    input  [WIDTH-1:0] in0, in1, in2, in3;
    output [WIDTH-1:0] out;

    wire [WIDTH-1:0] w1, w2;

    mux_2 #(WIDTH)
        first_top(w1, select[0], in0, in1);

    mux_2 #(WIDTH)
        first_bottom(w2, select[0], in2, in3);

    mux_2 #(WIDTH)
        second(out, select[1], w1, w2);

endmodule


module mux_8 #(parameter WIDTH = 32)
    (out, select, in0, in1, in2, in3, in4, in5, in6, in7);

    input  [2:0] select;
    input  [WIDTH-1:0] in0, in1, in2, in3, in4, in5, in6, in7;
    output [WIDTH-1:0] out;

    wire [WIDTH-1:0] w1, w2;

    mux_4 #(WIDTH)
        first_top(w1, select[1:0], in0, in1,in2,in3);

    mux_4 #(WIDTH)
        first_bottom(w2, select[1:0], in4, in5,in6,in7);

    mux_2 #(WIDTH)
        second(out, select[2], w1, w2);

endmodule

module mux_32 #(parameter WIDTH = 32)
    (out, select,
     in0,  in1,  in2,  in3,  in4,  in5,  in6,  in7,
     in8,  in9,  in10, in11, in12, in13, in14, in15,
     in16, in17, in18, in19, in20, in21, in22, in23,
     in24, in25, in26, in27, in28, in29, in30, in31);

    input  [4:0] select;
    input  [WIDTH-1:0] in0,  in1,  in2,  in3,  in4,  in5,  in6,  in7,
        in8,  in9,  in10, in11, in12, in13, in14, in15,
        in16, in17, in18, in19, in20, in21, in22, in23,
        in24, in25, in26, in27, in28, in29, in30, in31;
    output [WIDTH-1:0] out;

    wire [WIDTH-1:0] w1, w2, w3, w4;

    mux_8 #(WIDTH)
        first_1(w1, select[2:0], in0, in1, in2, in3, in4, in5, in6, in7);

    mux_8 #(WIDTH)
        first_2(w2, select[2:0], in8, in9, in10, in11, in12, in13, in14, in15);
    
    mux_8 #(WIDTH)
        first_3(w3, select[2:0], in16, in17, in18, in19, in20, in21, in22, in23);

    mux_8 #(WIDTH)
        first_4(w4, select[2:0], in24, in25, in26, in27, in28, in29, in30, in31);

    mux_4 #(WIDTH)
        second(out, select[4:3], w1, w2, w3, w4);
endmodule



