// 修正后的完整规格化舍入模块
`include "fp32_defines.vh"

module fp32_normalizer_rounder #(
    parameter IN_WIDTH = `FULL_SUM_WIDTH + 1 // 
) (
    input wire [IN_WIDTH-1:0] mant_raw,       // 原始尾数结果（绝对值）32位
    input wire [`EXP_WIDTH-1:0] exp_in,       // 输入指数（最大指数）8位
    input wire sign_in,                       // 输入符号 1位
    input wire denorm_to_zero_en,             // 非规格化数为零开关

    output wire [`FP32_WIDTH-1:0] fp_out,     // 最终FP32结果 32位
    output reg overflow,                      // 上溢标志
    output reg underflow,                     // 下溢标志
    output reg zero_out                       // 精确零标志
);

// 输出连接
reg [`FP32_WIDTH-1:0] fp_out_reg;
assign fp_out = fp_out_reg;

// 参数定义
localparam TARGET_POS       = `MANT_WIDTH + 1 ;    //24位
localparam NORM_MANT_WIDTH  = TARGET_POS + `GUARD_BITS; // 27

// 内部信号声明
reg [`EXP_WIDTH:0] adjusted_exp;              // 调整后的指数（带符号）9位
reg [NORM_MANT_WIDTH-1:0] normalized_mant;    // 规格化后的尾数27位
integer current_msb_pos;                      // 原始尾数最高有效位位置
integer logical_shift;                        // 移位量（正=右移，负=左移）
reg [IN_WIDTH+`GUARD_BITS-1:0] extended_mant; // 扩展尾数（含保护位）
reg sticky;                                   // 粘滞位

// 舍入相关信号
reg [`MANT_WIDTH-1:0] rounded_mant;           // 舍入后的尾数23位
reg [`EXP_WIDTH:0] final_exp;                 // 最终指数9位
reg carry_out_rounding;                       // 舍入进位标志
reg is_denorm_input;                          // 判断输入是否为非规格化数的标志

// 主规格化逻辑
reg g, r, s, lsb;
reg round_up;
reg [NORM_MANT_WIDTH-1:0] denorm_mant;
integer denorm_shift;
integer k;
reg [IN_WIDTH-1:0] temp_mant_for_small_denorm_shifted; // Added for small denormalized values path

always @(*) begin // 主规格化逻辑
    // 初始化默认值
    zero_out = 1'b0;
    overflow = 1'b0;
    underflow = 1'b0;
    adjusted_exp = {(`EXP_WIDTH+1){1'b0}};//9位
    normalized_mant = {NORM_MANT_WIDTH{1'b0}};
    current_msb_pos = -1;
    sticky = 1'b0;
    // 判断输入是否为非规格化数：指数为0且尾数不为0
    is_denorm_input = (exp_in == 0 && mant_raw != 0);
    extended_mant = {mant_raw, {`GUARD_BITS{1'b0}}}; 

    
    // 零检测
    if (mant_raw == 0) begin
        zero_out = 1'b1;
    end else begin
        // 查找最高有效位（MSB）
        current_msb_pos = IN_WIDTH - 1;
        while (current_msb_pos >= 0 && !mant_raw[current_msb_pos]) begin
            current_msb_pos = current_msb_pos - 1;
        end

        // 检查完全为0的特殊情况
        if (current_msb_pos < 0) begin
            zero_out = 1'b1;
        end else begin
            logical_shift = current_msb_pos - (TARGET_POS - 1); 
            
            // 执行移位操作
            if (logical_shift > 0) begin // 右移
                // 保护位处理
                sticky = 1'b0;
                for (k = 0; k < logical_shift; k = k + 1) begin
                    if (k < IN_WIDTH + `GUARD_BITS) begin
                        sticky = sticky | extended_mant[k];
                    end
                end
                normalized_mant = extended_mant >> logical_shift;//27位
                normalized_mant[0] = normalized_mant[0] | sticky;
            end else if (logical_shift < 0) begin // 左移
                normalized_mant = extended_mant << (-logical_shift);
            end else begin
                normalized_mant = extended_mant;
            end

            // 区分规格化和非规格化数的不同指数调整方式
            if (is_denorm_input) begin
                // 对于非规格化数输入，指数保持为0或根据移位量调整
                if (current_msb_pos < TARGET_POS - 1) begin
                    adjusted_exp = 0; // 结果依然是非规格化数
                end else begin
                    adjusted_exp = 1 + logical_shift - `GUARD_BITS; // 非规格化数变为规格化数
                end
            end else begin
                // 对于规格化数输入，正常调整指数
                adjusted_exp = exp_in + logical_shift - `GUARD_BITS;
            end
        end
    end
end

// 舍入逻辑（Round to nearest even）四舍六入五取偶
always @(*) begin
    rounded_mant = normalized_mant[NORM_MANT_WIDTH-1:`GUARD_BITS];
    final_exp = adjusted_exp;
    
    carry_out_rounding = 1'b0;

    if (!zero_out) begin
        g = normalized_mant[`GUARD_BITS-1];
        r = normalized_mant[`GUARD_BITS-2];
        s = |normalized_mant[`GUARD_BITS-3:0];
        lsb = rounded_mant[0];

        // 舍入判断
        round_up = (g & (r | s)) | (g & ~r & ~s & lsb);

        if (round_up) begin
            {carry_out_rounding, rounded_mant} = rounded_mant + 1;
            
            if (carry_out_rounding) begin
                rounded_mant = {1'b1, {`MANT_WIDTH-1{1'b0}}};
                final_exp = final_exp + 1;
            end
        end
    end
end

// 最终结果包装
always @(*) begin
    if (zero_out) begin
        fp_out_reg = {sign_in, {`EXP_WIDTH{1'b0}}, {`MANT_WIDTH{1'b0}}};
        underflow = 1'b0;
        overflow = 1'b0;

    
    end else begin
        // 上溢检查
        if (final_exp >= (2**`EXP_WIDTH-1)) begin
            fp_out_reg = {sign_in, {`EXP_WIDTH{1'b1}}, {`MANT_WIDTH{1'b0}}};
            overflow = 1'b1;
        end 
        // 下溢处理
        else if (final_exp <= 0) begin
            if (is_denorm_input && final_exp == 0) begin
                // 输入为非规格化数且结果仍为非规格化数的情况
                if (denorm_to_zero_en) begin
                    // 开关打开：非规格化数相加得到非规格化数时输出0
                    fp_out_reg = {sign_in, {`EXP_WIDTH{1'b0}}, {`MANT_WIDTH{1'b0}}};
                    zero_out = 1'b1;
                    underflow = 1'b0;
                end else begin
                    // 开关关闭：允许输出非规格化数
                    temp_mant_for_small_denorm_shifted = mant_raw >> 3; // 保护位
                    fp_out_reg = {sign_in, 8'h00, temp_mant_for_small_denorm_shifted[`MANT_WIDTH-1:0]};
                    underflow = 1'b1;
                end
            end
            else begin 
                // 其他下溢情况（规格化数输入但结果为非规格化数）
                if (denorm_to_zero_en && final_exp < 0) begin
                    // 开关打开且结果严重下溢时输出0
                    fp_out_reg = {sign_in, {`EXP_WIDTH{1'b0}}, {`MANT_WIDTH{1'b0}}};
                    zero_out = 1'b1;
                    underflow = 1'b0;
                end else begin
                    // 正常处理非规格化数输出
                    denorm_shift = 1 - final_exp;
                    denorm_mant = normalized_mant;
                    
                    // ==== 动态位选择为循环 ====
                    sticky = 1'b0;
                    for (k = 0; k < denorm_shift; k = k + 1) begin
                        if (k < NORM_MANT_WIDTH) begin // 防止索引越界
                            sticky = sticky | denorm_mant[k];
                        end
                    end
                    
                    denorm_mant = denorm_mant >> denorm_shift;
                    denorm_mant[0] = denorm_mant[0] | sticky;
                    
                    fp_out_reg = {sign_in, {`EXP_WIDTH{1'b0}}, denorm_mant[NORM_MANT_WIDTH-2:`GUARD_BITS]};
                    underflow = 1'b1;
                end
            end
        end 
        // 正常数
        else begin
            fp_out_reg = {sign_in, final_exp[`EXP_WIDTH-1:0], rounded_mant};
        end
    end
end

endmodule