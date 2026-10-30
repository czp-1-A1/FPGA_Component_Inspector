"""Derive an independent previous-renderer pixel oracle, plus overlap stress."""
from pathlib import Path
import json,hashlib
r=Path(__file__).resolve().parents[1];t=r/'tests/dual_stop_d3'
s=(t/'tb_d3_osd.sv').read_text()
instance=s[s.index(' compact_inspector_osd #'):s.index('\n function [75:0] object_at')]
ref=instance.replace('compact_inspector_osd #','r11_reference_compact_inspector_osd #',1).replace(' dut(',' baseline(').replace('.out_vs(ov),.out_hs(oh),.out_de(od),.out_rgb(pixel)', '.out_vs(rv),.out_hs(rh),.out_de(rd),.out_rgb(ref_pixel)')
compare='''
 wire rv,rh,rd;wire [23:0] ref_pixel;
 always @(posedge clk)begin
  #2;if(rst_n && ({ov,oh,od}!=={rv,rh,rd} || od && pixel!==ref_pixel))
   $fatal(1,"OSD previous-renderer pixel mismatch x%0d y%0d new%h ref%h",dut.x,dut.y,pixel,ref_pixel);
 end
'''
s=s.replace('module tb_d3_osd;','module tb_d3_osd_equivalence;',1)
s=s.replace('\n function [75:0] object_at',compare+ref+'\n function [75:0] object_at',1)
(t/'tb_d3_osd_equivalence.sv').write_text(s)
# Exhaust the combinational label overlap/priority/edge/font path with actual
# full rasters in both pages and arbitrary but known snapshot records.
stress=s[:s.index(' task text_at')]
stress=stress.replace('module tb_d3_osd_equivalence;','module tb_d3_osd_overlap;',1)
stress=stress.replace('reg [127:0] relay_status=0;', 'reg page=0,eligible=1;reg [127:0] relay_status=0;',1)
stress=stress.replace('.page(1\'b1)', '.page(page)').replace('.eligible(1\'b1)', '.eligible(eligible)')
stress+='''
 integer scene,seed=32'h41acd25f,compared=0;
 always @(posedge clk)begin #3;if(rst_n && od)compared++;end
 initial begin
  repeat(10)@(negedge clk);rst_n=1;
  for(scene=0;scene<8;scene++)begin
   page=scene[0];eligible=scene!=6;
   for(integer k=0;k<16;k++)begin live[k*32+:32]=$random(seed);packet[k*32+:32]=$random(seed);end
   for(integer b=0;b<2;b++)begin
    live[b*256+47-:16]=7;packet[b*256+47-:16]=7+(scene==7 && b==1);
    live[b*256+50-:3]=2;packet[b*256+50-:3]=2;packet[b*256+223]=1;
    packet[b*256+57]=scene[1];live[b*256+57]=scene[1];
   end
   case(scene/2)
    0:begin
     objects[75:0]=object_at(550,300,2,0);objects[151:76]=object_at(554,240,3,0);
     objects[227:152]=object_at(558,310,2,1);objects[303:228]=object_at(560,250,1,15);
    end
    1:begin
     objects[75:0]=object_at(1240,100,2,0);objects[151:76]=object_at(1200,590,3,0);
     objects[227:152]=object_at(1230,96,2,1);objects[303:228]=object_at(1220,620,1,7);
    end
    2:begin
     objects[75:0]=object_at(6,106,3,0);objects[151:76]=object_at(20,80,1,5);
     objects[227:152]=object_at(50,108,2,0);objects[303:228]=object_at(35,92,2,1);
     objects[151]=0;
    end
    3:begin
     objects[75:0]=object_at(800,432,2,0);objects[151:76]=object_at(820,472,3,0);
     objects[227:152]=object_at(808,435,1,7);objects[303:228]=object_at(824,476,2,1);
    end
   endcase
   vs=1;repeat(4)@(negedge clk);vs=0;repeat(10)@(negedge clk);
   for(yy=0;yy<720;yy++)begin
    hs=1;repeat(2)@(negedge clk);hs=0;de=1;
    for(xx=0;xx<1280;xx++)@(negedge clk);
    de=0;repeat(10)@(negedge clk);
    if(yy==350)begin live=~live;packet=~packet;objects=~objects;relay_status=~relay_status;end
   end
   repeat(8)@(negedge clk);
  end
  if(compared!=8*1280*720)$fatal(1,"incomplete raster oracle");
  $display("PASS shared OSD exact previous-renderer equivalence: 8 complete rasters %0d pixels, both pages, overlap last-slot priority, all P/E/review/unknown classes, clamp and top/bottom boundaries, invalid slots, generation/eligibility guards and atomic mid-frame changes",compared);$finish;
 end
 initial begin #100000000;$fatal(1,"OSD oracle watchdog");end
endmodule
'''
(t/'tb_d3_osd_overlap.sv').write_text(stress)
print('Wrote two original-renderer pixel equivalence benches')
