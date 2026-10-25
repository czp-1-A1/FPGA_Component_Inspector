"""Create separate P03 integration tests; retain all original P02 stimuli/oracles."""
from pathlib import Path
import hashlib
import json

P=Path(__file__).resolve().parents[1]
D=P/'sim/standing'
def replace(text,old,new):
 assert text.count(old)==1,(old,text.count(old))
 return text.replace(old,new,1)

# RGB: retain eight P02 scenes and add a ninth standing scene. Four instances
# compare P01/default-off/P02-active/P03-active without rewriting their answers.
s=(P/'sim/surface/tb_surface_detector.sv').read_text(encoding='utf-8-sig')
s=s.replace('tb_surface_detector','tb_standing_detector')
s=replace(s,'wire ar,an,br,bn,cr,cn,apr,bpr,cpr;',
          'wire ar,an,br,bn,cr,cn,apr,bpr,cpr,er,en;wire [607:0] ec;')
needle='integer scene=0,clocks=0,checks=0,means=0,changed=0,seen_baseline=0;'
baseline='''frame_shape_search_p02 #(.SURFACE_REVIEW(1),.REVIEW_PROBE(1),.WIDTH(1280),.HEIGHT(720),.REGIONS(1),.COUNT_EMPTY_MARGIN(1),
 .ROW_GUARDED_BRIGHT_EMPTY(1),.COUNT_CANDIDATES(1),.MULTITHRESHOLD_EMPTY(1)) frozen_p02(
 .clk(clk),.rst_n(rst_n),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.invalidate(cancel),
 .pixel_x(x),.pixel_y(y),.rgb(rgb),.ready(er),.sample_new(en),.recorder_objects(ec),
 .recorder_hold_valid(1'b0),.recorder_hold_x(11'd0),.recorder_hold_y(10'd0));
'''
s=replace(s,needle,baseline+needle+'integer new_standing_changes=0;')
s=replace(s,' clocks++;',' clocks++;\n if({br,bn}!=={er,en})$fatal(1,"P03 changed P02 active classification latency");')
s=replace(s,'w=scene==5 ? 30 : scene==6 ? 44 : 36;h=scene==5 ? 38 : scene==6 ? 38 : 48;',
          'w=scene==5 ? 30 : (scene==6 || scene==8) ? 44 : 36;h=(scene==5 || scene==6 || scene==8) ? 38 : 48;')
s=replace(s,'cy=(scene==4 ? (bank ? 516 : 320) : (bank ? 598 : 242))+(scene==5);',
          'cy=(scene==4 ? (bank ? 516 : 320) : (bank ? 598 : 242))+(scene==5 || scene==8);')
s=replace(s,'if(scene==6 && xx>=cx+2 && xx<cx+16 && yy>=cy-14 && yy<cy+14)image=30;',
 '''if(scene==6 && xx>=cx+2 && xx<cx+16 && yy>=cy-14 && yy<cy+14)image=30;
     if(scene==8)begin
      image=189;
      if(xx>=cx-8 && xx<cx+8 && yy>=cy-8 && yy<cy+8)image=192;
      if(xx>=cx-16 && xx<cx-8 && yy>=cy-8 && yy<cy+8)image=205;
      if(xx>=cx+8 && xx<cx+16 && yy>=cy-8 && yy<cy+8)image=186;
      if(yy>=cy-16 && yy<cy-8 && xx>=cx-8 && xx<cx+8)image=171;
     end''')
s=s.replace('scalar_mean','scalar_total')
s=replace(s,'  scalar_total=total/n;','  scalar_total=total;')
s=replace(s,'integer cx,cy,c,m,e,pass,valids;','integer cx,cy,c,m,e,pass,valids,ct,st,mx;')
s=replace(s,'''    c=scalar_total(cx,cy,0);m=31;
    for(integer f=1;f<5;f++)begin e=scalar_total(cx,cy,f);if(e<m)m=e;end
    pass=c>=13 && m*5>=c*4 && a[55:49]>=32 && a[48:42]>=32;''',
 '''    ct=scalar_total(cx,cy,0);c=ct/64;m=31;mx=0;
    for(integer f=1;f<5;f++)begin st=scalar_total(cx,cy,f);e=st/32;if(e<m)m=e;if(st>mx)mx=st;end
    pass=c>=13 && m*5>=c*4 && mx*2<=ct+16 && a[55:49]>=32 && a[48:42]>=32;''')
s=replace(s,'  check_packet(bc,saved_base);', '''  check_packet(bc,saved_base);
  if(scene!=8)begin if(bc!==ec)$fatal(1,"changed prior P02 classification scene%0d",scene);end
  else for(integer slot=0;slot<8;slot++)begin
   if(ec[slot*76+69+:4]!==0 || bc[slot*76+69+:4]!==8)
    $fatal(1,"standing did not isolate P02 normal to P03 review slot%0d old=%h new=%h",slot,ec[slot*76+:76],bc[slot*76+:76]);
   new_standing_changes++;
  end''')
