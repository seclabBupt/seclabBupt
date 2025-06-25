# FIFO学习

## 什么是FIFO

FIFO（First-In, First-Out，先入先出队列）是一种数据结构。\
FIFO存储器是系统的缓冲环节，主要有几方面的功能：

1. 对连续的数据流进行缓存，防止在进机和存储操作时丢失数据；
2. 数据集中起来进行进栈和存储，可避免频繁的总线操作，减轻CPU的负担；
3. 允许系统进行DMA操作，提高数据的传输速度。这是至关重要的一点，如果不采用DMA操作，数据传输将达不到传输要求，而且大大增加CPU的负担，无法同时完成数据的存储工作。

---

## FIFO有什么用

1. 作为数据缓存
2. 处理数据跨时钟域问题

> 解决一个系统多个时钟所带来的问题：异步时钟之间的接口电路。  
> 对于不同宽度的数据接口也可以使用FIFO。

---

## FIFO的原理

### FIFO要解决的问题

1. 怎么做跨时钟域处理？读写模块时钟不同。➡如何保证读写数据正确？是FIFO主要解决的问题。⬅用格雷码来对付。在跨时钟域问题数据很容易出现亚稳态状态。（数值跳变不是瞬时变化，上升沿是一个过程，跨时钟域数据导致采样点出现在上升沿位置，时钟之间有延时，导致信号不确定是0或1的状态，就是亚稳态。）格雷码每个码之间只有一个bit的变化，降低了亚稳态的几率。
2. 读写数据的控制以及空满信号的准确生成。通过一读一写两个模块实现[空、满信号产生逻辑](#空满信号产生逻辑)。

### 格雷码

格雷码，又叫循环二进制码或反射二进制码，格雷码是我们在工程中常会遇到的一种编码方式，它的基本的特点就是任意两个相邻的代码只有一位二进制数不同。格雷码应用在系统中可以提高数据读取的稳定性。为了应用格雷码就需要实现普通二进制码到格雷码的转换。

#### 二进制码转化为格雷码的规则

1. 二进制码右移一位；
2. 右移后结果与源码异或加/模二加。\
根据规则写出对应代码[跳转到代码](#二进制码转格雷码)。

### 空、满信号产生逻辑

核心是写端口&读端口；读的地址传给写模块，写的地址传给读模块，用来产生满信号&空信号。读地址追上了写地址就是满信号；写地址追上了读地址就是空信号。

#### 数据地址控制

读/写一位数据时，读/写地址同步+1，再转化成格雷码。读、写地址互相追赶，以它们的相对位置判断空、满信号。读地址rd_addr追上了写地址wr_addr就是空信号；写地址追上了读地址就是满信号。地址前加一位用来判断空/满信号，不同码（普通二进制码/格雷码）有不同的判断标准，相比额外添加标志符更能体现二进制的优势，优雅简洁。
![空满信号产生逻辑](./images/FIFO_signal.png)\
注：相同位置/码相同则为空信号；（二进制）最高位相反、其余位相同/（格雷码）高两位相反、低两位相同，则为满信号。（以4bit数据为例）

### FIFO的实现

首先需要一个缓存[RAM模块](#ram模块)，主要功能是根据读控制信号、写控制信号以及空信号和满信号读出和写入数据。\
其次需要一读一写两个控制模块，主要功能是记录读/写地址变化、生成空满信号。//empty信号由[读模块](#读模块)控制，full信号由[写模块](#写模块)控制。\
![FIFO模块](./images/FIFO_module.png)\
> //读写模块中还涉及二进制码到格雷码的转换，需要一个额外的子模块bin2grey_module[跳转到代码](#二进制码转格雷码)。\
> //最终控制读写数据的使能信号由读写控制指令和空满信号共同决定，即空不能读，满不能写。这一功能可以放在RAM模块中实现，也可以放在读写模块中实现。

---

## Verilog 编程练习：设计一个参数化的同步FIFO

以Verilog编程练习为例学习FIFO。

### 目标

- 掌握同步时序逻辑设计。
- 学习使用参数（parameter）进行模块化和可重用设计。
- 理解FIFO（First-In, First-Out，先入先出队列）的工作原理。
- 掌握基本状态信号（空、满）的产生逻辑。
- 练习编写简单的Verilog测试平台（Testbench）。

### 同步时序电路设计基本步骤

![同步时序电路设计基本步骤](./images/FIFO_study.png)\

### 主要参数

**宽度（WIDTH）：**FIFO每个地址的数据位宽（W）；\
**深度（DEEPTH）：**FIFO可以存储多少个W位的数据；//默认是2的幂次方\
**满（full）标志：**FIFO已满时，会输出一个对写操作的反压信号，以阻止被继续写入数据而溢出；\
**空（empty）标志：**FIFO已空时，会输出一个对读操作的反压信号，以避免被继续读出无效数据；\
**读/写时钟：**读/写操作所遵循的时钟，每个时钟沿触发。\
> WIDTH×DEEPTH=总数据

---

## FIFO的Verilog代码

实现代码如下。\
主要分成3个模块实现+一个top_module顶层模块+一个bin2gray_module子模块

### 写模块

```verilog
//code
`timescale 1ns / 1ps
module write_ctrl#(
    parameter   DATA_DEEPTH     =   'd8
)(
    input       i_wr_clk        ,
    input       i_wr_rst        ,
    
    input       i_wr_en         ,
    output      o_wr_full       ,
    output      o_ram_addr      ,
    output      o_ram_en        ,
    
    input       i_rd2wr_addr    ,   //收写模块一个读地址，用来判断空满信号
    output      o_wr2rd_addr        //给读模块一个写地址，用来判断空满信号
    );
    /*************start****************/  
    function integer clogb2(input integer number);             //计算地址位宽的函数，vivado可用
        for(clogb2 = 0 ; number > 0 ; clogb2 = clogb2 + 1)
        begin
            number = number >> 1;
        end
    endfunction
    /************parameter*************/
    localparam ADDR_WIDTH = clogb2(DATA_DEEPTH - 1);            //8是1000，实际上从0开始，以111（7）表示8，所以DATA_DEEPTH - 1//'d3;//
    /**************port****************/
    wire                            i_wr_clk        ;
    wire                            i_wr_rst        ;
    wire                            i_wr_en         ;
    wire                            o_wr_full       ;
    wire      [ADDR_WIDTH - 0 : 0]  o_ram_addr      ;
    wire                            o_ram_en        ;
    wire      [ADDR_WIDTH - 0 : 0]  i_rd2wr_addr    ;
    wire      [ADDR_WIDTH - 0 : 0]  o_wr2rd_addr    ;
    /*************machine**************/
    
    /**************reg*****************/
    reg       [ADDR_WIDTH - 0 : 0]  r_addr_cnt      ;       //计数器，需要转化成Gray码
    reg       [ADDR_WIDTH - 0 : 0]  r_gray_addr     ;
    /**************wire****************/  
    wire      [ADDR_WIDTH - 0 : 0]  w_gray_addr     ;
    /*************assign***************/
    assign o_ram_addr   =   r_addr_cnt              ;       //ram的两个控制位，传进来
    assign o_ram_en     =   i_wr_en & !o_wr_full    ;
    assign o_wr2rd_addr =   r_gray_addr             ;
    assign o_wr_full    =   (w_gray_addr == {~i_rd2wr_addr[ADDR_WIDTH],~i_rd2wr_addr[ADDR_WIDTH - 1],i_rd2wr_addr[ADDR_WIDTH - 2:0]});
    //assign o_wr_full    =   (i_rd2wr_addr == {~w_gray_addr[ADDR_WIDTH],~w_gray_addr[ADDR_WIDTH - 1],w_gray_addr[ADDR_WIDTH - 2:0]});
                                                            //满信号判断,高两位相反，低两位相同，则满
    /************component*************/
    bin2gray_module#(
        .WIDTH          (ADDR_WIDTH     )
    )
    bin2gray_module_u0                                      //计数器二进制码->写地址格雷码
    (
        .i_bin          (r_addr_cnt     ),
        .o_gray         (w_gray_addr   )
    );
    /*************always***************/
    always@(posedge i_wr_clk)              //写入使能信号，地址计数器+1
        if(i_wr_rst)
            r_addr_cnt <= 'd0;
        else if(i_wr_en)
            r_addr_cnt <= r_addr_cnt + 1;
        else
            r_addr_cnt <= r_addr_cnt;
    always@(posedge i_wr_clk)              //地址格雷码o_wr2rd_addr = r_gray_addr <= w_gray_addr
        if(i_wr_rst)
            r_gray_addr <= 'd0;
        else if(i_wr_en)
            r_gray_addr <= w_gray_addr;
        else
            r_gray_addr <= r_gray_addr;
endmodule
```

### 读模块

```verilog
//code
`timescale 1ns / 1ps
module read_ctrl#(
    parameter   DATA_DEEPTH     =   'd8
)(
    input       i_rd_clk        ,
    input       i_rd_rst        ,
    
    input       i_rd_en         ,
    output      o_rd_empty      ,
    output      o_ram_addr      ,
    output      o_ram_en        ,
    
    input       i_wr2rd_addr    ,   //收读模块一个写地址，用来判断空满信号
    output      o_rd2wr_addr        //给写模块一个读地址，用来判断空满信号
    );
    /*************start****************/  
    function integer clogb2(input integer number);             //计算地址位宽的函数，vivado可用
        for(clogb2 = 0 ; number > 0 ; clogb2 = clogb2 + 1)
        begin
            number = number >> 1;
        end
    endfunction
    /************parameter*************/
    localparam ADDR_WIDTH = clogb2(DATA_DEEPTH - 1);            //8是1000，实际上从0开始，以111（7）表示8，所以DATA_DEEPTH - 1
    /**************port****************/
    wire                            i_rd_clk        ;
    wire                            i_rd_rst        ;
    wire                            i_rd_en         ;
    wire                            o_rd_empty      ;
    wire      [ADDR_WIDTH - 0 : 0]  o_ram_addr      ;
    wire                            o_ram_en        ;
    wire      [ADDR_WIDTH - 0 : 0]  i_wr2rd_addr    ;
    wire      [ADDR_WIDTH - 0 : 0]  o_rd2wr_addr    ;
    /*************machine**************/
    
    /**************reg*****************/
    reg       [ADDR_WIDTH - 0 : 0]  r_addr_cnt      ;       //计数器，需要转化成Gray码
    reg       [ADDR_WIDTH - 0 : 0]  r_gray_addr     ;
    /**************wire****************/  
    wire      [ADDR_WIDTH - 0 : 0]  w_gray_addr    ;
    /*************assign***************/
    assign o_ram_addr   =   r_addr_cnt              ;       //ram的两个控制位，传进来
    assign o_ram_en     =   i_rd_en & !o_rd_empty   ;
    assign o_rd2wr_addr =   r_gray_addr             ;
    //assign o_rd_empty   =   (o_rd2wr_addr == i_wr2rd_addr);   //满信号判断,相同则空
    assign o_rd_empty   =   (r_gray_addr == i_wr2rd_addr);   //满信号判断,相同则空
    //assign o_rd_empty   =   0;
    /************component*************/
    bin2gray_module#(
        .WIDTH          (ADDR_WIDTH     )
    )
    bin2gray_module_u0                                      //计数器二进制码->写地址格雷码
    (
        .i_bin          (r_addr_cnt     ),
        .o_gray         (w_gray_addr    )
    );
    /*************always***************/
    always@(posedge i_rd_clk)              //读出使能信号，地址计数器+1
        if(i_rd_rst)
            r_addr_cnt <= 'd0;
        else if(i_rd_en)
            r_addr_cnt <= r_addr_cnt + 1;
        else
            r_addr_cnt <= r_addr_cnt;
    always@(posedge i_rd_clk)
        if(i_rd_rst)
            r_gray_addr <= 'd0;
        else if(i_rd_en)
            r_gray_addr <= w_gray_addr;
        else
            r_gray_addr <= r_gray_addr;
endmodule
```

### RAM模块

```verilog
//code
`timescale 1ns / 1ps
module ram_core_module#(
    parameter       DATA_WIDTH      =   'd8     ,
    parameter       DATA_DEEPTH     =   'd8 
    )(
    input           i_wr_data                     ,
    input           i_wr_addr                     ,
    input           i_wr_en                       ,
    input           i_wr_clk                      ,
    
    output          o_rd_data                     ,
    input           i_rd_addr                     ,
    input           i_rd_en                       ,
    input           i_rd_clk                      
    );
    /**************start***************/
    function integer clogb2(input integer number);             //计算地址位宽的函数，vivado可用'd3;//
        for(clogb2 = 0 ; number > 0 ; clogb2 = clogb2 + 1)
        begin
            number = number >> 1;
        end
    endfunction
     /************parameter*************/
    localparam ADDR_WIDTH = clogb2(DATA_DEEPTH - 1);
     /**************port****************/
    wire    [DATA_WIDTH - 1 :0]     i_wr_data       ;
    wire    [ADDR_WIDTH - 0 :0]     i_wr_addr       ;
    wire                            i_wr_en         ;
    wire                            i_wr_clk        ;
    wire    [DATA_WIDTH - 1 :0]     o_rd_data       ;
    wire    [ADDR_WIDTH - 0 :0]     i_rd_addr       ;
    wire                            i_rd_en         ;
    wire                            i_rd_clk        ;
    /**************machine**************/ 
    
    /****************reg****************/
    reg [ADDR_WIDTH - 0 :0]         r_ram_core[0 : DATA_DEEPTH - 1];    //不是数组，是内存块ram
    reg [ADDR_WIDTH - 0 :0]         r_rd_data;                        //读潜伏期是1个周期
    /****************wire***************/
    wire [ADDR_WIDTH   - 1 : 0] w_wr_addr   ;
    wire [ADDR_WIDTH   - 1 : 0] w_rd_addr   ;
    /***************asssign*************/
    assign o_rd_data = r_rd_data            ;
    assign w_wr_addr = i_wr_addr[ADDR_WIDTH   - 1 : 0];
    assign w_rd_addr = i_rd_addr[ADDR_WIDTH   - 1 : 0];
    /**************component************/
 
    /***************always**************/
    always@(posedge i_wr_clk)
        if(i_wr_en)
            r_ram_core[w_wr_addr] <= i_wr_data;                 //写入数据
        else
            r_ram_core[w_wr_addr] <= r_ram_core[w_wr_addr];     //else不写也行
    always@(posedge i_rd_clk)
        if(i_rd_en)
            r_rd_data <= r_ram_core[w_rd_addr];               //读出数据
        else
            r_rd_data <= r_rd_data;                         //else不写也行
 
