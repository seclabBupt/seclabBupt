`include "fp32_defines.vh"


module fp32_adder_tree_8_inputs (
    input wire [8*`FP32_WIDTH-1:0] fp_inputs_flat, // 8 个 FP32 输入
    input wire denorm_to_zero_en,                  // 非规格化数开关：1=非规格化数结果输出为0，0=允许非规格化数输出

    output wire [`FP32_WIDTH-1:0] fp_sum,          // FP32 和
    output wire is_nan_out,              
    output wire is_inf_out               
);

    localparam NUM_INPUTS = 8;
    genvar i;

    // --- 1. Unpack ---
    wire [`FP32_WIDTH-1:0] current_fp_input [0:NUM_INPUTS-1];
    wire [`EXP_WIDTH-1:0] temp_exponent [0:NUM_INPUTS-1];
    wire [`MANT_WIDTH-1:0] temp_mantissa [0:NUM_INPUTS-1];
    wire [NUM_INPUTS-1:0] signs;
    wire [NUM_INPUTS*`EXP_WIDTH-1:0] exponents_flat;
    wire [NUM_INPUTS*`MANT_WIDTH-1:0] mantissas_flat;
    wire [NUM_INPUTS-1:0] is_zeros;
    wire [NUM_INPUTS-1:0] is_infs;
    wire [NUM_INPUTS-1:0] is_nans;

    // --- 判断是否有任何有效正输入 ---
    wire any_valid_positive = |(~is_nans & ~is_infs & ~signs);
    wire no_positive_contribution_present = ~any_valid_positive;

    generate
        for (i = 0; i < NUM_INPUTS; i = i + 1) begin : unpack_gen
            assign current_fp_input[i] = fp_inputs_flat[(i+1)*`FP32_WIDTH-1 : i*`FP32_WIDTH];

            fp32_unpacker unpacker_inst (
                .fp_in(current_fp_input[i]),
                .sign(signs[i]),
                .exponent(temp_exponent[i]),
                .mantissa(temp_mantissa[i]),
                .is_zero(is_zeros[i]),
                .is_inf(is_infs[i]),
                .is_nan(is_nans[i])
            );

            assign exponents_flat[(i+1)*`EXP_WIDTH-1 : i*`EXP_WIDTH] = temp_exponent[i];
            assign mantissas_flat[(i+1)*`MANT_WIDTH-1 : i*`MANT_WIDTH] = temp_mantissa[i];
        end
    endgenerate


    // --- 2. 处理输入特殊值 ---
    wire any_nan_in = |is_nans;
    wire [NUM_INPUTS-1:0] is_pos_inf = is_infs & ~signs;
    wire [NUM_INPUTS-1:0] is_neg_inf = is_infs & signs;
    wire any_pos_inf = |is_pos_inf;
    wire any_neg_inf = |is_neg_inf;

    wire result_is_nan_condition = any_nan_in || (any_pos_inf && any_neg_inf);
    wire result_is_inf_condition = !result_is_nan_condition && (any_pos_inf ^ any_neg_inf);
    wire result_inf_sign = any_neg_inf;

    // --- 3. Align ---
    wire [`EXP_WIDTH-1:0] max_exponent;
    wire [NUM_INPUTS*`ALIGNED_MANT_WIDTH-1:0] aligned_mantissas_flat;
    wire [NUM_INPUTS-1:0] effective_signs;

    fp32_aligner #(
        .NUM_INPUTS(NUM_INPUTS)
    ) aligner_inst (
        .signs(signs),
        .exponents_flat(exponents_flat),
        .mantissas_flat(mantissas_flat),
        .is_zeros(is_zeros),
        .is_infs(is_infs),
        .is_nans(is_nans),
        .max_exponent(max_exponent),
        .aligned_mantissas_flat(aligned_mantissas_flat),
        .effective_signs(effective_signs)
    );

    // --- 4. 准备华莱士树输入 ---
    wire [`FULL_SUM_WIDTH-1:0] pos_mants [0:NUM_INPUTS-1];
    wire [`FULL_SUM_WIDTH-1:0] neg_mants [0:NUM_INPUTS-1];
    genvar j;
    generate
        for (j = 0; j < NUM_INPUTS; j = j + 1) begin : pos_neg_group
            wire [`ALIGNED_MANT_WIDTH-1:0] this_aligned_mantissa = aligned_mantissas_flat[(j+1)*`ALIGNED_MANT_WIDTH-1 : j*`ALIGNED_MANT_WIDTH];
            wire [`FULL_SUM_WIDTH-1:0] mantissa_ext = {1'b0, this_aligned_mantissa};
            assign pos_mants[j] = (effective_signs[j] == 1'b0) ? mantissa_ext : {`FULL_SUM_WIDTH{1'b0}};
            assign neg_mants[j] = (effective_signs[j] == 1'b1) ? mantissa_ext : {`FULL_SUM_WIDTH{1'b0}};
        end
    endgenerate

    // --- 准备华莱士树输入数据 ---
    wire [NUM_INPUTS*`FULL_SUM_WIDTH-1:0] pos_mants_flat;
    wire [NUM_INPUTS*`FULL_SUM_WIDTH-1:0] neg_mants_flat;

    genvar k;
    generate
        for (k = 0; k < NUM_INPUTS; k = k + 1) begin : flatten_mants
            assign pos_mants_flat[(k+1)*`FULL_SUM_WIDTH-1 : k*`FULL_SUM_WIDTH] = pos_mants[k];
            assign neg_mants_flat[(k+1)*`FULL_SUM_WIDTH-1 : k*`FULL_SUM_WIDTH] = neg_mants[k];
        end
    endgenerate

    // --- 使用华莱士树累加正负尾数 ---
    wire [`FULL_SUM_WIDTH:0] pos_sum;
    wire [`FULL_SUM_WIDTH:0] neg_sum;

    wallace_tree_8_inputs #(
        .NUM_INPUTS(NUM_INPUTS),
        .WIDTH(`FULL_SUM_WIDTH)
    ) wallace_pos_sum_inst (
        .data_in(pos_mants_flat),
        .final_result(pos_sum)
    );

    wallace_tree_8_inputs #(
        .NUM_INPUTS(NUM_INPUTS),
        .WIDTH(`FULL_SUM_WIDTH)
    ) wallace_neg_sum_inst (
        .data_in(neg_mants_flat),
        .final_result(neg_sum)
    );

    // --- 结果做差 ---
    wire signed [`FULL_SUM_WIDTH:0] wallace_final_result = $signed(pos_sum) - $signed(neg_sum);


    // --- 7. +0 -0 问题处理---
    // 组合逻辑：计算结果符号
    wire result_sign = (wallace_final_result == 0)
        ? no_positive_contribution_present
        : (wallace_final_result < 0);
    wire [`FULL_SUM_WIDTH:0] result_mant_raw = result_sign ? -wallace_final_result : wallace_final_result;

    // --- 8. 规格化与舍入 ---
    wire [`FP32_WIDTH-1:0] normalized_fp_out_internal;
    wire norm_overflow;
    wire norm_underflow;
    wire norm_zero_out;

    fp32_normalizer_rounder #(
        .IN_WIDTH(`FULL_SUM_WIDTH + 1) // = 32
    ) normalizer_rounder_inst (
        .mant_raw(result_mant_raw),   
        .exp_in(max_exponent),
        .sign_in(result_sign),
        .denorm_to_zero_en(denorm_to_zero_en),
        .fp_out(normalized_fp_out_internal),
        .overflow(norm_overflow),
        .underflow(norm_underflow),
        .zero_out(norm_zero_out)
    );

    // --- 9. 最终结果打包与选择 ---
    wire final_calc_sign = normalized_fp_out_internal[`FP32_WIDTH-1];
    wire [`EXP_WIDTH-1:0] final_calc_exp = normalized_fp_out_internal[`FP32_WIDTH-2 : `MANT_WIDTH];
    wire [`MANT_WIDTH-1:0] final_calc_mant = normalized_fp_out_internal[`MANT_WIDTH-1 : 0];
    
    // 处理规格化结果的特殊值
    assign is_nan_out = result_is_nan_condition;
    assign is_inf_out = !is_nan_out && (result_is_inf_condition || norm_overflow);
    wire is_zero_out = !is_nan_out && !is_inf_out && norm_zero_out;

    wire final_special_sign = is_inf_out ? (result_is_inf_condition ? result_inf_sign : result_sign)
                             : is_zero_out ? result_sign
                             : final_calc_sign;

    fp32_packer packer_inst (
        .final_sign(final_special_sign),
        .final_exponent(final_calc_exp),  
        .final_mantissa(final_calc_mant),
        .result_is_zero(is_zero_out),
        .result_is_inf(is_inf_out),
        .result_is_nan(is_nan_out),
        .fp_out(fp_sum)
    );

endmodule
