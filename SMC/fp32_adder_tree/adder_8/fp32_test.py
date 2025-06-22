import struct
import math # 导入math模块以使用math.isnan

def hex_to_fp32(hex_str):
    """
    将一个8位的十六进制字符串转换为其对应的IEEE 754单精度浮点数。
    假定十六进制字符串是按大端序（big-endian）表示的。

    参数:
    hex_str (str): 一个8位的十六进制字符串 (例如 "41480000")。

    返回:
    float: 对应的浮点数值。

    异常:
    ValueError: 如果输入不是有效的8位十六进制字符串。
    """
    if not (isinstance(hex_str, str) and len(hex_str) == 8):
        raise ValueError("输入必须是一个8位的十六进制字符串。")
    try:
        # 检查是否所有字符都是有效的十六进制字符
        int_val = int(hex_str, 16)
    except ValueError:
        raise ValueError(f"无效的十六进制字符在输入中: {hex_str}")

    # 将十六进制字符串转换为字节序列
    # bytes.fromhex() 要求十六进制字符串不含 "0x" 前缀且长度为偶数
    byte_val = bytes.fromhex(hex_str)

    # 将字节序列解包为大端序的单精度浮点数
    # '>' 指定大端序, 'f' 指定单精度浮点数
    float_val = struct.unpack('>f', byte_val)[0]
    return float_val

def fp32_to_hex(float_val):
    """
    将一个Python浮点数转换为其IEEE 754单精度浮点数的8位十六进制字符串表示（大端序）。

    参数:
    float_val (float): 需要转换的浮点数。

    返回:
    str: 对应的8位十六进制字符串 (例如 "41480000")。
    """
    if not isinstance(float_val, (float, int)): # 也允许整数，它们会被当作浮点数处理
        raise ValueError("输入必须是一个数字（浮点数或整数）。")

    # 处理 NaN 的特殊情况，确保一致的十六进制表示 (例如，标准的 quiet NaN)
    if math.isnan(float_val):
        return "7FC00000" # 一个常见的 quiet NaN 表示

    # 将浮点数打包为大端序的单精度浮点数字节序列
    byte_val = struct.pack('>f', float(float_val)) # 确保是float类型

    # 将字节序列转换为十六进制字符串，并转为大写
    hex_str = byte_val.hex().upper()
    return hex_str

def sum_eight_fp32_from_hex(hex_strings_list):
    """
    计算八个以8位十六进制字符串形式提供的FP32数的总和。

    参数:
    hex_strings_list (list[str]): 一个包含八个8位十六进制字符串的列表。

    返回:
    float: 八个数的总和，以Python的浮点数形式表示。

    异常:
    ValueError: 如果输入列表不符合要求（不是列表，或长度不为8），
                或者列表中的任何字符串无法正确转换为FP32数。
    """
    if not isinstance(hex_strings_list, list) or len(hex_strings_list) != 8:
        raise ValueError("输入必须是一个包含八个十六进制字符串的列表。")

    total_sum = 0.0
    converted_floats = []

    for i, hex_str in enumerate(hex_strings_list):
        try:
            float_val = hex_to_fp32(hex_str)
            converted_floats.append(float_val)
            # 累加时，Python的float是双精度，这有助于保持精度
            total_sum += float_val
        except ValueError as e:
            raise ValueError(f"处理列表中的第 {i+1} 个十六进制字符串 '{hex_str}' 时出错: {e}")

    return total_sum

# --- 示例用法 ---
if __name__ == "__main__":
    # 示例1: 一组简单的浮点数
    # 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0
    # 它们的和应该是 36.0
    hex_inputs1 = [
        "00000001",  # 1.0
        "00000001",  # 2.0
        "00000001",  # 3.0
        "00000001",  # 4.0
        "00000001",  # 5.0
        "00000001",  # 6.0
        "00000001",  # 7.0
        "00000001"   # 8.0
    ]
    print("--- 示例 1 ---")
    try:
        print(f"输入十六进制字符串: {hex_inputs1}")
        individual_floats1 = [hex_to_fp32(h) for h in hex_inputs1]
        print(f"转换后的FP32值: {[f'{f:.8f}' for f in individual_floats1]}")

        result_sum1 = sum_eight_fp32_from_hex(hex_inputs1)
        print(f"计算得到的总和 (Python float): {result_sum1:.8f}")

        # 将总和转换回FP32的十六进制表示
        sum_hex1 = fp32_to_hex(result_sum1)
        print(f"总和的FP32十六进制表示: {sum_hex1}") # 预期: 42100000 for 36.0
        print(f"验证总和的十六进制转回浮点数: {hex_to_fp32(sum_hex1):.8f}")

    except ValueError as e:
        print(f"错误: {e}")
    
    hex_inputs2 = [
        "00001003",  
        "00001003",  
        "0000f001" ,  
        "00003004",  
        "00003004",  
        "0000f001",  
        "0000f001" ,  
        "0000f001",  
    ]
    print("--- 示例 2 ---")
    try:
        print(f"输入十六进制字符串: {hex_inputs2}")
        individual_floats2 = [hex_to_fp32(h) for h in hex_inputs2]
        print(f"转换后的FP32值: {[f'{f:.8f}' for f in individual_floats2]}")

        result_sum2 = sum_eight_fp32_from_hex(hex_inputs2)
        print(f"计算得到的总和 (Python float): {result_sum2:.8f}")

        # 将总和转换回FP32的十六进制表示
        sum_hex2 = fp32_to_hex(result_sum2)
        print(f"总和的FP32十六进制表示: {sum_hex2}") # 预期: 42100000 for 36.0
        print(f"验证总和的十六进制转回浮点数: {hex_to_fp32(sum_hex2):.8f}")

    except ValueError as e:
        print(f"错误: {e}")

    hex_inputs3 = [
        "3f8ccccd",  # 1.0
        "c00ccccd",  # 2.0
        "40533333",  # 3.0
        "c08ccccd",  # 4.0
        "40b00000",  # 5.0
        "c0d33333",  # 6.0
        "40f66666",  # 7.0
        "c10ccccd"   # 8.0
    ]
    print("--- 示例 3 ---")
    try:
        print(f"输入十六进制字符串: {hex_inputs3}")
        individual_floats3 = [hex_to_fp32(h) for h in hex_inputs3]
        print(f"转换后的FP32值: {[f'{f:.8f}' for f in individual_floats3]}")

        result_sum3 = sum_eight_fp32_from_hex(hex_inputs3)
        print(f"计算得到的总和 (Python float): {result_sum3:.8f}")

        # 将总和转换回FP32的十六进制表示
        sum_hex3 = fp32_to_hex(result_sum3)
        print(f"总和的FP32十六进制表示: {sum_hex3}") # 预期: 42100000 for 36.0
        print(f"验证总和的十六进制转回浮点数: {hex_to_fp32(sum_hex3):.8f}")

    except ValueError as e:
        print(f"错误: {e}")