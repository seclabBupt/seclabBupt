`timescale 1ns/1ps
`include "fp32_defines.vh"

module tb_fp32_adder_tree_8_inputs_softfloat;

// 参数定义
parameter CLK_PERIOD = 10;
localparam NUM_INPUTS = 8;
localparam FP32_WIDTH = `FP32_WIDTH;
localparam EXP_WIDTH = `EXP_WIDTH;
localparam MANT_WIDTH = `MANT_WIDTH;
localparam BIAS = `BIAS;

// 输入信号
reg clk;
reg rst_n;
reg [NUM_INPUTS*FP32_WIDTH-1:0] fp_inputs_flat;
reg denorm_to_zero_en;

// 输出信号
wire [FP32_WIDTH-1:0] fp_sum;
wire is_nan_out;
wire is_inf_out;

// DPI-C 导入
import "DPI-C" function int unsigned fp32_add_8_softfloat(
    input int unsigned input0, input int unsigned input1, 
    input int unsigned input2, input int unsigned input3,
    input int unsigned input4, input int unsigned input5, 
    input int unsigned input6, input int unsigned input7);
import "DPI-C" function int unsigned fp32_add_2_softfloat(
    input int unsigned input0, input int unsigned input1);
import "DPI-C" function void set_softfloat_rounding_mode(input int unsigned mode);
import "DPI-C" function void clear_softfloat_flags();
import "DPI-C" function int unsigned get_softfloat_flags();

// SoftFloat 舍入模式
localparam SOFTFLOAT_ROUND_NEAR_EVEN = 0;
localparam SOFTFLOAT_ROUND_MINMAG    = 1;
localparam SOFTFLOAT_ROUND_MIN       = 2;
localparam SOFTFLOAT_ROUND_MAX       = 3;
localparam SOFTFLOAT_ROUND_NEAR_MAXMAG = 4;


// 比较结果
reg match_found;
reg is_expected_nan, is_fp_sum_nan;
reg is_inexact;
reg [31:0] expected_plus_one, expected_minus_one;

// 文件句柄
integer sim_log;
integer pass_count;
integer fail_count;

// 实例化被测模块
fp32_adder_tree_8_inputs dut (
    .fp_inputs_flat(fp_inputs_flat),
    .denorm_to_zero_en(denorm_to_zero_en),
    .fp_sum(fp_sum),
    .is_nan_out(is_nan_out),
    .is_inf_out(is_inf_out)
);

// 时钟生成
initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk = ~clk;
end

// 打开日志文件并初始化
initial begin
    sim_log = $fopen("sim_softfloat.log", "w");
    if (!sim_log) begin
        $display("Error: Could not open sim_softfloat.log");
        $finish;
    end
    $fdisplay(sim_log, "FP32 Adder Tree SoftFloat Simulation started at time %t", $time);
    pass_count = 0;
    fail_count = 0;

    // 设置 SoftFloat 舍入模式
    set_softfloat_rounding_mode(SOFTFLOAT_ROUND_NEAR_EVEN);
end

// 测试用例数据
reg [FP32_WIDTH-1:0] test_inputs [0:51][0:NUM_INPUTS-1]; // 52个测试用例，每个8个输入
integer i, j;
integer expected_fp32_from_softfloat;
integer softfloat_flags;

