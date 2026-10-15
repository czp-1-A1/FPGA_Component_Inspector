# V11 分辨率修改：GitHub上传完成

目标分支：`lj4747-contest-work`；源码提交：`97406f5c5a8c566947ef083cb19ef2471e040158`，提交标题“V11 分辨率修改”，前置V10为`da195838d8a1df052edeaa86f60312d32eeedf9a`。普通快进推送，未强推。随后只增加此上传回执、交接状态和构建指针Git绑定，不改RTL、冻结输入、镜像或桌面ZIP。

主工程：`fpga/component_inspector/td_project/camera_to_dsi_display.al`。
当前构建指针：`fpga/component_inspector/td_project/current_codex_build.json`。
V11完整冻结源/全部证据/bit/原样ZIP：`fpga/component_inspector/release/hd720_v11_r9_20261015/`。
上板与复跑：`开发实施/61_A_V11分辨率修改_上板与复跑说明.md`及release的README_FIRST.md。
精确上传回执：`开发实施/验收记录/20261015_A_V11仓库上传回执.json`。

源码提交前核对1522文件/582唯一blob，主工程331代码与测试文件保持冻结字节，5项TD元数据只重定位。GitHub重新下载bit1789539字节、完整ZIP58352494字节、烧录说明3721字节，SHA256全部一致；旧V10镜像保留。

已通过28项ModelSim、18图独立参考及最终路由setup+0.117ns/hold+0.020ns/TNS0。硬件未由助手烧录，V11实板与220mm配方仍待现场验收。冻结归档中的git_committed=false是当时构建事实，后续提交绑定以本上传回执为准。
