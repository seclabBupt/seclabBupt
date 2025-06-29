# p4 Tutorial

相关教程：

- https://github.com/nsg-ethz/p4-learning （主要）
- https://github.com/p4lang （文档等）
- https://google.com （中文社区质量较低，一般不容易搜到解决方案）

网络技术相关的资源：

- https://feisky.gitbooks.io/sdn/content/

---

（目前，基于已有平台，如下第一部分环境安装内容，仅供参考）

## 1. p4 环境安装 

**OS**：ubuntu 20.04.4

**depends：**

- **PI** ：p4runtime api，网络拓扑中有p4交换机时，必须安装该模块；
- **BMv2**： p4交换机虚拟机 ；
- **P4C**：p4程序编译器，支持p4_14 & p4_16；
- **Mininet**：基于namespace的linux网络仿真软件，对外提供python api；
- **FRRouting** ：网络协议栈仿真软件；
- **P4-Utils**：

**可优先使用安装脚本安装**：`https://github.com/nsg-ethz/p4-utils/blob/master/install-tools/install-p4-dev.sh`

PI、BMv2需要编译安装，有一定的安装难度。

P4C、Mininet、FRRouting支持用包管理器安装，非常容易操作。



### 1.1 PI 安装

> 建议每一个模块都在home路径下新建一个文件夹存放文件。
>
> PI部分安装较为繁琐，如有特殊报错需根据本地具体环境进行查阅

#### 1.1.1 子模块安装

##### 1.1.1.1 无需编译模块

```bash
apt install libreadline-dev valgrind libtool-bin libboost-dev libboost-system-dev libboost-thread-dev
```



##### 1.1.1.2 prtobuf v3.18.1

> https://github.com/p4lang/PI 	*protbuf部分*

- 安装步骤：

```bash
cd #回到home
git clone --depth=1 -b v3.18.1 https://github.com/google/protobuf.git
cd protobuf/
./autogen.sh
./configure
make
[sudo] make install
[sudo] ldconfig
```

- 可能出现的问题：
  显示未安装googletest, 或是警告No configuration information is in third_party/googletest in version1.10
  解决方法：https://github.com/google/protobuf.git 从这个上面找到thrid_party这个文件夹，然后找到里面的googletest文件夹并将其中的文件下载下来，放入/protobuf/thrid_party/googletest文件夹下，便可解决问题


##### 1.1.1.3 gRPC v1.43.2

> https://github.com/p4lang/PI 	*grpc部分*

- 安装步骤：

```shell
apt-get install build-essential autoconf libtool pkg-config
apt-get install cmake
apt-get install clang libc++-dev
apt-get install zlib1g-dev

cd #回到home
git clone --depth=1 -b v1.43.2 https://github.com/google/grpc.git 
cd grpc
git submodule update --init --recursive 
mkdir -p cmake/build
cd cmake/build
cmake ../..
make
make install
ldconfig
```

- 可能出现的问题：

 1. `git submodule update --init --recursive` 失败

    网络原因，一直重复直到全部成功（比较费事间，建议同步执行 1.1.1.4 bmv2及其依赖），也可以将github中的grpc库clone到gitee，再从gitee clone；

 1. 按照https://github.com/p4lang/PI grpc部分安装会提示不支持make编译，建议用cmake

    参考上述安装步骤即可；



##### 1.1.1.4 bmv2依赖

> https://github.com/p4lang/behavioral-model/blob/main/README.md

- 安装步骤：

```bash
cd #回到home
git clone https://github.com/p4lang/behavioral-model.git

sudo apt-get install -y automake cmake libgmp-dev \
    libpcap-dev libboost-dev libboost-test-dev libboost-program-options-dev \
    libboost-system-dev libboost-filesystem-dev libboost-thread-dev \
    libevent-dev libtool flex bison pkg-config g++ libssl-dev
    
cd ci
[sudo] chmod +x install-*
[sudo]./install-nanomsg.sh
[sudo]./install-thrift.sh

./autogen.sh
./configure
make
[sudo] make install   # if you need to install bmv2
```

- 可能出现的问题：

 1. `git clone https://github.com/p4lang/behavioral-model.git`失败

    网络问题，重复执行git clone直到成功。



##### 1.1.1.4 sysrepo
###### 1.1.1.4.1 子模块 libyang 编译安装

> https://github.com/CESNET/libyang

- 步骤

```bash
 cd #回到home
 git clone --depth=1 -b v0.16-r1 https://github.com/CESNET/libyang.git
  cd libyang
  mkdir build
  cd build
  cmake ..
  make
  make install
```
- 可能出现的问题：
 1. 缺少 pcre：

  ```bash
  sudo apt-get update
  sudo apt-get install libpcre3 libpcre3-dev
  # or
  sudo apt-get install openssl libssl-dev
  ```


###### 1.1.1.4.2 本体编译安装
> https://github.com/p4lang/PI/blob/main/proto/README.md

- 安装步骤：

```bash
cd #回到home
git clone --depth=1 -b v0.7.5 https://github.com/sysrepo/sysrepo.git
cd sysrepo
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_EXAMPLES=Off -DCALL_TARGET_BINS_DIRECTLY=Off ..
make
[sudo] make install
```

-----------------------#目前仍不确定是否安装完成

- 可能会出现的问题：

 1. 该部分可能出现的问题很多，主要集中在执行`cmake -DCMAKE...`阶段，会出现缺少库的问题

    解决方法，如报错缺少xxx，执行`apt install xxx`；

    如果报错提示无法定位到xxx库，执行`apt install libxxx-dev；`

    如果仍然找不到该库，百度&google搜ubuntu安装xxx；

-  可能需要执行如下命令：
   sudo apt install libpython2-dev
   sudo apt install liblua5.1-0
   sudo apt-get install lua5.1-0-dev
   sudo apt install swig
   sudo apt install libavl-dev  #这句不太确定是否正确
   sudo apt-get install libev-dev
   sudo apt install python3-virtualenv

   redblack的安装（下载地址：https://sourceforge.net/projects/libredblack/files/）
   下载完成后直接对tar.gz文件进行解压，再进行安装即可，需要可以检查更新

   Cmocka的安装（下载地址：https://cmocka.org/files/1.1/）
   下载完成后解压，然后创建build文件夹，再./configure，之后按照里面INSTALL文件的说明进行安装


     直到cmake成功



#### 1.1.2 pi 编译安装

> https://github.com/p4lang/PI

- 安装步骤

```bash
cd #回到home

git clone https://github.com/p4lang/PI.git
cd PI
git submodule update --init --recursive
./autogen.sh
./configure --with-proto --with-bmv2 --with-cli
make
make check
[sudo] make install
```

- 可能出现的问题

 1. 编译时报错缺少xxx头文件

    解决方法同1.1.1.4.2 sysrepo部分；

 2. 执行`git submodule update --init --recursive` 比较费时间，建议同步安装p4c或者mininet



### 1.2.1 bmv2 安装

如在1.1.1.4 bmv2依赖 部分执行了`[sudo] make install` 那么该部分可以跳过，否则返回 1.1.1.4 bmv2依赖 部分执行相关操作。



### 1.2.2 P4C 安装

> https://github.com/p4lang/p4c

- 安装步骤

