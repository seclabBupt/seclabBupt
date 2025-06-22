#!/bin/bash

# 快速启用Berkeley SoftFloat-3的脚本
# 适用于fp16_to_fp32_multiplier项目

echo "=== 快速启用 Berkeley SoftFloat-3 ==="

# 设置路径
SOFTFLOAT_ROOT="/home/Sunny/SMC/berkeley-softfloat-3-master"
SOFTFLOAT_INCLUDE="$SOFTFLOAT_ROOT/source/include"
SOFTFLOAT_LIB="$SOFTFLOAT_ROOT/build/Linux-x86_64-GCC/softfloat.a"

# 检查库文件
if [ ! -f "$SOFTFLOAT_LIB" ]; then
    echo "错误: SoftFloat库文件不存在"
    echo "正在构建SoftFloat库..."
    cd "$SOFTFLOAT_ROOT/build/Linux-x86_64-GCC"
    make
    if [ $? -ne 0 ]; then
        echo "构建失败！"
        exit 1
    fi
    echo "SoftFloat库构建完成"
fi

# 导出环境变量
export SOFTFLOAT_ROOT="$SOFTFLOAT_ROOT"
export SOFTFLOAT_INCLUDE="$SOFTFLOAT_INCLUDE"
export SOFTFLOAT_LIB="$SOFTFLOAT_LIB"

echo "✓ SoftFloat库: $SOFTFLOAT_LIB"
echo "✓ 头文件路径: $SOFTFLOAT_INCLUDE"
echo ""
echo "环境变量已设置，可以使用SoftFloat进行编译"
echo ""
echo "示例编译命令:"
echo "gcc -I\"$SOFTFLOAT_INCLUDE\" -fPIC -c your_dpi.c -o your_dpi.o"
echo "gcc -shared your_dpi.o \"$SOFTFLOAT_LIB\" -o libruntime.so"
