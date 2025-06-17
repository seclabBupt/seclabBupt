# vcs+verdi使用介绍与案例讲解

参考链接：https://blog.csdn.net/JasonFuyz/article/details/107508893

https://www.bilibili.com/video/BV1hX4y137Ph

## 1 vcs+verdi使用介绍

### 1.1 vcs+verdi安装

vcs+verdi是常用的FPGA仿真软件，它需要在linux系统中使用，所以一般情况需要在虚拟机上部署。

具体的部署流程十分漫长，本人是跟着b站视频号**BV1x88rebEKC**后面进行安装。

对于安装有一些个人的建议：第一遍安装时，对于用户的名称和各个文件的位置尽量和视频的一致，等到之后安装熟练了就可以按自己的喜好安装了。

安装过程中也出现一些问题，我的问题是在安装到最后出现[ERROR] Could not checkout Verdi license. Use verdi -licdebug for more information问题，最后我看网上的解答说是没有将虚拟机和主机的时间对其，之后我调整了时间再重启就解决问题了。

如果遇到不能解决的问题，可以多去csdn上搜索一下相关的问题，或者去问问AI，不过AI的建议仅供参考，不一定要按照AI的建议修改，AI有时候会让你修改一些很底层的东西，导致你有些其他的功能无法使用。

### 1.2 verdi的使用

如果按照1.1推荐的视频进行安装的话，想要开启verdi，需要先进入终端，输入**lmg_synopsys**，之后输入verdi即可进入verdi界面。
![example picture](/images/verdi1.png)
<div style="text-align: center;">
verdi界面
</div>

接下来对verdi的使用进行讲解。

![example picture](/images/verdi2.png)
根据该图指示先点击左上角的file，之后点击Import Design...，进入选择界面。

![example picture](/images/verdi3.png)
根据这四步将你的文件导入到verdi中。

![example picture](/images/verdi4.png)
根据这三步来开始导入你的波形图。

![example picture](/images/verdi5.png)
根据这两步导入你需要观测的波形图，注意第一步需要双击。
不过双击后仍然没有波形图出现。所以还需要最后一步。

![example picture](/images/verdi6.png)
根据这两步即可成功输出波形。

## 2 vcs+verdi联合使用实例

### 2.1 反相器

反相器是一种基本且至关重要的​​逻辑门​​，它的核心功能是将取值取反，如果取值是0，则经过反相器之后变为1，如果取值不为0，则经过反相器后变为0，其真值表为：
|输入|输出|
|----|----|
| 0 | 1 |
| 1 | 0 |

接下来进行反相器的vcs+verdi实例介绍。

1.先在虚拟机的桌面创建一个文件夹，用来放置接下来要使用的文件。如果对于Linux的操作指令不熟悉的话可以直接右键创建，也可以用以下代码实现：
```verilog
cd Desktop     //进入桌面
mkdir Study  //创建名为Study的文件夹
cd Study    //进入Study
```
如果系统装了gvim就用gvim指令，如果没有就用vim指令。接下来使用统一的vim指令进行。

2.在Study文件夹里新建inv.v，tb_inv.v和timescale.v文件，其步骤与内容如下：
```verilog
vim inv.v
```
```verilog
module inv(
		A,
		Y
		);
input		A;
output		Y;
assign		Y=~A;
endmodule
```
完成inv.v的创建与内容编辑

```verilog
vim tb_inv.v
```
```verilog
//testbench
module inv_tb;
reg		aa;
wire		yy;
inv 		inv(
			.A(aa),
			.Y(yy)
			);

initial begin
		aa<=0;      //reg类型的的变量用<=
	#10	aa<=1;
	#10	aa<=0;
	#10	aa<=1;
	#10	$finish;
end

`ifdef FSDB
initial begin
	$fsdbDumpfile("tb_inv.fsdb");
	$fsdbDumpvars;
end
`endif

endmodule
```
完成tb_inv.v的创建与内容编辑。

