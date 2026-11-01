from pathlib import Path
import hashlib,json
root=Path(__file__).resolve().parent;repo=Path('D:/CodexWork/erole_fix_20261102');folder=repo/'tests/pocket_row_roles'
s=(root/'frozen_r3/tb_tail_aperture_sweep.sv').read_text().replace('tb_tail_aperture_sweep','tb_pocket_row_contract')
s=s.replace('reg clk=0;', 'integer feed_present=1,feed_offset=-40; reg cancel=0;\n reg clk=0;',1)
s=s.replace('.invalidate(1\'b0)', '.invalidate(cancel)')
s=s.replace('if(ellipse(xx,yy,700+xyphase,pocket_y-40,feed_w,feed_h))', 'if(feed_present && ellipse(xx,yy,700+xyphase,pocket_y+feed_offset,feed_w,feed_h))')
begin=s.index(' integer c=0,bw,');end=s.index(' initial begin #(64',begin)
s=s[:begin]+''' integer c=0,slot,cy0,cx0,pocket_e,feed_target,checks=0;
 task check_frame(input integer expect_empty);
  begin
   frame(1);pocket_e=0;feed_target=0;
   for(slot=0;slot<4;slot++)if(records[slot*76+75])begin
    cy0=(integer'(records[slot*76+10+:10])+integer'(records[slot*76+:10]))/2;
    cx0=(integer'(records[slot*76+31+:11])+integer'(records[slot*76+20+:11]))/2;
    if(cx0>=696 && cx0<=706 && cy0>=pocket_y-4 && cy0<=pocket_y+4 && records[slot*76+73+:2]==3)pocket_e++;
    if(feed_present && feed_offset!=0 && cy0>=pocket_y+feed_offset-4 && cy0<=pocket_y+feed_offset+4 && records[slot*76+73+:2]>=2)feed_target++;
   end
   $display("ROW_CONTRACT case=%0d feed_present=%0d offset=%0d body=%0d y=%0d w=%0d gray=%0d actual_E=%0d expected_E=%0d wrong_feed_target=%0d",c,feed_present,feed_offset,body_present,pocket_y,pocket_w,pocket_gray,pocket_e,expect_empty,feed_target);
   if(pocket_e!=expect_empty || feed_target!=0)$fatal(1,"pocket/feed role, current-frame evidence or negative evidence contract failed");
   checks++;c++;
  end
 endtask
 initial begin
  rst_n=0;ticks(5);rst_n=1;ticks(5);command=2;ticks(5);frame(0);
  // Exact small-aperture phase witness without any present-body anchor.
  xyphase=1;pocket_y=321;pocket_w=6;pocket_h=6;pocket_gray=180;
  check_frame(1);
  // A prior frame's feed row cannot certify this source frame.
  feed_present=0;check_frame(0);
  feed_present=1;check_frame(1);
  cancel=1;ticks(2);cancel=0;feed_present=0;check_frame(0);
  feed_present=1;check_frame(1);
  rst_n=0;ticks(5);rst_n=1;ticks(5);command=2;ticks(5);feed_present=0;check_frame(0);
  // A currently measured body still proves the row without a feed hole.
  body_present=1;check_frame(1);body_present=0;
  // Below-row and excessively far contours do not provide upper-feed proof.
  feed_present=1;feed_offset=40;check_frame(0);
  feed_offset=-100;check_frame(0);
  feed_offset=-40;pocket_y=349;check_frame(0);
  // Weak small locating-hole witness: old code counted this as EMPTY.
  pocket_y=320;xyphase=0;pocket_w=14;pocket_h=12;feed_w=8;feed_h=8;feed_gray=95;check_frame(1);
  body_present=1;check_frame(1);
  // No bright evidence at a real cavity is never promoted to EMPTY.
  pocket_gray=30;check_frame(0);
  $display("PASS POCKET ROW CONTRACT: %0d complete RGB frames asserting small-hole recovery, weak upper-hole rejection, current frame/reset/cancel, missing-feed/body, off-row and dark-cavity negatives",checks);$finish;
 end
'''+s[end:]
(folder/'tb_pocket_row_contract.sv').write_text(s)
(folder/'tb_tail_29_plus_7_rgb.sv').write_bytes((root/'motion_r3/tb_tail_29_plus_7_rgb.sv').read_bytes())
old=(repo/'tests/rl7_alarm_roles_v3/tb_all_empty_rgb_alarm.sv').read_text()
s=old.replace('tb_all_empty_rgb_alarm','tb_small_tail_closed_loop')
s=s.replace('frame_shape_search #(', 'frame_shape_search #(.POCKET_ROW_ROLES(1),',1).replace('pocket_relay_stop_v2 #(', 'pocket_relay_stop_v2 #(.EMPTY_ONLY_STOP(1),',1)
s=s.replace('integer lead=870','integer lead=871').replace('n<6;n++','n<7;n++')
s=s.replace('cx,320,14,12','cx,321,6,6').replace('cx,280,16,14','cx,281,16,14')
s=s.replace('PASS ALL EMPTY RGB ALARM:', 'PASS SMALL TAIL CLOSED LOOP:')
(folder/'tb_small_tail_closed_loop.sv').write_text(s)
# Log input-generation mistake before execution; unrun r0/r1 remain archived.
(root/'motion_unrun_r0_r1.json').write_text(json.dumps({'status':'NOT_EXECUTED_STIMULUS_DRAFT','paths':['motion_r0','motion_r1'],'reason':'Nearest-centre tail segment had a +32 offset twice. Corrected before any simulation, r2/r3 independently compared. No test expectation changed.'},indent=2)+'\n')
print('Frozen 3 asserted RGB contracts; moving observer copied exactly; old closed-loop shape witness narrowed to real6px,7E,odd phase')
