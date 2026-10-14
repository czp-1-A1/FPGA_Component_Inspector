from pathlib import Path
import json,hashlib,shutil
r=Path.cwd();p=r/'fpga/component_inspector';s=p/'sim/tb_frame_video.v'
t=s.read_text().replace('tb_frame_video','tb_frame_stop')
t=t.replace('always #4.444 clk=~clk;','reg run_clk=1;always #4.444 if(run_clk)clk=~clk;')
t=t.replace('rv=0;ticks(1);','rv=0;ticks(b%4==3 ? 3 : 1);')
t=t.replace('hs=0;ticks(200);','hs=0;ticks(98);')
a=t.index(' // Full-frame analysis intentionally follows FE.')
b=t.index(' // The truth monitor observes',a)
t=t[:a]+''' // Native CSI LP738; only 200 tail clocks, then no CSI edges for 33ms.
 ticks(200);run_clk=0;#33000000;
 post_cycles=200;
 $display("STOP evidence mode=%0d pub=%b good=%b bad=%b W=%h count=%0d done=%b metadata=%b cap=%0d state=%0d",mode,writer.published,good,bad,writer.written,writer.camera_count,writer.camera_done,mready,dut.fullframe_search.detector.cap_count,dut.fullframe_search.detector.state_fsm);
 if(frame_no!=1 && (!writer.published || !mready))$fatal(1,"stopped CSI must still publish complete video and two results");
 run_clk=1;
''' +t[b:]
# Avoid depending on a late compute clock from the following source epoch.
t=t.replace('if(post_cycles<3750000)ticks(3750000-post_cycles);','ticks(20);')
a=t.index(' frame(0,1,0,0);');b=t.index(' @(negedge hclk);vs=1;',a)
t=t[:a]+' frame(0,0,0,0);frame(0,3,0,0);\n'+t[b:]
t=t.replace('accepted_frames!=6','accepted_frames!=2').replace('PASS frame video:','PASS frame stop:')
t=t.replace('dut.fullframe_search.detector.state_fsm','dut.fullframe_search.detector.state')
(p/'sim/tb_frame_stop.v').write_text(t)
runner=p/'sim/run_modelsim.ps1';q=runner.read_text()
line=next(x for x in q.splitlines() if '@{Name="frame_video";' in x)
q=q.replace(line,line.replace('frame_video','frame_stop').replace('PASS frame video:','PASS frame stop:')+'\n'+line)
q=q.replace('"frame_video", "frame_tailproof"','"frame_video", "frame_tailproof", "frame_stop"')
runner.write_text(q)
# Archive original photo independently of build evidence.
e=r/'开发实施/验收记录/20261014_A_V8黑屏现场反馈_轮次1';e.mkdir()
src=Path('C:/Users/yiziw/AppData/Local/Temp/codex-clipboard-1957921e-9685-484a-b07c-5ef09ff62c67.jpg')
shutil.copy2(src,e/'original.jpg')
(e/'observations.json').write_text(json.dumps(dict(date='2026-10-14',status='FAIL_BLACK_ONSITE',version='D9 FRAME EXP V8',photo_sha256=hashlib.sha256(src.read_bytes()).hexdigest(),manual_readout=dict(P='59',W='1C124',FPS=27,CFG=1,ER='0',LP='02E2',WS='0000',OF='0000',UF='0000',VF='031E'),user_confirmation='RAW and reset remain black',readout_caveat='Photo manually transcribed; board bit SHA not verified'),ensure_ascii=False,indent=2))
print('Created stopped-clock regression and archived board failure')