```bash
sudo apt-get install cmake g++ git automake libtool libgc-dev bison flex \
libfl-dev libgmp-dev libboost-dev libboost-iostreams-dev \
libboost-graph-dev llvm pkg-config python3 python3-pip \
tcpdump

pip3 install ipaddr scapy ply
sudo apt-get install -y doxygen graphviz texlive-full

安装方法1：
. /etc/os-release
echo "deb http://download.opensuse.org/repositories/home:/p4lang/xUbuntu_${VERSION_ID}/ /" | sudo tee /etc/apt/sources.list.d/home:p4lang.list
curl -L "http://download.opensuse.org/repositories/home:/p4lang/xUbuntu_${VERSION_ID}/Release.key" | sudo apt-key add -
sudo apt-get update
sudo apt install p4lang-p4c
```

```
安装方法2：
git clone --recursive https://github.com/p4lang/p4c.git
mkdir build
cd build
cmake .. <optional arguments>
make -j4
make -j4 check  
（check需要100成功，如果出现问题参考/home/wly/p4c/build/Testing/Temporary/LastTest.log的这个文件）
```

- 可能需要额外执行的命令：
  sudo apt-get install scapy
  pip install thrift
  1.若在LastTest.Log中发现   ImportError: cannot import name 'Thrift' from 'thrift' (unknown location) ubuntu  这个错误
  则卸载thrift（pip uninstall thrift）, 然后重新安装

  2.若在LastTest.Log中发现  /usr/bin/ld: cannot find /home/wly/p4c/backends/ebpf/runtime/usr/lib64/libbpf.a: No such file or directory  这个错误
  则表明需要安装 libbpf，在 p4c 文件夹下运行 python3 backends/ebpf/build_libbpf

- 可能出现的问题
 1. `sudo apt-get install -y doxygen graphviz texlive-full` 非常费时间，建议与编译gRPC或者编译prtobuf同时进行



### 1.2.3 mininet 安装

```bash
sudo apt install mininet
```



### 1.2.4 FRRouting 安装

> https://deb.frrouting.org

- 安装步骤：

```bash
# add GPG key
curl -s https://deb.frrouting.org/frr/keys.asc | sudo apt-key add -

# possible values for FRRVER: frr-6 frr-7 frr-8 frr-stable
# frr-stable will be the latest official stable release
FRRVER="frr-stable"
echo deb https://deb.frrouting.org/frr $(lsb_release -s -c) $FRRVER | sudo tee -a /etc/apt/sources.list.d/frr.list

# update and install FRR
sudo apt update && sudo apt install frr frr-pythontools
```

- 可能出现的问题

 1. apt update报错

    删除`/etc/apt/sources.list.d/frr.list`，执行`sudo apt update && sudo apt install frr frr-pythontools`



### 1.2.5 p4-utils

> https://github.com/nsg-ethz/p4-utils

- 安装步骤：

```bash
cd #回到home
git clone https://github.com/nsg-ethz/p4-utils.git
cd p4-utils
sudo ./install.sh

cd
git clone https://github.com/mininet/mininet mininet
cd mininet
# Build mininet
sudo PYTHON=python3 ./util/install.sh -nwv

apt-get install bridge-utils
```

- 可能遇到的问题：
 1. `./install.sh` 部分报错缺少xxx库，参考1.1.1.4.2 sysrepo部分；



### 1.3 运行时出现的BUG

> Under maintenance……



#### 1.3.1 无法调用xterm

- 报错：

> xterm: Xt error: Can't open display: %s
> xterm: DISPLAY is not set



- **原因**：https://github.com/mininet/mininet/wiki/FAQ#x11-forwarding

> 没有正确开启**X11 forwarding**



- **MAC OS X 解决方法**：https://zhuanlan.zhihu.com/p/265207166（下载XQuartz）

```zsh
$ brew install XQuartz
$ XQuartz
$ export DISPLAY=:0

$ ssh -Y root@xxx.xxx.xxx.xxx

#连接linux服务器端
$ xterm
```
	1. `export DISPLAY=:0` 仅对当前shell起作用.
	1. 最简单的办法：不安装X11，直接再多开一个shell




---
## 2. P4基础知识



### 2.1 p4程序基本结构（组件）介绍

> 参考资料：
>
> - 官方文档：
    >   - https://p4.org/specs/
> - 网络&博客文档：
    >   - https://www.sdnlab.com/17882.html
>   - https://www.zhihu.com/column/c_1336207793033015296
>   - https://bbs.huaweicloud.com/blogs/288890
>   - http://www.nfvschool.cn
> - 一些重要的文档：
    >   - BMv2中一些参数定义的介绍：https://github.com/nsg-ethz/p4-learning/wiki/BMv2-Simple-Switch#creating-multicast-groups

- 首部（Headers）
- 解析器（parsers）
- 表（tables）
- 动作（actions）
- 控制器（control）

> 该部分内容请详细阅读参考资料，参考资料中**sdnlab的文章**中详细介绍了p4基本语法、p4各个组件的功能，建议与参考资料中**知乎的文章**一起阅读，互相借鉴理解。nfvschool的p4文章对各个模块的总结也很到位，非常具有参考价值。

---



### 2.2 P4程序解读

> 该部分主要参考苏黎世联邦理工学院的*Advanced Topics in Communication Networks* lecture：https://github.com/nsg-ethz/p4-learning/tree/master/examples
> 里面的例子都非常有代表性，建议仔细理解，本节仅分析综合度相对高的几个实例。
>
> 该部分每小节开头都会贴出对应内容的完整源码，之后会对源码逐段分析（或对重点函数进行分析）。阅读时可以先大致浏览一遍源码，了解其大致结构及逻辑，然后再对照后续的讲解进行理解。由于我们的水平有限，程序解读可能会存在一定的差错，如存在任何歧义，请以官方文档中的定义及描述为主。

---



#### 以Source Routing为例

> https://github.com/nsg-ethz/p4-learning/tree/master/examples/source_routing
>
> 源路由实例是通过在数据包包头添加源路由字段（用于指定数据包需要经过的交换机节点），p4交换机解析源路由字段并判断如何转发数据包，从而实现数据包指定路径转发。

##### (1) include/header.p4

```c
#define MAX_HOPS 127

const bit<16> TYPE_IPV4 = 0x800;
const bit<16> TYPE_SOURCE_ROUTING = 0x1111;
...

header ethernet_t {
	...
}

header source_routing_t {
    bit<1> last_header;
    bit<7> switch_id;
}

header ipv4_t {
	...
  ...
}

struct metadata {
    /* empty */
}

struct headers {
    ethernet_t   ethernet;
    source_routing_t[MAX_HOPS] source_routes;
    ipv4_t       ipv4;
} 
```

p4程序定义数据包头部是用header分别定义各个字段的头部模版，最后再在结构体headers中使用报文头部模版实例化各个报文头部，这里的header可以理解为c语言中的struct。

ethernt头部和ipv4头部定义比较基础，这里不再过多赘述，我们将重点分析source_routing_t和headers的定义。

- **source_routing_t**

```c
header source_routing_t {
    bit<1> last_header;
    bit<7> switch_id;
}
```

首先分析 `header source_routing_t` ，里面包括两个变量：last_header：用于判断当前报文头部是否是最后一个头部；switch_id：用于判断当前交换机是否是我们制定路径中的指定交换机。

- **headers**

```c
#define MAX_HOPS 127
...
...
struct headers {
    ethernet_t   ethernet;
    source_routing_t[MAX_HOPS] source_routes;
    ipv4_t       ipv4;
} 
```

