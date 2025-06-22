# --- 可执行文件和工具 ---
VCS = vcs
VIEWER = verdi

# --- Verdi PLI 路径 
VERDI_PLI_TAB = $(VERDI_HOME)/share/PLI/VCS/LINUXAMD64/novas.tab
VERDI_PLI_A   = $(VERDI_HOME)/share/PLI/VCS/LINUXAMD64/pli.a


# --- 编译和仿真选项 ---
# 添加 +fsdb 启用 FSDB dump
# 添加 -P <pli.tab> <pli.a> 链接 Verdi PLI 库
VCS_COMPILE_FLAGS = -sverilog +v2k -full64 +fsdb -debug_access+all \
                    -P $(VERDI_PLI_TAB) $(VERDI_PLI_A)\
					-cm line+cond+fsm+branch+tgl

VCS_RUN_FLAGS = -cm line+cond+fsm+branch+tgl

# --- 文件列表 ---
# Verilog 源文件 (.v)
SRCS = \
	fp32_unpacker.v \
	fp32_aligner.v \
	full_adder.v \
	wallace_tree_8_inputs.v \
	fp32_normalizer_rounder.v \
	fp32_packer.v \
	fp32_adder_tree_8_inputs.v \
	tb_fp32_adder_tree_8_inputs.v\
	final_adder.v

# Verilog 头文件 (.vh)
INCLUDES = fp32_defines.vh

# --- 顶层模块和输出文件 ---
TOP_MODULE = tb_fp32_adder_tree_8_inputs 
SIMV = simv
LOG_COMPILE = compile.log
LOG_RUN = run.log
WAVEFORM = fp32_adder_tree.fsdb 



# 默认目标: 编译并运行
all: run

# 编译目标
compile: $(SRCS) $(INCLUDES)
	@echo "--- Compiling Verilog sources with FSDB support ---"
	@if [ ! -f "$(VERDI_PLI_TAB)" ] || [ ! -f "$(VERDI_PLI_A)" ]; then \
		echo "错误: 找不到 Verdi PLI 文件。请检查 Makefile 中的 VERDI_PLI_TAB 和 VERDI_PLI_A 路径设置。"; \
		exit 1; \
	fi
	$(VCS) $(VCS_COMPILE_FLAGS) $(SRCS) -l $(LOG_COMPILE) -o $(SIMV)

# 运行目标
run: compile
	@echo "--- Running simulation (generating FSDB) ---"
	@echo "--- Removing old log files ---"
	rm -f $(LOG_RUN) sim.log # 先删除旧的日志文件
	./$(SIMV) -l $(LOG_RUN) $(VCS_RUN_FLAGS)
	@echo "--- Simulation finished. Check $(LOG_RUN) and $(WAVEFORM) ---"
	urg -dir simv.vdb -report coverage_report
	@echo "--- Coverage report generated in ./coverage_report ---"

# 打开波形目标
wave: $(WAVEFORM)
	@echo "--- Opening waveform viewer [Verdi] for $(WAVEFORM) ---"
	$(VIEWER) -ssf $(WAVEFORM) &


# 清理目标
clean:
	@echo "--- Cleaning generated files ---"
	rm -f $(SIMV) $(LOG_COMPILE) $(LOG_RUN) $(WAVEFORM) sim.log # 清理日志文件和波形文件
	rm -rf csrc simv.daidir ucli.key *.vpd DVEfiles/ verdiLog/ novalog/
	rm -rf coverage_report simv.vdb # 清理覆盖率相关文件
	rm -f novas_dump.log cm.log # 清理其他日志文件
	



# 将 .PHONY 用于非文件目标
.PHONY: all compile run wave clean help