s=replace(s,'for(integer n=0;n<8;n++)frame(n);','for(integer n=0;n<9;n++)frame(n);')
s=replace(s,' if(changed<8)$fatal', ' if(new_standing_changes!=8)$fatal(1,"not all8 standing targets corrected");\n if(changed<8)$fatal')
s=s.replace('PASS surface detector:8','PASS P03 standing detector:9')
(D/'tb_standing_detector.sv').write_text(s,encoding='utf-8')

# Native RAW: first frame includes the new bright-edge standing part, followed
# by all seven unchanged original native scenarios and their existing guards.
s=(P/'sim/surface/tb_surface_raw_chain.v').read_text(encoding='utf-8-sig')
s=s.replace('tb_surface_raw_chain','tb_standing_raw_chain').replace('PASS surface raw chain:','PASS P03 standing raw chain:')
s=replace(s,'if(px>=1128 && px<1152 && ((yy>=456 && yy<468) || (yy>=756 && yy<768)))source=420;',
 '''if(pattern!=5 && px>=1128 && px<1152 && ((yy>=456 && yy<468) || (yy>=756 && yy<768)))source=420;
  if(pattern==5 && px>=1113 && px<1167 && ((yy>=447 && yy<513) || (yy>=747 && yy<813)))source=600;
  if(pattern==5 && px>=1113 && px<1137 && ((yy>=447 && yy<513) || (yy>=747 && yy<813)))source=840;''')
s=s.replace('surface_mean','surface_total')
s=replace(s,'  surface_total=total/n;','  surface_total=total;')
s=replace(s,'integer cx,cy,c,m,e,expected,valid_objects;',
          'integer cx,cy,c,m,e,expected,valid_objects,ct,st,mx,old_proof;')
s=replace(s,'''    c=surface_total(cx,cy,0);m=31;
    for(integer f=1;f<5;f++)begin e=surface_total(cx,cy,f);if(e<m)m=e;end
    surface_total_checks+=5;expected=c>=13 && 5*m>=4*c;''',
 '''    ct=surface_total(cx,cy,0);c=ct/64;m=31;mx=0;
    for(integer f=1;f<5;f++)begin st=surface_total(cx,cy,f);e=st/32;if(e<m)m=e;if(st>mx)mx=st;end
    surface_total_checks+=5;old_proof=c>=13 && 5*m>=4*c;expected=old_proof && mx*2<=ct+16;
    if(pattern==5 && cx>700 && (!old_proof || expected))
     $fatal(1,"native new pose failed isolation old=%0d new=%0d Csum=%0d edgeSum=%0d",old_proof,expected,ct,mx);''')
s=replace(s,'frame(0,0);frame(0,0);frame(4,0);frame(3,0);frame(3,3);frame(3,1);frame(3,2);',
          'frame(5,0);frame(0,0);frame(0,0);frame(4,0);frame(3,0);frame(3,3);frame(3,1);frame(3,2);')
s=replace(s,'accepted_frames!=7','accepted_frames!=8')
(D/'tb_standing_raw_chain.v').write_text(s,encoding='utf-8')

s=(P/'sim/surface/tb_surface_counting.v').read_text(encoding='utf-8-sig')
s=s.replace('tb_surface_counting','tb_standing_counting').replace('PASS surface counting:','PASS P03 standing counting:')
(D/'tb_standing_counting.v').write_text(s,encoding='utf-8')

s=(P/'sim/surface/tb_surface_ui.sv').read_text(encoding='utf-8-sig')
s=s.replace('tb_surface_ui','tb_standing_ui').replace('PASS surface UI:','PASS P03 standing UI:')
s=s.replace('surface/ui_out/surface_ui_','standing/ui_out/standing_ui_')
(D/'tb_standing_ui.sv').write_text(s,encoding='utf-8');(D/'ui_out').mkdir()
v=(P/'sim/surface/verify_surface_ui_pixels.py').read_text(encoding='utf-8-sig')
v=v.replace('DETECT P02','DETECT P03').replace('COUNT P02','COUNT P03').replace('surface_ui_','standing_ui_').replace('P02_DESIGN_INPUTS.json','P03_DESIGN_INPUTS.json')
(D/'verify_standing_ui_pixels.py').write_text(v,encoding='utf-8')
(D/'UI_REFERENCE_PROVENANCE.json').write_text(json.dumps(dict(parent_sha256=hashlib.sha256((P/'sim/surface/verify_surface_ui_pixels.py').read_bytes()).hexdigest(),
 changes=['P03 title literals','output/provenance paths'],DUT_formatter_evaluated=False),indent=2),encoding='utf-8')
r=(P/'sim/run_surface_tests.ps1').read_text(encoding='utf-8-sig')
r=r.replace('surface_raw_chain','standing_raw_chain').replace('surface_ui','standing_ui')
r=r.replace('surface/tb_standing_raw_chain.v','standing/tb_standing_raw_chain.v').replace('surface/tb_standing_ui.sv','standing/tb_standing_ui.sv')
r=r.replace('PASS surface raw chain:','PASS P03 standing raw chain:').replace('PASS surface UI:','PASS P03 standing UI:')
(P/'sim/run_standing_tests.ps1').write_text(r,encoding='utf-8')
print('Created independent P03 RGB/native/count/UI tests; original P02 test and gold files retained')