然后还需要注意的是`struct headers` 中的 `source_routing_t[MAX_HOPS] source_routes;` 在程序的开头定义了宏`#define MAX_HOPS 127` ，所以整个数据包包头我们可以理解为：

`ethernet + source_routers[0] + source_routers[1] + ... + source_routers[n] + ipv4`

这里的n由我们设定的路径决定，最多能经过128个交换机。使用 https://github.com/nsg-ethz/p4-learning/tree/master/examples/source_routing 的send.py程序可以创建一个包含源路由头部的数据包，具体使用方法参考链接。假设在执行send.py后输入 2 3 2 2 1，那么我们会得到一个这样的包头：

```c
ETH	| 0 2 | 0 3 | 0 2 | 0 2 | 1 1 | IPV4 |
  	   ↓     ↓     ↓     ↓     ↓
  	 SR[0] SR[1] SR[2] SR[3] SR[4]
```

可以看到SR[0]到SR[3]的last_header都是0（两个数字中的前一个），SR[4]的last_header是1。

在parser阶段，每一次执行extract，指针就指向下一报文头部，在执行一定次数extract后，指针最后指向ipv4头部对ipv4进行解析，最终accept该数据包。

---



##### (2) include/parser.p4

```c
parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {

    state start {

        transition parse_ethernet;

    }

    state parse_ethernet {

        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType){
            TYPE_IPV4: parse_ipv4;
            TYPE_SOURCE_ROUTING: parse_source_routing;
            default: accept;
        }
    }

    state parse_source_routing {
        packet.extract(hdr.source_routes.next);
        transition select(hdr.source_routes.last.last_header){
            1: parse_ipv4;
            default: parse_source_routing;
        }
    }

    state parse_ipv4 {
        packet.extract(hdr.ipv4);
        transition accept;
    }
}

/*************************************************************************
***********************  D E P A R S E R  *******************************
*************************************************************************/

control MyDeparser(packet_out packet, in headers hdr) {
    apply {

        //parsed headers have to be added again into the packet.
        packet.emit(hdr.ethernet);
        packet.emit(hdr.source_routes);
        packet.emit(hdr.ipv4);

    }
}
```

parser部分可以理解为实现了把输入数据包的头部剥离出来的功能，parser本质上是一个由多种状态组成的状态机。所有数据包的状态都从start状态出发，根据当前报头的TYPE字段不同从而转移到不同的状态下进行解析；而deparser部分（需要注意deparser本身属于conrtol，不是paser）会将剥离的报头重新添加到数据包中。

我们先看**Myparser的函数定义**，理解函数定义可以便于我们理解p4程序的处理逻辑。

```c
// Myparser的函数定义
parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {
  ...
  ...
}
```

- **packet_in**：packet_in是定义在core.p4中的extern模版，packet_in实例化的对象packet中包含了当前到达交换机的数据包中的信息，需要注意的是由packert_in实例化的对象packet不需要使用in、out或者inout等关键字修饰，它本身属于in类型的对象。而后面三个形参都在定义时声明了out、inout的属性。在p4中，被in修饰的参数可以理解为仅可读，被out修饰的对象可以理解为仅可写，inout为可读可写。

- **headers**：headers是在header.p4中定义的数据包头部结构体。`out headers hdr` 中声明的变量hdr是一个out类型、且数据结构为header类型的变量，hdr用来存放在parser过程中解析packet得到的数据。

- **metadata**：metadata是在header.p4中定义的用户自定义数据结构（通常用来存放寄存器、计数器与及Meter的数据）。后续的几个例子会介绍该字段的详细用法。

- **standard_metadata_t**：standard_metadata_t是在交换机runtime定义的数据结构，用来存储数据包转发时的ingress_port、packet_length、egress_spec、egress_port等信息。我们这里是用的p4 runtime是BMv2，standard_metadata_t的详细定义可以参考：https://github.com/p4lang/behavioral-model/blob/main/docs/simple_switch.md ，不同厂商的p4设备standard_metadata_t定义可能不同，因此需要根据具体的runtime定义设计p4程序。

接下来分析**MYparser中的各个状态**。状态转移过程决定了数据包包头的处理顺序，我们需要仔细分析各个状态下的parser分别做了什么处理，才能理解最后得到了一个什么样的数据包。

- **start**

```c
// start状态
state start {
  transition parse_ethernet;
}
```

start状态不区分数据包类型，直接将所有数据包状态转移到parse_ethernet状态。通常每个p4程序的第一个parser都是start状态，整个parser过程由start状态开始，以accept或reject结束。

- **parse_ethernet**

```c
// parse_ethernet状态
state parse_ethernet {
  packet.extract(hdr.ethernet);
  transition select(hdr.ethernet.etherType){
    TYPE_IPV4: parse_ipv4;
    TYPE_SOURCE_ROUTING: parse_source_routing;
    default: accept;
  }
}
```

parse_ethernet：parse_ethernet状态下，程序首先调用packet的extract函数，将packet中index指针指向的数据块提取出来（首先计算需要提取的比特数目n，然后将packet当前index位置后n个bit提取出来存入hdr的index指向的位置，此处需要注意hdr为out类型，仅可以写入），然后packet的index指针后移到下一个报文头部的首字节，并同时操作hdr.ethernet的index指针后移一位，整个过程如下所示（官方文档中的extract函数定义），所以extract函数可以理解为 *即改变了header的index，又改变了hdr的index*。

```c
// extract函数定义（伪代码）
void packet_in.extract<T>(out T headerLValue) { 
  bitsToExtract = sizeofInBits(headerLValue);
  lastBitNeeded = this.nextBitIndex + bitsToExtract; 
  ParserModel.verify(this.lengthInBits >= lastBitNeeded, error.PacketTooShort); 
  headerLValue = this.data.extractBits(this.nextBitIndex, bitsToExtract); 
  headerLValue.valid$ = true;
	if headerLValue.isNext$ {
		verify(headerLValue.nextIndex$ < headerLValue.size, error.StackOutOfBounds);
		headerLValue.nextIndex$ = headerLValue.nextIndex$ + 1; 
  }
  this.nextBitIndex += bitsToExtract;
}
```

- **parse_source_routing**

```c
state parse_source_routing {
  packet.extract(hdr.source_routes.next);
  transition select(hdr.source_routes.last.last_header){
    1: parse_ipv4;
    default: parse_source_routing;
  }
}
```

在parse_source_routing状态，我们需要注意 `packet.extract(hdr.source_routes.next)`，这里out类型的变量是source_routes下一个位置。初始时，next 指向堆栈的第一个元素，当成功调用extract方法后，next将自动向前偏移，指向下一个元素。last指向 next 前面的那个元素（如果元素存在），即最近 extract 出来的那个元素。

```c
//初始：
                  packet.index
		       ↓
        packet: ETH |0 2 | 0 3 | 0 2 | 0 2 | 1 1 | IPV4 |

                      next
                       ↓
        hdr:	 ETH|	  |     |     |     |     |      |
  
//第一次执行完extract：
                       packet.index
			    ↓
        packet: ETH |0 2 | 0 3 | 0 2 | 0 2 | 1 1 | IPV4 |

                last  next
                  ↓    ↓
        hdr:	 ETH| 0 2 |     |     |     |     |     |
```

