# 当前候选为P03

先读P03_FIELD_GUIDE.md。其余P01/P02命名收据及旧说明属于保留的父版本历史，不能作为P03通过证据。P03专用证据为P03_*、sim/standing/以及standing_raw_chain；物理证据为本次classified_audit。硬件依赖100项和完整源清单均冻结。

移植时先具备完整P02成果，再应用包根P02_to_P03.patch，仅涉及present_surface_check.v与compact_template_rom.v。若接收工程本身还有变更，逐项合并并独立验收；不能直接继承本bit时序或假定本bit适配其他工程。P03尚待实物验收，不自动替换已发布P02。
