# 验证与回归

公开版验证覆盖 CPU ISA、Cache/分支预测、AXI4/AXI4-Lite/APB、DMA、I2C 及软件示例。每次结论仅以
新鲜日志为依据；未运行、超时与历史结果需分别记录。

常用入口：

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run_isa_regression.ps1
powershell -ExecutionPolicy Bypass -File .\tools\run_dma_full_regression.ps1
powershell -ExecutionPolicy Bypass -File .\tools\run_axi_apb_regression.ps1
powershell -ExecutionPolicy Bypass -File .\tools\run_branch_predictor_tb.ps1
```

第三方 VIP 对接实验位于 `verify/vip_sanity/`，其中 harness 只连接项目真实 DUT；VIP 本体不纳入本仓库。
