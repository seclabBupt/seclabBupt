# FP32 浮点加法树设计文档

## 项目概述

本项目实现了一个高效的单精度浮点（FP32）加法树结构，主要用于同时处理多个（默认8个）浮点输入的加法运算。设计遵循IEEE 754标准，支持规格化数、非规格化数以及特殊值（零、无穷大、NaN）的处理。

## 主要功能

### 核心功能
- **多输入浮点加法**：支持同时对8个FP32浮点数进行并行加法运算
- **IEEE 754标准兼容**：完全遵循IEEE 754单精度浮点运算标准
- **特殊值处理**：正确处理零值、无穷大（±∞）、非数字（NaN）等特殊情况
- **高精度计算**：通过扩展尾数位宽和粘滞位机制保证计算精度
- **并行优化设计**：采用华莱士树结构实现高效并行加法

### 技术特性
- **尾数对齐**：找到最大指数并对齐所有输入的尾数
- **规格化处理**：进行结果的规格化和舍入操作
- **溢出保护**：防止指数溢出和下溢的安全机制
- **模块化设计**：便于扩展和维护的分层架构

### 代码结构
├── adder_8
│   ├── final_adder.v
│   ├── fp32_adder_tree_8_inputs.v
│   ├── fp32_aligner.v
│   ├── fp32_defines.vh
│   ├── fp32_normalizer_rounder.v
│   ├── fp32_packer.v
│   ├── fp32_unpacker.v
│   ├── full_adder.v
│   ├── libruntime.so
│   ├── Makefile
│   ├── run_sim_softfloat.sh
│   ├── softfloat_fp32_dpi.c
│   ├── tb_fp32_adder_tree_8_inputs_softfloat.v
│   ├── tb_fp32_adder_tree_8_inputs.v
│   ├── testplan.md
│   └── wallace_tree_8_inputs.v
└── add.md

## 核心代码解读

### 1. 顶层模块 (fp32_adder_tree_8_inputs.v)

**功能**：整合所有子模块，实现8输入FP32加法树

```verilog
module fp32_adder_tree_8_inputs (
    input wire [NUM_INPUTS*`FP32_WIDTH-1:0] fp_inputs_flat,  // 8个FP32输入
    input wire denorm_to_zero_en,                            // 非规格化数处理使能
    output wire [`FP32_WIDTH-1:0] fp_sum,                   // FP32输出结果
    output wire is_nan_out,                                  // NaN标志
    output wire is_inf_out                                   // 无穷大标志
);
```

**核心流程**：输入解包 → 尾数对齐 → 华莱士树加法 → 规格化 → 输出打包

### 2. FP32解包器 (fp32_unpacker.v)

**功能**：将FP32格式分解为符号位、指数和尾数

```verilog
assign sign = fp_in[31];                    // 符号位
assign exponent = fp_in[30:23];             // 指数位
assign mantissa = fp_in[22:0];              // 尾数位
assign is_zero = (exponent == 0) && (mantissa == 0);
assign is_inf = (exponent == 8'hFF) && (mantissa == 0);
assign is_nan = (exponent == 8'hFF) && (mantissa != 0);
```

### 3. 尾数对齐器 (fp32_aligner.v)

**功能**：找到最大指数，将所有尾数对齐到相同的指数基准

```verilog
// 找到最大指数
always_comb begin
    max_exp = 0;
    for (int i = 0; i < NUM_INPUTS; i++) begin
        if (!is_zeros[i] && !is_infs[i] && !is_nans[i]) begin
            if (input_exponents[i] > max_exp) 
                max_exp = input_exponents[i];
        end
    end
end

// 尾数右移对齐
wire [EXP_WIDTH:0] shift_amount = max_exp - input_exponents[i];
wire [ALIGNED_MANT_WIDTH-1:0] shifted_mantissa = extended_mantissa >> shift_amount;
```

### 4. 华莱士树加法器 (wallace_tree_8_inputs.v)

**功能**：高效并行计算8个对齐尾数的和

```verilog
// 第一层：8输入 → 6中间结果
generate 
    for (genvar i = 0; i < NUM_INPUTS/3; i++) begin
        full_adder fa1 (
            .a(pos_mantissas[3*i]), 
            .b(pos_mantissas[3*i+1]), 
            .cin(pos_mantissas[3*i+2]),
            .sum(layer1_sum[i]), 
            .cout(layer1_carry[i])
        );
    end
endgenerate

// 最终加法：进位保留加法器
final_adder fa_final (
    .a(final_sum), .b(final_carry), 
    .sum(result_sum), .carry(result_carry)
);
```

### 5. 规格化器 (fp32_normalizer_rounder.v)

**功能**：处理加法结果的规格化、舍入和特殊情况

```verilog
// 前导零检测
leading_zero_count lzc (
    .data_in(abs_mantissa),
    .zero_count(leading_zeros)
);

// 规格化左移
wire [MANT_WIDTH-1:0] normalized_mantissa = abs_mantissa << leading_zeros;

// 指数调整
wire [EXP_WIDTH-1:0] adjusted_exponent = max_exponent - leading_zeros + 1;

// 舍入处理（向最近偶数舍入）
wire round_bit = normalized_mantissa[GUARD_POS];
wire sticky_bit = |normalized_mantissa[GUARD_POS-1:0];
wire round_up = round_bit & (sticky_bit | normalized_mantissa[GUARD_POS+1]);
```

### 6. FP32打包器 (fp32_packer.v)

**功能**：将处理后的符号位、指数和尾数重新组合为标准FP32格式

```verilog
assign fp_out = {final_sign, final_exponent, final_mantissa};

// 特殊值处理
assign fp_out = is_nan_in ? 32'h7FC00000 :      // NaN
                is_inf_in ? {sign, 31'h7F800000} : // ±∞
                is_zero_result ? {sign, 31'h0} :    // ±0
                {final_sign, final_exponent, final_mantissa};
```

### 7. SoftFloat DPI接口 (softfloat_fp32_dpi.c)

**功能**：提供标准SoftFloat库的参考实现，用于验证硬件结果

```c
uint32_t fp32_add_8_softfloat(uint32_t input0, uint32_t input1, /*...*/ uint32_t input7) {
    float32_t inputs[8] = {
        {.v = input0}, {.v = input1}, /*...*/ {.v = input7}
    };
    
    float32_t result = inputs[0];
    for (int i = 1; i < 8; i++) {
        result = f32_add(result, inputs[i]);
    }
    
    return result.v;
}
```

### 核心算法特点

1. **并行设计**：所有输入同时进行解包和对齐处理
2. **精度保护**：使用27位扩展尾数（23+1隐含位+3保护位）和粘滞位机制
3. **特殊值优先处理**：NaN、无穷大等特殊值有独立的快速处理路径
4. **IEEE 754兼容**：严格遵循标准的舍入规则和异常处理

## 快速入门指南

### 1. 克隆项目
```bash
git clone git@github.com:seclabBupt/aiacc.git
cd fp32_adder_tree/adder_8
```

### 2. 运行仿真
```bash
chmod +x run_sim_softfloat.sh
./run_sim_softfloat.sh
```

### 3. 查看结果
```bash
# 查看仿真日志
cat sim_softfloat.log

# 使用波形查看器
verdi  sim_softfloat.fsdb
```
