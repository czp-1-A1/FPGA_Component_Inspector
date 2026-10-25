"""Derive a separate independent P03 testbench; retain every old P02 test file."""
from pathlib import Path
P=Path(__file__).resolve().parents[1]
dest=P/'sim/standing/tb_present_surface_standing.sv'
assert not dest.exists()
s=(P/'sim/surface/tb_present_surface_check.sv').read_text(encoding='utf-8-sig')
s=s.replace('tb_present_surface_check','tb_present_surface_standing')
s=s.replace('wire ready,normal;','wire ready,normal,old_ready,old_normal;')
s=s.replace('present_surface_check dut(clk,rst_n,cancel,we,measure,wx,wy,wd,xmin,xmax,ymin,ymax,ready,normal);',
 '''present_surface_check dut(clk,rst_n,cancel,we,measure,wx,wy,wd,xmin,xmax,ymin,ymax,ready,normal);
present_surface_check_p02 baseline(clk,rst_n,cancel,we,measure,wx,wy,wd,xmin,xmax,ymin,ymax,old_ready,old_normal);''')
s=s.replace('integer expected[0:4];','integer expected[0:4],expected_total[0:4];integer ex_old,old_only=0;')
s=s.replace('if(mode==11)v=254;if(mode==12)v=242;if(mode==13)v=175;',
 '''if(mode==11)v=254;if(mode==12)v=242;if(mode==13)v=175;
   if(mode>=14 && mode<=18)v=192;
   if(mode==19 || mode==20)v=200;
   if(mode==21)v=255;if(mode==22)v=176;''')
s=s.replace('   gray=v;', '''   if(mode==14)begin
    if(x>=cx-16 && x<cx-8 && y>=cy-8 && y<cy+8)v=205;
    if(x>=cx+8 && x<cx+16 && y>=cy-8 && y<cy+8)v=186;
    if(y>=cy-16 && y<cy-8 && x>=cx-8 && x<cx+8)v=171;
    if(y>=cy+8 && y<cy+16 && x>=cx-8 && x<cx+8)v=189;
   end
   if(mode==15 && x>=cx-16 && x<cx-8 && y>=cy-8 && y<cy+8)v=208;
   if(mode==16 && x>=cx+8 && x<cx+16 && y>=cy-8 && y<cy+8)v=208;
   if(mode==17 && y>=cy-16 && y<cy-8 && x>=cx-8 && x<cx+8)v=208;
   if(mode==18 && y>=cy+8 && y<cy+16 && x>=cx-8 && x<cx+8)v=208;
   if((mode==19 || mode==20) && x>=cx-16 && x<cx-8 && y>=cy-8 && y<cy+8 &&
      (((y-(cy-8))/2)*4+(x-(cx-16))/2)<(mode==19 ? 8 : 9))v=208;
   if(mode==22 && x>=cx-16 && x<cx-8 && y>=cy-8 && y<cy+8)v=206;
   gray=v;''')
s=s.replace('integer f,x,y,x0,x1,y0,y1,total,n,minimum;',
            'integer f,x,y,x0,x1,y0,y1,total,n,minimum,maximum;')
s=s.replace('   expected[f]=total/n;','   expected_total[f]=total;expected[f]=total/n;')
s=s.replace('  ex_normal=expected[0]>=13 && 5*minimum>=4*expected[0];',
 '''  ex_old=expected[0]>=13 && 5*minimum>=4*expected[0];
  maximum=expected_total[1];for(f=2;f<5;f=f+1)if(expected_total[f]>maximum)maximum=expected_total[f];
  ex_normal=ex_old && maximum*2<=expected_total[0]+16;''')
s=s.replace(' actual_feature=dut.feature;', ''' actual_feature=dut.feature;
 if(ready!==old_ready)$fatal(1,"P03 changed measurement latency");
 if(dut.next_sum!==expected_total[actual_feature])$fatal(1,"exact sum mismatch feature%0d",actual_feature);''')
s=s.replace('  if(features-saved_features!=(should_measure ? 5 : 0))$fatal(1,"unexpected feature count");',
 '''  if(old_ready!==ready || old_normal!==(should_measure ? ex_old : 0))$fatal(1,"frozen P02 reference disagreement");
  if(should_measure && old_normal && !normal)old_only++;
  if(features-saved_features!=(should_measure ? 5 : 0))$fatal(1,"unexpected feature count");''')
s=s.replace('for(k=0;k<14;k=k+1)','for(k=0;k<23;k=k+1)')
s=s.replace(' mode=0;clear_frame;capture(1);request(0);',
 ''' for(k=0;k<4;k=k+1)begin cx=400+2*k;cy=240;mode=14;clear_frame;capture(0);request(1);end
 cx=640;cy=320;mode=0;clear_frame;capture(1);request(0);''')
s=s.replace(' $display("PASS present surface:',
 ''' if(old_only<11)$fatal(1,"new bright-edge fixtures did not isolate old P02 false accepts");
 $display("PASS P03 standing surface:''')
dest.write_text(s,encoding='utf-8')
print('Created separate P03 unit/oracle; original P02 tests unchanged')
