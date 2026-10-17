# RAW底图抖动修复交接（WIP，未发布）

用户因额度不足要求立即上传交接。本目录保存完整360输入、当前代码、负轮次源差异/日志、21节奏测试、实际路由报告与未发布bit。当前临时交付指针仍指旧16bd8beb版，未烧板/Flash。

目标：用户现场确认RAW也抖。已复现前帧行时长驱动的读追写/快慢切换截断，以及行缓存停在末地址时提前置valid。仅5个RTL改变，阈值/1092/40/WB100/3528/180mm/UI/CDC/SDC不变。手机拍屏含OIS/摩尔纹，复现行尾错像素不能证明现场全图抖动同因。

当前冻结manifest ed7cc98129abbd4bac0f92ccdae1fa18a5c34c579efccc321b0de1c26cbf34cf；构建r13 manifest 7de1a3676fe09bc426ea288d52f5cee980782d38beda7fc09b8b818a9ed95ef1。两者生产代码逐字节相同，仅2项测试的独立行周期参考由valid边沿改为有效256组计数，r15还移除了测试未用变量残留。r13实际setup+.105/hold+.020ns、TNS0，40max_delay匹配ignored0，20Gray位/扇出8ns通过；Slice17753/21216、ERAM104/108、DSP26/40、PLL5/6。历史相机/DDR/PLL/I/O覆盖警告不冒称已解决。

当前测试状态详见HANDOFF.json（复制日志的时点状态）。r13完整静止FHD已完成前5帧，720行/172800视频字且像素差0，最后第6帧尚未拿到最终PASS；21快慢组合/额外空闲测试PASS；27FPS/四视图/13栅格12538001精确DDR像素/OF UF0通过；HDMI/缩放/WB5项通过；r15安全回归仍需核对最终3项PASS。不得将进行中的日志视为通过。

下一步先查本机tmp/base_jitter_creditfix_r13_20261017/work_repeat/sim/modelsim_work/base_picture_repeatability/console.log及r15 safety.log/err。进程不随Git传输。若无完整最终PASS，在新ASCII工作目录重跑：

```powershell
python -X utf8 scripts/replay.py --action prepare --work D:/fpga_video_resume --td-root D:/AAA/FPGA.....YZW
python -X utf8 scripts/replay.py --action sim --work D:/fpga_video_resume --td-root D:/AAA/FPGA.....YZW --modelsim-bin D:/modelsim/win64 --tests base_picture_repeatability isp_writer_stop isp_metadata_stop frame_tailproof
```

在本目录执行以上命令，prepare目录必须全新。确认6帧3686400后续比较像素不变、cold等于nominal、全部3项安全PASS。旧版与新nominal RGB应逐字节一致（39bcf8d7...）；完整原生/缩放数量不是像素正确性的替代。运行original_workspace_scripts/audit_video_credit.py前需恢复其原工作区轮次布局或按记录严格适配路径，不放松物理审计条件。源码5文件不再改动时可使用已完成r13路由证据，但最终测试-only差异必须明确绑定。

provenance每轮inputs.json可用source_snapshot加delta重建，保留失败而不改答案。r7/r8旧强制丢首帧假设、r11快慢截断、r12行valid错、r13旧独立行周期误认气泡、r14变量残留编译错误均留档。candidate_unreleased仅供接续，不自动更新发布指针；bit SHA c093c98bc5b59003c663a10f7c66e8c3a7d5600e30c583a5d16262630b969acd。