//always@(posedge i_wr_clk)
//    r_ram_core[w_wr_addr] <= i_wr_en ? i_wr_data : r_ram_core[w_wr_addr]; 

//always@(posedge i_rd_clk)
//    r_rd_data <= i_rd_en ? r_ram_core[w_rd_addr] : r_rd_data;
endmodule
```

### 二进制码转格雷码

```verilog
//code
`timescale 1ns / 1ps

module bin2gray_module#(
    parameter       WIDTH = 'd8
)(
    input   [WIDTH : 0]     i_bin       ,
    output  [WIDTH : 0]     o_gray      
    );
    
    assign o_gray = (i_bin >> 1) ^ i_bin    ;
    
endmodule
```

### top_module

```verilog
//code
`timescale 1ns / 1ps
module fifo_top#(
    parameter       DATA_WIDTH      =   'd8     ,
    parameter       DATA_DEEPTH     =   'd8 
)
(
    input               i_wr_clk                ,
    input               i_wr_rst                ,
    input               i_wr_en                 ,
    input               i_wr_data               ,
    output              o_wr_full               ,

    input               i_rd_clk                ,
    input               i_rd_rst                ,
    input               i_rd_en                 ,
    output              o_rd_data               ,
    output              o_rd_empty      

);
/****************function******************/
function integer clogb2(integer number);
    for(clogb2 = 0 ; number > 0 ; clogb2 = clogb2 + 1)
    begin
        number = number >> 1;
    end
