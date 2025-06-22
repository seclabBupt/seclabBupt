module final_adder #(
    parameter WIDTH = 32
)(
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
    output wire [WIDTH-1:0] sum
);

    wire [WIDTH:0] carry;
    assign carry[0] = 1'b0;
    
    genvar i;
    generate
        for (i=0; i<WIDTH; i=i+1) begin : adder
            wire p = a[i] ^ b[i];//进位传递信号
            wire g = a[i] & b[i];//进位生成信号
            assign sum[i] = p ^ carry[i];
            assign carry[i+1] = g | (p & carry[i]);
        end
    endgenerate
endmodule