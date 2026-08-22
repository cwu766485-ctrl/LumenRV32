# I-Cache、D-Cache 与分支预测

## 职责

提供 CPU 指令/数据缓存、预取与分支预测，降低 AXI/内存访问停顿。

## RTL

- I-Cache：`rtl/core/icache.v`
- D-Cache：`rtl/core/dcache.v`
- Cache RAM：`rtl/core/cache_ram_1r1w.v`
- BTB/BHT：`rtl/core/branch_predictor.v`

当前 CPU 默认使用 32-entry direct-mapped BTB 与 2-bit BHT；容量通过
`riscv_cpu_core.BRANCH_PREDICTOR_ENTRIES` 参数配置。BTB miss 仍保留静态 backward-taken
fallback，EX 阶段负责最终分支解析和训练。

CPU-only A/B 性能试验也可通过编译宏 `TinyriscvBranchPredictorEntries` 覆盖默认值；
该宏仅用于同一 workload 下比较 predictor 容量，产品默认值仍为 32。

## 验证

- D-Cache store path 专项TB：`tb/dcache_store_path_tb.sv`。
- 性能和PMU依据：[`../project_coremark.md`](../project_coremark.md) 与 [`pmu.md`](pmu.md)。
- BRAM模式与组合环的当前结论已合并到 `project_coremark.md` 和 `update_log.md`。

## 已知边界

- Cache 是单核私有缓存；没有多核一致性协议。
- 性能结论仅以对应提交、ELF、PMU和新鲜日志为准。
