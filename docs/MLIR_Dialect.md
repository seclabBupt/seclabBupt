
**参考资料**

https://github.com/KEKE046/mlir-tutorial

https://www.bilibili.com/video/BV1JCZzYFEEJ/?share_source=copy_web&vd_source=4d9d633c1e01e9c9b929fe8311e2ad5b



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