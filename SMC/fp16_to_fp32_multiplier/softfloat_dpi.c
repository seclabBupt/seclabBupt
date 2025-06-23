#include <stdio.h>
#include <stdint.h>
#include "softfloat.h"


// SoftFloat 使用全局变量来管理舍入模式和异常标志
// 这些变量在 softfloat.h 中声明为 extern

// 设置SoftFloat的舍入模式
void set_softfloat_rounding_mode(uint32_t mode) {
    softfloat_roundingMode = mode;
}

// 清除SoftFloat的异常标志
void clear_softfloat_flags() {
    softfloat_exceptionFlags = 0;
}

// 获取SoftFloat的异常标志
uint32_t get_softfloat_flags() {
    return softfloat_exceptionFlags;
}
/***
#define softfloat_flag_inexact   1 不精确
#define softfloat_flag_underflow 2 下溢
#define softfloat_flag_overflow  4 上溢
#define softfloat_flag_infinite  8 无穷大
#define softfloat_flag_invalid   16 无效
***/
// 不选：将两个FP16数相乘，并将结果转换为FP32
uint32_t fp16_mul_to_fp32_softfloat(uint16_t a, uint16_t b) {
    float16_t f16_a, f16_b, f16_mul_res;
    float32_t f32_res;

    f16_a.v = a;
    f16_b.v = b;

    // 执行FP16乘法
    f16_mul_res = f16_mul(f16_a, f16_b);

    // 将FP16结果转换为FP32
    f32_res = f16_to_f32(f16_mul_res);

    return f32_res.v;
}

// 选：直接将FP16输入转换为FP32后再做乘法
uint32_t fp16_inputs_mul_to_fp32_softfloat(uint16_t a, uint16_t b) {
    float16_t f16_a_val, f16_b_val;
    float32_t f32_a_val, f32_b_val, f32_res;

    f16_a_val.v = a;
    f16_b_val.v = b;

    f32_a_val = f16_to_f32(f16_a_val);
    f32_b_val = f16_to_f32(f16_b_val);

    f32_res = f32_mul(f32_a_val, f32_b_val);

    return f32_res.v;
}