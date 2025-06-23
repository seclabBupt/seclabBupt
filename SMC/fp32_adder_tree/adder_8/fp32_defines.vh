`ifndef FP32_DEFINES_VH
`define FP32_DEFINES_VH

`define FP32_WIDTH 32 // 总位宽
`define EXP_WIDTH 8   // 指数位宽
`define MANT_WIDTH 23 // 尾数位宽

`define BIAS 127     // 指数偏移量

// 对齐阶段参数
`define GUARD_BITS 3 // G, R, S bits


// 对齐后的尾数宽度 (隐藏位 + 尾数 + GRS)
`define ALIGNED_MANT_WIDTH (1+ `MANT_WIDTH + `GUARD_BITS)// 1代表隐藏位

// 华莱士树和最终加法器参数
// 需要能容纳 8 个 (ALIGNED_MANT_WIDTH + 1) 位.+1为了尾数相加防止溢出
// 符号位扩展 + 幅度位 (ALIGNED_MANT_WIDTH + clog2(8)) 1 + (27 + 3) = 31
`define FULL_SUM_WIDTH 31

// Normalizer/Rounder 输入位宽 (来自华莱士树的幅度)
// 华莱士树输出 final_result 是 FULL_SUM_WIDTH+1 位
// 其幅度是 FULL_SUM_WIDTH 位
`define NORM_IN_WIDTH `FULL_SUM_WIDTH 




`define TEXT_RESET   "\033[0m"
`define TEXT_BLACK   "\033[0;30m"
`define TEXT_RED     "\033[0;31m"
`define TEXT_GREEN   "\033[0;32m"
`define TEXT_YELLOW  "\033[0;33m"
`define TEXT_BLUE    "\033[0;34m"
`define TEXT_MAGENTA "\033[0;35m"
`define TEXT_CYAN    "\033[0;36m"
`define TEXT_WHITE   "\033[0;37m"

`endif 