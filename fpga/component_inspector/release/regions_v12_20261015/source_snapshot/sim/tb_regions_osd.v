`timescale 1ns/1ps
module tb_regions_osd;
reg clk=0,rst=0,vs=0,hs=0,de=0,valid=1;reg [303:0] objects=0,expected_objects=0;
reg [1:0] mode=3;wire ov,oh,od;wire [23:0] rgb;
always #5 clk=~clk;
experiment_osd #(.WIDTH(1280),.HEIGHT(720),.DIAG_BITS(27),.RESOLUTION_V11(1),.REGIONS(1),.LOCAL_SEARCH(1),.SHAPE_MODEL(1),.DIRECT_DETECTION(1),.FRAME_OBJECTS(1)) dut(
 .clk(clk),.rst_n(rst),.vs(vs),.hs(hs),.de(de),.rgb(24'h556677),.exposure(16'd2244),.gain(16'd48),
 .wb_r(8'd100),.wb_b(8'd100),.wb_tune(1'b0),.wb_pending(1'b0),.view_mode(mode),.edge_count(13'd0),.edge_sum(24'd0),
 .local_box_valid(1'b1),.local_x0(11'd479),.local_x1(11'd546),.local_y0(10'd261),.local_y1(10'd340),
 .frame_objects(objects),.roi_valid(valid),.roi_mean(8'd120),.roi_min(8'd30),.roi_max(8'd180),.roi_state(2'd2),
 .width(16'd1024),.height(16'd600),.fps(16'd27),.lane_errors(16'd0),.format_errors(16'd0),.i2c_errors(16'd0),.gaps(16'd0),
 .frames(32'd3),.uptime(32'd8),.cfg_done(1'b1),.overflow_frames(16'd0),.lost_frames(16'd0),.underflow_frames(16'd0),
 .diagnostics(36'd0),.publish_diagnostic({1'b0,8'hfb,18'h2a300}),.pocket_records(340'd0),.pocket_enable(1'b0),
 .track_valid(1'b0),.track_x0(11'd0),.track_x1(11'd0),.track_reason(4'd0),.track_rows(3'd0),.out_vs(ov),.out_hs(oh),.out_de(od),.out_rgb(rgb));
reg [7:0] ascii_rows[0:2047];reg [23:0] cjk_rows[0:2047];
initial begin $readmemh("osd_assets/osd_ascii_rom.hex",ascii_rows);$readmemh("osd_assets/osd_cjk_rom.hex",cjk_rows);end
function [75:0] record(input integer state,reason,x0,x1,y0,y1);
 begin record={1'b1,2'(state),4'(reason),13'd4000,7'd64,7'd76,11'(x0),11'(x1),10'(y0),10'(y1)};end
endfunction
integer ppm;
reg checking=0;integer n=0,checked=0,frames=0,px,py,glyph,col,row,s,r,lx,ly,bx0,bx1,by0,by1;
reg [23:0] expected,color;reg [75:0] a;reg [63:0] text_value;reg [103:0] version_value;reg cjk;
reg [2:0] hd=0,hh=0,hv=0;
always @(posedge clk)begin
 hd={hd[1:0],de};hh={hh[1:0],hs};hv={hv[1:0],vs};#1;
 if(rst && (od!==hd[2] || oh!==hh[2] || ov!==hv[2]))$fatal(1,"full OSD sync pipeline changed");
end
always @(negedge clk)if(checking && od)begin
 if(frames==1)$fwrite(ppm,"%c%c%c",rgb[23:16],rgb[15:8],rgb[7:0]);
 px=n%1280;py=n/1280;expected=24'h556677;
 if(py>=80 && py<624)begin
  // Independent specification: two 464x360 effective areas, 4-on/4-off dashes.
  for(integer zone=0;zone<2;zone++)begin
   integer zx0,zx1,zy0,zy1;
   zx0=400;zx1=880;zy0=zone==0 ? 240 : 432;zy1=zone==0 ? 400 : 600;
   if(px>=zx0 && px<zx1 && py>=zy0 && py<zy1 &&
      (((px==zx0 || px==zx1-1) && py%8<4) || ((py==zy0 || py==zy1-1) && px%8<4)))
     expected=zone==0 ? 24'h00ffff : 24'hc6a0ff;
  end
  for(integer obj=0;obj<4;obj++)begin
   a=expected_objects[obj*76+:76];s=a[74:73];r=a[72:69];bx0=a[41:31];bx1=a[30:20];by0=a[19:10];by1=a[9:0];
   color=s==2 ? (r!=0 ? 24'hffcc55 : 24'h74dbc7) : s==3 ? 24'hffae64 : 24'hb0c0d4;
   if(a[75])begin
    if(px>=bx0 && px<bx1 && py>=by0 && py<by1 && (px==bx0 || px==bx1-1 || py==by0 || py==by1-1))expected=color;
    lx=bx0>1176 ? 1176 : bx0;ly=obj%2==1 && by1<568 ? by1+4 : by0>=136 ? by0-56 : by1+4;if(ly>568)ly=568;
    if(px>=lx && px<lx+104 && py>=ly && py<ly+56)begin
     expected=24'h142336;cjk=0;row=0;glyph=" ";col=(px-lx)%8;
     if(py<ly+24)begin
      if(px<lx+24)begin if(py>=ly+4 && py<ly+20)begin
        case((px-lx)/8)0:glyph=obj<2 ? "1" : "2";1:glyph=".";2:glyph=obj%2==0 ? "1" : "2";endcase
        row=py-ly-4;end end
      else begin cjk=1;row=py-ly;col=(px-lx-24)%24;glyph=(px-lx-24)/24==0 ? (s==2 ? 18 : 20) : (px-lx-24)/24==1 ? (s==2 ? 19 : 21) : 0;end
     end else begin
      row=(py-ly-24)%16;
      if(s==2 && r!=0)text_value=py<ly+40 ? {r[0] ? "SIZE" : "----",8'd32,r[1] ? "ASP" : "---"} : {r[2] ? "FILL" : "----",8'd32,r[3] ? "REF" : "---"};
      else text_value=py<ly+40 ? "MODEL OK" : "EDGE ON ";
      if(px<lx+64)glyph=text_value[63-((px-lx)/8)*8-:8];
     end
     if(cjk ? cjk_rows[glyph*32+row][23-col] : ascii_rows[glyph*16+row][7-col])expected=color;
    end
   end
  end
  for(integer zone=0;zone<2;zone++)begin
   integer zx0,zy0;reg [127:0] header;reg hv;
   zx0=400;zy0=zone==0 ? 220 : 412;
   if(px>=zx0 && px<zx0+128 && py>=zy0 && py<zy0+16)begin
    hv=expected_objects[zone*152+75] || expected_objects[zone*152+151];
    header={zone==0 ? "R1 " : "R2 ","3528 ",!valid ? "WAIT    " : hv ? "READY   " : "NO TGT  "};
    glyph=header[127-((px-zx0)/8)*8-:8];col=(px-zx0)%8;row=py-zy0;
    expected=ascii_rows[glyph*16+row][7-col] ? (zone==0 ? 24'h00ffff : 24'hc6a0ff) : 24'h142336;
   end
  end
  if(rgb!==expected)$fatal(1,"full OSD pixel (%0d,%0d) got%h expected%h frame%0d",px,py,rgb,expected,frames);checked++;
 end
 if(py>=8 && py<24 && ((px>=128 && px<232) || (px>=240 && px<344)))begin
  version_value=px<232 ? "DD PFB W2A300" : "FRAME EXP V12";
  glyph=version_value[103-((px-(px<232?128:240))/8)*8-:8];col=(px-(px<232?128:240))%8;row=py-8;
  expected=ascii_rows[glyph*16+row][7-col] ? 24'hffffff : 24'h142336;
  if(rgb!==expected)$fatal(1,"full OSD version glyph");checked++;
 end
 n++;
end
task raster(input [303:0] value,input integer v);
 begin
 frames++;if(frames==1)begin ppm=$fopen("regions_osd.ppm","wb");$fwrite(ppm,"P6\n1280 720\n255\n");end
 checking=0;valid=v;objects=0;expected_objects=v ? value : 0;
 vs=1;repeat(20)@(negedge clk);vs=0;repeat(30)@(negedge clk);
 // Metadata arrives after VS, then changes halfway through active video.
 objects=value;checking=1;n=0;
 for(integer yy=0;yy<720;yy++)begin
  de=1;hs=1;for(integer xx=0;xx<1280;xx++)@(negedge clk);
  de=0;hs=0;repeat(20)@(negedge clk);if(yy==300)objects=0;
 end
 repeat(6)@(negedge clk);checking=0;if(frames==1)$fclose(ppm);if(n!=921600)$fatal(1,"full raster missing pixels");
 end
endtask
initial begin
 repeat(5)@(negedge clk);rst=1;repeat(5)@(negedge clk);
 raster({record(3,0,750,772,510,532),record(2,0,486,554,482,562),record(2,8,726,794,282,362),record(2,0,486,554,282,362)},1);
 raster({76'd0,record(2,0,486,554,482,562),76'd0,record(2,5,486,554,282,362)},1);
 raster(0,1);raster({record(2,0,726,794,482,562),record(2,0,486,554,482,562),record(2,0,726,794,282,362),record(2,0,486,554,282,362)},0);
 $display("PASS regions osd: %0d rasters/%0d independent pixels, both boxes/classes/numbers/size-fill reasons, both dashed zones and bound model headers, four independent cards, first-active atomic snapshot, zero/stale result suppression, unchanged 3-clock sync",frames,checked);$finish;
end
initial begin #45000000;$fatal(1,"full OSD watchdog");end
endmodule
