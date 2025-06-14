
**参考资料**

https://github.com/KEKE046/mlir-tutorial

https://www.bilibili.com/video/BV1JCZzYFEEJ/?share_source=copy_web&vd_source=4d9d633c1e01e9c9b929fe8311e2ad5b


# 一、自定义Dialect


## 1. 定义 Dialect
### 1.1 概念解释
在 MLIR 中，Dialect 是语法单位的命名空间（Namespace），用来组织和管理一组相关的操作（Operations）、类型（Types）、属性（Attributes）等。通过 Dialect，可以将 DSL（如 Toy、Tiny、深度学习中间表示）表示成 MLIR 的形式。

**举例**
```
例1：arith Dialect  mlir定义的一个Dialecet，有很多个
负责基础算术指令：arith.addi, arith.muli, arith.constant 等
类型支持如 i32, f32

例2：自定义的 mydialect 
可以定义指令Op，如 mydialect.my_add, mydialect.my_relu
也可以定义类型：如张量类型、量化类型等
```
### 1.2 定义 Dialect 描述文件（TableGen）
`MyDialect.td`
```tablegen
def MyDialect : Dialect {
  let name = "mydialect";
  let cppNamespace = "::mydialect";
}
```
解释：

(1)def MyDialect：定义了一个名为 MyDialect 的 Dialect。

(2)let name = "mydialect"：这个 Dialect 的 MLIR 名称空间是 mydialect，最终在 .mlir 文件中写的操作前缀会是 mydialect.xxx。

(3)let cppNamespace = "::mydialect"：告诉生成的 C++ 代码要使用的命名空间是 
mydialect，这样生成的类型、操作等都在这个命名空间中。

### 1.3 使用 mlir-tblgen 生成头文件和源文件
```bash
mlir-tblgen MyDialect.td --gen-dialect-decls -o include/my_dialect/
mlir-tblgen MyDialect.td --gen-dialect-defs -o lib/my_dialect/
```
解释：

--gen-dialect-decls：生成 MyDialect.h.inc，声明 Dialect 类。

--gen-dialect-defs：生成 MyDialect.cpp.inc，定义 Dialect 的基础行为（注册等）。


**生成结构**
```c++
// include/my_dialect/MyDialect.h
namespace mlir {
namespace mydialect {

class MyDialect : public ::mlir::Dialect {
  ...
};

} // namespace mydialect
} // namespace mlir

```
这些 .inc 文件是手写 .h/.cpp 引用，不能单独用。


### 1.4 实现 Dialect 类（MyDialect.cpp）
**实现 MyDialect 初始化逻辑**
```c++
#include "my_dialect/MyDialect.h"
#include "my_dialect/MyOps.h"
#include "my_dialect/MyTypes.h"
#include "my_dialect/MyAttributes.h"

using namespace mlir;
using namespace mydialect;

void MyDialect::initialize() {
  addOperations<
    #include "my_dialect/MyOps.cpp.inc"
  >();

  addTypes<
    #include "my_dialect/MyTypes.cpp.inc"
  >();

  addAttributes<
    #include "my_dialect/MyAttributes.cpp.inc"
  >();
}

```
*说明：这里是添加Op、Types、Attrbutes的部分，后面会讲*
addOperations：注册所有定义在 MyOps.td 中的操作
addTypes：注册所有自定义类型
addAttributes：注册所有自定义属性
## 2. 定义 Type
### 2.1 概念解释
MLIR 的类型系统是高度可扩展的，可以为 Dialect 定义任意复杂的类型，比如：
标量类型（如整数、浮点），张量类型（如 tensor<3x3xf32>），自定义结构类型（如量化类型、分布式类型等）

**定义流程**
### 2.2 定义 Type 描述
**MyTypes.td**
```c++
def MyType : TypeDef<MyDialect, "MyType"> {
  let summary = "A simple custom type";
  let description = [{
    This is a custom type for demonstration, like `!mydialect.mytype`.
  }];

  let mnemonic = "mytype"; 
  let parameters = (ins
    "int":$width,
    "mlir::Type":$elementType
  );
}

```
**解释：**
MyType 是类型名

