@echo off
REM 设置ModelSim环境变量
set MODELSIM_PATH=D:\modeltech64_10.7\win32
set PATH=%MODELSIM_PATH%;%PATH%

REM 设置项目路径
set PROJECT_PATH=%~dp0
cd %PROJECT_PATH%

REM 删除之前的日志和波形文件
if exist sim.log del sim.log
if exist sim.coverage.tcl del sim.coverage.tcl
if exist sim.wave.wlf del sim.wave.wlf
if exist sim.wave.vcd del sim.wave.vcd
if exist transcript del transcript

REM 启动ModelSim并执行仿真
vsim -c -do "do run_sim.tcl; quit -f"

REM 检查是否有错误
if exist sim.log (
    findstr /i "Error error" sim.log > nul
    if not errorlevel 1 (
        echo Simulation failed with errors!
        exit /b 1
    ) else (
        echo Simulation completed successfully.
        exit /b 0
    )
) else (
    echo Simulation log file not found!
    exit /b 1
) 