执行完extract后，如果当前hdr.source_routes.last.last_header仍为0，那么数据包的下一个状态仍为parse_source_routing。程序会一直持续该循环，直到当前hdr.source_routes.last.last_header为1，那么进入parse_ipv4状态。在parse_ipv4状态中，程序执行完一次extract之后，数据包报文头部的解析就结束了，之后程序进入到control流程，control部分的处理将会在source_routing.p4部分中分析。

- **Deparser**

```c
control MyDeparser(packet_out packet, in headers hdr) {
    apply {

        //parsed headers have to be added again into the packet.
        packet.emit(hdr.ethernet);
        packet.emit(hdr.source_routes);
        packet.emit(hdr.ipv4);

    }
}
```

在deparser阶段，control会将hdr（in类型）中的数据写入packet中（packet_out类型，与packet_in一样在core.p4中定义，但是其本身是out类型的数据）。这里需要注意的是`emit`函数，该函数同extract函数一样，需要我们仔细理解，emit函数的伪代码定义如下：

```c
//emi函数定义：
void emit<T>(T data) {
        if (isHeader(T))
            if(data.valid$) {
                this.data.append(data);
								this.lengthInBits += data.lengthInBits; 
            }
        else if (isHeaderStack(T)){
            for (e : data){
                 emit(e);
            }
        }
        else if (isHeaderUnion(T) || isStruct(T)){
            for (f : data.fields$){
                 emit(e.f)
            }
        }
        // Other cases for T are illegal
}
```

对于`packet.emit(hdr.ethernet)`语句，emit函数的输入变量hdr.ethernet属于header类型，调用函数后会直接进入第一个if分支，由于hdr.ethernet非空，同样满足第二个if分支判定，函数最终会在packet的首部直接填充该部分内容，并将packet的index指针移动到下一个位置。

而`packet.emit(hdr.source_routes)`语句比较复杂，我们需要注意的是hdr.source_routes是一个header stack（详情见header.p4中的定义`source_routing_t[MAX_HOPS] source_routes`），执行emit后程序将会进入第一个else if语句，然后循环遍历hdr.source_routes中的每一个元素hdr.source_routes[i]，并且以hdr.source_routes[i]为输入，递归调用emit函数。很显然hdr.source_routes[i]是header类型变量，但与hdr.ethernet不同的是，此时hdr.source_routes[i]中并没有任何内容（source_routing.p4中`control MyIngress{}`调用pop_front()函数去掉了hdr.source_routes中的内容，详情可以参考source_routing.p4部分的分析），并且在source_routing.p4的control流程中也没有调用`setvalid`函数使hdr.source_routes的有效位置为1，因此在递归调用emit函数过程中，程序进入第一个if分支判定后不满足第二个if分支判定的条件，最终不会往header中填充任何内容。

最后的`packet.emit(hdr.ipv4)`语句同`packet.emit(hdr.ethernet)`的处理流程一样，这里不再过多赘述。

---



##### (3) source_routing.p4

```c
#include <core.p4>
#include <v1model.p4>

//My includes
#include "include/headers.p4"
#include "include/parsers.p4"


/*************************************************************************
************   C H E C K S U M    V E R I F I C A T I O N   *************
*************************************************************************/

control MyVerifyChecksum(inout headers hdr, inout metadata meta) {
    apply {  }
}


/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {

    action drop() {
        mark_to_drop(standard_metadata);
    }

    action set_normal_ethernet(){
        hdr.ethernet.etherType = TYPE_IPV4;
    }

    action ipv4_forward(macAddr_t dstAddr, egressSpec_t port) {

        //set the src mac address as the previous dst, this is not correct right?
        hdr.ethernet.srcAddr = hdr.ethernet.dstAddr;

       //set the destination mac address that we got from the match in the table
        hdr.ethernet.dstAddr = dstAddr;

        //set the output port that we also get from the table
        standard_metadata.egress_spec = port;

        //decrease ttl by 1
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;

    }

    table ipv4_lpm {
        key = {
            hdr.ipv4.dstAddr: lpm;
        }
        actions = {
            ipv4_forward;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = NoAction();
    }

    table device_to_port {

        key = {
            hdr.source_routes[0].switch_id: exact;
        }

        actions = {
            ipv4_forward;
            NoAction;
        }
        size = 128;
        default_action = NoAction();

    }

    apply {

        //only if IPV4 the rule is applied. Therefore other packets will not be forwarded.
        if (hdr.source_routes[0].isValid() && device_to_port.apply().hit){
            //if it is the last header then.
            if (hdr.source_routes[0].last_header == 1 ){
               set_normal_ethernet();
            }
            hdr.source_routes.pop_front(1);
        }

        else if (hdr.ipv4.isValid()){
            ipv4_lpm.apply();
            //it means that it did not hit but that there is something to remove..
            if (hdr.source_routes[0].isValid()){
                //if it is the last header then.
                if (hdr.source_routes[0].last_header == 1 ){
                   set_normal_ethernet();
                }
                hdr.source_routes.pop_front(1);

            }
        }
    }
}

/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {

    apply {}

}

/*************************************************************************
*************   C H E C K S U M    C O M P U T A T I O N   **************
*************************************************************************/

control MyComputeChecksum(inout headers hdr, inout metadata meta) {
     apply {
	update_checksum(
	    hdr.ipv4.isValid(),
            { hdr.ipv4.version,
	      hdr.ipv4.ihl,
              hdr.ipv4.dscp,
              hdr.ipv4.ecn,
              hdr.ipv4.totalLen,
              hdr.ipv4.identification,
              hdr.ipv4.flags,
              hdr.ipv4.fragOffset,
              hdr.ipv4.ttl,
              hdr.ipv4.protocol,
              hdr.ipv4.srcAddr,
              hdr.ipv4.dstAddr },
            hdr.ipv4.hdrChecksum,
            HashAlgorithm.csum16);
    }
}




/*************************************************************************
***********************  S W I T C H  *******************************
*************************************************************************/

//switch architecture
V1Switch(
MyParser(),
MyVerifyChecksum(),
MyIngress(),
MyEgress(),
MyComputeChecksum(),
MyDeparser()
) main;
```

观察p4代码我们可以看到，这部分代码主要由4个control构成：`MyVerifyChecksum`、`MyIngress`、`MyEgress`、`MyComputeChecksum`。在这四个control中，` MyVerifyChecksum` 、`MyEgress`部分仅给出了定义，无任何apply实现，因此这几个control可以暂时忽略。剩下的两个conrtol中需要重点关注的是` MyIngress`，源路由p4程序中的大部分控制逻辑都是由`MyIngress`实现的。

- **control MyIngress**

```c
// MyIngress定义
control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {
	...
  ...
}
```

同parser一样，在分析`control MyIngress`的具体实现前我们需要注意它的定义



```c
// action定义
action drop() {
  ...
}

action set_normal_ethernet(){
  ...
}

action ipv4_forward(macAddr_t dstAddr, egressSpec_t port) {
	...
}
```

`control MyIngress`定义了三个action，action可以按照c语言中的函数进行理解，action可以在apply中通过匹配table触发，也可以通过在apply直接调用函数触发。



```c
// table定义
table ipv4_lpm {
  key = {
    hdr.ipv4.dstAddr: lpm;
  }
  actions = {
    ipv4_forward;
    drop;
    NoAction;
  }
  size = 1024;
  default_action = NoAction();
}

table device_to_port {

  key = {
    hdr.source_routes[0].switch_id: exact;
  }

  actions = {
    ipv4_forward;
    NoAction;
  }
  size = 128;
  default_action = NoAction();

}
```

