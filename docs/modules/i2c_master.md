# APB I2C Master

## 职责

单主 I2C 控制器，供 CPU 经 AXI-to-APB control island 操作简单板级管理器件。
提供 open-drain SCL/SDA、字节读写、ACK/NACK、HOLD_LOW、Repeated START与done IRQ。

## RTL 与寄存器

- RTL：`rtl/perips/i2c_master.v`
- APB window：`0x2000_8000`
- `STATUS[5]`：`bus_active`；`STATUS[6]`：sticky `cmd_error`。
- 完整寄存器、命令合法性和验证入口均以本页、RTL 与对应 TB 为准。

## 验证

- `tools/run_i2c_master_tb.ps1 -Snapshot i2c_master_v2_tb`
  - 覆盖 `START → A0 → 12 → Repeated START → A1 → READ 3C → NACK → STOP`。
- `tools/run_axi_apb_regression.ps1` 覆盖控制岛访问。

## 已知边界

- 未实现 clock stretching、输入同步/去毛刺、多主仲裁、bus recovery、FIFO、DMA。
- 仅完成RTL/仿真验证；外部I2C管脚与板级器件尚未签收。
