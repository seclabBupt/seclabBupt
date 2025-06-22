// 将 FP32 输入分解为符号、指数和尾数
`include "fp32_defines.vh"

module fp32_unpacker (
    input wire [`FP32_WIDTH-1:0] fp_in,       // FP32 输入

    output wire sign,                         // 符号位
    output wire [`EXP_WIDTH-1:0] exponent,    // 指数位 (偏移后)
    output wire [`MANT_WIDTH-1:0] mantissa,   // 尾数位
    output wire is_zero,                      // 输入是否为 0
    output wire is_inf,                       // 输入是否为无穷大
    output wire is_nan,                       // 输入是否为 NaN
    output wire is_subnormal,                  // 输入是否为子规格化数
    output wire [4:0] lz_count                  // 非规格化数前导零计数
);

    // 直接分解
    assign sign = fp_in[`FP32_WIDTH-1];
    assign exponent = fp_in[`FP32_WIDTH-2 : `MANT_WIDTH];
    assign mantissa = fp_in[`MANT_WIDTH-1 : 0];

    // 特殊情况检测
    wire exp_all_zeros = (exponent == {`EXP_WIDTH{1'b0}});
    wire exp_all_ones = (exponent == {`EXP_WIDTH{1'b1}});
    wire mant_all_zeros = (mantissa == {`MANT_WIDTH{1'b0}});

    // 是否为零 (包括 +0 和 -0)
    assign is_zero = exp_all_zeros && mant_all_zeros;
    // 是否为无穷大 (指数全1，尾数全0)
    assign is_inf = exp_all_ones && mant_all_zeros;
    // 是否为 NaN (指数全1，尾数非0)
    assign is_nan = exp_all_ones && !mant_all_zeros;
    // 是否为非规格化数 (指数全0，尾数非0)
    assign is_subnormal = exp_all_zeros && !mant_all_zeros;


endmodule
