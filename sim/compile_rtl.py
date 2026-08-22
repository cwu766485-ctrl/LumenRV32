import sys
import filecmp
import subprocess
import sys
import os


# 主函数
def main():
    rtl_dir = sys.argv[1]

    if rtl_dir != r'..':
        tb_file = r'/tb/compliance_test/tinyriscv_soc_tb.v'
    else:
        tb_file = r'/tb/tinyriscv_soc_tb.v'

    # iverilog程序
    iverilog_cmd = ['iverilog']
    # 顶层模块
    #iverilog_cmd += ['-s', r'tinyriscv_soc_tb']
    # 编译生成文件
    iverilog_cmd += ['-o', r'out.vvp']
    # 头文件(defines.v)路径
    iverilog_cmd += ['-I', rtl_dir + r'/rtl/core']
    # 宏定义，仿真输出文件
    iverilog_cmd += ['-D', r'OUTPUT="signature.output"']
    extra_defines = os.environ.get('IVERILOG_DEFINES', '')
    for define in extra_defines.replace(';', ',').split(','):
        define = define.strip()
        if define:
            iverilog_cmd += ['-D', define]
    # testbench文件
    iverilog_cmd.append(rtl_dir + tb_file)
    # ../rtl/core
    iverilog_cmd.append(rtl_dir + r'/rtl/core/clint.v')
    iverilog_cmd.append(rtl_dir + r'/rtl/core/csr_reg.v')
    iverilog_cmd.append(rtl_dir + r'/rtl/core/ctrl.v')
    iverilog_cmd.append(rtl_dir + r'/rtl/core/defines.v')
    iverilog_cmd.append(rtl_dir + r'/rtl/core/cache_ram_1r1w.v')
    iverilog_cmd.append(rtl_dir + r'/rtl/core/div.v')
    iverilog_cmd.append(rtl_dir + r'/rtl/core/ex.v')
    iverilog_cmd.append(rtl_dir + r'/rtl/core/ex_mem.v')
    iverilog_cmd.append(rtl_dir + r'/rtl/core/dcache.v')
    iverilog_cmd.append(rtl_dir + r'/rtl/core/icache.v')
    iverilog_cmd.append(rtl_dir + r'/rtl/core/id.v')
    iverilog_cmd.append(rtl_dir + r'/rtl/core/id_ex.v')
    iverilog_cmd.append(rtl_dir + r'/rtl/core/ifetch.v')
    iverilog_cmd.append(rtl_dir + r'/rtl/core/if_id.v')
    iverilog_cmd.append(rtl_dir + r'/rtl/core/mem.v')
    iverilog_cmd.append(rtl_dir + r'/rtl/core/mem_wb.v')
    iverilog_cmd.append(rtl_dir + r'/rtl/core/pc_reg.v')
    iverilog_cmd.append(rtl_dir + r'/rtl/core/regs.v')
    iverilog_cmd.append(rtl_dir + r'/rtl/core/riscv_cpu_core.v')
    iverilog_cmd.append(rtl_dir + r'/rtl/interconnect/native_to_axi4_master.v')
    iverilog_cmd.append(rtl_dir + r'/rtl/interconnect/axi4_crossbar.v')
    iverilog_cmd.append(rtl_dir + r'/rtl/interconnect/axi4_to_native_slave.v')
    iverilog_cmd.append(rtl_dir + r'/rtl/interconnect/axi4_to_apb_bridge.v')
    # ../rtl/perips
    iverilog_cmd.append(rtl_dir + r'/rtl/perips/axi_lite_bridge.v')
    iverilog_cmd.append(rtl_dir + r'/rtl/perips/axi_lite_apb_bridge.v')
    iverilog_cmd.append(rtl_dir + r'/rtl/perips/apb_perips.v')
    iverilog_cmd.append(rtl_dir + r'/rtl/perips/ram.v')
    iverilog_cmd.append(rtl_dir + r'/rtl/perips/rom.v')
    iverilog_cmd.append(rtl_dir + r'/rtl/perips/timer.v')
    iverilog_cmd.append(rtl_dir + r'/rtl/perips/uart.v')
    iverilog_cmd.append(rtl_dir + r'/rtl/perips/gpio.v')
    iverilog_cmd.append(rtl_dir + r'/rtl/perips/spi.v')
    iverilog_cmd.append(rtl_dir + r'/rtl/perips/qspi.v')
    iverilog_cmd.append(rtl_dir + r'/rtl/perips/pmu.v')
    iverilog_cmd.append(rtl_dir + r'/rtl/perips/dma.v')
    iverilog_cmd.append(rtl_dir + r'/rtl/perips/external_memory_wrapper.v')
    iverilog_cmd.append(rtl_dir + r'/rtl/perips/axi4_extmem_bridge.v')
    iverilog_cmd.append(rtl_dir + r'/rtl/perips/axi4_mem_model.v')
    # ../rtl/debug
    iverilog_cmd.append(rtl_dir + r'/rtl/debug/jtag_dm.v')
    iverilog_cmd.append(rtl_dir + r'/rtl/debug/jtag_driver.v')
    iverilog_cmd.append(rtl_dir + r'/rtl/debug/jtag_top.v')
    iverilog_cmd.append(rtl_dir + r'/rtl/debug/uart_debug.v')
    # ../rtl/soc
    iverilog_cmd.append(rtl_dir + r'/rtl/soc/heterogeneous_soc_top.v')
    # ../rtl/utils
    iverilog_cmd.append(rtl_dir + r'/rtl/utils/full_handshake_rx.v')
    iverilog_cmd.append(rtl_dir + r'/rtl/utils/full_handshake_tx.v')
    iverilog_cmd.append(rtl_dir + r'/rtl/utils/gen_buf.v')
    iverilog_cmd.append(rtl_dir + r'/rtl/utils/gen_dff.v')

    # 编译
    process = subprocess.Popen(iverilog_cmd)
    process.wait(timeout=30)

if __name__ == '__main__':
    sys.exit(main())
