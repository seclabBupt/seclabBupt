// 将内部格式的结果打包成 FP32 格式
// 接收来自 normalizer/rounder 的信号以及顶层判断的特殊标志
`include "fp32_defines.vh"

module fp32_packer (
    // 输入来自规格化/舍入阶段 或 顶层逻辑
    input wire final_sign,
    input wire [`EXP_WIDTH-1:0] final_exponent, // normalizer 输出的指数
    input wire [`MANT_WIDTH-1:0] final_mantissa, // normalizer 输出的尾数
    input wire result_is_zero, // 最终结果是否为零 (来自 normalizer 或顶层)
    input wire result_is_inf,  // 最终结果是否为无穷大 (来自 normalizer 或顶层)
    input wire result_is_nan,  // 最终结果是否为 NaN (来自顶层判断)

    output wire [`FP32_WIDTH-1:0] fp_out // 最终 FP32 输出
);

    // 定义标准特殊值表示
    localparam FP32_QNAN     = {1'b0, {`EXP_WIDTH{1'b1}}, {1'b1, {(`MANT_WIDTH-1){1'b0}}}}; // 标准 Quiet NaN (符号位通常为0)
    localparam FP32_POS_INF  = {1'b0, {`EXP_WIDTH{1'b1}}, {`MANT_WIDTH{1'b0}}};
    localparam FP32_NEG_INF  = {1'b1, {`EXP_WIDTH{1'b1}}, {`MANT_WIDTH{1'b0}}};
    localparam FP32_POS_ZERO = {1'b0, {(`EXP_WIDTH + `MANT_WIDTH){1'b0}}};
    localparam FP32_NEG_ZERO = {1'b1, {(`EXP_WIDTH + `MANT_WIDTH){1'b0}}};

    // 根据特殊情况标志选择最终输出
    assign fp_out = result_is_nan ? FP32_QNAN :
                    result_is_inf ? (final_sign ? FP32_NEG_INF : FP32_POS_INF) :
                    result_is_zero ? (final_sign ? FP32_NEG_ZERO : FP32_POS_ZERO) :
                    {final_sign, final_exponent, final_mantissa}; // Normal number

endmodule