`control MyIngress`定义了两个table，通过匹配key去触发相应的action，key以及action的参数等可在表项的配置文件中定义。



```c
// header对象的push和pop函数定义（伪代码）
void push_front(int count) {
for (int i = this.size-1; i >= 0; i -= 1) {
        if (i >= count) {
            this[i] = this[i-count];
        } else {
            this[i].setInvalid();
} }
this.nextIndex = this.nextIndex + count;
if (this.nextIndex > this.size) this.nextIndex = this.size;
// Note: this.last, this.next, and this.lastIndex adjust with this.nextIndex
}

void pop_front(int count) {
    for (int i = 0; i < this.size; i++) {
        if (i + count < this.size) {
            this[i] = this[i+count];
        } 
      	else {
            this[i].setInvalid();
					}
    }
    if (this.nextIndex >= count) {
        this.nextIndex = this.nextIndex - count;
    } 
  	else {
        this.nextIndex = 0;
    }
// Note: this.last, this.next, and this.lastIndex adjust with this.nextIndex
}
```
push与pop可以根据以上伪代码进行理解。








# p4实验相关（持续更新） @Hamid @Clannd
## simple_l3运行示例
### 常用脚本简介
- set_sde.bash 是设置P4运行环境的脚本。每次做实验之前需要运行此脚本设置运行环境才能继续进行实验。
- run_tofino_model.sh 是在硬件中进行软访的脚本。可以不启动硬件交换机，启用虚拟环境，生成一些虚拟网卡以及虚拟交换机环境，供我们调试。
- run_switchd.sh 是启动交换机把P4程序烧录到交换机的脚本。
- run_bfshell.sh是启动交换机控制命令行的脚本。
- p4_build.sh 是编译P4文件的脚本。

![picture 1](images/p4_script.png)

### 交换机配置
```shell
cd onl-bf-sde
. set_sde.bash
./p4_build.sh simple_l3/simple_l3.p4
```
结果显示DONE即编译成功。编译完之后，硬件交换机就会生成一个和 .p4文件同名的交换机程序。

 ![picture 2](./images/p4_compile.png)

```shell
./run_switchd.sh -p simple_l3
```
这样就把程序烧录到交换机中，交换机就启动了，这个界面就作为一个后台进行管理，关掉的话交换机就关闭了。再复制一个界面进行一些配置。

![picture 3](./images/p4_config.png)

- 可能会出现端口占用的情况，如果报错端口被占用，用sudo lsof -i :9090命令查看占用进程的PID，再用sudo kill -9 <PID>命令来强制终止对应进程，再运行即可

开一新的连接，在新的界面中启动命令行
```shell
cd onl-bf-sde
. set_sde.bash
./run_bfshell.sh
```
![picture 4](./images/p4_control.png)

启动交换机端口
```shell
ucli
Pm

port-add -/- 100G RS
an-set -/- 2
port-enb -/-
show
```
显示端口信息，看到这些端口up就是启动成功了


![picture 5](./images/p4_port.png)

- 交换机通常是有32个板卡，每个板卡有4个端口。32/-就是启动32下所有端口，32/0就是启动32下第一个端口。我们的交换机的硬件连接是三个服务器连接在交换机上。210.12.140.209:1021连接在31上，210.12.140.209:1022连接在32上，210.12.140.209:1023连接在28上
100G为端口速率，必须设置为1，10，25，40，50，100中的一个，而且必须和服务器的网卡速率匹配，使用的交换机上只有-/0端口支持100G速率。


### 服务器配置
交换机端口启动之后，还需要配置服务器端的ip地址和arp
在服务器中查看网卡
```shell
sudo ip a
```
实验室交换机和服务器硬件连接为
210.12.140.209:1021的enp131s0连接28/0 160号端口
210.12.140.209:1022的enp130s0f0np0连接32/0 136号端口
210.12.140.209:1023的enp130s0f0np0连接31/0 128号端口

```shell
sudo ip a
sudo ifconfig enp131s0 192.168.100.3
sudo ifconfig enp130s0f0np0 192.168.100.2
sudo ifconfig enp130s0f0np0 192.168.100.1
```

arp是把局域网内的ip地址解析为mac地址，设置目的地的mac地址。
在203.207.106.7服务器上配置arp，就是要让服务器把203.207.106.8的ip地址和目的地为该ip地址的下一跳的mac地址对应起来。
下面还需要获取一下端口的mac地址
```shell
ucli
bf_pltfm
chss_mgmt
port_mac_get 28 0 
port_mac_get 32 0 
port_mac_get 31 0 
```
有了mac地址就可以配置arp了
210.12.140.209:1021服务器上配置arp
```shell
sudo arp -s 192.168.100.1 ec:b9:70:b3:a0:c9
sudo arp -s 192.168.100.2 ec:b9:70:b3:a0:c9
```
210.12.140.209:1022服务器上arp配置也一样
```shell
sudo arp -s 192.168.100.1 ec:b9:70:b3:a0:c9
sudo arp -s 192.168.100.3 ec:b9:70:b3:a0:c9
```
210.12.140.209:1023服务器上arp配置
```shell
sudo arp -s 192.168.100.2 ec:b9:70:b3:a0:c9
sudo arp -s 192.168.100.3 ec:b9:70:b3:a0:c9
```

### 控制面表象下发
还需要修改一下交换机控制面程序，也就是在交换机上配置arp。


![picture 6](./images/p4_arp.png)

再复制一个交换机界面，启动交换机控制命令行，下发表象。
```shell
bfrt_python simple_l3/set_up.py
```
表象就下发成功了。
到这里，本实验就基本结束了，可以尝试一下任意两个服务器相互发包。
可以收到包就说明l3实验完成了。

## simple_l3_acl实验
本实验的目的是在simple_l3程序基础上扩展实现一个简易防火墙。通过该实验，您将掌握修改和完善P4程序并完成完整工作流程的技能。

实验重点在于正确解析IPv4数据包，特别是存在选项时的第四层头部处理。您需要扩展解析器并添加一个ACL表功能。目录中的初始程序已预定义所有头部结构（以减少代码量）。

### 测试程序
至少安装一条主机或路由条目（例如将目标IP为192.168.1.1的流量发送到端口1），并配置ACL条目（例如拒绝源端口为7的UDP数据包）。

使用多种测试数据包验证ACL功能：
```text
p1 = 以太网头/IP(源IP="10.10.10.1", 目标IP="192.168.1.1")/UDP(源端口=7, 目标端口=77)/"载荷"

p2 = 以太网头/IP(源IP="10.10.10.1", 目标IP="192.168.1.1", 选项=IP选项("abcdefgh"))/UDP(源端口=7, 目标端口=77)/"载荷"

# 思考该数据包是否应被放行
p3 = 以太网头/IP(源IP="10.10.10.1", 目标IP="192.168.1.1", 分片=23)/UDP(源端口=7, 目标端口=77)/"载荷"

# 这个呢？
p4 = 以太网头/IP(源IP="10.10.10.1", 目标IP="192.168.1.1", 分片=23)/"\x00\x07\x00\xc5    载荷"
```

