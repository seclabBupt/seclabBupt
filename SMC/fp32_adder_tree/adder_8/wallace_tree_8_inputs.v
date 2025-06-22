`include "fp32_defines.vh"

module wallace_tree_8_inputs #(
    parameter NUM_INPUTS = 8,  
    parameter WIDTH = `FULL_SUM_WIDTH  // 31
) (
    input  wire [NUM_INPUTS*WIDTH-1:0] data_in,
    output wire [WIDTH:0] final_result
);

    // 输入展开为数组
    wire [WIDTH-1:0] inputs [0:NUM_INPUTS-1];
    genvar i;
    generate
        for (i = 0; i < NUM_INPUTS; i = i + 1) begin : unpack_inputs
            assign inputs[i] = data_in[(i+1)*WIDTH-1 : i*WIDTH];
        end
    endgenerate

    // --- 第1层压缩：8 -> 6 ---
    wire [WIDTH-1:0] layer1 [0:5];
    genvar b;
    generate
        for (b=0; b<WIDTH; b=b+1) begin : layer1_compress
            // 获取当前b位的8个输入
            wire [7:0] bs = {
                inputs[7][b], inputs[6][b],
                inputs[5][b], inputs[4][b],
                inputs[3][b], inputs[2][b],
                inputs[1][b], inputs[0][b]
            };

            // 全加器1处理位0-2
            wire fa1_sum, fa1_cout;
            full_adder fa1(.a(bs[0]), .b(bs[1]), .cin(bs[2]), .sum(fa1_sum), .cout(fa1_cout));

            // 全加器2处理位3-5 
            wire fa2_sum, fa2_cout;
            full_adder fa2(.a(bs[3]), .b(bs[4]), .cin(bs[5]), .sum(fa2_sum), .cout(fa2_cout));

            assign layer1[0][b] = fa1_sum;    // Sum1
            assign layer1[1][b] = fa2_sum;    // Sum2
            assign layer1[2][b] = bs[6];      // 直通位1
            assign layer1[3][b] = bs[7];      // 直通位2
            assign layer1[4][b] = fa1_cout;   // Carry1（下一位）
            assign layer1[5][b] = fa2_cout;   // Carry2
        end
    endgenerate

    // --- 第2层压缩：6 -> 4---
    wire [WIDTH-1:0] layer2 [0:3];
    generate
        for (b=0; b<WIDTH; b=b+1) begin : layer2_compress
            // 处理进位偏移
            wire [5:0] bs = {
                (b>0) ? layer1[4][b-1] : 1'b0,  // Carry1偏移到当前b
                (b>0) ? layer1[5][b-1] : 1'b0,  // Carry2偏移
                layer1[0][b], 
                layer1[1][b],
                layer1[2][b],
                layer1[3][b]
            };

            // 全加器处理前3位
            wire fa1_sum, fa1_cout;
            full_adder fa1(.a(bs[0]), .b(bs[1]), .cin(bs[2]), .sum(fa1_sum), .cout(fa1_cout));

            // 全加器处理后3位
            wire fa2_sum, fa2_cout;
            full_adder fa2(.a(bs[3]), .b(bs[4]), .cin(bs[5]), .sum(fa2_sum), .cout(fa2_cout));

            assign layer2[0][b] = fa1_sum;    // Sum1
            assign layer2[1][b] = fa2_sum;    // Sum2
            assign layer2[2][b] = fa1_cout;   // Carry1
            assign layer2[3][b] = fa2_cout;   // Carry2
        end
    endgenerate

    // --- 第3层压缩：4 -> 3 ---
    wire [WIDTH-1:0] layer3 [0:2];
    generate
        for (b=0; b<WIDTH; b=b+1) begin : layer3_compress
            // 处理进位偏移
            wire [3:0] bs = {
                (b>0) ? layer2[2][b-1] : 1'b0,  // Carry1偏移
                (b>0) ? layer2[3][b-1] : 1'b0,  // Carry2偏移
                layer2[0][b],
                layer2[1][b]
            };

            wire fa_sum, fa_cout;
            full_adder fa(.a(bs[0]), .b(bs[1]), .cin(bs[2]), .sum(fa_sum), .cout(fa_cout));

            assign layer3[0][b] = fa_sum;     // Sum
            assign layer3[1][b] = bs[3];     // 直通位
            assign layer3[2][b] = fa_cout;    // Carry
        end
    endgenerate

    // --- 第4层压缩：3 -> 2---
    wire [WIDTH-1:0] sum_out, carry_out;
    generate
        for (b=0; b<WIDTH; b=b+1) begin : layer4_compress
            wire [2:0] bs = {
                (b>0) ? layer3[2][b-1] : 1'b0,  // Carry偏移
                layer3[0][b],
                layer3[1][b]
            };

            wire fa_sum, fa_cout;
            full_adder fa(.a(bs[0]), .b(bs[1]), .cin(bs[2]), .sum(fa_sum), .cout(fa_cout));

            assign sum_out[b] = fa_sum;
            assign carry_out[b] = fa_cout;
        end
    endgenerate

    // --- 最终加法器---
    // 确保保留最低有效位的数据，防止超小的非规格化数丢失
    // 扩展到足够的位宽以避免溢出
    wire [WIDTH:0] sum_ext = {1'b0, sum_out};
    wire [WIDTH:0] carry_ext = {carry_out, 1'b0};
    
    // 使用最终加法器累加结果
    final_adder #(
        .WIDTH(WIDTH+1) // 支持进位
    ) final_adder (
        .a(sum_ext),
        .b(carry_ext),
        .sum(final_result)
    );

endmodule