**注**：要VCS与Verdi联合仿真，需要在testbench里面必须加入`ifdef FSDB到endif`的代码，这样才能生成fsdb文件提供Verdi读取，不然不会输出波形。

```verilog
vim timescale.v
```
```verilog
`timescale 1ns/10ps
```
完成timescale.v的创建与内容编辑。

之后在你文件的路径下运行
```verilog
vcs -R -full64 +v2k -fsdb +define+FSDB -sverilog inv.v tb_inv.v timescale.v -l run.log
```

之后在终端输入verdi，按照第1章的讲解进行操作即可获取波形，该代码的波形结果为：
![example picture](/images/inv1.png)

此外，本文分享一个测试起来更快（可能）的方法。

常规方法你需要复制vcs -R ... run.log一长串的代码，但是有一种方法可以不用打出每一个文件的名称，具体方法如下：
```verilog
cd Desktop/Study
vim file.f
```
file.f的内容为：
```verilog
tb_inv.v inv.v timescale.v
```
这样file.f的文件内就包含了这三个文件的名称，之后在终端输入：
```verilog
vcs -R -full64 +v2k -fsdb +define+FSDB -sverilog -f file.f -l run.log
```
当然，还有更简便的用法，不过我暂时没有研究，有待后续补充。

### 2.2 与非门

在数字逻辑电路中，​​与非门​​（NAND Gate）是最重要、最常用的​​复合逻辑门​​之一。它的名称来源于其功能：​​先执行“与”操作，再执行“非”操作​​。其真值表为：
|输入A|输入B|输出Y|
|----|----|----|
| 0 | 0 | 1 |
| 1 | 0 | 1 |
| 0 | 1 | 1 |
| 1 | 1 | 0 |

接下来我将各个部分代码贴出，具体测试流程与2.1一致。
nand.v:
```verilog
module nand_gate(
		A,
		B,
		Y
		);
input		A;
input		B;
output		Y;

assign		Y=~(A&B); //先与后非
endmodule
```

tb_nand.v:
```verilog
//testbench
module nand_gate_tb;
reg		aa,bb;
wire		yy;
nand_gate 	nand_gate(
			.A(aa),
			.B(bb),
			.Y(yy)
			);

initial begin
		aa<=0;bb<=0;
	#10	aa<=0;bb<=1;
	#10	aa<=1;bb<=0;
	#10	aa<=1;bb<=1;
	#10	$finish;
end

`ifdef FSDB
initial begin
	$fsdbDumpfile("tb_nand.fsdb");
	$fsdbDumpvars;
end
`endif

endmodule
```

定时与2.1一致。
最后结果展示：
![example picture](/images/nand1.png)

### 2.3 四位与非门

四位与非门是与非门​的进阶版，具体是什么意思举个例子就可以：
A = 4'b0011
B = 4'b1110
C = ~(A&B) = 4'b1101
四位与非门就是将每一位进行与非计算，最后和到一起就可以。

接下来我将各个部分代码贴出，具体测试流程与2.1一致。
nand_4bits.v:
```verilog
module nand_gate_4bits(
		A,
		B,
		Y
		);
input[3:0]	A;
input[3:0]	B;
output[3:0]	Y;

assign		Y=~(A&B); //先与后非
endmodule
```

tb_nand_4bits.v:
```verilog
//testbench
module nand_gate_4bits_tb;
reg[3:0]	aa,bb;
wire[3:0]	yy;
nand_gate_4bits 	nand_gate_4bits(
			.A(aa),
			.B(bb),
			.Y(yy)
			);

initial begin
		aa<=4'b0000;bb<=4'b1111;
	#10	aa<=4'b0010;bb<=4'b0110;
	#10	aa<=4'b0111;bb<=4'b0100;
	#10	aa<=4'b1111;bb<=4'b1110;
	#10	$finish;
end

`ifdef FSDB
initial begin
	$fsdbDumpfile("tb_nand.fsdb");
	$fsdbDumpvars;
end
`endif

endmodule
```

定时与2.1一致。
最后结果展示：
![example picture](/images/nand2.png)