- pkt/send.py默认发送类似p1的简单数据包。建议直接使用scapy生成多样化测试数据包。测试未显式解析的协议（如SCTP，ipv4.protocol=132）：
```text
p4 = 以太网头/IP(源IP="10.10.10.1", 目标IP="192.168.1.1")/SCTP(源端口=7, 目标端口=77)/"载荷"
```

### 拓展练习
- 添加出口acl功能
- 完善ipv4分片包处理
- 增加ipv6支持

## simple_l3_rewrite
本实验的目的是扩展simple_l3程序，实现更精细的转发动作：既能重写L2头部，又能通过递减TTL来更新L3头部。

实验重点在于正确处理IPv4数据包，特别是校验和（在TTL递减后必须重新计算）和TTL（必须正确处理数值回绕，且TTL为0或1的数据包不应被转发）。

你的任务是相应地扩展解析器，并添加必要的检查逻辑。目录中已提供带有必要注释的初始程序。

### 测试程序
- 至少安装一条使用新动作的主机或路由条目
- 发送数据包并确认：
- 最简单的方法是用Wireshark捕获数据包：该工具默认会校验IPv4校验和
- 对于TTL，直接比较捕获包中的数值即可
- 确保TTL=0和/或TTL=1的数据包不被转发

### 额外测试
观察程序的可视化图表，比较其与simple_l3程序所需的SRAM和TCAM资源（假设表大小相同）。哪些资源使用量增加了？哪些保持不变？为什么？

你还能注意到其他资源使用量增加的情况吗？原因是什么？

## simple_l3_nexthop
本实验旨在修改simple_l3_rewrite程序，通过允许多个主机/路由条目共享相同的下一跳信息，从而减少其动作SRAM（静态随机存取存储器）的资源需求。

目录中包含带有必要注释的初始程序。

### 测试程序
由于该程序的功能与simple_l3_rewrite相同，基本测试方法类似：
- 安装至少一个使用新动作的主机或路由条目
  - 发送数据包并验证：
  TTL 是否确实递减
  IP 校验和是否正确重新计算
  最简单的方法是在 Wireshark 中捕获数据包（该工具默认会校验 IPv4 校验和）

对于 TTL，只需比较捕获包中的数值
- 确保 TTL=0 或 TTL=1 的数据包不被转发
- 你还可以进一步优化。例如，"新源 MAC 地址"的不同取值通常很少，因此可以：
改用索引表：无需为每个条目存储 48 位的 MAC 地址，而是创建一个单独的表，并使用较小的索引（如 8 位）进行查找。

### 额外实验
你可以创建多个指向同一下一跳的主机/路由条目：

- 测试共享下一跳：

发送数据包，确认下一跳被正确使用且数据包按预期转发

修改下一跳信息，观察所有相关路由是否均受影响（通过向共享该下一跳的其他条目发送数据包验证）

- 资源对比：

观察程序的可视化图表，比较其与 simple_l3_rewrite 在相同表大小下的 SRAM 和 TCAM 资源占用情况

关键代价：这种优化方案最主要的代价是什么？为什么？

（注：最后一句提问暗示读者思考共享下一跳可能带来的额外查表开销或灵活性限制，例如需要额外查询 nexthop 表，或在修改共享 nexthop 时影响多条路由。）


## simple_l3_arping

### 实验目标
本实验旨在展示一个典型的 L3 交换机如何同时作为 自动 ARP 和 ICMP 响应器，从而减轻其后方主机处理这些特定数据包的负担。这种机制可以：

防御基础的 DoS 攻击

隐藏后端网络（使外部无法探测实际存在的设备）

完成实验（编写程序并正确配置表项）后，你可以在一个或多个 veth 接口上配置 IP 地址，并成功 Ping 通实际并不存在的主机。

### 实验配置
假设你编程了以下主机和路由表项：

| IP address (prefix) | Port |  Destination MAC  |    Source MAC     |
|---------------------|-----:|:-----------------:|:-----------------:|
| 192.168.1.1         |    1 | 00:00:00:00:00:01 | 00:12:34:56:78:9A |
| 192.168.1.2         |    2 | 00:00:00:00:00:02 | 00:AA:BB:CC:DD:EE |
| 192.168.1.5         |    2 | 00:00:00:00:00:05 | 00:AA:BB:CC:DD:EE |
| 192.168.1.0/24      |   64 | 00:00:00:00:00:01 | 00:12:34:56:78:9A |
| 192.168.3.0/24      |   64 | 00:00:00:00:00:01 | 00:12:34:56:78:9A |

然后在 veth1 上配置 IP 地址 192.168.1.254/24，并指定 192.168.1.100 作为 192.168.3.0/24 网络的网关：
```
sudo ip addr add 192.168.1.254/24 dev veth1
sudo ip route add 192.168.3.0/24 via 192.168.1.100
```
如果程序正确运行，即使 192.168.1.0/24 和 192.168.3.0/24 网络中的主机实际不存在，你也能成功 Ping 通它们。

本目录中的 do_ping.sh 脚本会自动完成上述测试（并在最后清理 veth1 的配置），可作为测试参考。
### 理论背景

当你 Ping 一个 IP 地址时，Linux 主机会执行以下步骤：
查询路由表，可能的结果：

a. 无路由 → Ping 失败

b. 目标位于直连网络（同子网） → 先发送 ARP "Who-has" 请求 解析目标 MAC

c. 目标位于远程网络 → 先发送 ARP 请求解析网关 MAC

获取目标 MAC 后，发送 ICMP Echo 请求 至该 MAC 地址。

因此，交换机（响应器）必须能同时处理 ARP 和 ICMP 请求，才能正确模拟主机响应。

### 附加实验

- 测试不同子网的 Ping：
尝试 Ping 192.168.3.0/24 中的地址，观察交换机如何代理响应。

- 修改 ARP 表项：
更改某个 IP 的 MAC 地址，观察 Ping 是否仍然成功（验证交换机是否动态响应）。
- 模拟 DoS 防御：
向交换机发送大量 ARP 请求，观察是否仍能稳定响应（验证资源占用情况）。

通过本实验，你将更深入理解 L3 交换机如何优化网络流量并增强安全性。


## simple_l3_dir_cntr

### 实验目标
本实验旨在探索 直接计数器（direct counter） 功能，通过在现有 P4 程序中添加计数器来统计关键表项的匹配情况。

可选扩展方案
- 在 simple_l3.p4 或其衍生版本中，为 ipv4_host 表添加直接计数器，统计每个主机表项的命中次数。
- 在 simple_l3_nexthop.p4中为 nexthop 表添加计数器，统计每个下一跳的使用次数。
- 在 simple_l3_acl.p4 中 为 ACL 表项添加计数器，统计每条规则的匹配次数。

### 计数器读取方法
由于读取计数器需要知道表项的句柄（handles），本实验还要求学习如何通过以下方式获取数据：
- Python + run_pd_rpc 工具： 使用 get_entries() 函数获取表中所有条目的句柄，再通过句柄读取计数器。
- PTF 测试框架：编写测试脚本验证计数器功能。

### 额外实验
- 通用计数器查询函数 编写一个函数，输入表名和计数器名，自动显示所有表项的计数器值（可附带句柄和匹配规则）。
- 扩展功能：仅显示非零计数器，或对比上次查询结果只输出变化的值。
- 资源占用分析：观察添加计数器后的资源可视化图表，分析 SRAM/TCAM 的使用变化；实验 min_width 属性，研究其对 SRAM 占用的影响（例如调整计数器位宽）。

