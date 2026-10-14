from pathlib import Path
r=Path.cwd();p=r/'fpga/component_inspector'
t=(p/'sim/tb_frame_video.v').read_text(encoding='utf-8').replace('tb_frame_video','tb_frame_process')
t=t.replace('always #4.444 clk=~clk;','reg run_clk=1;always #4.444 if(run_clk)clk=~clk;')
t=t.replace('wire sv,mready,good,bad;','reg procclk=0;always #5 procclk=~procclk;\nwire sv,mready,good,bad;')
t=t.replace('.I_camera_clk(clk)','.I_camera_clk(procclk)').replace('isp_top #(.DIRECT_DETECTION(1)','isp_top #(.ASYNC_PROCESSING(1),.DIRECT_DETECTION(1)').replace('.axi4s_video_aclk(clk)','.processing_clk(procclk),.axi4s_video_aclk(clk)')
t=t.replace('rv=0;ticks(1);','rv=0;ticks(b%4==3 ? 3 : 1);').replace('hs=0;ticks(200);','hs=0;ticks(98);')
a=t.index(' // Full-frame analysis intentionally follows FE.');b=t.index(' // The truth monitor observes',a)
t=t[:a]+''' // Native LP738 and a stopped receive clock, with continuous DDR/processor.
 ticks(200);run_clk=0;post_cycles=200;
 while(post_cycles<2250000 && !writer.published && !bad)begin #10;post_cycles++;end
 // Bad source frames must also let their queued cancel/proof settle.
 #1000;
''' +t[b:]
t=t.replace('if(post_cycles<3750000)ticks(3750000-post_cycles);','if(post_cycles<3300000)#(10*(3300000-post_cycles));run_clk=1;ticks(20);')
t=t.replace('PASS frame video: 8 real correction/RAW10/vendor RAM frames, all four views,','PASS frame process: 8 real correction/RAW10/vendor RAM frames, native LP738 and CSI stopped after 200 tail clocks, 100MHz continuous post-AWB, all four views,')
(p/'sim/tb_frame_process.v').write_text(t,encoding='utf-8')
f=p/'sim/run_modelsim.ps1';q=f.read_text(encoding='utf-8');line=next(l for l in q.splitlines() if '@{Name="frame_video";' in l)
q=q.replace(line,line.replace('frame_video','frame_process').replace('PASS frame video:','PASS frame process:')+'\n'+line)
line='        @{Name="process_bridge"; Pass="PASS process bridge:"; Sources=@("$hdl/frame_process_bridge.v", "$ip/w128_d512_fifo/w128_d512_fifo.v", "$ip/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v", "tb_process_bridge.v")},'
q=q.replace('    $tests = @(\n','    $tests = @(\n'+line+'\n')
q=q.replace('"frame_tailproof", "frame_stop"','"frame_tailproof", "frame_stop", "frame_process"')
f.write_text(q,encoding='utf-8')
# Preserve the exact old checkpoint; put active failure ahead of its history.
f=r/'AGENTS.md';s=f.read_text(encoding='utf-8');a=s.index('## 当前断点')
old=r/'开发实施/验收记录/20261014_A_V8黑屏现场反馈_轮次1/previous_checkpoint.md';old.write_text(s[a:],encoding='utf-8')
f.write_text(s[:a]+'''## 当前断点（2026-10-14，V8现场黑屏，V9连续处理链路修复中）

- 目标：修复D9 V8黑屏，保留同一3528、全画面算法、两穴位独立框/结果；不把模型诊断当实际偏移/旋转/立起/翻面质量真值。
- 基线：lj4747-contest-work，HEAD e604d4fbe4bd40f0d7b40e5fce4ecfda10ea4351；工作区未提交/推送。V8 bit SHA 2f5bd322d3243443adb5437c7b2ff6aaab4074207aa8e633f780b812477b7852和完整档案保留，不再称现场待验/已通过。
- 现场：原图/SHA/人工抄数在20261014_A_V8黑屏现场反馈_轮次1。用户确认RAW和复位也黑；FPS27/CFG1，P59/W1C124、VF031E、LP02E2、OF/UF0。照片不证明bit SHA。
- 复现：frame_stop_v8_r1/r2冻结同214生产输入，LP738、FE后200拍停CSI33ms。RAW完整视频能超时发布但没有双结果；EDGE缺帧尾，W1C020/114949 packed/metadata0，FAIL。与现场RAW仍黑差别保留，尚不声称物理根因闭合。V8常开CSI仿真漏了此反例。
- 修复：新frame_process_bridge使用原128×512异步FIFO，将AWB像素/原生完整证明/取消事件有序转到既有连续100MHz；原生guard/去马赛克/WB仍CSI。下游Sobel、全帧搜索、统计、metadata和video_in输入在连续时钟运行，溢出拒帧并需复位。isp_top/wrapper/.al及测试修改中，尚未新bit。
- 验证：process_v9_r1为UTF8编辑脚本失败后的旧端口夹具轮，保留；process_v9_r2正在frame_stop/搜索/guard仿真，未判通过。SDC尚未变；待新增FIFO CDC预算和最终完整TD审计。原V8/V7/V6/V5发布不覆盖。
- 下一步：读r2日志，连续处理8帧/停钟/独立FIFO精确载荷回归，修复后冻结215生产输入，完整TD资源/双角STA/全部CDC约束，生成V9新独立镜像/说明/证据。
- 进程/设备：ModelSim r2任务进行中；无JTAG/Flash，无提交/推送；用户负责烧录现场复测。历史V8 checkpoint在现场反馈previous_checkpoint.md。
''',encoding='utf-8')
print('Added real stopped-clock processor and exact bridge regressions; checkpoint updated')