TypeDef<..., "..."> 表示这是一个 Type，挂载在 MyDialect 上

mnemonic = "mytype" 表示源码中可写为 !mydialect.mytype<...>

parameters 是这个类型的内部结构，比如包含一个整数 width 和一个 elementType

**这段 TableGen 会生成：**

类型类（如 MyType）继承自 mlir::TypeBase

自动的访问器 getWidth(), getElementType()

构造函数 MyType::get(width, elementType, context)

### 2.3 使用 mlir-tblgen 生成代码
```tablegen
mlir-tblgen MyTypes.td --gen-typedef-decls -o include/my_dialect/
mlir-tblgen MyTypes.td --gen-typedef-defs -o lib/my_dialect/

```

### 2.4 编写 MyTypes.h 和 MyTypes.cpp
### 2.5 注册到 Dialect 中（MyDialect.cpp）
```c++
void MyDialect::initialize() {
  addTypes<
    #include "my_dialect/MyTypes.cpp.inc"
  >();
}
```

## 3. 定义 Attribute

### 3.1 概念解释
Attribute（属性） 是操作的元信息，它常用于传递参数、常量或配置，可以是内建类型（如整数、字符串），也可以是自定义的结构化类型

**定义流程**
### 3.1 编写 TableGen 文件
**MyAttributes.td**

```c++
def MyAttr : AttrDef<MyDialect, "MyAttr"> {
  let summary = "Custom attribute with an integer and type";
  let description = [{
    A custom attribute with a width and a type field.
    Example: #mydialect.myattr<42, f32>
  }];

  let mnemonic = "myattr";

  let parameters = (ins
    "int":$width,
    "mlir::Type":$elemType
  );
}

```
**解释：**
AttrDef<...>：定义一个 Attribute 类型

mnemonic = "myattr"：表示语法中为 #mydialect.myattr<...>

parameters：定义这个 Attribute 拥有的结构字段

### 3.2 使用 mlir-tblgen 生成头文件和定义文件
```bash
mlir-tblgen MyAttributes.td --gen-attrdef-decls -o include/my_dialect/
mlir-tblgen MyAttributes.td --gen-attrdef-defs -o lib/my_dialect/

```

### 3.3 编写c++文件
### 3.4 在Dailect中注册Attribute

```c++
addAttributes<
  #include "my_dialect/MyAttributes.cpp.inc"
>();
```
## 4. 定义 Operation

### 4.1 概念解释
MLIR 中每一个操作都是一个 Op 实例，它包含信息：操作名（如 mydialect.add），操作数 operands（输入），结果 results（输出），属性 attributes
，类型信息，可选的 region 和 block。
一个 Operation 类似于这样：
```mlir
%res = mydialect.add %a, %b : i32
```
**定义Op流程**
### 4.2  MyOps.td 中定义 Operation
**MyOps.td**
```c++
def MyAddOp : MyDialect_Op<"add", [Pure]> {
  let summary = "Add two integers";
  let description = [{
    Performs integer addition of two 32-bit values.
  }];

  let arguments = (ins I32:$lhs, I32:$rhs);
  let results = (outs I32:$result);

  let assemblyFormat = "$lhs `,` $rhs attr-dict `:` type($result)";
}
```
**解释：**
def MyAddOp：Op 名称

最终 MLIR 中使用为：mydialect.add

MyDialect_Op<...>：继承自 Dialect 定义

自动将此 Op 注册到 mydialect 中

[Pure]：Traits表示此操作没有副作用（side effects）

arguments：输入参数
```tablegen
(ins I32:$lhs, I32:$rhs)
// 输入为两个 32-bit 整数类型的 SSA 值，名称为 lhs 和 rhs
```
results：输出结果
```tablegen
(outs I32:$result)
//结果是一个 32-bit 整数，绑定变量名 result
```
assemblyFormat,定义了 .mlir 中的语法格式，例如：
```
%res = mydialect.add %a, %b : i32
```