### 实验意义
- 网络监控：实时了解流量匹配情况（如热门路由、ACL 规则触发频率）。
- 调试优化：通过计数器定位未预期的表项匹配或资源瓶颈。
- 资源权衡：理解计数器位宽（如 8bit vs 32bit）对硬件资源的影响。

通过本实验，你将掌握 P4 数据平面的统计能力，并学会高效管理计数器资源。

## simple_l3_ind_cntr
### 实验目标
本实验旨在探索 间接计数器（indirect counter） 功能，通过扩展 simple_l3.p4 或其衍生版本，实现 IPv4 主机和路由表条目共享计数器，从而按目标子网统计数据包。
- 核心需求:

在 ipv4_host 和 ipv4_route 表中添加间接计数器,相同子网的不同条目应共享计数器索引

例如：

主机条目：192.168.1.1、192.168.1.2、192.168.1.10
路由条目：192.168.1.0/24
以上所有条目应指向同一个计数器，统计发往 192.168.1.0/24 的所有数据包


### 实现要点
- 计数器生成逻辑：对主机 IP，提取子网前缀（如 192.168.1.0/24）作为索引；对路由条目，直接使用其子网作为索引

- P4关键修改
```P4
counter(1024, CounterType.packets) ipv4_subnet_counter;  // 声明间接计数器

action count_subnet_traffic() {
    ipv4_subnet_counter.count(/* 动态计算子网索引 */);  
}
```
- 表项关联：在 ipv4_host 和 ipv4_route 的动作中调用 count_subnet_traffic

### 额外实验

- 资源对比分析

与 simple_l3_dir_cntr.p4 的可视化对比

主要差异：间接计数器通过共享索引减少 SRAM 占用，但需额外逻辑计算索引

优势：适合大规模子网统计；劣势：索引计算可能增加处理延迟

- 计数器数量极限测试

默认限制：通常受限于计数器块大小（如 1024 个）

突破限制的方法：

分层计数：将大子网拆分为更小子网，合并统计时累加

采样计数：每 N 个数据包更新一次计数器

动态分配：运行时按需分配计数器（需硬件支持）

### 实验意义
流量分析：精准统计子网级流量，优化网络规划

资源效率：间接计数器比直接计数器更节省内存（适合共享统计场景）

扩展性思考：理解计数器规模与硬件资源的权衡关系

通过本实验，你将掌握间接计数器的设计哲学及其在网络监控中的高效应用。


## simple_l3_histogram

### 实验目标
本实验目标是探索如何结合直接计数器和范围匹配功能来创建数据包长度的直方图。

思考：执行计数功能的表应该放置在流水线的哪个位置？是入口(ingress)还是出口(egress)？为什么？

这个表的编程方式有多种选择：可以使用类似SNMP的指数级扩大的范围区间（例如[0..64]、[65..128]、[129..256]等），也可以采用线性区间（例如[64..75]、[74..85]等）。

pkt/send.py脚本演示了如何发送随机长度的数据包。它会发送1000个数据包并记录其长度，以便您将程序运行结果与这些记录进行比对。

### 扩展实验

观察可视化界面：范围匹配表占用了哪种类型的硬件资源？

对比发现所需流水线阶段数是增加了还是保持不变？原因是什么？


## simple_l3_lag_ecmp

### 实验目标

本实验旨在学习如何使用动态选择动作配置(action profiles)实现LAG(链路聚合组)和ECMP(等价多路径路由)。我们将基于simple_l3_nexthop.p4程序进行增强，使其能够：

- 为每个下一跳ID关联多个动作数据集

- 通过动作选择器(action selector)动态选择动作

### 主要任务
1. 转换nexthop表结构
将普通匹配动作表改为使用action_profile和action_selector的动态表
2.  实现流哈希计算
选择适当的字段组合计算哈希值以实现流分配；IPv4/IPv6可分别实现哈希计算(可选)
3. 测试流量分配
使用send.py发送多种流特征的数据包；观察各端口的包计数分布

### 测试方法
#### 手动测试
1. 使用pm show命令查看端口计数器

```
bfshell> ucli
bf-sde> pm
bf-sde.pm> show 1/-
```

2. 使用send.py发送测试流量

```
python send.py <目标IP> <包数量>
```

#### 自动化测试

使用verify_packet_any_port()验证包分发

### 进阶实验
1. 动作配置API探索
- 动态启用/禁用成员

- 观察流量重分布情况

2. 非标准流量分配方法
- 随机分配：使用TNA的Random extern
```P4
Random<bit<14>>() my_rng;
hash = my_rng.get();
```

- 轮询分配：(需使用寄存器，较复杂)

3. 权重分配实现
- 通过重复添加成员实现权重分配

- 修改PTF测试验证权重分布

### 资源分析

- 对比可视化结果，观察新增资源使用情况

- 特别注意action profile和selector的资源占用。

### 实验提示

- 哈希字段选择应考虑实际流量特征

- 测试时注意观察不同流类型的分布均匀性

- 权重实现时注意成员配置比例

通过本实验，您将掌握现代交换芯片实现高级负载均衡功能的核心技术。

## simple_l3_mcast
### 实验目标
学习使用Tofino的PRE(数据包复制引擎)实现组播功能，掌握从入站控制到出站处理的完整组播工作流。
### 核心实现步骤
1. 入站控制层配置
```P4
// 在ipv4_host和ipv4_lpm表中添加组播动作
action set_multicast(bit<16> mcast_grp) {
    ig_intr_md_for_tm.mcast_grp_a = mcast_grp;
}

// 表项匹配时调用组播动作
table ipv4_lpm {
    actions = {
        set_multicast;  // 新增组播动作
        ipv4_forward;
        drop;
    }
    // ...其他配置
}
```

2. PRE引擎编程
使用Python控制平面API配置组播组
```python
# 创建组播组
mc.conn_mgr.mc.create_group(device, mc_group_id)

# 创建组播节点(注意端口号转换)
port_list = [devport_to_mcport(p) for p in target_ports]
mc_bitmap = devports_to_mcbitmap(port_list)
mc.conn_mgr.mc.create_node(device, rid, mc_bitmap)

# 关联节点与组
mc.conn_mgr.mc.associate_node(device, mc_group_id, rid)
```

3.出站处理优化
```P4
// 使用出站元数据区分不同复制包
control Egress(...) {
    action modify_based_on_rid(bit<16> rid) {
        // 根据rid进行不同修改
    }
    
    table egress_processing {
        key = {
            eg_intr_md.egress_rid : exact;
            eg_intr_md.egress_port : exact;
        }
        actions = { modify_based_on_rid; ... }
    }
    
    apply {
        if(eg_intr_md.egress_rid_first) {
            // 组播组级别的计数处理
        }
        egress_processing.apply();
    }
}
```

### 关键问题解决方案
1. 校验和问题修复
```P4
control Egress(...) {
    apply {
        if(ig_intr_md_for_tm.mcast_grp_a != 0) {
            // 组播包需要重新计算校验和
            ipv4.hdrChecksum = ipv4_checksum.update();
            if(udp.isValid()) {
                udp.checksum = udp_checksum.update();
            }
        }
    }
}
```

2. LAG实现进阶
- PRE层LAG配置
```python
# 创建LAG组
mc.conn_mgr.mc.create_lag(device, lag_id)

# 添加成员端口
for port in lag_members:
    mc_port = devport_to_mcport(port)
    mc.conn_mgr.mc.create_lag_member(device, lag_id, mc_port)
```