initial begin
    // 初始化测试用例
    
    // 测试用例 0: 基本正数加法
    test_inputs[0][0] = 32'h3f800000; // 1.0
    test_inputs[0][1] = 32'h40000000; // 2.0
    test_inputs[0][2] = 32'h40400000; // 3.0
    test_inputs[0][3] = 32'h40800000; // 4.0
    test_inputs[0][4] = 32'h40a00000; // 5.0
    test_inputs[0][5] = 32'h40c00000; // 6.0
    test_inputs[0][6] = 32'h40e00000; // 7.0
    test_inputs[0][7] = 32'h41000000; // 8.0 (总和应为36.0)

    // 测试用例 1: 正负数混合
    test_inputs[1][0] = 32'h41200000; // 10.0
    test_inputs[1][1] = 32'hc1200000; // -10.0
    test_inputs[1][2] = 32'h40a00000; // 5.0
    test_inputs[1][3] = 32'hc0a00000; // -5.0
    test_inputs[1][4] = 32'h3f800000; // 1.0
    test_inputs[1][5] = 32'hbf800000; // -1.0
    test_inputs[1][6] = 32'h40000000; // 2.0
    test_inputs[1][7] = 32'hc0000000; // -2.0 (总和应为0.0)

    // 测试用例 2: 全零
    for (j = 0; j < NUM_INPUTS; j = j + 1) begin
        test_inputs[2][j] = 32'h00000000; // +0.0
    end

    // 测试用例 3: 负零
    for (j = 0; j < NUM_INPUTS; j = j + 1) begin
        test_inputs[3][j] = 32'h80000000; // -0.0
    end

    // 测试用例 4: 正负零混合
    test_inputs[4][0] = 32'h00000000; // +0.0
    test_inputs[4][1] = 32'h80000000; // -0.0
    test_inputs[4][2] = 32'h00000000; // +0.0
    test_inputs[4][3] = 32'h80000000; // -0.0
    test_inputs[4][4] = 32'h00000000; // +0.0
    test_inputs[4][5] = 32'h80000000; // -0.0
    test_inputs[4][6] = 32'h00000000; // +0.0
    test_inputs[4][7] = 32'h80000000; // -0.0

    // 测试用例 5: 无穷大
    test_inputs[5][0] = 32'h7f800000; // +Inf
    test_inputs[5][1] = 32'h3f800000; // 1.0
    test_inputs[5][2] = 32'h40000000; // 2.0
    test_inputs[5][3] = 32'h40400000; // 3.0
    test_inputs[5][4] = 32'h40800000; // 4.0
    test_inputs[5][5] = 32'h40a00000; // 5.0
    test_inputs[5][6] = 32'h40c00000; // 6.0
    test_inputs[5][7] = 32'h40e00000; // 7.0 (总和应为+Inf)

    // 测试用例 6: 负无穷大
    test_inputs[6][0] = 32'hff800000; // -Inf
    test_inputs[6][1] = 32'h3f800000; // 1.0
    test_inputs[6][2] = 32'h40000000; // 2.0
    test_inputs[6][3] = 32'h40400000; // 3.0
    test_inputs[6][4] = 32'h40800000; // 4.0
    test_inputs[6][5] = 32'h40a00000; // 5.0
    test_inputs[6][6] = 32'h40c00000; // 6.0
    test_inputs[6][7] = 32'h40e00000; // 7.0 (总和应为-Inf)

    // 测试用例 7: NaN
    test_inputs[7][0] = 32'h7fc00000; // qNaN
    test_inputs[7][1] = 32'h3f800000; // 1.0
    test_inputs[7][2] = 32'h40000000; // 2.0
    test_inputs[7][3] = 32'h40400000; // 3.0
    test_inputs[7][4] = 32'h40800000; // 4.0
    test_inputs[7][5] = 32'h40a00000; // 5.0
    test_inputs[7][6] = 32'h40c00000; // 6.0
    test_inputs[7][7] = 32'h40e00000; // 7.0 (总和应为NaN)

    // 测试用例 8: 最小规格化数
    for (j = 0; j < NUM_INPUTS; j = j + 1) begin
        test_inputs[8][j] = 32'h00800000; // 最小正规格化数
    end

    // 测试用例 9: 最大规格化数
    for (j = 0; j < NUM_INPUTS; j = j + 1) begin
        test_inputs[9][j] = 32'h7f7fffff; // 最大正规格化数
    end

    // 测试用例 10: 非规格化数
    for (j = 0; j < NUM_INPUTS; j = j + 1) begin
        test_inputs[10][j] = 32'h00000001; // 最小正非规格化数
    end

    // 测试用例 11: 混合规格化和非规格化数
    test_inputs[11][0] = 32'h00800000; // 最小正规格化数
    test_inputs[11][1] = 32'h00000001; // 最小正非规格化数
    test_inputs[11][2] = 32'h007fffff; // 最大正非规格化数
    test_inputs[11][3] = 32'h3f800000; // 1.0
    test_inputs[11][4] = 32'h00000000; // +0.0
    test_inputs[11][5] = 32'h80000000; // -0.0
    test_inputs[11][6] = 32'h40000000; // 2.0
    test_inputs[11][7] = 32'h40400000; // 3.0

    // 测试用例 12: 很小的数（可能发生下溢）
    for (j = 0; j < NUM_INPUTS; j = j + 1) begin
        test_inputs[12][j] = 32'h00000100; // 小的非规格化数
    end

    // 测试用例 13: 很大的数（可能发生上溢）
    for (j = 0; j < NUM_INPUTS; j = j + 1) begin
        test_inputs[13][j] = 32'h7f000000; // 很大的数
    end

    // 测试用例 14: 精度测试
    test_inputs[14][0] = 32'h3f800000; // 1.0
    test_inputs[14][1] = 32'h33800000; // 2^-24 (非常小的数)
    test_inputs[14][2] = 32'h34000000; // 2^-23
    test_inputs[14][3] = 32'h34800000; // 2^-22
    test_inputs[14][4] = 32'h35000000; // 2^-21
    test_inputs[14][5] = 32'h35800000; // 2^-20
    test_inputs[14][6] = 32'h36000000; // 2^-19
    test_inputs[14][7] = 32'h36800000; // 2^-18
    
    
    // 测试用例 15: 简单加法 (1.0 + 2.5)
    test_inputs[15][0] = 32'h3f800000; // 1.0
    test_inputs[15][1] = 32'h40200000; // 2.5
    for (j = 2; j < NUM_INPUTS; j = j + 1) begin
        test_inputs[15][j] = 32'h00000000; // 0.0
    end
    
    // 测试用例 16: 简单减法 (4.0 - 3.75)
    test_inputs[16][0] = 32'h40800000; // 4.0
    test_inputs[16][1] = 32'hc0700000; // -3.75
    for (j = 2; j < NUM_INPUTS; j = j + 1) begin
        test_inputs[16][j] = 32'h00000000; // 0.0
    end
    
    // 测试用例 17: 负数与正数相加 (-1.5 + 2.25)
    test_inputs[17][0] = 32'hbfc00000; // -1.5
    test_inputs[17][1] = 32'h40100000; // 2.25
    for (j = 2; j < NUM_INPUTS; j = j + 1) begin
        test_inputs[17][j] = 32'h00000000; // 0.0
    end
    
    // 测试用例 18: 多个正数相加 (0.5+1.5+2.0+3.0)
    test_inputs[18][0] = 32'h3f000000; // 0.5
    test_inputs[18][1] = 32'h3fc00000; // 1.5
    test_inputs[18][2] = 32'h40000000; // 2.0
    test_inputs[18][3] = 32'h40400000; // 3.0
    for (j = 4; j < NUM_INPUTS; j = j + 1) begin
        test_inputs[18][j] = 32'h00000000; // 0.0
    end
    
    // 测试用例 19: 多个负数相加 (-1-2-3-4)
    test_inputs[19][0] = 32'hbf800000; // -1.0
    test_inputs[19][1] = 32'hc0000000; // -2.0
    test_inputs[19][2] = 32'hc0400000; // -3.0
    test_inputs[19][3] = 32'hc0800000; // -4.0
    for (j = 4; j < NUM_INPUTS; j = j + 1) begin
        test_inputs[19][j] = 32'h00000000; // 0.0
    end
    
    // 测试用例 20: 正负数抵消 (1.25-1.25+2.5-2.5)
    test_inputs[20][0] = 32'h3fa00000; // 1.25
    test_inputs[20][1] = 32'hbfa00000; // -1.25
    test_inputs[20][2] = 32'h40200000; // 2.5
    test_inputs[20][3] = 32'hc0200000; // -2.5
    for (j = 4; j < NUM_INPUTS; j = j + 1) begin
        test_inputs[20][j] = 32'h00000000; // 0.0
    end
    
    // 测试用例 21: 基本的 8 输入求和 (1+2+...+8)
    test_inputs[21][0] = 32'h3f800000; // 1.0
    test_inputs[21][1] = 32'h40000000; // 2.0
    test_inputs[21][2] = 32'h40400000; // 3.0
    test_inputs[21][3] = 32'h40800000; // 4.0
    test_inputs[21][4] = 32'h40a00000; // 5.0
    test_inputs[21][5] = 32'h40c00000; // 6.0
    test_inputs[21][6] = 32'h40e00000; // 7.0
    test_inputs[21][7] = 32'h41000000; // 8.0
    
    // 测试用例 22: 输入顺序颠倒
    test_inputs[22][0] = 32'h41000000; // 8.0
    test_inputs[22][1] = 32'h40e00000; // 7.0
    test_inputs[22][2] = 32'h40c00000; // 6.0
    test_inputs[22][3] = 32'h40a00000; // 5.0
    test_inputs[22][4] = 32'h40800000; // 4.0
    test_inputs[22][5] = 32'h40400000; // 3.0
    test_inputs[22][6] = 32'h40000000; // 2.0
    test_inputs[22][7] = 32'h3f800000; // 1.0
    
    // 测试用例 23: 混合正负数累加
    test_inputs[23][0] = 32'h3fc00000; // 1.5
    test_inputs[23][1] = 32'hc0100000; // -2.25
    test_inputs[23][2] = 32'h40700000; // 3.75
    test_inputs[23][3] = 32'hc0840000; // -4.125
    test_inputs[23][4] = 32'h40a20000; // 5.0625
    test_inputs[23][5] = 32'hc0c0a000; // -6.03125
    test_inputs[23][6] = 32'h40e08000; // 7.015625
    test_inputs[23][7] = 32'hc1000000; // -8.0
    
    // 测试用例 24: 对称抵消 (+a, -a, +b, -b...)
    test_inputs[24][0] = 32'h3f800000; // 1.0
    test_inputs[24][1] = 32'hbf800000; // -1.0
    test_inputs[24][2] = 32'h40000000; // 2.0
    test_inputs[24][3] = 32'hc0000000; // -2.0
    test_inputs[24][4] = 32'h40400000; // 3.0
    test_inputs[24][5] = 32'hc0400000; // -3.0
    test_inputs[24][6] = 32'h40800000; // 4.0
    test_inputs[24][7] = 32'hc0800000; // -4.0
    
    // 测试用例 25: 精确舍入 (0.5 * 8 = 4.0)
    test_inputs[25][0] = 32'h3f000000; // 0.5
    test_inputs[25][1] = 32'h3f000000; // 0.5
    test_inputs[25][2] = 32'h3f000000; // 0.5
    test_inputs[25][3] = 32'h3f000000; // 0.5
    test_inputs[25][4] = 32'h3f000000; // 0.5
    test_inputs[25][5] = 32'h3f000000; // 0.5
    test_inputs[25][6] = 32'h3f000000; // 0.5
    test_inputs[25][7] = 32'h3f000000; // 0.5
    
    // 舍入测试
    // 测试用例 26: 舍入位 = 0.5, LSB=0, round-down
    test_inputs[26][0] = 32'h3f000000; // 0.5
    for (j = 1; j < NUM_INPUTS; j = j + 1) begin
        test_inputs[26][j] = 32'h00000000; // 0.0
    end
    
    // 测试用例 27: 舍入位 = 0.5, LSB=1, round-up
    test_inputs[27][0] = 32'h3f000001; // 0.5 + 2^-24
    for (j = 1; j < NUM_INPUTS; j = j + 1) begin
        test_inputs[27][j] = 32'h00000000; // 0.0
    end
    
    // 测试用例 28: 需要进位
    test_inputs[28][0] = 32'h3f7fffff; // 0.9999999
    for (j = 1; j < NUM_INPUTS; j = j + 1) begin
        test_inputs[28][j] = 32'h00000000; // 0.0
    end
    
    // 测试用例 29: 舍入位 < 0.5, round-down
    test_inputs[29][0] = 32'h3effff00; // 约0.4999999
    for (j = 1; j < NUM_INPUTS; j = j + 1) begin
        test_inputs[29][j] = 32'h00000000; // 0.0
    end
    
    // 测试用例 30: 舍入位 > 0.5, round-up
    test_inputs[30][0] = 32'h3f000100; // 约0.5000001
    for (j = 1; j < NUM_INPUTS; j = j + 1) begin
        test_inputs[30][j] = 32'h00000000; // 0.0
    end
    
    // 指数对齐测试
    // 测试用例 31: 大指数差
    test_inputs[31][0] = 32'h3f800000; // 1.0
    test_inputs[31][1] = 32'h36000000; // 2^-20
    for (j = 2; j < NUM_INPUTS; j = j + 1) begin
        test_inputs[31][j] = 32'h00000000; // 0.0
    end
    
    // 测试用例 32: 最大指数
    test_inputs[32][0] = 32'h7f000000; // 2^127
    test_inputs[32][1] = 32'h3f800000; // 1.0
    for (j = 2; j < NUM_INPUTS; j = j + 1) begin
        test_inputs[32][j] = 32'h00000000; // 0.0
    end
    
    // 测试用例 33: 最小指数
    test_inputs[33][0] = 32'h00800000; // 2^-126
    test_inputs[33][1] = 32'h3f800000; // 1.0
    for (j = 2; j < NUM_INPUTS; j = j + 1) begin
        test_inputs[33][j] = 32'h00000000; // 0.0
    end
    
    // 测试用例 34: 混合指数
    test_inputs[34][0] = 32'h3f800000; // 1.0
    test_inputs[34][1] = 32'h36000000; // 2^-20
    test_inputs[34][2] = 32'h7f000000; // 2^127
    test_inputs[34][3] = 32'h00800000; // 2^-126
    for (j = 4; j < NUM_INPUTS; j = j + 1) begin
        test_inputs[34][j] = 32'h00000000; // 0.0
    end
    
    // 特殊值测试
    // 测试用例 35: 多个 NaN 输入
    test_inputs[35][0] = 32'h7fc00000; // qNaN
    test_inputs[35][1] = 32'h7fc00000; // qNaN
    test_inputs[35][2] = 32'h3f800000; // 1.0
    test_inputs[35][3] = 32'h40000000; // 2.0
    test_inputs[35][4] = 32'h40400000; // 3.0
    test_inputs[35][5] = 32'h40800000; // 4.0
    test_inputs[35][6] = 32'h40a00000; // 5.0
    test_inputs[35][7] = 32'h40c00000; // 6.0
    
    // 测试用例 36: Inf + (-Inf) = NaN
    test_inputs[36][0] = 32'h7f800000; // +Inf
    test_inputs[36][1] = 32'hff800000; // -Inf
    for (j = 2; j < NUM_INPUTS; j = j + 1) begin
        test_inputs[36][j] = 32'h3f800000; // 1.0
    end
    
    // 测试用例 37: Inf + Inf = Inf
    test_inputs[37][0] = 32'h7f800000; // +Inf
    test_inputs[37][1] = 32'h7f800000; // +Inf
    for (j = 2; j < NUM_INPUTS; j = j + 1) begin
        test_inputs[37][j] = 32'h3f800000; // 1.0
    end
    
    // 测试用例 38: -Inf + -Inf = -Inf
    test_inputs[38][0] = 32'hff800000; // -Inf
    test_inputs[38][1] = 32'hff800000; // -Inf
    for (j = 2; j < NUM_INPUTS; j = j + 1) begin
        test_inputs[38][j] = 32'h3f800000; // 1.0
    end
    
    // 测试用例 39: 多个 Inf (+/-) 混合 -> NaN
    test_inputs[39][0] = 32'h7f800000; // +Inf
    test_inputs[39][1] = 32'hff800000; // -Inf
    test_inputs[39][2] = 32'h7f800000; // +Inf
    test_inputs[39][3] = 32'hff800000; // -Inf
    test_inputs[39][4] = 32'h3f800000; // 1.0
    test_inputs[39][5] = 32'hbf800000; // -1.0
    test_inputs[39][6] = 32'h00000000; // 0.0
    test_inputs[39][7] = 32'h00000000; // 0.0
    
    // 测试用例 40: 8个 0x00000001 (最小正非规格化数) 相加
    for (j = 0; j < NUM_INPUTS; j = j + 1) begin
        test_inputs[40][j] = 32'h00000001; // 最小正非规格化数
    end
    
    // 测试用例 41: 8个 0x00000002 相加
    for (j = 0; j < NUM_INPUTS; j = j + 1) begin
        test_inputs[41][j] = 32'h00000002; // 两倍最小正非规格化数
    end
    
    // 测试用例 42: 4 x 0x00000001 + 4 x 0x00000002
    for (j = 0; j < NUM_INPUTS; j = j + 1) begin
        if (j < 4) test_inputs[42][j] = 32'h00000001; // 最小正非规格化数
        else test_inputs[42][j] = 32'h00000002; // 两倍最小正非规格化数
    end
    
    // 测试用例 43: 8 x 0x00100000
    for (j = 0; j < NUM_INPUTS; j = j + 1) begin
        test_inputs[43][j] = 32'h00100000; // 大的非规格化数
    end
    
    // 测试用例 44: 8 x 0x00100001
    for (j = 0; j < NUM_INPUTS; j = j + 1) begin
        test_inputs[44][j] = 32'h00100001; // 大的非规格化数+1
    end
    
    // 测试用例 45: 8 x 0x007FFFFF (最大非规格化数)
    for (j = 0; j < NUM_INPUTS; j = j + 1) begin
        test_inputs[45][j] = 32'h007FFFFF; // 最大非规格化数
    end
    
    // 测试用例 46: 小数测试 (0.125, 0.25, ...)
    test_inputs[46][0] = 32'h3e000000; // 0.125
    test_inputs[46][1] = 32'h3e800000; // 0.25
    test_inputs[46][2] = 32'h3ec00000; // 0.375
    test_inputs[46][3] = 32'h3f000000; // 0.5
    test_inputs[46][4] = 32'h3f200000; // 0.625
    test_inputs[46][5] = 32'h3f400000; // 0.75
    test_inputs[46][6] = 32'h3f600000; // 0.875
    test_inputs[46][7] = 32'h3f800000; // 1.0
    
    // 测试用例 47: 正负数相加 (1.1 + -2.2 + 3.3 + ...)
    test_inputs[47][0] = 32'h3f8ccccd; // 1.1
    test_inputs[47][1] = 32'hc00ccccd; // -2.2
    test_inputs[47][2] = 32'h40533333; // 3.3
    test_inputs[47][3] = 32'hc08ccccd; // -4.4
    test_inputs[47][4] = 32'h40b00000; // 5.5
    test_inputs[47][5] = 32'hc0d33333; // -6.6
    test_inputs[47][6] = 32'h40f66666; // 7.7
    test_inputs[47][7] = 32'hc10ccccd; // -8.8
    
    // 测试用例 48: 8个很小的数求和
    for (j = 0; j < NUM_INPUTS; j = j + 1) begin
        test_inputs[48][j] = 32'h33D70A3D; // 约 1e-7
    end
    
    // 测试用例 49: 8个很大的数求和
    for (j = 0; j < NUM_INPUTS; j = j + 1) begin
        test_inputs[49][j] = 32'h4E6E6B28; // 约 1e9
    end
    
    // 测试用例 50: 很小的数 + 很大的数
    test_inputs[50][0] = 32'h4E6E6B28; // 约 1e9
    test_inputs[50][1] = 32'h33D70A3D; // 约 1e-7
    for (j = 2; j < NUM_INPUTS; j = j + 1) begin
        test_inputs[50][j] = 32'h00000000; // 0.0
    end
    
    // 测试用例 51: 溢出测试 - 应该产生INF
    for (j = 0; j < NUM_INPUTS; j = j + 1) begin
        test_inputs[51][j] = 32'h7F7FFFFF; // 最大正规格化数
    end

    // 复位
    rst_n = 0;
    denorm_to_zero_en = 0;
    fp_inputs_flat = 0;
    #20;
    rst_n = 1;
    #10;

    // 运行测试用例
    for (i = 0; i < 52; i = i + 1) begin // 运行所有测试用例
        // 设置输入
        fp_inputs_flat[31:0]   = test_inputs[i][0];
        fp_inputs_flat[63:32]  = test_inputs[i][1];
        fp_inputs_flat[95:64]  = test_inputs[i][2];
        fp_inputs_flat[127:96] = test_inputs[i][3];
        fp_inputs_flat[159:128] = test_inputs[i][4];
        fp_inputs_flat[191:160] = test_inputs[i][5];
        fp_inputs_flat[223:192] = test_inputs[i][6];
        fp_inputs_flat[255:224] = test_inputs[i][7];
        
        // 清除 SoftFloat 异常标志
        clear_softfloat_flags();
        
        // 通过 DPI-C 从 SoftFloat 获取期望结果
        expected_fp32_from_softfloat = fp32_add_8_softfloat(
            test_inputs[i][0], test_inputs[i][1], test_inputs[i][2], test_inputs[i][3],
            test_inputs[i][4], test_inputs[i][5], test_inputs[i][6], test_inputs[i][7]);
        softfloat_flags = get_softfloat_flags();

        #10; // 等待DUT处理

        // 比较结果
        
        match_found = 0;
        is_inexact = (softfloat_flags & 32'h00000001) != 0; // 检查不精确标志
        
        // 处理 NaN 的比较
        is_expected_nan = (expected_fp32_from_softfloat[30:23] == 8'hFF) && (expected_fp32_from_softfloat[22:0] != 0);
        is_fp_sum_nan   = (fp_sum[30:23] == 8'hFF) && (fp_sum[22:0] != 0);

        if (is_expected_nan && is_fp_sum_nan) begin
            match_found = 1;
        end else if (fp_sum === expected_fp32_from_softfloat) begin
            // 精确匹配
            match_found = 1;
        end else if (is_inexact) begin
            // 当结果不精确时，允许最低位±1的误差
            expected_plus_one = expected_fp32_from_softfloat + 1;
            expected_minus_one = expected_fp32_from_softfloat - 1;
            
            if ((fp_sum === expected_plus_one) || (fp_sum === expected_minus_one)) begin
                match_found = 1;
            end
        end

        if (match_found) begin
            if (is_expected_nan && is_fp_sum_nan) begin
                $fdisplay(sim_log, "测试用例 %0d: PASS (NaN): softfloat=%h (标志=%h), 实际值=%h", 
                         i, expected_fp32_from_softfloat, softfloat_flags, fp_sum);
            end else if (fp_sum === expected_fp32_from_softfloat) begin
                $fdisplay(sim_log, "测试用例 %0d: PASS: softfloat=%h (标志=%h), 实际值=%h", 
                         i, expected_fp32_from_softfloat, softfloat_flags, fp_sum);
            end else begin
                $fdisplay(sim_log, "测试用例 %0d: PASS: softfloat=%h (标志=%h), 实际值=%h (±1 tolerance)", 
                         i, expected_fp32_from_softfloat, softfloat_flags, fp_sum);
            end
            pass_count = pass_count + 1;
        end else begin
            $fdisplay(sim_log, "测试用例 %0d: FAIL: softfloat=%h (标志=%h), 实际值=%h", 
                     i, expected_fp32_from_softfloat, softfloat_flags, fp_sum);
            // 输出输入值用于调试
            $fdisplay(sim_log, "输入: %h %h %h %h %h %h %h %h",
                     test_inputs[i][0], test_inputs[i][1], test_inputs[i][2], test_inputs[i][3],
                     test_inputs[i][4], test_inputs[i][5], test_inputs[i][6], test_inputs[i][7]);
            fail_count = fail_count + 1;
        end
        
        #10;
    end

    // 输出统计信息
    $fdisplay(sim_log, "\nTest Summary:");
    $fdisplay(sim_log, "Total tests: %0d", pass_count + fail_count);
    $fdisplay(sim_log, "Passed: %0d", pass_count);
    $fdisplay(sim_log, "Failed: %0d", fail_count);
    
    if (fail_count == 0) begin
        $fdisplay(sim_log, "\nPASSED: All test cases passed!");
    end else begin
        $fdisplay(sim_log, "\nFAILED: %0d test cases failed", fail_count);
    end
    
    // 关闭文件
    $fclose(sim_log);
    $finish;
end

endmodule