### 4.3 生成c++文件
使用 mlir-tblgen 生成头文件和源文件
```bash
mlir-tblgen MyOps.td --gen-op-decls -o include/my_dialect/
mlir-tblgen MyOps.td --gen-op-defs -o lib/my_dialect/
```
**生成内容：**

MyOps.h.inc：声明 Op 类（如 MyAddOp），带有自动生成的构造器、访问器、验证器等

MyOps.cpp.inc：定义 Op 的基础功能（如打印、解析等）

### 4.4  写 MyOps.h 和 MyOps.cpp
**MyOps.h**
**MyOps.cpp**

### 4.5在Dialect中注册
```c++
void MyDialect::initialize() {
  addOperations<
    #include "my_dialect/MyOps.cpp.inc"
  >();
}
```

### 4.6 测试Op
创建 .mlir 测试文件（test/my_ops.mlir）：
```mlir
module {
  %a = arith.constant 10 : i32
  %b = arith.constant 32 : i32
  %res = mydialect.add %a, %b : i32
}

```
用mlir-opt测试
```bash
mlir-opt test/my_ops.mlir -load-pass-plugin ./MyDialect.so -some-pass

```



# 二、MLIR附带dialect
| Dialect   | 作用                   | 举例                                   |
| --------- | -------------------- | ------------------------------------ |
| `builtin` | 提供基础元素，如 module、func | `module`, `func.func`, `func.return` |
| `arith`   | 标量计算，如加法、乘法          | `arith.addf`, `arith.constant`       |
| `scf`     | 控制流，如 for、if、while   | `scf.for`, `scf.if`                  |
| `memref`  | 显式内存管理               | `memref.alloc`, `memref.load`        |
| `tensor`  | 隐式内存、张量类型            | `tensor.extract`, `tensor.insert`    |
| `linalg`  | 高层次张量操作（线性代数）        | `linalg.matmul`, `linalg.generic`    |
| `cf`      | 低层次控制流               | `cf.br`, `cf.cond_br`（非结构化）          |


## 1. builtin Dialect 详解（内建 Dialect）
### 1.1 定义
builtin 是 MLIR 的内建基础 Dialect。它提供了最核心的抽象元素：module、func、tensor、基本类型等。几乎任何 MLIR 代码都会用到它，即使是自定义 Dialect也要建立在它提供的结构上。

不是通过 TableGen 来定义 Op 的 Dialect（不像 arith 或 linalg），而是直接由 MLIR 核心写死的基础内容，因此叫“builtin”。

### 1.2 提供内容
**主要OP**

`builtin.module` 和`func.func` 最常用。module 是顶层容器，代表一段 IR 单元。不支持嵌套，一个 module 内不能再有 module,通常作为 mlir-opt 或 mlir-translate 的输入单元。`func`是函数Op，可以包含多个 block。
| Op                                   | 说明                                                                     |
| ------------------------------------ | ---------------------------------------------------------------------- |
| `builtin.module`                     | 模块顶层容器                   |
| `func.func`                          | 函数定义，包含参数、返回值、函数体。<br>（虽然形式上属于 `func` Dialect，但内嵌在 `builtin.module` 中） |
| `builtin.unrealized_conversion_cast` | IR 变换中的“虚转换”，用于类型未解决的桥接。<br>（高级用法）                                     |

**主要类型Type**

这些都是内建的类型，都是由 builtin Dialect 统一提供。
| 类型                         | 示例                  | 说明                     |
| -------------------------- | ------------------- | ---------------------- |
| `i32`, `i64`, `f32`, `f64` | `i32`, `f32`        | 基本整数和浮点类型              |
| `function`                 | `(f32, f32) -> f32` | 函数类型，用于 `func.func` 声明 |

### 1.3 示例
```
module {
  func.func @add(%arg0: f32, %arg1: f32) -> f32 {
    %sum = arith.addf %arg0, %arg1 : f32
    return %sum : f32
  }
}

```
说明：
- module {} 是顶层结构，由 builtin.module 提供。