- P4程序需要相应修改：
1. 添加LAG选择逻辑
2. 可能需要额外的负载均衡哈希计算

### 实验建议
1. 端口号转换工具
```python
from run_pd_rpc import devport_to_mcport, devports_to_mcbitmap

# 示例转换
mc_port = devport_to_mcport(128)  # 管道0端口0
bitmap = devports_to_mcbitmap([1, 2, 3])
```

2. 调试技巧
- 使用egress_rid_first标识首包进行组级统计
- 通过bfshell的tm.mc命令查看PRE状态

3. 流量观察
```bash
# 在bfshell中查看组播统计
bfshell> tm.mc.group_stats_get <group_id>
```

通过本实验，您将深入理解Tofino芯片的组播处理架构，掌握从数据平面到控制平面的完整组播实现方案。


## simple_l3_mirror

### 实验目标
掌握Tofino设备的镜像功能，实现数据包的镜像复制（用于远程观测或发送至CPU）.

### 核心实现步骤

1. 基础镜像配置（入口镜像）
```p4
// 定义镜像会话动作
action mirror_packet(mirror_id_t session_id) {
    ig_intr_md.force_mirror = true;
    ig_intr_md.mirror_session_id = session_id;
}

// 在需要镜像的表项中调用
table monitor_table {
    actions = {
        mirror_packet;
        normal_forwarding;
        drop;
    }
    // ... 表配置
}
```

2. 出口镜像扩展实现（进阶）
```P4
// 使用clone_e2e实现出口镜像
action egress_mirror(mirror_id_t session_id) {
    eg_intr_md_for_tm.mirror_session = session_id;
    eg_intr_md_for_tm.mirror_enable = true;
}

control Egress(...) {
    apply {
        if(/* 镜像条件 */) {
            egress_mirror(MIRROR_SESSION_EGRESS);
        }
    }
}
```

3. 控制平面配置示例
```python
# 配置镜像会话
def setup_mirror_session(conn_mgr, session_id, dest_port, dir="INGRESS"):
    if dir == "INGRESS":
        conn_mgr.mirror.session_create(
            session_id,
            destination_port=dest_port,
            direction=conn_mgr.mirror.DIRECTION_INGRESS
        )
    else:
        # 出口镜像需要额外配置
        conn_mgr.mirror.session_create(
            session_id,
            destination_port=dest_port,
            direction=conn_mgr.mirror.DIRECTION_EGRESS,
            egress_type=conn_mgr.mirror.EGRESS_TYPE_TRUE
        )

# 调用示例
setup_mirror_session(conn_mgr, 1, 128)  # 入口镜像到端口128
setup_mirror_session(conn_mgr, 2, 129, "EGRESS") # 出口镜像
```

4. 镜像数据包处理要点
- 元数据保留：镜像包会保留原始包的元数据

- 性能影响：高频镜像可能影响转发性能

- 多层镜像：支持嵌套镜像（镜像的镜像）

### 验证方法
1. 端口统计检查

```bash
bfshell> pm show
# 观察目标镜像端口的RX计数增长
```

2. 数据包捕获

```bash
# 在镜像目标端口抓包
tcpdump -i eth1 -nn -w mirror.pcap
```

### 进阶实验建议
- 条件镜像：基于特定流特征触发镜像

- 采样镜像：每N个包镜像1个（使用寄存器实现计数）

- CPU镜像：配置镜像目标为CPU端口

通过本实验，您将掌握数据平面可编程镜像的核心技术，为网络监控和故障排查提供强大工具。



## simple_l2
### 实验目标
开发高级API来动态控制一个支持VLAN的简易L2转发平面，实现：

- MAC地址学习

- 老化机制

- VLAN内未知地址的泛洪

### 核心架构

1. 数据平面关键组件

```p4
#define AGEING_TIME 300  // 300秒老化时间

table mac_learning_table {
    key = {
        vlan.vid : exact;
        ethernet.srcAddr : exact;
    }
    actions = {
        update_timestamp;
        no_op;
    }
}

table mac_forwarding_table {
    key = {
        vlan.vid : exact;
        ethernet.dstAddr : exact;
    }
    actions = {
        forward_to_port;
        flood_in_vlan;  // VLAN内泛洪
        send_to_cpu;    // 特殊处理
    }
    const default_action = flood_in_vlan;
}
```

2. 控制平面API设计

```python
class L2Controller:
    def __init__(self, bfrt_info):
        # 初始化表对象
        self.mac_table = bfrt_info.table_get("mac_forwarding_table")
        self.learn_table = bfrt_info.table_get("mac_learning_table")
        
        # 设置老化线程
        self.ageing_thread = threading.Thread(target=self._age_entries)
        self.ageing_thread.daemon = True
        self.ageing_thread.start()

    def _age_entries(self):
        """后台老化线程"""
        while True:
            time.sleep(60)  # 每分钟检查一次
            self._remove_stale_entries()

    def add_static_entry(self, vlan, mac, port):
        """添加静态转发表项"""
        self.mac_table.entry_add(
            [self.mac_table.make_key(
                KeyTuple('vlan.vid', vlan),
                KeyTuple('ethernet.dstAddr', mac)
            ],
            [self.mac_table.make_data(
                DataTuple('port', port))
            ]
        )
```

### 关键实现机制
1. MAC学习流程
```P4
control Ingress {
    apply {``
        if (ethernet.isValid() && vlan.isValid()) {
            // 源MAC学习
            mac_learning_table.apply();
            
            // 目标MAC查找
            mac_forwarding_table.apply();
        }
    }
}
```

2. 老化机制实现

```python
def _remove_stale_entries(self):
    """删除超时表项"""
    now = time.time()
    resp = self.learn_table.entry_get()
    
    for entry in resp:
        vlan = entry.key['vlan.vid']
        mac = entry.key['ethernet.srcAddr']
        timestamp = entry.data['timestamp']
        
        if now - timestamp > AGEING_TIME:
            self.mac_table.entry_del(
                [self.mac_table.make_key(
                    KeyTuple('vlan.vid', vlan),
                    KeyTuple('ethernet.dstAddr', mac)
                )]
            )
```

### 实现验证方法
1. 基础功能测试

```bash
# 添加静态条目
python controller.py add-static 100 00:11:22:33:44:55 1

# 查看转发表
python controller.py show-table
```

2. 动态学习验证

- 在端口1发送源MAC为00:11:22:33:44:55的包

- 检查转发表是否自动学习

- 5分钟后验证老化机制是否生效

### 进阶实验建议
- VLAN隔离测试：验证不同VLAN的广播域隔离

- 性能优化：实现批量老化操作减少控制平面负载

- 安全扩展：添加MAC防漂移保护机制

这个实验框架提供了L2网络的核心功能，可作为更复杂功能的开发基础。通过实践将深入理解交换芯片的数据平面编程范式。


## simple_l3_vrf

### 队列管理lab

相关文件：

` BMv2`

- Cache：算力调度

- Codel：Codel算法
- NWHHD：Count-Min Sketch计数
- PI：PI算法
- RED：RED算法
- aqm_v1/aqm_dqn：AQM算法
- cfn_bgp：BGP协议配置
- multi_queue_v1：多队列管理算法

` Tofino`

- tofino_example：官方代码示例
- tofino：硬件交换机命令、三层转发、算力调度
