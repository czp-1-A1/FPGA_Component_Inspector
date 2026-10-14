from pathlib import Path
r=Path.cwd();p=r/'fpga/component_inspector'
f=p/'td_project/camera_to_dsi_display.al';t=f.read_text(encoding='utf-8');line=next(l for l in t.splitlines() if 'frame_process_bridge.v' in l);t=t.replace(line,line.replace('Val="123"','Val="124"'));f.write_text(t,encoding='utf-8')
f=p/'sim/tb_frame_osd.v';t=f.read_text(encoding='utf-8').replace('D9 PFB W1C200','DA PFB W1C200').replace('FRAME EXP V8','FRAME EXP V9');f.write_text(t,encoding='utf-8')
f=p/'sim/tb_frame_process.v';t=f.read_text(encoding='utf-8')
t=t.replace('reg [17:0] request=1;','reg [31:0] image_config=32\'h08c40030;\nreg [17:0] request=1;')
t=t.replace('.image_config({16\'d2244,16\'d48})','.image_config(image_config)')
t=t.replace('fs=1;ticks(1);fs=0;ticks(48);',"if(kind==3)image_config={16'd2260,16'd49};\n fs=1;ticks(1);fs=0;ticks(48);")
t=t.replace('aa=meta[198+:76];bb=meta[274+:76];', 'if(meta[169:138]!==image_config)$fatal(1,"image configuration came from previous frame");\n   aa=meta[198+:76];bb=meta[274+:76];')
# Independent queue stores accepted native RGB/coordinates, not bridge packing.
a=t.index('function integer source(')
t=t[:a]+'''reg [116:0] native_truth[0:262143];integer native_tail=0,post_head=0;
always @(posedge clk)if(rst && dut.roi_accept)begin
 native_truth[native_tail%262144]={dut.roi_y,dut.roi_x,dut.awb_O_tdata};native_tail++;
end
always @(posedge procclk)if(rst && dut.post_accept)begin
 if(post_head>=native_tail || {dut.post_y,dut.post_x,dut.post_rgb}!==native_truth[post_head%262144])
  $fatal(1,"native accepted RGB/coordinates changed through asynchronous processing beat=%0d",post_head);
 post_head++;
end
''' +t[a:]
t=t.replace('if(accepted_frames!=6 || overflows!=0 || underflows!=0)', 'if(post_head!=native_tail)$fatal(1,"native accepted pixel records did not all reach processing");\n if(accepted_frames!=6 || overflows!=0 || underflows!=0)')
f.write_text(t,encoding='utf-8')
f=p/'sim/tb_process_bridge.v';t=f.read_text(encoding='utf-8').replace('run_s=1,rst=0','run_s=1,run_d=1,checking=1,rst=0').replace('always #5 dclk=~dclk;','always #5 if(run_d)dclk=~dclk;').replace('if(rst && ov)begin','if(rst && ov && checking)begin')
t=t.replace('$display("PASS process bridge:', '''checking=0;run_s=1;@(negedge dclk);run_d=0;
 for(integer x=0;x<700;x++)begin @(negedge sclk);valid=1;data=x;end
 @(negedge sclk);valid=0;run_d=1;#20000;
 if(!overflow)$fatal(1,"lost bridge records were not reported as overflow");
 rst=0;#100;rst=1;#200;
 if(overflow)$fatal(1,"bridge overflow did not clear on reset");
 $display("PASS process bridge:''')
t=t.replace('stopped source drain and resume','stopped source drain and resume, overflow latched until reset')
f.write_text(t,encoding='utf-8')
print('Prepared V9 marker, configuration-tag and exact accepted-pixel/overflow checks')