- 里面可以包含一个或多个函数 func.func。

- 所有的变量如 %arg0、%sum 都是 SSA 变量

## 2. arith Dialect（算术运算 Dialect）

### 2.1 定义
arith 是 MLIR 中用于标量级算术运算的 Dialect。提供了熟悉的加、减、乘、除、取反、比较等基础操作。对应于 C 语言中的 + - * / == < > 等操作，是编写任何需要“数值运算”的 MLIR 程序的基础。

### 2.2 提供内容
**主要Op**
**基础运算类**
| 操作 | Op 名                             | 示例                             |
| -- | -------------------------------- | ------------------------------ |
| 加法 | `arith.addi` / `arith.addf`      | `%r = arith.addi %a, %b : i32` |
| 减法 | `arith.subi` / `arith.subf`      | `%r = arith.subf %a, %b : f32` |
| 乘法 | `arith.muli` / `arith.mulf`      | `%r = arith.muli %a, %b : i64` |
| 除法 | `arith.divsi`（有符号）/ `arith.divf` | `%r = arith.divf %a, %b : f32` |

**常量定义类**

一个 Op 实现了所有标量常量定义，支持任意整数、浮点值。
| 操作   | Op 名             | 示例                                |
| ---- | ---------------- | --------------------------------- |
| 整数常量 | `arith.constant` | `%c1 = arith.constant 1 : i32`    |
| 浮点常量 | `arith.constant` | `%cf = arith.constant 3.14 : f32` |

**比较类**
| 操作   | Op 名         | 示例                                    |
| ---- | ------------ | ------------------------------------- |
| 浮点比较 | `arith.cmpf` | `%cmp = arith.cmpf olt, %a, %b : f32` |
| 整数比较 | `arith.cmpi` | `%cmp = arith.cmpi slt, %a, %b : i32` |

### 2.3 示例
**(1)表示 5 + 3 = 8，类型是 i32。这些值都会被寄存在 SSA 变量中。**
```mlir
%a = arith.constant 5 : i32
%b = arith.constant 3 : i32
%r = arith.addi %a, %b : i32

```
**(2)比较 3.0 < 5.0，返回一个 i1 布尔值（true/false 表示结果）。**
```
%f1 = arith.constant 3.0 : f32
%f2 = arith.constant 5.0 : f32
%cond = arith.cmpf olt, %f1, %f2 : f32

```
**(3)函数内计算**
```
func.func @example() -> i32 {
  %c1 = arith.constant 1 : i32
  %c2 = arith.constant 2 : i32
  %sum = arith.addi %c1, %c2 : i32
  return %sum : i32
}
```

## 3 scf Dialect (Structured Control Flow)
### 3.1. 定义
scf提供了 MLIR 中的控制流结构：循环、分支、条件跳转。不是类似汇编那样的“goto”风格，而是更像高级语言里的 if、for、while 结构，结构化，没有 scf Dialect就没法写有控制逻辑的 MLIR 程序。

### 3.2 提供内容
**常用Op**
| Op 名                 | 用途            | 类比 C 语言                           |
| -------------------- | ------------- | --------------------------------- |
| `scf.if`             | 条件执行分支        | `if (cond) {...} else {...}`      |
| `scf.for`            | 有边界的计数循环      | `for (i = lb; i < ub; i += step)` |
| `scf.while`          | 条件控制的循环       | `while (cond) {...}`              |
| `scf.yield`          | 返回循环体或分支块的结果值 | 类似 `return`                       |
| `scf.execute_region` | 封闭可嵌套计算块      | 用于嵌套或 region 封闭操作                 |