endfunction

/****************localmeter****************/
localparam ADDR_WIDTH     = clogb2(DATA_DEEPTH - 1);

/****************io port*******************/
wire                        i_wr_clk            ;
wire                        i_wr_rst            ;
wire                        i_wr_en             ;
wire [DATA_WIDTH - 1 : 0]   i_wr_data           ;
wire                        o_wr_full           ;
wire                        i_rd_clk            ;
wire                        i_rd_rst            ;
wire                        i_rd_en             ;
wire [DATA_WIDTH - 1 : 0]   o_rd_data           ;
wire                        o_rd_empty          ;
/****************mechine*******************/

/****************reg***********************/

/****************wire**********************/
wire [ADDR_WIDTH - 0 : 0]   w_rd2wr_addr    ;
wire [ADDR_WIDTH - 0 : 0]   w_wr2rd_addr    ;
wire                        w_wr_ram_en     ;
wire [ADDR_WIDTH - 1 : 0]   w_wr_ram_addr   ;
wire                        w_rd_ram_en     ;
wire [ADDR_WIDTH - 1 : 0]   w_rd_ram_addr   ;

/****************assign********************/
//assign w_wr_ram_en = i_wr_en ;
//assign w_rd_ram_en = i_rd_en ;
/****************component*****************/
ram_core_module#(
    .DATA_WIDTH      (DATA_WIDTH    ),
    .DATA_DEEPTH     (DATA_DEEPTH   )
)
ram_core_module_u0
(
    .i_wr_data       (i_wr_data     ),
    .i_wr_addr       (w_wr_ram_addr ),
    .i_wr_en         (w_wr_ram_en   ),
    .i_wr_clk        (i_wr_clk      ),

    .o_rd_data       (o_rd_data     ),
    .i_rd_addr       (w_rd_ram_addr ),
    .i_rd_en         (w_rd_ram_en   ),
    .i_rd_clk        (i_rd_clk      )
    
);

