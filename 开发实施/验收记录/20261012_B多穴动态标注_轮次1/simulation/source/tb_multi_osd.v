`timescale 1ns/1ps
module tb_multi_osd;
reg clk=0,rst=0,vs=0,hs=0,de=0,enable=0;reg [339:0] records=0,expected_records;
always #5 clk=~clk;
wire ov,oh,od;wire [23:0] color;
experiment_osd #(.TRACKING(1),.MULTI_POCKETS(1)) dut(
 .clk(clk),.rst_n(rst),.vs(vs),.hs(hs),.de(de),.rgb(24'h556677),
 .exposure(16'd2244),.gain(16'd48),.wb_r(8'd100),.wb_b(8'd100),.wb_tune(1'b0),.wb_pending(1'b0),
 .view_mode(2'd3),.edge_count(13'd0),.edge_sum(24'd0),.roi_valid(1'b1),.roi_mean(8'd120),.roi_min(8'd20),.roi_max(8'd180),.roi_state(2'd2),
 .width(16'd1024),.height(16'd600),.fps(16'd27),.lane_errors(16'd0),.format_errors(16'd0),.i2c_errors(16'd0),.gaps(16'd0),
 .frames(32'd3),.uptime(32'd8),.cfg_done(1'b1),.overflow_frames(16'd0),.lost_frames(16'd0),.underflow_frames(16'd0),.diagnostics(36'd0),.publish_diagnostic(25'd0),
 .track_valid(1'b1),.track_x0(11'd208),.track_x1(11'd288),.track_reason(4'd0),.track_rows(3'd7),
 .pocket_records(records),.pocket_enable(enable),.out_vs(ov),.out_hs(oh),.out_de(od),.out_rgb(color));
reg [7:0] ascii_rows[0:2047];reg [23:0] cjk_rows[0:2047];
reg [103:0] version_text="AUTO4 EXP V1 ";
integer n=0,xx,yy,px,py,p,bx,by,state,glyph,col,row,checked=0;
reg checking=0,expected_enable;reg [23:0] expected_color,ink_color;
reg [2:0] hist_de=0,hist_hs=0,hist_vs=0;
initial begin $readmemh("osd_assets/osd_ascii_rom.hex",ascii_rows);$readmemh("osd_assets/osd_cjk_rom.hex",cjk_rows);end
always @(posedge clk) begin
 hist_de={hist_de[1:0],de};hist_hs={hist_hs[1:0],hs};hist_vs={hist_vs[1:0],vs};
 #1;if(rst && (od!==hist_de[2] || oh!==hist_hs[2] || ov!==hist_vs[2])) $fatal(1,"three pixel sync delay changed");
end
always @(negedge clk) if(checking && od) begin
 px=n%1024;py=n/1024;
 if(py>=8 && py<24 && px>=240 && px<344) begin
  glyph=version_text[103-((px-240)/8)*8-:8];
  expected_color=ascii_rows[glyph*16+py-8][7-((px-240)%8)] ? 24'hffffff : 24'h142336;
  if(color!==expected_color) $fatal(1,"AUTO4 visible version mismatch");checked++;
 end
 // Interior region excludes header/footer; no old ROI or fixed guides may remain.
 if(py>=180 && py<450 && px>=128 && px<896) begin
  expected_color=24'h556677;
  for(p=0;p<4;p++) begin
   bx=expected_records[p*85+74+:11];by=expected_records[p*85+64+:10];state=expected_records[p*85+61+:2];
   ink_color=state==2 ? 24'h74dbc7 : state==3 ? 24'hffae64 : 24'hffff00;
   if(expected_enable && expected_records[p*85+63]) begin
    if(px>=bx && px<bx+80 && py>=by && py<by+80 && (px==bx || px==bx+79 || py==by || py==by+79)) expected_color=ink_color;
    if(px>=bx && px<bx+72 && py>=by-26 && py<by-2) begin
     col=(px-bx)%24;row=py-by+26;
     case(state)
      2:glyph=(px-bx)/24==0 ? 18 : (px-bx)/24==1 ? 19 : 0;
      3:glyph=(px-bx)/24==0 ? 20 : (px-bx)/24==1 ? 21 : 0;
      1:glyph=(px-bx)/24==0 ? 17 : (px-bx)/24==1 ? 34 : 35;
      default:glyph=(px-bx)/24==0 ? 13 : (px-bx)/24==1 ? 14 : 15;
     endcase
     expected_color=cjk_rows[glyph*32+row][23-col] ? ink_color : 24'h142336;
    end
   end
  end
  if(color!==expected_color) $fatal(1,"multi label/box/frame mismatch %0d,%0d got %h expected %h",px,py,color,expected_color);checked++;
 end
 n++;
end
task raster(input integer shift,input integer enabled);
 begin
  checking=0;enable=0;records=0;vs=1;repeat(25) @(negedge clk);vs=0;repeat(40) @(negedge clk);
  for(integer i=0;i<4;i++) records[i*85+:85]={11'(208+shift+i*96),10'(260+i*8),1'b1,2'(i==0 ? 2 : i==1 ? 3 : i==2 ? 1 : 0),8'd100,8'd30,8'd200,13'd100,24'd40000};
  // Slot arrives during blanking after VS, exactly as in the actual reader.
  enable=enabled;expected_enable=enabled;expected_records=records;n=0;checking=1;
  for(yy=0;yy<600;yy++) begin
   de=1;hs=1;for(xx=0;xx<1024;xx++) @(negedge clk);
   de=0;hs=0;repeat(20) @(negedge clk);
   if(yy==100) begin records=0;enable=0;end // Next capture must not alter this raster.
  end
  repeat(5) @(negedge clk);if(n!=614400) $fatal(1,"multi OSD raster incomplete");checking=0;
 end
endtask
initial begin
 repeat(5) @(negedge clk);rst=1;raster(0,1);raster(16,1);raster(0,0);
 $display("PASS multi OSD: %0d pixels; four independent colored boxes/Chinese labels, AUTO4 version, post-VS frame metadata, no mid-raster jump/stale boxes, three clock RGB/sync alignment",checked);$finish;
end
initial begin #25000000;$fatal(1,"multi OSD watchdog");end
endmodule
