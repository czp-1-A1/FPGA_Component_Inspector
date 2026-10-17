# RAW底图抖动修复交接：软件/路由已验证，实板待复核

代码与最初交接已推送3f97a948；上传期间最后长回归结束，本回执补齐最终11项PASS和严格组合审计。无需重复已完成的测试。HANDOFF.json、validation/final_audit.json为最新状态，provenance及INITIAL_WIP_README保留原时点/失败记录。

仅5个RTL修复行缓存：不再使用前帧行时长，读当前已写数据；空拍保持邻居；行valid按实际RAM读请求；AWB按有效组计EOL。阈值/3528/180mm/EXP1092/GAIN40/WB100、照明/UI/四目标ID/CDC/SDC未变。手机拍屏含OIS/摩尔纹，复现行尾像素问题不能证明现场所有抖动同因。

- 360冻结输入，最终manifest ed7cc98129abbd4bac0f92ccdae1fa18a5c34c579efccc321b0de1c26cbf34cf。
- 构建r13 manifest7de1a3676fe09bc426ea288d52f5cee980782d38beda7fc09b8b818a9ed95ef1；生产完全同字节，最终r15只改2项测试行周期参考/无用测试变量，严格审计已绑定。
- 11项回归全部PASS；完整6帧、4节奏、3686400后续比较像素无差；cold等于nominal，nominal230400组与旧版完全同SHA39bcf8d7...；21快慢/额外间隔测试PASS。
- 27FPS/四视图、13栅格12538001精确DDR像素、OF/UF0；坏尾、599行短帧、恢复及元数据配对、HDMI/缩放/WB均通过。
- TD6.2.168116实际双角路由setup+.105/hold+.020ns、TNS0、STA92.94%；Slice17753/21216=83.68%，ERAM104/108，DSP26/40，PLL5/6；40max_delay matched/ignored0，20Gray位及20实际扇出8ns通过。原相机/DDR/PLL/I/O覆盖边界保持。
- bit SHA c093c98bc5b59003c663a10f7c66e8c3a7d5600e30c583a5d16262630b969acd，1789539字节，保存于candidate_unreleased，尚未烧板或更新交付指针。屏幕标题仍180MM STABLE IDS，必须用文件名/SHA区分。

下一步：以已验证源码/路由证据完成正式候选发布包与候选指针，再由用户用同一机位/曝光/照明上板观察RAW/GRAY+EDGE底图稳定性。不要直接把本次软件通过称作现场抖动完全解决；正式current_codex_build和旧16bd8beb候选仍保留。无本轮后台测试进程，不需要等待。

scripts/verify_handoff.py检查所有归档文件及负轮次重建；scripts/replay.py可在新ASCII无空格工作路径prepare/sim/build，参数见该脚本；original_workspace_scripts/audit_video_credit.py为完成组合审计的原工作区脚本，路径需按记录恢复。provenance/每轮inputs.json用source_snapshot+delta可重建负源，不改失败答案。旧标定来源继续在上一stable_ids/pose交接目录，未改变。
