from pathlib import Path
import json,re,shutil,hashlib
from PIL import Image
r=Path.cwd();p=r/'fpga/component_inspector';rd=r/'tmp/small_dual_edit_20261018';s=rd/'source_snapshot'
sha=lambda q:hashlib.sha256(q.read_bytes()).hexdigest()
# Frozen operator specification: ROI160x104 centered at(640,300)/(640,420),
# one result per lane; every valid label follows its current box, not the ROI.
cases=[dict(rec=[(2,0,610,648,278,322),(3,0,634,650,412,428)],valid=1,mode=3,e=1092,g=40,f=27,error=0),
 dict(rec=[(2,4,634,672,278,322),(2,15,612,650,400,444)],valid=1,mode=0,e=1200,g=48,f=26,error=0),
 dict(rec=[(2,0,610,648,278,322),(3,0,634,650,412,428)],valid=0,mode=1,e=1200,g=48,f=26,error=1),
 dict(rec=[None,(3,0,642,658,412,428)],valid=1,mode=2,e=1092,g=40,f=27,error=0)]
ar=[int(x,16) for x in (s/'sim/osd_assets/osd_ascii_rom.hex').read_text().split()]
cr=[int(x,16) for x in (s/'sim/osd_assets/compact_cjk.hex').read_text().split()]
lr=[int(x,16) for x in (s/'sim/osd_assets/osd_logo_rom.hex').read_text().split()]
def ascii_text(im,x,y,text,color):
 for i,ch in enumerate(text):
  for yy in range(16):
   v=ar[ord(ch)*16+yy]
   for xx in range(8):
    if v&(128>>xx):im.putpixel((x+i*8+xx,y+yy),color)
def chinese(im,x,y,ids,color):
 for i,g in enumerate(ids):
  for yy in range(24):
   v=cr[g*32+yy]
   for xx in range(24):
    if v&(1<<(23-xx)):im.putpixel((x+i*24+xx,y+yy),color)
def render(c):
 im=Image.new('RGB',(1280,720),(85,102,119));pix=im.load()
 for y in range(48):
  for x in range(1280):pix[x,y]=(20,35,54)
 for y in range(32):
  for x in range(48):pix[16+x,8+y]=[(255,255,255),(32,70,134),(204,37,59)][lr[(y*2)*128+x*2]]
 mode=['RAW      ','GRAY     ','EDGE     ','GRAY+EDGE'][c['mode']]
 ascii_text(im,80,16,f"ANLOGIC 3528 E{c['e']:5d} G{c['g']:5d} FPS{c['f']:5d} {mode}",(216,229,237))
 ascii_text(im,688,16,'CHECK' if c['error'] else 'RUN  ',(239,113,134) if c['error'] else (116,219,199))
 ascii_text(im,1160,16,'SMALL DUAL R1',(216,229,237))
 for lane,rec in enumerate(c['rec']):
  y0,y1=(248,352) if lane==0 else (368,472)
  active=c['valid'] and rec is not None;state=rec[0] if active else 1;reason=rec[1] if active else 0
  color=(145,164,180) if state<2 else (255,174,100) if state==3 else (255,204,85) if reason else (116,219,199)
  if active:
   _,_,a,b,d,e=rec
   for y in range(d,e):
    for x in range(a,b):
     if x in (a,b-1) or y in (d,e-1):pix[x,y]=color
  for y in range(y0,y1):
   for x in range(560,720):
    if ((x in (560,719) and y%8<4) or (y in (y0,y1-1) and x%8<4)):pix[x,y]=(101,146,167)
  a=min(rec[2],1120) if active else 560;b=(rec[4]-28 if rec[4]>=80 else rec[5]+4) if active else y0-28
  for y in range(b,b+24):
   for x in range(a,a+160):pix[x,y]=(20,35,54)
  ascii_text(im,a,b+4,str(lane+1),color)
  ids=[5,6,7] if state<2 else [3,4] if state==3 else [1,2,8,9] if reason else [1,2]
  chinese(im,a+24,b,ids,color)
 return im
for i,c in enumerate(cases):
 im=render(c);im.save(rd/f'ui_case_{i}.png')
 (s/f'sim/lane_ui_{i}.hex').write_text(''.join(f'{a:02x}{b:02x}{c:02x}\n' for a,b,c in im.getdata()),encoding='ascii')
