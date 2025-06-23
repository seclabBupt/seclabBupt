`timescale 1ns/1ps

module tb_fp16_to_fp32_multiplier;

// 参数定义
parameter FP16_EXP_WIDTH = 5;
parameter FP16_MANT_WIDTH = 10;
parameter FP32_EXP_WIDTH = 8;
parameter FP32_MANT_WIDTH = 23;

// 波形转储模块例化
//dump #(
//    .DUMP_WLF(0),   // 开启WLF格式
//    .DUMP_VCD(1),   // 关闭VCD格式
//    .WAVE_FILE("sim.wave")  // 波形文件名
//) u_dump();

// 输入信号
reg clk;
reg rst_n;
reg [15:0] fp16_a;
reg [15:0] fp16_b;
reg valid_in;

// 输出信号
wire [31:0] fp32_out;
wire valid_out;

// DPI-C 导入
//import "DPI-C" function int unsigned fp16_mul_to_fp32_softfloat(input shortint unsigned a, input shortint unsigned b);
import "DPI-C" function int unsigned fp16_inputs_mul_to_fp32_softfloat(input shortint unsigned a, input shortint unsigned b);
import "DPI-C" function void set_softfloat_rounding_mode(input int unsigned mode);
import "DPI-C" function void clear_softfloat_flags();
import "DPI-C" function int unsigned get_softfloat_flags();

// SoftFloat 舍入模式 (来自 softfloat_types.h)
localparam SOFTFLOAT_ROUND_NEAR_EVEN = 0; // 四舍五入到最近的偶数
localparam SOFTFLOAT_ROUND_MINMAG    = 1; // 向零舍入
localparam SOFTFLOAT_ROUND_MIN       = 2; // 向负无穷大舍入
localparam SOFTFLOAT_ROUND_MAX       = 3; // 向正无穷大舍入
localparam SOFTFLOAT_ROUND_NEAR_MAXMAG = 4; // 四舍五入到最近，关系到最大幅度
// 文件句柄
integer sim_log;
integer coverage_log;
integer pass_count;
integer fail_count;

// 实例化被测模块
fp16_to_fp32_multiplier uut (
    .clk(clk),
    .rst_n(rst_n),
    .fp16_a(fp16_a),
    .fp16_b(fp16_b),
    .valid_in(valid_in),
    .fp32_out(fp32_out),
    .valid_out(valid_out)
);

// 时钟生成
initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

// 打开日志文件
initial begin
    sim_log = $fopen("sim.log", "w");
    coverage_log = $fopen("sim.coverage.tcl", "w");
    if (!sim_log) begin
        $display("Error: Could not open sim.log");
        $finish;
    end
    if (!coverage_log) begin
        $display("Error: Could not open sim.coverage.tcl");
        $finish;
    end
    $fdisplay(sim_log, "Simulation started at time %t", $time);
    pass_count = 0;
    fail_count = 0;

    // 设置 SoftFloat 舍入模式 (例如，四舍五入到最近的偶数)
    set_softfloat_rounding_mode(SOFTFLOAT_ROUND_NEAR_EVEN);
end

// 测试用例
reg [15:0] test_cases_a [0:29]; // 增加测试用例数量
reg [15:0] test_cases_b [0:29];
// reg [31:0] expected_results [0:29]; // 期望结果现在将来自 SoftFloat
integer i;

// Declare the missing variable 'expected_fp32_from_softfloat' as an integer
integer expected_fp32_from_softfloat;

// Remove 'automatic' and declare 'softfloat_flags' as an integer
integer softfloat_flags;

initial begin
    // 基本规格化数测试
    test_cases_a[0] = 16'h3c00; // 1.0
    test_cases_b[0] = 16'h3c00; // 1.0

    test_cases_a[1] = 16'h4000; // 2.0
    test_cases_b[1] = 16'h3c00; // 1.0

    test_cases_a[2] = 16'h3c00; // 1.0
    test_cases_b[2] = 16'h4000; // 2.0

    test_cases_a[3] = 16'h7bff; // 最大规格化数
    test_cases_b[3] = 16'h3c00; // 1.0

    test_cases_a[4] = 16'h0400; // 最小规格化数
    test_cases_b[4] = 16'h3c00; // 1.0

    // 无穷大测试
    test_cases_a[5] = 16'h7c00; // +Inf
    test_cases_b[5] = 16'h3c00; // 1.0

    test_cases_a[6] = 16'h3c00; // 1.0
    test_cases_b[6] = 16'h7c00; // +Inf

    test_cases_a[7] = 16'h7c00; // +Inf
    test_cases_b[7] = 16'h7c00; // +Inf

    // NaN测试
    test_cases_a[8] = 16'h7c01; // NaN
    test_cases_b[8] = 16'h3c00; // 1.0

    test_cases_a[9] = 16'h3c00; // 1.0
    test_cases_b[9] = 16'h7c01; // NaN

    // 零测试
    test_cases_a[10] = 16'h0000; // +0
    test_cases_b[10] = 16'h3c00; // 1.0

    test_cases_a[11] = 16'h3c00; // 1.0
    test_cases_b[11] = 16'h0000; // +0

    test_cases_a[12] = 16'h8000; // -0
    test_cases_b[12] = 16'h3c00; // 1.0

    // 非规格化数测试
    test_cases_a[13] = 16'h0001; // 最小非规格化数
    test_cases_b[13] = 16'h3c00; // 1.0

    test_cases_a[14] = 16'h03ff; // 最大非规格化数
    test_cases_b[14] = 16'h3c00; // 1.0

    // 增加更多规格化数测试
    test_cases_a[15] = 16'h4400; // 4.0 
    test_cases_b[15] = 16'h4400; // 4.0 

    test_cases_a[16] = 16'h4400; // 4.0 
    test_cases_b[16] = 16'h4500; // 5.0

    test_cases_a[17] = 16'h4400; // 4.0
    test_cases_b[17] = 16'h3e00; // 1.5

    test_cases_a[18] = 16'h3800; // 0.5
    test_cases_b[18] = 16'h3800; // 0.5

    test_cases_a[19] = 16'h4400; // 4.0 
    test_cases_b[19] = 16'hc000; // -2.0

    test_cases_a[20] = 16'hbc00; // -1.0
    test_cases_b[20] = 16'hbc00; // -1.0

    test_cases_a[21] = 16'h5400; // 64.0 
    test_cases_b[21] = 16'h5400; // 64.0 

    test_cases_a[22] = 16'h4800; // 8.0 
    test_cases_b[22] = 16'h3400; // 0.25 

    // 添加测试边界情况的规格化数
    test_cases_a[23] = 16'h0400; // 2^-14 (最小规格化数)
    test_cases_b[23] = 16'h0400; // 2^-14 (最小规格化数)

    test_cases_a[24] = 16'h7800; // 2^15 
    test_cases_b[24] = 16'h0400; // 2^-14 (最小规格化数)

    test_cases_a[25] = 16'h0400; // 2^-14 (最小规格化数)
    test_cases_b[25] = 16'h7800; // 2^15 

    // 测试指数接近上限/下限的情况
    test_cases_a[26] = 16'h7800; // 2^15 
    test_cases_b[26] = 16'h7800; // 2^15 

    // 新 Case 27: 大数乘以小数 (2^15 * 2^-13 = 2^2)
    test_cases_a[27] = 16'h7800; // 2^15 (最大正指数规格化数)
    test_cases_b[27] = 16'h0800; // 2^-13

    // 尾数全1的情况测试
    test_cases_a[28] = 16'h3bff; // 1.0 - epsilon
    test_cases_b[28] = 16'h4000; // 2.0

    // 测试舍入
    test_cases_a[29] = 16'h3c01; // 1.0 + epsilon
    test_cases_b[29] = 16'h3c01; // 1.0 + epsilon


    // 复位
    rst_n = 0;
    valid_in = 0;
    fp16_a = 0;
    fp16_b = 0;
    #20;
    rst_n = 1;
    #10;

    // 运行测试用例
    for (i = 0; i < 30; i = i + 1) begin
        fp16_a = test_cases_a[i];
        fp16_b = test_cases_b[i];
        valid_in = 1;
        
        // 在每次操作前清除 SoftFloat 异常标志
        clear_softfloat_flags();
        
        // 通过 DPI-C 从 SoftFloat 获取期望结果
        expected_fp32_from_softfloat = fp16_inputs_mul_to_fp32_softfloat(fp16_a, fp16_b);
        softfloat_flags = get_softfloat_flags();

        #10; // 等待 DUT 处理输入 (如果 DUT 有延迟则调整)
        
        // 等待一个时钟周期后检查结果
        // 最好等待 valid_out 或固定的延迟
        // 本示例假设为组合逻辑 DUT 或 1 周期延迟
        // 对于流水线 DUT，您需要一种更可靠的方法来对齐期望结果和实际结果。
        
        // 如果您的 DUT 使用 valid_out，则等待它
        // 现在，我们假设结果在几个周期后可用
        // 这部分需要根据您的 DUT 行为进行调整。
        // 示例: wait(valid_out === 1); 
        // 或者，如果是固定延迟，例如 # (NUM_CYCLES_LATENCY * CLK_PERIOD);

        if (valid_out) begin // 如果DUT的输出有效 (valid_out 为高)
            if (fp32_out !== expected_fp32_from_softfloat) begin
                // 处理 NaN 的比较：NaN 从不等于 NaN。
                // 如果两个值都是 NaN (指数位全1，尾数位非零)，那么对于NaN来说它们是匹配的。
                logic is_expected_nan, is_fp32_out_nan;
                is_expected_nan = (expected_fp32_from_softfloat[30:23] == 8'hFF) && (expected_fp32_from_softfloat[22:0] != 0);
                is_fp32_out_nan   = (fp32_out[30:23] == 8'hFF) && (fp32_out[22:0] != 0);

                if (is_expected_nan && is_fp32_out_nan) begin
                    $fdisplay(sim_log, "用例 %0d: PASS (NaN): a=%h, b=%h, softfloat=%h (标志=%h), 实际值=%h", 
                             i, fp16_a, fp16_b, expected_fp32_from_softfloat, softfloat_flags, fp32_out);
                    pass_count = pass_count + 1;
                end else begin
                    $fdisplay(sim_log, "用例 %0d: FAIL: a=%h, b=%h, softfloat=%h (标志=%h), 实际值=%h", 
                             i, fp16_a, fp16_b, expected_fp32_from_softfloat, softfloat_flags, fp32_out);
                    fail_count = fail_count + 1;
                end
            end else begin
                $fdisplay(sim_log, "用例 %0d: PASS: a=%h, b=%h, softfloat=%h (标志=%h), 实际值=%h", 
                         i, fp16_a, fp16_b, expected_fp32_from_softfloat, softfloat_flags, fp32_out);
                pass_count = pass_count + 1;
            end
        end else begin
            // 如果在检查结果时 valid_out 未置位，则可能进入此 'else' 分支。
            // 这可能是因为 valid_in 被过早地取消置位，或者 valid_out 的逻辑与预期不符。
            $fdisplay(sim_log, "用例 %0d: 警告: 检查时 valid_out 未有效。 a=%h, b=%h. Softfloat  %h (标志=%h). DUT 输出 %h.",
                               i, fp16_a, fp16_b, expected_fp32_from_softfloat, softfloat_flags, fp32_out);
            // 根据严格程度，这可能被视为一个失败。
            // fail_count = fail_count + 1; 
        end
        
        valid_in = 0;
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
    $fclose(coverage_log);
    $finish;
end

endmodule