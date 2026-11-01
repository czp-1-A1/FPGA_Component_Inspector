from pathlib import Path
import hashlib,json,shutil
root=Path(__file__).resolve().parent;old=root/'frozen_r0';out=root/'frozen_r1';out.mkdir(exist_ok=False)
for p in old.glob('*.v'):shutil.copy2(p,out/p.name)
s=(old/'tb_tail_role_sweep.sv').read_text().replace('tb_tail_role_sweep','tb_tail_aperture_sweep')
s=s.replace('integer feed_w=12,feed_h=12,feed_gray=180,pocket_y=320,body_present=0;','integer feed_w=16,feed_h=14,feed_gray=180,pocket_y=320,body_present=0,pocket_w=14,pocket_h=12,pocket_gray=180,xyphase=0;')
s=s.replace('700,pocket_y,14,12))image=180','700+xyphase,pocket_y,pocket_w,pocket_h))image=pocket_gray')
s=s.replace('700,pocket_y-40,feed_w,feed_h','700+xyphase,pocket_y-40,feed_w,feed_h')
s=s.replace('feed_w=%0d feed_gray=%0d feed_E=', 'feed_w=%0d feed_gray=%0d pocket_w=%0d pocket_gray=%0d xyphase=%0d feed_E=')
s=s.replace('feed_w,feed_gray,feed_e,feed_p,feed_u,pocket_e);','feed_w,feed_gray,pocket_w,pocket_gray,xyphase,feed_e,feed_p,feed_u,pocket_e);')
begin=s.index(' initial begin\n  for(bp=');end=s.index(' initial begin #(64',begin)
s=s[:begin]+''' initial begin
  for(bp=0;bp<2;bp++)for(bw=6;bw<=14;bw+=2)for(bg=95;bg<=180;bg+=85)for(by0=0;by0<2;by0++)begin
   body_present=bp;feed_w=16;feed_h=14;feed_gray=180;
   pocket_w=bw;pocket_h=bw;pocket_gray=bg;xyphase=by0;pocket_y=320+by0;run_case();
  end
  $display("DIAG_SWEEP_COMPLETE cases=%0d cases_with_wrong_feed_target=%0d; true aperture-size sweep, not field replay",c,errors);$finish;
 end
'''+s[end:]
(out/'tb_tail_aperture_sweep.sv').write_text(s)
inputs={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob('*') if p.is_file()}
(out/'INPUT_SHA256.json').write_text(json.dumps(inputs,indent=2)+'\n')
runner=(root/'run_probe.py').read_text().replace("src=root/'frozen_r0';out=root/'run_r0'","src=root/'frozen_r1';out=root/'run_r1'").replace('tb_tail_role_sweep','tb_tail_aperture_sweep')
(root/'run_aperture_probe.py').write_text(runner)
