`timescale 1ns/1ps
module tb_calibration_osd;
reg clk=0,rst=0,vs=0,hs=0,de=0,eligible=1;reg [127:0] measurements=0;reg [3:0] reason=6;
always #5 clk=~clk;
wire ov,oh,od;wire [23:0] rgb;
experiment_osd #(.WIDTH(1280),.HEIGHT(720),.DIAG_BITS(27),.RESOLUTION_V11(1),.REGIONS(1),.LOCAL_SEARCH(1),.SHAPE_MODEL(1),.DIRECT_DETECTION(1),.FRAME_OBJECTS(1),.CALIBRATION(1)) dut(
 .clk(clk),.rst_n(rst),.vs(vs),.hs(hs),.de(de),.rgb(24'h556677),.exposure(16'd1092),.gain(16'd40),
 .wb_r(8'd100),.wb_b(8'd100),.wb_tune(1'b0),.wb_pending(1'b0),.view_mode(2'd0),.edge_count(13'd0),.edge_sum(24'd0),
 .local_box_valid(1'b0),.local_x0(11'd0),.local_x1(11'd0),.local_y0(10'd0),.local_y1(10'd0),
 .frame_objects(304'd0),.roi_valid(1'b1),.roi_mean(8'd120),.roi_min(8'd30),.roi_max(8'd180),.roi_state(2'd1),
 .width(16'd1920),.height(16'd1080),.fps(16'd27),.lane_errors(16'd0),.format_errors(16'd0),.i2c_errors(16'd0),.gaps(16'd0),
 .frames(32'd3),.uptime(32'd8),.cfg_done(1'b1),.overflow_frames(16'd0),.lost_frames(16'd0),.underflow_frames(16'd0),
 .diagnostics(36'd0),.publish_diagnostic({1'b0,8'hfb,18'h2a300}),.pocket_records(340'd0),.pocket_enable(1'b0),
 .track_valid(1'b0),.track_x0(11'd0),.track_x1(11'd0),.track_reason(4'd0),.track_rows(3'd0),
 .calibration_record(measurements),.calibration_valid(eligible),.local_wait_reason(reason),
 .out_vs(ov),.out_hs(oh),.out_de(od),.out_rgb(rgb));
reg [7:0] font[0:2047];initial $readmemh("osd_assets/osd_ascii_rom.hex",font);
integer px,py,n=0,checked=0,probe,rr,cc,row,cy;reg checking=0,expected_valid=1,panel,outline;
reg [287:0] text_line;reg [7:0] glyph;reg [23:0] expected,ink;
reg [2:0] hd=0,hh=0,hv=0;
always @(posedge clk)begin hd={hd[1:0],de};hh={hh[1:0],hs};hv={hv[1:0],vs};#1;
 if(rst && (od!==hd[2] || oh!==hh[2] || ov!==hv[2]))$fatal(1,"OSD sync pipeline changed");end
always @(negedge clk)if(checking && od)begin
 px=n%1280;py=n/1280;panel=0;outline=0;expected=24'h556677;ink=24'h74dbc7;text_line=0;rr=0;cc=0;row=0;probe=0;
 if(px>=16 && px<304 && ((py>=96 && py<160) || (py>=432 && py<496)))begin
  panel=1;probe=py>=432;rr=(py-(probe ? 432 : 96))/16;row=(py-(probe ? 432 : 96))%16;
  case(rr)
   0:text_line=probe ? "CAL2 T080 OUT32 CORE16              " : "CAL1 T120 OUT32 CORE16              ";
   1:text_line=expected_valid ? (probe ? "M255 MIN255 MAX255 SAT256           " : "M123 MIN045 MAX222 SAT128           ") : "M--- MIN--- MAX--- SAT---           ";
   2:text_line=expected_valid ? (probe ? "W032 H032 A1024 CLIP1               " : "W024 H020 A0384 CLIP0               ") : "W--- H--- A---- CLIP-               ";
   3:text_line=!expected_valid ? "WAIT CURRENT FRAME                  " : probe ? "CLIP: RECENTER TARGET               " : "SAMPLE OK / ONE TARGET ONLY         ";
  endcase
  ink=!expected_valid ? 24'hb0c0d4 : probe ? 24'hffcc55 : 24'h74dbc7;
 end
 if(px>=16 && px<304 && py>=176 && py<208)begin
  panel=1;row=(py-176)%16;text_line=py<192 ? "RAW100 GRAY080 EDGE120 BOTH140      " : "BODY100 HOLE080 / CAL NOT FROZEN    ";ink=24'hb0c0d4;
 end
 if(px>=16 && px<304 && py>=584 && py<600)begin panel=1;row=py-584;text_line="WAIT: EXP/GAIN CHANGED              ";ink=24'hffcc55;end
 if(panel)begin
  cc=(px-16)/8;glyph=text_line[287-cc*8-:8];expected=font[glyph*16+row][7-(px-16)%8] ? ink : 24'h142336;
 end
 for(integer z=0;z<2;z++)begin
  cy=z ? 516 : 320;
  // The old64px outline must be gone.
  if(px>=608 && px<672 && py>=cy-32 && py<cy+32 && (px==608 || px==671 || py==cy-32 || py==cy+31))begin outline=1;expected=24'h556677;end
  if(px>=624 && px<656 && py>=cy-16 && py<cy+16 && (px==624 || px==655 || py==cy-16 || py==cy+15))begin outline=1;expected=24'hff66cc;end
  if(px>=632 && px<648 && py>=cy-8 && py<cy+8 && (px==632 || px==647 || py==cy-8 || py==cy+7))begin outline=1;expected=24'hffff00;end
 end
 if(panel || outline)begin if(rgb!==expected)$fatal(1,"calibration pixel%0d,%0d got%h expected%h valid%0d",px,py,rgb,expected,expected_valid);checked++;end
 n++;
end
function [63:0] probe_record(input integer second);
 begin probe_record=second ? {1'b1,1'b1,2'd1,8'd255,8'd255,8'd255,9'd256,13'd1024,7'd32,7'd32} :
 {1'b1,1'b0,2'd2,8'd123,8'd45,8'd222,9'd128,13'd384,7'd24,7'd20};end
endfunction
task raster(input integer v);begin
 checking=0;eligible=v;reason=6;measurements={probe_record(1),probe_record(0)};expected_valid=v;
 vs=1;repeat(20)@(negedge clk);vs=0;repeat(30)@(negedge clk);n=0;checking=1;
 for(integer yy=0;yy<720;yy++)begin
  de=1;hs=1;for(integer xx=0;xx<1280;xx++)@(negedge clk);
  de=0;hs=0;repeat(20)@(negedge clk);
  if(yy==220)begin measurements=0;eligible=0;reason=0;end
 end
 repeat(6)@(negedge clk);checking=0;if(n!=921600)$fatal(1,"incomplete raster");
end endtask
initial begin
 repeat(5)@(negedge clk);rst=1;repeat(5)@(negedge clk);raster(1);raster(0);
 $display("PASS calibration OSD: two complete rasters, %0d independent glyph/border pixels, OUT32 header and exact32px outline, old64px outline absent, unchanged16px core/area/clip values, both centers, WAIT, first-active atomic snapshot, three-clock sync",checked);$finish;
end
initial begin #22000000;$fatal(1,"calibration OSD timeout");end
endmodule
