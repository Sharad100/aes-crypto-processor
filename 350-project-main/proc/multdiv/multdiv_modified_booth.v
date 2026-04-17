module multdiv(
    data_operandA, data_operandB, ctrl_MULT, ctrl_DIV,
    clock, data_result, data_exception, data_resultRDY
);

    input [31:0] data_operandA, data_operandB;
    input ctrl_MULT, ctrl_DIV, clock;

    output [31:0] data_result;
    output data_exception, data_resultRDY;

    wire [5:0] counter;

    wire start_mult, start_div;
    
    wire prev_ctrl_MULT;
    dffe_ref prev_mult_dff(.q(prev_ctrl_MULT), .d(ctrl_MULT), .clk(clock), .en(1'b1), .clr(1'b0));
    assign start_mult = ctrl_MULT & ~prev_ctrl_MULT;   


    wire prev_ctrl_DIV;
    dffe_ref prev_div_dff(.q(prev_ctrl_DIV), .d(ctrl_DIV), .clk(clock), .en(1'b1), .clr(1'b0));
    assign start_div = ctrl_DIV & ~prev_ctrl_DIV;  



    wire operation_is_mult, operation_is_div;
    wire operation_next_mult, operation_next_div;
    
    
    assign operation_next_mult = start_div? 1'b0: start_mult ? 1'b1 : (data_resultRDY ? 1'b0 : operation_is_mult);
    assign operation_next_div = start_mult? 1'b0: start_div ? 1'b1 : (data_resultRDY ? 1'b0 : operation_is_div);
    
    dffe_ref op_mult_dff(.q(operation_is_mult), .d(operation_next_mult), .clk(clock), .en(1'b1), .clr(1'b0));
    dffe_ref op_div_dff(.q(operation_is_div), .d(operation_next_div), .clk(clock), .en(1'b1), .clr(1'b0)); 


    
    wire counter_lower_zero;
    nor(counter_lower_zero, counter[0], counter[1], counter[2], counter[3]);

    wire counter_clear;
    or(counter_clear, start_mult, start_div);
  

    counter_mod64 cnt(.clk(clock), .en(1'b1), .clr(counter_clear), .counter(counter));

    wire mult_resultRDY;
    and(mult_resultRDY, counter_lower_zero, counter[4]);

    wire div_resultRDY;
    and(div_resultRDY, counter_lower_zero, counter[5]);

    assign data_resultRDY = operation_is_mult ? mult_resultRDY : div_resultRDY;




    wire [31:0] operandA_stored, operandB_stored;
    assign operandA_stored = data_operandA;  
    assign operandB_stored = data_operandB;

   
    wire [32:0] product_high, product_low;
    wire [32:0] product_high_next, product_low_next;

   
    assign product_high_next = start_mult ? 33'd0 : {product_high_after_op[32], product_high_after_op[32], product_high_after_op[32:2]};

                           

    assign product_low_next = start_mult ? {data_operandB, 1'b0} : {product_high_after_op[1:0], product_low[32:2]};
                            

    reg33 reg_product_high(.clk(clock), .rst(1'b0), .en(1'b1), .d(product_high_next), .q(product_high));
    reg33 reg_product_low(.clk(clock), .rst(1'b0), .en(1'b1), .d(product_low_next), .q(product_low));






    //Booth algorithm  

    wire [32:0] operandA_extended;
    assign operandA_extended = {operandA_stored[31], operandA_stored};

    wire [32:0] operandA_shifted;
    assign operandA_shifted = {operandA_stored[31], operandA_stored[30:0], 1'b0};



    wire [32:0] add_m_result, sub_m_result, add_2m_result, sub_2m_result;
    wire add_m_cout, add_m_ovf, add_2m_cout, add_2m_ovf, sub_m_cout, sub_m_ovf, sub_2m_cout, sub_2m_ovf;
 

    // +M operation
    wire [31:0] add_m_result_32_bit;
    addsub add_m_unit(
        .sum(add_m_result_32_bit),
        .cout(add_m_cout),
        .overflow(add_m_ovf),
        .a(product_high[31:0]),      
        .b(operandA_extended[31:0]),
        .sub(1'b0)
    );

  
    xor(add_m_result[32], product_high[32], operandA_extended[32], add_m_cout);           

    assign add_m_result[31:0] = add_m_result_32_bit;


    // -M operation 
    wire [31:0] sub_m_result_32_bit;
    addsub sub_m_unit(
        .sum(sub_m_result_32_bit),
        .cout(sub_m_cout),
        .overflow(sub_m_ovf),
        .a(product_high[31:0]),      
        .b(operandA_extended[31:0]),
        .sub(1'b1)
    );
    wire [32:0] operandA_extended_inverted;
    assign operandA_extended_inverted = ~operandA_extended; 
    

    // Compute 33rd bit: 
    wire sub_m_sign_sum;
    xor(sub_m_sign_sum, product_high[32], operandA_extended_inverted[32]); 
    xor(sub_m_result[32], sub_m_sign_sum, sub_m_cout);           
    assign sub_m_result[31:0] = sub_m_result_32_bit;
   



  // +2M operation
    wire [31:0] add_2m_result_32_bit;
    addsub add_2m_unit(
        .sum(add_2m_result_32_bit),
        .cout(add_2m_cout),
        .overflow(add_2m_ovf),
        .a(product_high[31:0]),      
        .b(operandA_shifted[31:0]),
        .sub(1'b0)
    );

    // Compute 33rd bit:
    wire add_2m_sign_sum;
    xor(add_2m_sign_sum, product_high[32], operandA_shifted[32]);  
    xor(add_2m_result[32], add_2m_sign_sum, add_2m_cout);          
    assign add_2m_result[31:0] = add_2m_result_32_bit;


    
    // -2M operation
    wire [31:0] sub_2m_result_32_bit;
    addsub sub_2m_unit(
        .sum(sub_2m_result_32_bit),
        .cout(sub_2m_cout),
        .overflow(sub_2m_ovf),
        .a(product_high[31:0]),      
        .b(operandA_shifted[31:0]),
        .sub(1'b1)
    );
    wire [32:0] operandA_shifted_inverted;
    assign operandA_shifted_inverted = ~operandA_shifted; 


   // Compute 33rd bit:
    wire sub_2m_sign_sum;
    xor(sub_2m_result[32], product_high[32], operandA_shifted_inverted[32],sub_2m_cout);
    assign sub_2m_result[31:0] = sub_2m_result_32_bit;

    
    wire prev_bit, prev_bit_next;

    assign prev_bit_next = start_mult ? 1'b0 : product_low[1];
                      

    dffe_ref prev_bit_reg (.q(prev_bit), .d(prev_bit_next), .clk(clock), .en(1'b1), .clr(1'b0));


    // === BOOTH ENCODING ===
    wire [2:0] booth_bits;
   assign booth_bits = product_low[2:0];

   wire [32:0] product_high_after_op;
   mux_8 #(33) booth_mux(
        .out(product_high_after_op), 
        .select(booth_bits),    
        .in0(product_high),
        .in1(add_m_result),     
        .in2(add_m_result),      
        .in3(add_2m_result),   
        .in4(sub_2m_result),  
        .in5(sub_m_result),      
        .in6(sub_m_result),     
        .in7(product_high) 
    );

    wire mult_overflow;
    wire product_sign;
    wire all_high_match_sign;
    
    assign product_sign = product_low[32];
    assign all_high_match_sign =  product_sign ? (&product_high[32:0]) : 
                                               (~(|product_high[32:0]));
    assign mult_overflow = ~all_high_match_sign;




    // ========================================
    // DIVISION LOGIC (Non-Restoring Algorithm)
    // ========================================


    wire dividend_negative, divisor_negative;
    wire [31:0] dividend_abs, divisor_abs;
    wire quotient_should_be_negative;

    assign dividend_negative = data_operandA[31];
    assign divisor_negative = data_operandB[31];
    xor(quotient_should_be_negative, dividend_negative, divisor_negative);


 
    wire dividend_abs_cout, dividend_abs_ovf;
    addsub dividend_abs_unit(
        .sum(dividend_abs),
        .cout(dividend_abs_cout),
        .overflow(dividend_abs_ovf),
        .a(32'd0),              
        .b(data_operandA),
        .sub(1'b1)              
    );

    wire [31:0] dividend_to_use;
    assign dividend_to_use = dividend_negative ? dividend_abs : data_operandA;

    wire divisor_abs_cout, divisor_abs_ovf;
    addsub divisor_abs_unit(
        .sum(divisor_abs),
        .cout(divisor_abs_cout),
        .overflow(divisor_abs_ovf),
        .a(32'd0),              
        .b(data_operandB),
        .sub(1'b1)              
    );


    wire [31:0] divisor_to_use;
    assign divisor_to_use = divisor_negative ? divisor_abs : data_operandB;

    
    
    wire [31:0] R, R_next;
    
    // Q register (Quotient)
    wire [31:0] Q, Q_next;
    
    // V register (Divisor) 
    wire [31:0] V, V_next;
    
    // MSB of R after operation
    wire R_msb;
    assign R_msb = R[31];
    
   
    wire [31:0] div_add_result, div_sub_result;
    wire div_add_cout, div_sub_cout;
    wire div_add_ovf, div_sub_ovf;

     // RQ shifted left
    wire [31:0] R_shifted;
    wire [31:0] Q_shifted;
    assign R_shifted = {R[30:0], Q[31]};  
    assign Q_shifted = {Q[30:0], 1'b0};   
    
    
    // R + V (for when MSB = 1)
    addsub div_add_unit(
        .sum(div_add_result),
        .cout(div_add_cout),
        .overflow(div_add_ovf),
        .a(R_shifted),
        .b(V[31:0]),
        .sub(1'b0)
    );

    
    // R - V (for when MSB = 0)
    addsub div_sub_unit(
        .sum(div_sub_result),
        .cout(div_sub_cout),
        .overflow(div_sub_ovf),
        .a(R_shifted),
        .b(V[31:0]),
        .sub(1'b1)
    );

    
   
    
   
    wire [31:0] R_after_op;
    assign R_after_op = R_msb ? div_add_result : div_sub_result;
    

    wire Q_new_bit;
    assign Q_new_bit = ~R_after_op[31];
    
    wire div_done;
    assign div_done = counter_lower_zero & counter[5];


    wire [31:0] R_final_corrected;
    assign R_final_corrected = (div_done & R[31]) ? div_add_result : R;
    
 
    
  
    assign V_next = start_div ? divisor_to_use : V;  
    
    assign R_next = start_div ? 32'd0 :                          
                    div_done ? R_final_corrected :                 
                    R_after_op;                                    
    
    assign Q_next = start_div ? dividend_to_use :                   
                    div_done ? Q :                                 
                    {Q_shifted[31:1], Q_new_bit};                 
    
    // Division registers
    reg32 reg_R(.clk(clock), .rst(1'b0), .en(1'b1), .d(R_next), .q(R));
    reg32 reg_Q(.clk(clock), .rst(1'b0), .en(1'b1), .d(Q_next), .q(Q));
    reg32 reg_V(.clk(clock), .rst(1'b0), .en(1'b1), .d(V_next), .q(V));
    
    // Division by zero exception
    wire divisor_is_zero;
    assign divisor_is_zero = ~(|V);  
    
    
    


    wire [31:0] mult_result, div_result;
    assign mult_result = product_low[32:1];
   


    wire [31:0] Q_negated;
    wire Q_neg_cout, Q_neg_ovf;
    addsub quotient_negate_unit(
        .sum(Q_negated),
        .cout(Q_neg_cout),
        .overflow(Q_neg_ovf),
        .a(32'd0),             
        .b(Q),
        .sub(1'b1)              
    );

    wire [31:0] Q_signed;
    assign Q_signed = quotient_should_be_negative ? Q_negated : Q;
    assign div_result = Q_signed;
    
  
    
    assign data_result = operation_is_div ? div_result : mult_result;
    
    // Exception output
    wire mult_exception;
    assign mult_exception = data_resultRDY & mult_overflow;
    assign data_exception = operation_is_mult ? mult_exception : 
                           operation_is_div ? (data_resultRDY & divisor_is_zero) : 
                           1'b0;








endmodule



module counter_mod64(input clk, input en, input clr, output[5:0] counter);
    wire t01, t012, t0123, t01234;
    and(t01, counter[0], counter[1]);
    and(t012, t01, counter[2]);
    and(t0123, t012, counter[3]);
    and(t01234, t0123, counter[4]);

    tff tff0(.T(1'b1), .clk(clk), .en(en), .clr(clr), .q(counter[0]));
    tff tff1(.T(counter[0]), .clk(clk), .en(en), .clr(clr), .q(counter[1]));
    tff tff2(.T(t01), .clk(clk), .en(en), .clr(clr), .q(counter[2]));
    tff tff3(.T(t012), .clk(clk), .en(en), .clr(clr), .q(counter[3]));
    tff tff4(.T(t0123), .clk(clk), .en(en), .clr(clr), .q(counter[4]));
    tff tff5(.T(t01234), .clk(clk), .en(en), .clr(clr), .q(counter[5]));
endmodule