write_ctrl#(
    .DATA_DEEPTH     (DATA_DEEPTH   )   
)
write_ctrl_u0
(
    .i_wr_clk        (i_wr_clk      ),
    .i_wr_rst        (i_wr_rst      ),

    .i_wr_en         (i_wr_en       ),
    .o_wr_full       (o_wr_full     ),
    .o_ram_addr      (w_wr_ram_addr ),
    .o_ram_en        (w_wr_ram_en   ),

    .i_rd2wr_addr    (w_rd2wr_addr  ),
    .o_wr2rd_addr    (w_wr2rd_addr  )
);

read_ctrl#(
    .DATA_DEEPTH     (DATA_DEEPTH   )
)
read_ctrl_u0
(
    .i_rd_clk        (i_rd_clk      ),
    .i_rd_rst        (i_rd_rst      ),

    .i_rd_en         (i_rd_en       ),
    .o_rd_empty      (o_rd_empty    ),
    .o_ram_addr      (w_rd_ram_addr ),
    .o_ram_en        (w_rd_ram_en   ),

    .i_wr2rd_addr    (w_wr2rd_addr  ),
    .o_rd2wr_addr    (w_rd2wr_addr  )
);
endmodule
```

最后的testbench主要包含一次写满操作+一次读空操作。

### testbench文件

```verilog
//code
`timescale 1ns / 100ps

module FIFO_TB();

reg clk,rst;
reg clk2,rst2;

initial
begin
    clk = 0;
    rst = 1;
    #100;
    @(posedge clk)#0 rst = 0;
end

initial
begin
    clk2 = 0;
    rst2 = 1;
    #100;
    @(posedge clk2)#0 rst2 = 0;
end

always#10 clk = ~clk;
always#20 clk2 = ~clk2;
/**************************************************/
reg        r_wr_en   ;  
reg  [7:0] r_wr_data ;
wire       w_wr_full ;
reg        r_rd_en   ;
wire [7:0] w_rd_data ;
wire       w_rd_empty ;

localparam DATA_WIDTH = 'd8;
localparam DATA_DEEPTH = 'd8;

fifo_top#(
    .DATA_WIDTH      (DATA_WIDTH    ),
    .DATA_DEEPTH     (DATA_DEEPTH   )
)
fifo_top_u0
(
    .i_wr_clk               (clk        )            ,
    .i_wr_rst               (rst        )            ,
    .i_wr_en                (r_wr_en    )            ,
    .i_wr_data              (r_wr_data  )            ,
    .o_wr_full              (w_wr_full  )            ,

    .i_rd_clk               (clk2       )            ,
    .i_rd_rst               (rst2       )            ,
    .i_rd_en                (r_rd_en    )            ,
    .o_rd_data              (w_rd_data  )            ,
    .o_rd_empty             (w_rd_empty )    
);
/**************************************************/
initial
begin
    r_wr_en   = 0;
    r_wr_data = 0;
    r_rd_en   = 0;
    wait(!rst);
    wait(!rst2);
    fork
        begin
            fifo_write_task();
            fifo_read_task();
        end
    join
end

task fifo_write_task();
    int  i;
    @(posedge clk);
    for(i = 0 ; i < 8 ; i = i + 1)
    begin
        r_wr_en   <= 'd1;
        r_wr_data <= i;
        @(posedge clk);
    end
    r_wr_en   <= 'd0;
    r_wr_data <= 0;
    @(posedge clk);
endtask

task fifo_read_task();
    int i;
    @(posedge clk2);
    for(i = 0 ; i < 8; i = i + 1)
    begin
        r_rd_en   <= 'd1;
        @(posedge clk2);
    end
    r_rd_en   <= 'd0;
    @(posedge clk2);
endtask

endmodule
```

![FIFO_testbench验证结果时序图](./images/FIFO_out.png)

---

## over
