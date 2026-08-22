# heterogeneous_soc 文档导航

本文档树分为“当前设计说明”和“历史证据”两层。阅读项目时先从
[`STATUS.md`](STATUS.md) 与 [`modules/`](modules/README.md) 进入；不要把带日期的记录当作当前接口规格。

| 入口 | 用途 |
| --- | --- |
| [`STATUS.md`](STATUS.md) | 首先阅读：当前 commit 的能力、签收边界与推荐下一步 |
| [`modules/`](modules/README.md) | 当前模块职责、接口、验证入口与边界 |
| [`SPEC.md`](SPEC.md) | 当前系统级规格、地址空间、能力范围与限制 |
| [`project_prospective.md`](project_prospective.md) | 当前系统定位、架构和路线图 |
| [`validation/`](validation/) | 当前 CPU、RTOS、DC 与板级验证证据 |
| [`hardware/`](hardware/) | 板卡资料和厂商工程，仅作硬件参考 |
| [`update_log.md`](update_log.md) | 按时间追加的改动日志，不是接口说明 |

## 维护规则

- RTL 接口、寄存器映射或验证入口发生变化时，先更新对应 `modules/*.md`，
  再补充 `update_log.md`。
- 长期有效的接口放在 `modules/`；板级与回归证据放在 `validation/`；不再新增
  已被当前 `STATUS.md`/`SPEC.md` 覆盖的日期化迁移记录。
- 新模块文档使用 [`modules/TEMPLATE.md`](modules/TEMPLATE.md) 模板；状态必须
  区分已验证、未运行和已知限制。
