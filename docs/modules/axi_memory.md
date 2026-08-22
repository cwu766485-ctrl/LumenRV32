# AXI4 互连与存储路径

公开版由 CPU D-Cache、CPU I-Cache 和 DMA 作为 AXI4 master，经 `axi4_crossbar` 访问
ROM、RAM、外部 AXI memory 与控制岛。顶层保留一个静默的保留 master 槽，默认不发起请求，
用于保持既有 crossbar 端口编号稳定。

`native_to_axi4_master` 将 CPU/DMA 的 native 请求转换为 AXI4。CPU 两个 adapter 与 DMA
当前各自仍是单笔事务发射；crossbar 具备 ID 字段与响应路由框架，但公开版不宣称支持面向软件的
高并发 OoO/interleaving 服务等级。

相关 RTL：`rtl/interconnect/axi4_crossbar.v`、`rtl/interconnect/native_to_axi4_master.v`、
`rtl/perips/axi4_mem_model.v`、`rtl/perips/axi4_extmem_bridge.v`。