### 3.3 使用示例
**计数循环**
%i 是循环变量，循环从 0 到 <10（不含10），步长为1每次循环中执行一次 %i + %i 的计算
```
%zero = arith.constant 0 : i32
%ten = arith.constant 10 : i32
%step = arith.constant 1 : i32

scf.for %i = %zero to %ten step %step {
  %val = arith.addi %i, %i : i32
}

```
**条件语句**
条件判断基于 arith.cmpi / cmpf 等比较结果
```mlir
%a = arith.constant 5 : i32
%b = arith.constant 10 : i32
%cond = arith.cmpi slt, %a, %b : i32

scf.if %cond {
  %r = arith.addi %a, %b : i32
} else {
  %r = arith.subi %b, %a : i32
}

```

**条件循环**
```mlir
%res = scf.while (%i = %init) : (i32) -> (i32) {
  %cond = arith.cmpi slt, %i, %limit : i32
  scf.condition(%cond) %i : i32
} do {
  %next = arith.addi %i, %one : i32
  scf.yield %next : i32
}
```
**scf.yield**

在 scf.for、scf.if、scf.while 的 region 中，用于显式返回结果。多数控制结构都需要一个 scf.yield 作为 region 的结束。比如上面的案例
```mlir
scf.for %i = %a to %b step %c {
  ...
  scf.yield
}

```

## 4. memref Dialect(Memory Reference)
### 4.1 定义
memref 是 MLIR 中描述内存布局与访问的专用 Dialect。主要负责 MLIR 程序中的内存分配（allocate）、内存访问（load/store）等操作。

### 4.2 内容
**常见Op**
| Op 名称                     | 作用简介                       |
| ------------------------- | -------------------------- |
| `memref.alloc`            | 在堆上动态分配一段内存        |
| `memref.alloca`           | 在栈上分配内存                    |
| `memref.dealloc`          | 显式释放之前分配的内存                |
| `memref.load`             | 从 memref 内读取值              |
| `memref.store`            | 将值写入 memref                |

**常见Type**
| Type 名称                         | 示例                                            | 含义说明                         |
| ------------------------------- | --------------------------------------------- | ---------------------------- |
| `memref<shape x element>`       | `memref<4x4xf32>`                             | 多维数组，带形状和元素类型                |
| `memref<?x?xi32>`               | `?` 表示动态维度                                    | 动态维度 memref                  |
| `memref<...> with layout`       | `memref<2x3xf32, affine_map<...>>`            | 带自定义访问规则的 memref（布局）         |
| `memref<...> with strides`      | `memref<2x3xf32, strided<[?, ?], offset: ?>>` | 显式指定内存布局（通过 strides）         |
| `memref<...> with memory space` | `memref<4xf32, 1>`                            | 在特定内存空间（如 GPU global memory） |

### 4.3 使用案例
```mlir
module {
  func.func @matrix_example() {
    // 分配一个 4x4 的浮点型矩阵：memref<4x4xf32>
    %matrix = memref.alloc() : memref<4x4xf32>

    // 定义常数：浮点数和索引
    %cst = arith.constant 1.0 : f32
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %c2 = arith.constant 2 : index
    %c3 = arith.constant 3 : index

    // 将矩阵左上角元素 [0, 0] 赋值为 1.0
    memref.store %cst, %matrix[%c0, %c0] : memref<4x4xf32>

    // 从 [0, 0] 读取并写入到 [1, 1] 位置（拷贝一份）
    %val = memref.load %matrix[%c0, %c0] : memref<4x4xf32>
    memref.store %val, %matrix[%c1, %c1] : memref<4x4xf32>

    // 提取一个从 [1, 1] 开始的 2x2 子矩阵
    %sub = memref.subview %matrix[%c1, %c1] [2, 2] [1, 1] :
      memref<4x4xf32> to memref<2x2xf32, strided<[?, ?], offset: ?>>

    // 获取矩阵的第一个维度大小
    %dim0 = memref.dim %matrix, %c0 : memref<4x4xf32>

    // 类型转换：将静态 memref 转换为动态形状 memref<?x?xf32>
    %casted = memref.cast %matrix : memref<4x4xf32> to memref<?x?xf32>

    // 释放分配的矩阵
    memref.dealloc %matrix : memref<4x4xf32>

    return
  }
}

```

