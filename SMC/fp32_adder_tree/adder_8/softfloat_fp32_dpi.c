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

// 对8个FP32数进行加法运算
uint32_t fp32_add_8_softfloat(uint32_t input0, uint32_t input1, uint32_t input2, uint32_t input3,
                               uint32_t input4, uint32_t input5, uint32_t input6, uint32_t input7) {
    float32_t f32_inputs[8];
    float32_t f32_result;
    
    // 将输入转换为SoftFloat格式
    f32_inputs[0].v = input0;
    f32_inputs[1].v = input1;
    f32_inputs[2].v = input2;
    f32_inputs[3].v = input3;
    f32_inputs[4].v = input4;
    f32_inputs[5].v = input5;
    f32_inputs[6].v = input6;
    f32_inputs[7].v = input7;
    
    // 执行加法运算：((((((input0 + input1) + input2) + input3) + input4) + input5) + input6) + input7
    f32_result = f32_add(f32_inputs[0], f32_inputs[1]);
    f32_result = f32_add(f32_result, f32_inputs[2]);
    f32_result = f32_add(f32_result, f32_inputs[3]);
    f32_result = f32_add(f32_result, f32_inputs[4]);
    f32_result = f32_add(f32_result, f32_inputs[5]);
    f32_result = f32_add(f32_result, f32_inputs[6]);
    f32_result = f32_add(f32_result, f32_inputs[7]);
    
    return f32_result.v;
}

// 对任意数量的FP32数进行加法运算（可变参数版本）
uint32_t fp32_add_array_softfloat(uint32_t *inputs, int num_inputs) {
    if (num_inputs <= 0) {
        // 返回正零
        return 0x00000000;
    }
    
    float32_t f32_result;
    f32_result.v = inputs[0];
    
    for (int i = 1; i < num_inputs; i++) {
        float32_t f32_input;
        f32_input.v = inputs[i];
        f32_result = f32_add(f32_result, f32_input);
    }
    
    return f32_result.v;
}

// 对2个FP32数进行加法运算（用于基本测试）
uint32_t fp32_add_2_softfloat(uint32_t input0, uint32_t input1) {
    float32_t f32_a, f32_b, f32_result;
    
    f32_a.v = input0;
    f32_b.v = input1;
    
    f32_result = f32_add(f32_a, f32_b);
    
    return f32_result.v;
}
