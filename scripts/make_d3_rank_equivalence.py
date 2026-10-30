"""Create a fixed four-zone pre-optimization oracle and real RGB rank stress."""
from pathlib import Path
import hashlib,json
r=Path(__file__).resolve().parents[1];t=r/'tests/dual_stop_d3'
old=Path('E:/2026FPGA/.codex_tmp/d3_dual_stop_build_r11_resource_opt_20261030/project/user_source/hdl_source/frame_shape_search.v')
raw=old.read_bytes();s=raw.decode().replace('\r\n','\n')
ref=t/'r11_reference_frame_shape_search.sv';assert not ref.exists()
ref.write_bytes(s.replace('module frame_shape_search #','module r11_reference_frame_shape_search #',1).replace('empty_gate_trace','r11_reference_empty_gate_trace').encode())
b=(t/'tb_d3_pixels.sv').read_text();instance=b[b.index(' frame_shape_search #'):b.index('\n r27b_reference_frame_shape_search #')]
instance=instance.replace(".recorder_hold_valid(1'b0),.recorder_hold_x(11'd0),.recorder_hold_y(10'd0)",'.recorder_hold_valid(hold),.recorder_hold_x(11\'d440),.recorder_hold_y(10\'d320)')
instance=instance.replace(".recorder_hold_valid2(1'b0),.recorder_hold_x2(11'd0),.recorder_hold_y2(10'd0)",'.recorder_hold_valid2(hold),.recorder_hold_x2(11\'d440),.recorder_hold_y2(10\'d516)')
instance=instance.replace(".station_hold_valid(2'd0),.station_hold_x(22'd0),.station_hold_y(20'd0)",".station_hold_valid({2{hold}}),.station_hold_empty_only(2'b11),.station_hold_x({11'd88,11'd88}),.station_hold_y({10'd516,10'd320})")
reference=instance.replace('frame_shape_search #','r11_reference_frame_shape_search #',1).replace(' dut(', ' baseline(').replace('.ready(ready)', '.ready(reference_ready)').replace('.sample_new(sample)', '.sample_new(reference_sample)').replace('.station_objects(station_records)', '.station_objects(reference_station)').replace('.transport_occupied(occupied)', '.transport_occupied(reference_occupied)').replace('.probe_record(probe)', '.probe_record(reference_probe)').replace('.recorder_objects(records)', '.recorder_objects(reference_records)').replace('.region_objects(display_objects)', '.region_objects(reference_display)')
header=b[:b.index(' frame_shape_search #')].replace('module tb_d3_pixels;', 'module tb_d3_rank_pixels;')
header+=" wire [607:0] reference_station;wire [303:0] reference_display;wire [1:0] reference_occupied;reg hold=0;\n"
body=b[b.index(' integer pattern=0'):b.index(' task ticks(')]
body=body[:body.index(' function integer wanted')]+''' function integer image(input integer xx,yy);
  integer zone,k,xxc,yyc,dx,dy,kind,extent;
  begin image=30;
   for(zone=0;zone<4;zone++)for(k=0;k<8;k++)begin
    xxc=zone>=2 ? 88+k*44 : 440+k*60;yyc=zone%2 ? 516 : 320;
    dx=xx-xxc;dy=yy-yyc;kind=pattern==0 ? 2 : pattern==1 || pattern==3 || pattern==4 ? 3 : k%3==0 ? 3 : 2;
    if(pattern==4 && k==0)kind=0;
    if(pattern==5 || pattern==6)kind=1;
    if(pattern==7)kind=0;
    if(kind==3 && ellipse(xx,yy,xxc,yyc,14,12))image=180;
    if(kind==2 && dx>=-18 && dx<18 && dy>=-22 && dy<22 && !((dx< -14 || dx>=14)&&(dy< -14 || dy>=14)))image=180;
    if(kind==1 && dx>=-9 && dx<9 && dy>=-(9+k%2) && dy<9+k%2)image=180;
    if(ellipse(xx,yy,xxc,yyc+40,16,14))image=180;
   end
   if(pattern==6)begin
    image=30;
    for(zone=0;zone<4;zone++)for(k=0;k<4;k++)begin
     xxc=zone>=2 ? 88+k*96 : 460+k*120;yyc=zone%2 ? 516 : 320;dx=xx-xxc;dy=yy-yyc;extent=k%2 ? 57 : 55;
     // Half-scale areas exceed 2047; full ranking counts must not truncate.
     if(dx>=-41 && dx<41 && dy>=-extent && dy<extent)image=180;
    end
   end
  end
 endfunction
'''
tail=''' task ticks(input integer k);repeat(k)@(negedge clk);endtask
 task frame(input integer p);
  begin pattern=p;hold=p==3 || p==4;fs=1;ticks(1);fs=0;ticks(3);
   for(py=0;py<720;py++)begin
    for(px=0;px<1280;px+=4)begin x=px;y=py;sof=px==0 && py==0;accept=1;
     for(l=0;l<4;l++)begin v=image(px+l,py);rgb[95-l*24-:24]={3{8'(v)}};end
     ticks(1);accept=0;sof=0;
    end
    ticks(2);
   end
   waited=0;while(!(ready && reference_ready) && waited<1500000)begin ticks(1);waited++;end
   if(!reference_ready || !ready)$fatal(1,"rank analysis timeout");ticks(2);
   if(records!==reference_records || station_records!==reference_station || display_objects!==reference_display || probe!==reference_probe || occupied!==reference_occupied)
    $fatal(1,"rank semantics changed scene%0d main%h ref%h station%h refstation%h probe%h refprobe%h",p,records,reference_records,station_records,reference_station,probe,reference_probe);
   for(lane=0;lane<4;lane++)for(slot=0;slot<4;slot++)begin
    rec=lane>=2 ? station_records[((lane-2)*4+slot)*76+:76] : records[(lane*4+slot)*76+:76];
    if(rec[75])checks++;
   end
   frames++;
  end
 endtask
 initial begin
  ticks(5);rst=1;ticks(3);
  for(integer p=0;p<8;p++)frame(p);
  cancel=1;ticks(3);cancel=0;ticks(2);frame(2);
  if(checks<64)$fatal(1,"rank scenes retained too few candidates");
  $display("PASS lossless rank storage vs original four-zone renderer: %0d full RGB frames %0d retained records, >4 candidate replacement/ties, held far-slot EMPTY, missing-held target, full18-bit large unknown count, FG saturation, empty/cancel/restart; all1216 candidate bits +304 UI +128 diagnostic +occupied exact",frames,checks);$finish;
 end
 initial begin #400000000;$fatal(1,"rank pixels watchdog");end
endmodule
'''
(t/'tb_d3_rank_pixels.sv').write_text(header+instance+reference+'\n'+body+tail)
(r/'docs/D3_RANK_REFERENCE.json').write_text(json.dumps({'source':str(old),'raw_sha256':hashlib.sha256(raw).hexdigest(),'reference':str(ref),'reference_sha256':hashlib.sha256(ref.read_bytes()).hexdigest(),'changes':'Only module names and newline normalization; original four-zone R11 behavior.'},indent=2)+'\n')
print('Wrote original four-zone RGB rank oracle')
