`timescale 1ns/1ps
module fp16_to_fp32_multiplier (
    input  wire        clk,        // 时钟信号
    input  wire        rst_n,      // 复位信号，低电平有效
    input  wire [15:0] fp16_a,     // 第一个FP16输入
    input  wire [15:0] fp16_b,     // 第二个FP16输入
    input  wire        valid_in,   // 输入有效信号
    output reg  [31:0] fp32_out,   // FP32输出
    output reg         valid_out   // 输出有效信号
);

// FP16和FP32的格式定义
localparam FP16_EXP_WIDTH = 5;
localparam FP16_MANT_WIDTH = 10;
localparam FP32_EXP_WIDTH = 8;
localparam FP32_MANT_WIDTH = 23;

// FP16的偏置常数
localparam FP16_BIAS = 15;
// FP32的偏置常数
localparam FP32_BIAS = 127;

// 提取FP16字段
wire sign_a = fp16_a[15];
wire sign_b = fp16_b[15];
wire [FP16_EXP_WIDTH-1:0] exp_a = fp16_a[14:10];
wire [FP16_EXP_WIDTH-1:0] exp_b = fp16_b[14:10];
wire [FP16_MANT_WIDTH-1:0] mant_a = fp16_a[9:0];
wire [FP16_MANT_WIDTH-1:0] mant_b = fp16_b[9:0];

// 分析输入值类型
wire a_is_zero = (exp_a == 0) && (mant_a == 0);
wire b_is_zero = (exp_b == 0) && (mant_b == 0);
wire output_is_zero = a_is_zero || b_is_zero;

wire a_is_inf = (exp_a == 5'b11111) && (mant_a == 0);
wire b_is_inf = (exp_b == 5'b11111) && (mant_b == 0);
wire output_is_inf = a_is_inf || b_is_inf;

wire a_is_nan = (exp_a == 5'b11111) && (mant_a != 0);
wire b_is_nan = (exp_b == 5'b11111) && (mant_b != 0);
wire output_is_nan = a_is_nan || b_is_nan;

wire a_is_denorm = (exp_a == 0) && (mant_a != 0);
wire b_is_denorm = (exp_b == 0) && (mant_b != 0);

// 输出符号位 = 输入符号位异或
wire sign_out = sign_a ^ sign_b;

// 计算前导零的函数 - 优化版本
function automatic [4:0] count_leading_zeros;
    input [21:0] value;
    reg [4:0] count;
    reg [21:0] temp;
    begin
        count = 0;
        temp = value;
        // 修正循环条件
        while (count < 21 && temp[21] == 1'b0 && temp != 0) begin
            count = count + 1;
            temp = temp << 1;
        end
        count_leading_zeros = count;
    end
endfunction

// =========================== 处理尾数 =========================
// 规格化数的隐含前导1，非规格化数则为0
wire [FP16_MANT_WIDTH:0] mant_a_with_hidden = a_is_denorm ? {1'b0, mant_a} : {1'b1, mant_a};
wire [FP16_MANT_WIDTH:0] mant_b_with_hidden = b_is_denorm ? {1'b0, mant_b} : {1'b1, mant_b};


// 执行尾数乘法，结果为22位
wire [2*(FP16_MANT_WIDTH+1)-1:0] mant_product = mant_a_with_hidden * mant_b_with_hidden;

// 改进的规格化检测
wire normalize_shift = mant_product[2*(FP16_MANT_WIDTH+1)-1];

// 表明是否需要处理非规格化数
wire need_denorm_handling = a_is_denorm || b_is_denorm;
// 计算前导零数量
wire [4:0] leading_zeros = count_leading_zeros(mant_product);


wire [21:0] shifted_mant = (mant_product == 0) ? 22'b0 :
                           (need_denorm_handling) ? ((leading_zeros >= 22) ? 22'b0 : (mant_product << leading_zeros)) :
                           (normalize_shift) ? (mant_product >> 1) :
                           mant_product;

// final_mant的计算
wire [FP32_MANT_WIDTH-1:0] final_mant = 
    (mant_product == 0) ? 23'b0 :
    need_denorm_handling ? 
        {shifted_mant[20:0], 2'b00} :     // 取高21位，补2个0
    normalize_shift ? 
        {mant_product[20:0], 2'b00} :     // 取高21位，补2个0
        {mant_product[19:0], 3'b00}; 

// ================================ 指数计算 ===========================
// 非规格化数的无偏指数为-14（等于1-偏置）
wire signed [7:0] exp_a_unbiased = a_is_denorm ? -14 : {3'b000, exp_a} - FP16_BIAS;
wire signed [7:0] exp_b_unbiased = b_is_denorm ? -14 : {3'b000, exp_b} - FP16_BIAS;

// 计算输出无偏指数，加上规格化调整
// 需要确保位宽足够容纳两个8位有符号数的和以及1位normalize_shift
wire signed [9:0] exp_out_unbiased = {{2{exp_a_unbiased[7]}}, exp_a_unbiased} + 
                                     {{2{exp_b_unbiased[7]}}, exp_b_unbiased} ;
// 修改指数调整逻辑
wire signed [9:0] exp_adjustment = 
    need_denorm_handling ? 
        (mant_product == 0) ? 10'd0 :
        -{{5{1'b0}}, leading_zeros} + {9'b0, shifted_mant[21]} :
    normalize_shift ? 10'd1 : 10'd0;

// 添加FP32偏置得到偏置指数
wire signed [9:0] exp_out_biased = exp_out_unbiased + exp_adjustment + FP32_BIAS;

// 处理指数溢出和下溢
wire exp_overflow = exp_out_biased > 254;
wire exp_underflow = exp_out_biased < 1;
 
// 确保所有位都有明确的赋值（不会有X值）
wire [FP32_MANT_WIDTH-1:0] mant_out = 
    output_is_zero   ? {FP32_MANT_WIDTH{1'b0}} :     // 零
    output_is_inf    ? {FP32_MANT_WIDTH{1'b0}} :     // 无穷大
    output_is_nan    ? {1'b1, {(FP32_MANT_WIDTH-1){1'b0}}} : // NaN
    exp_overflow     ? {FP32_MANT_WIDTH{1'b0}} :     // 溢出到无穷大
    exp_underflow    ? {FP32_MANT_WIDTH{1'b0}} :     // 下溢到零
    final_mant;                                      // 正常情况

// 最终指数值，考虑特殊情况
wire [FP32_EXP_WIDTH-1:0] exp_out = 
    output_is_zero   ? 8'd0 :                  // 零
    output_is_inf    ? 8'd255 :                // 无穷大
    output_is_nan    ? 8'd255 :                // NaN
    exp_overflow     ? 8'd255 :                // 溢出到无穷大
    exp_underflow    ? 8'd0 :                  // 下溢到零或非规格化（此处简化为零）
    exp_out_biased[7:0];                       // 正常情况

// 输出寄存
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // 复位状态
        fp32_out <= 32'd0;
        valid_out <= 1'b0;
    end else if (valid_in) begin
        // 根据IEEE 754标准构建FP32输出
        fp32_out <= {sign_out, exp_out, mant_out};
        valid_out <= 1'b1;
    end else begin
        valid_out <= 1'b0;
    end
end


endmodule 