(s/'sim/lane_ui_spec.json').write_text(json.dumps(cases,indent=2)+'\n',encoding='utf-8')
def rec(z):return "76'd0" if z is None else "record("+','.join(str(x) for x in z)+')'
tb=r'''`timescale 1ns/1ps
module tb_lane_osd;
reg clk=0,rst=0,vs=0,hs=0,de=0,valid=1;reg [303:0] objects=0;
reg [15:0] ex=1092,ga=40,fp=27,gap=0;reg [1:0] mode=3;wire ov,oh,od;wire [23:0] rgb;
always #5 clk=~clk;
experiment_osd #(.WIDTH(1280),.HEIGHT(720),.REGIONS(1),.LOCAL_SEARCH(1),.FRAME_OBJECTS(1)) dut(
 .clk(clk),.rst_n(rst),.vs(vs),.hs(hs),.de(de),.rgb(24'h556677),.exposure(ex),.gain(ga),.fps(fp),.view_mode(mode),
 .roi_valid(valid),.cfg_done(1'b1),.frame_objects(objects),.lane_errors(16'd0),.format_errors(16'd0),.i2c_errors(16'd0),.gaps(gap),
 .overflow_frames(16'd0),.lost_frames(16'd0),.underflow_frames(16'd0),.out_vs(ov),.out_hs(oh),.out_de(od),.out_rgb(rgb));
wire bv,bh,bd;wire [23:0] brgb;
experiment_osd #(.WIDTH(1280),.HEIGHT(720),.REGIONS(1),.FRAME_OBJECTS(1),.ENABLE(0)) bypass(
 .clk(clk),.rst_n(rst),.vs(vs),.hs(hs),.de(de),.rgb(24'h556677),.exposure(ex),.gain(ga),.fps(fp),.view_mode(mode),
 .roi_valid(valid),.cfg_done(1'b1),.frame_objects(objects),.lane_errors(16'd0),.format_errors(16'd0),.i2c_errors(16'd0),.gaps(gap),
 .overflow_frames(16'd0),.lost_frames(16'd0),.underflow_frames(16'd0),.out_vs(bv),.out_hs(bh),.out_de(bd),.out_rgb(brgb));
reg [23:0] expected[0:921599];reg [2:0] ed=0,eh=0,ev=0;
function [75:0] record(input integer state,reason,x0,x1,y0,y1);
 record={1'b1,2'(state),4'(reason),13'd4000,7'd36,7'd44,11'(x0),11'(x1),10'(y0),10'(y1)};
endfunction
task set_case(input integer c);begin
case(c)
// CASES
endcase
end endtask
integer frame=0,pixel=0,checks=0,xx,yy;reg checking=0;
always @(posedge clk)begin
 ed={ed[1:0],de};eh={eh[1:0],hs};ev={ev[1:0],vs};#1;
 if(rst && ({od,oh,ov}!=={ed[2],eh[2],ev[2]} || {bd,bh,bv}!=={ed[2],eh[2],ev[2]}))$fatal(1,"lane UI sync/bypass latency");
 if(checking && od)begin
  if(rgb!==expected[pixel])$fatal(1,"lane UI case%0d x%0d y%0d got%h expected%h",frame,pixel%1280,pixel/1280,rgb,expected[pixel]);
  if(brgb!==24'h556677)$fatal(1,"lane UI bypass changed pixel");pixel++;checks++;
 end
end
task ticks(input integer n);repeat(n)@(negedge clk);endtask
initial begin
 ticks(5);rst=1;ticks(5);
 for(frame=0;frame<4;frame++)begin
  set_case(frame);$readmemh($sformatf("lane_ui_%0d.hex",frame),expected);
  vs=1;ticks(3);vs=0;ticks(4);pixel=0;checking=1;
  for(yy=0;yy<720;yy++)begin
   hs=1;ticks(2);hs=0;de=1;ticks(1280);de=0;ticks(4);
   if(yy==360)set_case((frame+1)%4); // New tuple must wait for next raster.
  end
  ticks(5);checking=0;if(pixel!=921600)$fatal(1,"lane UI raster coverage");
 end
 $display("PASS lane OSD: 4 full rasters/%0d independent pixels, moving labels follow boxes,2 lanes,unused slots ignored,invalid clears,atomic snapshots,logo/fonts/header,3-clock sync and ENABLE bypass",checks);$finish;
end
initial begin #70000000;$fatal(1,"lane UI watchdog");end
endmodule
'''
ct=[]
for i,c in enumerate(cases):
 # Populate both discarded slots deliberately. They must never leak on screen.
 ct.append(f"{i}:begin objects={{record(2,0,900,940,500,544),{rec(c['rec'][1])},record(3,0,480,496,260,276),{rec(c['rec'][0])}}};valid={c['valid']};mode={c['mode']};ex={c['e']};ga={c['g']};fp={c['f']};gap={c['error']};end")
