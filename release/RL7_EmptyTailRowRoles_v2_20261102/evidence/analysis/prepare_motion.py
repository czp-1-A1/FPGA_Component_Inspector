from pathlib import Path
import hashlib,json,shutil
root=Path(__file__).resolve().parent
repo=Path('D:/CodexWork/erole_fix_20261102')
old=(repo/'tests/rl7_alarm_roles_v3/tb_all_empty_rgb_alarm.sv').read_text()
s=old.replace('tb_all_empty_rgb_alarm','tb_tail_29_plus_7_rgb')
s=s.replace('frame_shape_search #(', 'frame_shape_search #(.POCKET_ROW_ROLES(1),',1)
s=s.replace('pocket_relay_stop_v2 #(', 'pocket_relay_stop_v2 #(.EMPTY_ONLY_STOP(1),',1)
s=s.replace('integer lead=870','integer lead=871')
s=s.replace('wire [2:0] ms,ls,state;', 'wire [3:0] event_reason; wire [2:0] ms,ls,state;')
s=s.replace('.event_kind(kind),\n  .stop_begin', '.event_kind(kind),.event_reason(event_reason),\n  .stop_begin',1)
s=s.replace('function integer empty(input integer n);empty=1;endfunction', '''// These prefix positions are SYNTHETIC, not the user's unknown per-hole truth.
 function integer empty(input integer n);empty=n==2 || n==8 || n==16 || n==17 || n==21 || n==27 || n>=29;endfunction''')
begin=s.index(' function integer image(');end=s.index(' task frame(',begin)
s=s[:begin]+''' // Stimulus advances independently of feed_enable. This is a full-traverse
 // observer test, not a motor-feedback claim. Separate alarm latch assertion
 // records the fifth appended E at ID34 before two externally advanced holes.
 function integer image(input integer xx,yy);
  integer n,dx,dy,cx,offset;begin
   image=material_present ? 30 : 150;
   if(material_present && yy>=257 && yy<=345)begin
    offset=xx-lead;
    // Pockets are disjoint (<64px): nearest centre avoids 36 pixel-time loops.
    if(offset>=-32 && offset<29*64-32) n=(offset+32)/64;
    else if(offset>=29*64 && offset<36*64) n=29+(offset-29*64)/64;
    else n=-1;
    if(n>=0 && n<36)begin
     cx=lead+n*64+(n>=29 ? 32 : 0);dx=xx-cx;dy=yy-321;
     if(empty(n))begin
      if(n>=29)begin if(ellipse(xx,yy,cx,321,6,6))image=180;end
      else if(ellipse(xx,yy,cx,321,14,12))image=180;
     end else if(n==1)begin
      if(dx>=-6 && dx<6 && dy>=-22 && dy<22)image=180;
     end else if(dx>=-18 && dx<18 && dy>=-22 && dy<22 &&
        !((dx< -14 || dx>=14)&&(dy< -14 || dy>=14)))image=180;
     if(ellipse(xx,yy,cx,281,16,14))image=180;
    end
   end
  end
 endfunction
'''+s[end:]
begin=s.index(' always @(negedge clk)if(rst_n)begin');end=s.index(' initial begin #(64',begin)
s=s[:begin]+''' integer alarm_id=0,alarm_count=0,kind_errors=0,review_events=0;
 reg alarm_seen=0;
 always @(negedge clk)if(rst_n)begin
  if(ev_new)begin
   events++;
   $display("TAIL_EVENT id=%0d kind=%0d reason=%0h source=%0d lead=%0d",ev_id,kind,event_reason,current_frame,lead);
   if(ev_id!=events || kind!=(empty(events-1) ? 3 : 2))begin
    kind_errors++;$display("TAIL_MISMATCH expected_id=%0d expected_kind=%0d",events,empty(events-1) ? 3 : 2);
   end
   if(event_reason!=0 && kind==2)review_events++;
  end
  if(alarm_stop && !alarm_seen)begin
   alarm_seen=1;alarm_count++;alarm_id=main_total;
   $display("TAIL_ALARM total=%0d present=%0d empty=%0d review=%0d feed=%0b",main_total,main.pt,main.et,main.rt,feed);
   if(main_total!=34 || main.pt!=23 || main.et!=11 || main.rt!=1 || feed)
    $fatal(1,"fifth appended EMPTY did not stop at physical ID34");
  end
  if(alarm_seen && (!alarm_stop || feed))$fatal(1,"alarm failed to remain stopped while external observer input advances");
 end
 initial begin
  ticks(5);rst_n=1;ticks(5);command=2;ticks(5);
  frame(0);
  for(k=0;k<170;k++)begin
   frame(1);lead-=16;
  end
  $display("TAIL_FINAL total=%0d present=%0d empty=%0d review=%0d events=%0d kind_errors=%0d alarm_id=%0d review_events=%0d",main_total,main.pt,main.et,main.rt,events,kind_errors,alarm_id,review_events);
  if(events!=36 || main_total!=36 || main.pt!=23 || main.et!=13 || main.rt!=1 ||
     kind_errors!=0 || review_events!=1 || alarm_count!=1 || alarm_id!=34 || !alarm_stop || feed)
    $fatal(1,"29+7 full RGB truth or fifth-EMPTY observer contract failed");
  $display("PASS TAIL 29+7 RGB: 171 full1280x720 source frames, synthetic22normal/6E/1review then7E; full36/22normal/13E/1review; alarm34; external motion after alarm explicitly separate from motor closed loop");$finish;
 end
'''+s[end:]
s=s.replace("#(64'd3000000000)","#(64'd15000000000)")
for label,source in [('motion_r2',root/'frozen_r0'),('motion_r3',repo/'fpga/component_inspector/user_source/hdl_source')]:
 out=root/label;out.mkdir(exist_ok=False)
 for p in (root/'frozen_r0').glob('*.v'):shutil.copy2(source/p.name,out/p.name)
 bench=s if label=='motion_r3' else s.replace('.POCKET_ROW_ROLES(1),','')
 (out/'tb_tail_29_plus_7_rgb.sv').write_text(bench)
 proof={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in out.iterdir()}
 (out/'INPUT_SHA256.json').write_text(json.dumps(proof,indent=2)+'\n')
 print('Frozen',label,len(proof),'inputs')
