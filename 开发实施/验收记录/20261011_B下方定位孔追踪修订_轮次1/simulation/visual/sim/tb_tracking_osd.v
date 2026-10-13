`timescale 1ns/1ps
module tb_tracking_osd;
reg clk=0,rst=0,vs=0,hs=0,de=0,tv=0;reg [10:0] tx0=472,tx1=552;
always #5 clk=~clk;
wire ov,oh,od;wire [23:0] color;
experiment_osd #(.TRACKING(1),.HOLE_Y(380)) dut(
 .clk(clk),.rst_n(rst),.vs(vs),.hs(hs),.de(de),.rgb(24'h556677),
 .exposure(16'd2244),.gain(16'd48),.wb_r(8'd64),.wb_b(8'd64),.wb_tune(1'b0),.wb_pending(1'b0),
 .view_mode(2'd1),.edge_count(13'd0),.edge_sum(24'd0),.roi_valid(tv),.roi_mean(8'd120),.roi_min(8'd20),.roi_max(8'd180),.roi_state(2'd2),
 .width(16'd1024),.height(16'd600),.fps(16'd27),.lane_errors(16'd0),.format_errors(16'd0),.i2c_errors(16'd0),.gaps(16'd0),
 .frames(32'd3),.uptime(32'd8),.cfg_done(1'b1),.overflow_frames(16'd0),.lost_frames(16'd0),.underflow_frames(16'd0),.diagnostics(36'd0),
 .track_valid(tv),.track_x0(tx0),.track_x1(tx1),.track_reason(tv ? 4'd0 : 4'd2),.track_rows(tv ? 3'd7 : 3'd0),.out_vs(ov),.out_hs(oh),.out_de(od),.out_rgb(color));
integer xx,yy,n=0,frame_no=0,expected_x0,expected_x1;
reg expected_valid=0,checking=0;
integer px,py,ppm;
reg [7:0] ascii_rows[0:2047];
reg [79:0] status_text;
reg [127:0] reason_text;
integer glyph;
initial $readmemh("osd_assets/osd_ascii_rom.hex",ascii_rows);
always @(negedge clk) if(checking && od) begin
 px=n%1024;py=n/1024;
 if(py>=148 && py<164 && px>=256 && px<336) begin
  status_text=expected_valid ? "TRACK LOCK" : "TRACK WAIT";
  glyph=status_text[79-((px-256)/8)*8-:8];
  if(color!==(ascii_rows[glyph*16+py-148][7-((px-256)%8)] ? 24'hffffff : 24'h142336))
   $fatal(1,"tracking status label mismatch at %0d,%0d",px,py);
 end
 if(py>=148 && py<164 && px>=352 && px<480) begin
  reason_text=expected_valid ? "OK              " : "NO HOLE         ";
  glyph=reason_text[127-((px-352)/8)*8-:8];
  if(color!==(ascii_rows[glyph*16+py-148][7-((px-352)%8)] ? 24'hffffff : 24'h142336))
   $fatal(1,"tracking reason label mismatch at %0d,%0d",px,py);
 end
 if(py>=372 && py<=388 && px>=400 && px<650) begin
  if((px%16==0 && (py==372 || py==380 || py==388)) || px==464) begin
   if(color!==24'hffff00) $fatal(1,"lower hole guide absent");
  end else if(color!==24'h556677) $fatal(1,"lower hole guide misplaced");
 end
 if(py>=260 && py<340 && px>=400 && px<650) begin
  if(expected_valid && px>=expected_x0 && px<expected_x1 &&
     (px==expected_x0 || px==expected_x1-1 || py==260 || py==339)) begin
   if(color!==24'h00ffff) $fatal(1,"dynamic frame box missed at %0d,%0d color %h",px,py,color);
  end else if(!expected_valid && px>=472 && px<552 &&
     (px==472 || px==551 || py==260 || py==339) && (px%8==0 || py%8==0)) begin
   if(color!==24'hffff00) $fatal(1,"waiting alignment box absent");
  end else if(color!==24'h556677) $fatal(1,"old/wrong frame box drawn at %0d,%0d color %h",px,py,color);
 end
 $fwrite(ppm,"%d %d %d\n",color[23:16],color[15:8],color[7:0]);
 n=n+1;
end
task raster(input integer shift,input integer valid_target);
 begin
  frame_no=frame_no+1;ppm=$fopen($sformatf("tracking_%0d.ppm",frame_no),"w");$fwrite(ppm,"P3\n1024 600\n255\n");
  checking=0;tv=0;tx0=472;tx1=552;
  @(negedge clk);vs=1;repeat(25) @(negedge clk);vs=0;
  // Simulate the new DDR slot arriving AFTER VS, during blanking.
  repeat(40) @(negedge clk);tv=valid_target;tx0=472+shift;tx1=552+shift;
  expected_valid=valid_target;expected_x0=tx0;expected_x1=tx1;n=0;checking=1;
  for(yy=0;yy<600;yy=yy+1) begin
   de=1;hs=1;for(xx=0;xx<1024;xx=xx+1) @(negedge clk);
   de=0;hs=0;repeat(20) @(negedge clk);
   // The next camera frame must not move this display frame's box.
   if(yy==100) begin tv=1;tx0=620;tx1=700;end
  end
  repeat(5) @(negedge clk);
  if(n!=614400) $fatal(1,"tracking OSD raster incomplete");checking=0;$fclose(ppm);
 end
endtask
initial begin
 repeat(5) @(negedge clk);rst=1;raster(12,1);raster(-16,1);raster(0,0);
 $display("PASS tracking OSD: post-VS slot metadata, complete rasters, moving box, no mid-frame jump, lost target hides box");$finish;
end
initial begin #25000000;$fatal(1,"tracking OSD watchdog");end
endmodule