## 5. tensor Dialect
### 5.1 定义
tensor Dialect 提供了一组操作和类型，用来描述不可变（immutable）的多维张量。

### 5.2 内容
**常见Op**
| Op 名称                   | 作用简介                       |
| ----------------------- | -------------------------- |
| `tensor.empty`          | 创建一个空张量（用于构建新张量）           |
| `tensor.extract`        | 从张量中提取一个元素                 |
| `tensor.insert`         | 向张量中插入一个元素                 |
| `tensor.generate`       | 通过映射函数生成一个新张量              |
| `tensor.cast`           | 张量类型转换（静态/动态大小转换）          |
| `tensor.extract_slice`  | 提取张量的一个切片（类似 numpy 切片）     |
| `tensor.insert_slice`   | 将一个张量插入到另一个张量的子块中          |
| `tensor.dim`            | 获取张量某一维的大小                 |
| `tensor.reshape`        | 重塑张量形状（不同于 memref.reshape） |
| `tensor.expand_shape`   | 增加维度（广播式）                  |
| `tensor.collapse_shape` | 降低维度（压缩）                   |

**常见Type**
| Type 名称                   | 示例                | 含义说明                   |
| ------------------------- | ----------------- | ---------------------- |
| `tensor<shape x type>`    | `tensor<4x4xf32>` | 固定形状的张量                |
| `tensor<?x?xf32>`         | 动态形状张量            | ? 表示维度在运行时确定           |
| `tensor<*xf32>`           | rank 不定张量         | 任意维度，常用于通用张量函数或占位符     |

### 5.3 案例
构建一个张量，读取、修改和切片
```mlir
func.func @tensor_example(%arg0: index, %arg1: index) -> tensor<4xf32> {
  %c0 = arith.constant 0 : index
  %c1 = arith.constant 1 : index
  %cst = arith.constant 1.0 : f32

  // 1. 创建空张量：tensor<4xf32>
  %tensor = tensor.empty() : tensor<4xf32>

  // 2. 插入元素到 index=1 的位置
  %tensor2 = tensor.insert %cst into %tensor[%c1] : tensor<4xf32>

  // 3. 提取 index=1 的值
  %val = tensor.extract %tensor2[%c1] : f32

  // 4. 获取张量维度
  %dim = tensor.dim %tensor2, %c0 : index

  // 5. 提取一个切片（从1开始，取2个）
  %slice = tensor.extract_slice %tensor2[1] [2] [1] : 
      tensor<4xf32> to tensor<2xf32>

  return %tensor2 : tensor<4xf32>
}

```
## 6 linalg Dialect
### 6.1 定义
linalg（Linear Algebra Dialect）提供了线性代数层级的操作描述，是 MLIR 中进行深度学习建模与优化的主要中间表示（IR）框架，表达张量/矩阵的操作（点乘、矩阵乘、卷积等）。

### 6.2 内容
**常见Op**
| Op 名称                      | 作用简述                        |
| -------------------------- | --------------------------- |
| `linalg.matmul`            | 标准矩阵乘法（2D \* 2D -> 2D）      |
| `linalg.batch_matmul`      | 批处理矩阵乘法                     |
| `linalg.fill`              | 用常数填充张量                     |
| `linalg.generic`           | 通用 N 维张量操作（自定义计算）           |
| `linalg.indexed_generic`   | 与 `generic` 类似，但支持 index 访问 |
| `linalg.conv_2d_nhwc_hwcf` | 卷积操作（常见于 CNN）               |
| `linalg.transpose`         | 转置张量                        |

**linalg中没有定义新的Type，和tensor、memref这两个dialect里的类型搭配使用**

### 6.3 示例
用 linalg.fill 创建常量张量
```mlir
func.func @fill_tensor(%cst: f32) -> tensor<4x4xf32> {
  %empty = tensor.empty() : tensor<4x4xf32>
  %filled = linalg.fill ins(%cst: f32) outs(%empty: tensor<4x4xf32>) -> tensor<4x4xf32>
  return %filled : tensor<4x4xf32>
}

```