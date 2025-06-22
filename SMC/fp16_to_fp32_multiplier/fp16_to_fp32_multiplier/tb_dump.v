`timescale 1ns/1ps

module dump;
    // 波形转储控制参数
    parameter DUMP_VCD  = 1;  // 是否保存VCD格式
    //parameter DUMP_FSDB  = 0;  // 是否保存VCD格式
    parameter WAVE_FILE = "sim.wave";  // 波形文件名（不带扩展名）

    // 初始化波形转储
    initial begin
        // WLF格式（ModelSim专有格式）
        /*if (DUMP_WLF) begin
            $display("Enabling WLF format dump...");
            $wlfdumpvars(0, tb_fp16_to_fp32_multiplier);
        end
*/
        // VCD格式（标准格式）
        if (DUMP_VCD) begin
            $display("Enabling VCD format dump...");
            $dumpfile({WAVE_FILE, ".vcd"});
            $dumpvars(0, tb_fp16_to_fp32_multiplier);
        end

        // FSDB格式（SystemVerilog专有格式）
        //if (DUMP_FSDB) begin
        //    $display("Enabling FSDB format dump...");
        //    $fsdbDumpfile({WAVE_FILE, ".fsdb"});
        //    $fsdbDumpvars(0, tb_fp16_to_fp32_multiplier);
        //end

        // 等待一段时间后保存波形
        #1000000;
        /*if (DUMP_WLF) begin
            $display("Waveform saved to %s.wlf", WAVE_FILE);
        end*/
        if (DUMP_VCD) begin
            $dumpflush;
            $display("Waveform saved to %s.vcd", WAVE_FILE);
        end
        //if (DUMP_FSDB) begin
        //    $display("Waveform saved to %s.fsdb", WAVE_FILE);
        //end
    end
endmodule 