(s/'sim/tb_lane_osd.v').write_text(tb.replace('// CASES','\n'.join(ct)),encoding='utf-8')
shutil.copy2(r/'tmp/tb_lane_search.v.txt',s/'sim/tb_lane_search.v')
# Retain the original full serialized video/address oracle. New production
# compact UI is covered by an additional actual-HDMI run, not a bypass.
t=(s/'sim/tb_hd_pins.v').read_text('utf-8').replace('module tb_hd_pins;','module tb_lane_hd_pins;')
t=t.replace('wire [151:0] objects={record(3,0,1180,1202,590,612),record(2,0,1080,1148,480,560)};',f"wire [303:0] objects={{76'd0,{rec(cases[0]['rec'][1])},76'd0,{rec(cases[0]['rec'][0])}}};")
t=t.replace('experiment_osd #(.WIDTH(1280)', 'experiment_osd #(.REGIONS(1),.WIDTH(1280)',1).replace(".exposure(16'd2244),.gain(16'd48)",".exposure(16'd1092),.gain(16'd40)")
a=t.index(' // Only the declared version banner changed');b=t.index(' function automatic [7:0] decode_rgb',a)
t=t[:a]+' initial $readmemh("lane_ui_0.hex",overlay);\n'+t[b:]
t=t.replace('PASS hd pins:','PASS lane hd pins:');(s/'sim/tb_lane_hd_pins.v').write_text(t,encoding='utf-8')
q=s/'sim/run_modelsim.ps1';t=(p/'sim/run_modelsim.ps1').read_text('utf-8')
def entry(oldname,newname,oldpass,newpass,oldtb,newtb):
 line=next(l for l in t.splitlines() if f'Name="{oldname}"' in l)
 return line.replace(f'Name="{oldname}"',f'Name="{newname}"').replace(oldpass,newpass).replace(oldtb,newtb)
entries=[entry('threshold180','lane_search','PASS threshold180:','PASS lane search:','tb_threshold180.v','tb_lane_search.v'),entry('regions_osd','lane_osd','PASS regions osd:','PASS lane OSD:','tb_regions_osd.v','tb_lane_osd.v'),entry('hd_pins','lane_hd_pins','PASS hd pins:','PASS lane hd pins:','tb_hd_pins.v','tb_lane_hd_pins.v')]
t=t.replace('    $tests = @(\n','    $tests = @(\n'+'\n'.join(entries)+'\n',1);q.write_text(t,encoding='utf-8')
shutil.copy2(p/'sim/tb_csi_pixels.v',s/'sim/tb_csi_pixels.v')
# Freeze all inputs before invoking simulation or synthesis.
fr=r/'tmp/small_dual_r0_20261018';fr.mkdir(exist_ok=False)
for n in ['source_snapshot','scripts']:shutil.copytree(rd/n,fr/n)
shutil.copy2(rd/'baseline.json',fr/'baseline.json')
m=json.loads((fr/'source_snapshot/inputs.json').read_text('utf-8'))
for q in (fr/'source_snapshot/sim').glob('lane_*'):m[q.relative_to(fr/'source_snapshot').as_posix()]=sha(q)
for name in ['sim/tb_lane_search.v','sim/tb_lane_osd.v','sim/tb_lane_hd_pins.v','sim/tb_csi_pixels.v','sim/osd_assets/compact_cjk.hex']:m[name]=sha(fr/'source_snapshot'/name)
for name in m:m[name]=sha(fr/'source_snapshot'/name)
(fr/'source_snapshot/inputs.json').write_text(json.dumps(m,indent=2)+'\n',encoding='utf-8')
q=fr/'scripts/replay.py';t=q.read_text('utf-8');t=re.sub(r'^TESTS = .+$',"TESTS = ['lane_search','lane_osd','lane_hd_pins','threshold180','pose180','field180','cal180_holes','cal180_body','regions_osd','hd_pins','sobel_view','sobel_tail','dynamic_sobel']",t,count=1,flags=re.M);q.write_text(t,encoding='utf-8')
print('FROZEN',fr.name,len(m),'inputs',sha(fr/'source_snapshot/inputs.json'))
