from pathlib import Path
import hashlib,json,shutil
repo=Path('D:/CodexWork/rl7_alarm_roles_empty_only_20261102');root=Path(__file__).resolve().parent
base=repo/'release/RL7_AlarmRolesV3_EmptyOnlyStop_v1_20261102';src=base/'fpga/component_inspector'
manifest=json.loads((base/'SOURCE_SHA256.json').read_text());out=root/'frozen_r0';assert not out.exists();out.mkdir()
names=['contest_latency_clock','pocket_relay_stop_v2','classified_pocket_counter','classified_count_pipeline','pocket_run_controls','status_cdc',
 'inspection_region_config','empty_candidate_probe','present_surface_check','local_edge_surface_check','present_review_probe','frame_shape_search',
 'compact_inspector_osd','rl7_shared_font_rom','compact_ascii_rom','compact_cjk_rom','compact_template_rom','osd_logo_rom']
proof={}
for name in names:
 rel='user_source/hdl_source/'+name+'.v';p=src/rel;digest=hashlib.sha256(p.read_bytes()).hexdigest();assert digest==manifest[rel]
 shutil.copy2(p,out/p.name);proof[rel]=digest
old=(repo/'tests/rl7_alarm_roles_v3/tb_empty_row_roles_phase.sv').read_text()
s=old.replace('tb_empty_row_roles_phase','tb_tail_role_sweep')
s=s.replace('reg clk=0;', 'integer feed_w=12,feed_h=12,feed_gray=180,pocket_y=320,body_present=0;\n reg clk=0;',1)
begin=s.index(' function integer image(');end=s.index(' task frame(',begin)
s=s[:begin]+''' function integer image(input integer xx,yy);
  integer dx,dy;begin
   image=material_present ? 30 : 150;
   if(material_present)begin
    if(ellipse(xx,yy,700,pocket_y,14,12))image=180;
    if(ellipse(xx,yy,700,pocket_y-40,feed_w,feed_h))image=feed_gray;
    dx=xx-760;dy=yy-pocket_y;
    if(body_present && dx>=-18 && dx<18 && dy>=-22 && dy<22 &&
       !((dx< -14 || dx>=14)&&(dy< -14 || dy>=14)))image=180;
   end
  end
 endfunction
'''+s[end:]
begin=s.index(' initial begin\n  ticks(5);');end=s.index(' initial begin #(64',begin)
s=s[:begin]+''' integer c=0,bw,bg,bp,by0,slot,cy0,feed_e,feed_p,feed_u,pocket_e,errors=0;
 task run_case;
  begin
   rst_n=0;command=0;source_start=0;commit=0;accept=0;sof=0;ticks(5);rst_n=1;ticks(5);command=2;ticks(5);
   frame(0);frame(1);feed_e=0;feed_p=0;feed_u=0;pocket_e=0;
   for(slot=0;slot<4;slot++)if(records[slot*76+75])begin
    cy0=(integer'(records[slot*76+10+:10])+integer'(records[slot*76+:10]))/2;
    if(cy0>=pocket_y-44 && cy0<=pocket_y-36)begin
     if(records[slot*76+73+:2]==3)feed_e++;
     if(records[slot*76+73+:2]==2)feed_p++;
     if(records[slot*76+73+:2]==1)feed_u++;
    end
    if(cy0>=pocket_y-4 && cy0<=pocket_y+4 && records[slot*76+73+:2]==3)pocket_e++;
    $display("ROLE_RECORD case=%0d slot=%0d kind=%0d y=%0d x0=%0d x1=%0d",c,slot,records[slot*76+73+:2],cy0,records[slot*76+31+:11],records[slot*76+20+:11]);
   end
   if(feed_e || feed_p)errors++;
   $display("ROLE_CASE case=%0d body=%0d pocket_y=%0d feed_y=%0d feed_w=%0d feed_gray=%0d feed_E=%0d feed_P=%0d feed_U=%0d pocket_E=%0d",c,body_present,pocket_y,pocket_y-40,feed_w,feed_gray,feed_e,feed_p,feed_u,pocket_e);
   c++;
  end
 endtask
 initial begin
  for(bp=0;bp<2;bp++)for(bw=8;bw<=16;bw+=2)for(bg=95;bg<=180;bg+=(bg==95 ? 15 : 70))begin
   body_present=bp;feed_w=bw;feed_h=bw;pocket_y=320;feed_gray=bg;run_case();
  end
  for(bp=0;bp<2;bp++)for(by0=304;by0<=344;by0+=8)begin
   body_present=bp;feed_w=12;feed_h=12;pocket_y=by0;feed_gray=180;run_case();
  end
  $display("DIAG_SWEEP_COMPLETE cases=%0d cases_with_wrong_feed_target=%0d; synthetic RGB, not field replay",c,errors);$finish;
 end
'''+s[end:]
s=s.replace("#(64'd3000000000)","#(64'd10000000000)")
(out/'tb_tail_role_sweep.sv').write_text(s)
proof['fixture']=hashlib.sha256((out/'tb_tail_role_sweep.sv').read_bytes()).hexdigest()
(out/'INPUT_SHA256.json').write_text(json.dumps(proof,indent=2)+'\n')
print('Frozen published production RTL and synthetic hole-role sweep')
