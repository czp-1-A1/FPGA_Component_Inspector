from pathlib import Path
import hashlib,json,shutil
r=Path.cwd();old=r/'tmp/process_v9_r8_20261015';new=r/'tmp/video_first_v10_r4_20261015'
dst=r/'tmp/video_first_v10_v9_cadence_repro_20261015';assert not dst.exists();dst.mkdir()
inputs=json.loads((old/'inputs.json').read_text(encoding='utf-8-sig'))
for item in inputs:
 source=old/item['path'];assert hashlib.sha256(source.read_bytes()).hexdigest()==item['sha256']
 target=dst/item['path'];target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
shutil.copytree(new/'sim',dst/'sim',ignore=shutil.ignore_patterns('modelsim_work','*.log','*.wlf','modelsim.ini','transcript','*.pgm'))
bench=dst/'sim/tb_frame_cadence.v';s=bench.read_text(encoding='utf-8')
s=s.replace('.VIDEO_FIRST(1)', '.METADATA_WAIT_CYCLES(1500000)')
s=s.replace('if(frame_no!=1)begin\n   while', 'if(0)begin\n   while')
needle='else begin\n   if(commits!=1'
assert needle in s
s=s.replace(needle,'''else begin
   if(!writer.published)begin
    $display("REPRO V9 cadence: P=%h W=%h complete=%b good=%b bad=%b metadata_ready=%b wait=%0d period_ns=%0f LP=%h",writer.publish_seen,writer.written,writer.complete_frame,good,bad,mready,writer.metadata_wait,$realtime-frame_time,dut.u_roi_sobel_view.line_min);
    $fatal(1,"V9 complete frame blocked for a whole real source period by absent analysis result");
   end
   if(commits!=1''')
s=s.replace('frame(0,0);frame(0,0);frame(4,0);frame(3,0);frame(3,3);frame(3,1);frame(3,2);', 'frame(0,0);frame(4,0);')
s=s.replace('#320000000', '#90000000')
bench.write_text(s,encoding='utf-8',newline='\n')
(dst/'inputs.json').write_text(json.dumps(inputs,indent=2),encoding='utf-8')
sim=dst/'sim'
manifest=[dict(path=f.relative_to(dst).as_posix(),sha256=hashlib.sha256(f.read_bytes()).hexdigest()) for f in sim.rglob('*') if f.is_file()]
(dst/'simulation_inputs.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
print('Frozen exact V9 production with 26-FPS full-frame counterexample')
