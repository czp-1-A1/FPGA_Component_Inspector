from pathlib import Path
r=Path.cwd();p=r/'fpga/component_inspector';f=p/'sim/tb_frame_process.v';t=f.read_text(encoding='utf-8')
t=t.replace('ticks(200);run_clk=0;post_cycles=200;', '''if(kind==6)begin ticks(40);rv=1;ticks(1);rv=0;ticks(159);end
 else ticks(200);
 run_clk=0;post_cycles=200;''')
t=t.replace('frame_no==1 || kind==5','frame_no==1 || kind==5 || kind==6')
t=t.replace('frame(0,1,0,0);frame(4,0,0,0);','frame(6,3,0,0);frame(0,1,0,0);frame(4,0,0,0);')
t=t.replace('8 real correction/RAW10/vendor RAM frames','9 real correction/RAW10/vendor RAM frames').replace('mode cancellation and recovery;','mode cancellation, post-FE extra RAW rejection and next-frame recovery;')
f.write_text(t,encoding='utf-8')
t=(r/'tmp/check_frame_native.py').read_text(encoding='utf-8')
t=t.replace("('native_full','REF native frame=','frame_tailproof')", "('native_full','REF native frame=','frame_tailproof'),('native_full','REF native frame=','frame_stop'),('native_full','REF native frame=','frame_process')")
(r/'tmp/check_process_native.py').write_text(t,encoding='utf-8')
print('Added native post-FE rejection/recovery with CSI stopped; independent reference unchanged')
