`timescale 1ns/1ps
module tb_local_osd;
reg clk=0,rst=0,vs=0,hs=0,de=0,valid=1;
reg [1:0] mode=0,classification=2;
reg box_valid=1;reg [10:0] bx0=479,bx1=546;reg [9:0] by0=261,by1=340;
reg [7:0] mean=120;reg [12:0] ec=0;reg [23:0] gs=0;
always #5 clk=~clk;
wire ov,oh,od;wire [23:0] color;
experiment_osd #(.DIRECT_DETECTION(1),.SHAPE_MODEL(1),.LOCAL_SEARCH(1)) dut(
 .clk(clk),.rst_n(rst),.vs(vs),.hs(hs),.de(de),.rgb(24'h556677),
 .exposure(16'd2244),.gain(16'd48),.wb_r(8'd100),.wb_b(8'd100),.wb_tune(1'b0),.wb_pending(1'b0),
 .view_mode(mode),.edge_count(ec),.edge_sum(gs),.local_box_valid(box_valid),.local_x0(bx0),.local_x1(bx1),.local_y0(by0),.local_y1(by1),.roi_valid(valid),.roi_mean(mean),.roi_min(8'd20),.roi_max(8'd180),.roi_state(classification),
 .width(16'd1024),.height(16'd600),.fps(16'd27),.lane_errors(16'd0),.format_errors(16'd0),.i2c_errors(16'd0),.gaps(16'd0),
 .frames(32'd3),.uptime(32'd8),.cfg_done(1'b1),.overflow_frames(16'd0),.lost_frames(16'd0),.underflow_frames(16'd0),.diagnostics(36'd0),
 .publish_diagnostic({1'b0,8'hfb,17'h1c200}),.track_valid(1'b0),.track_x0(11'd0),.track_x1(11'd0),.track_reason(4'd2),.track_rows(3'd0),
 .pocket_records(340'd0),.pocket_enable(1'b0),.out_vs(ov),.out_hs(oh),.out_de(od),.out_rgb(color));
reg [7:0] ascii_rows[0:2047];reg [23:0] cjk_rows[0:2047];
reg [103:0] version_text="LOCAL EXP V7 ",diagnostic_text="D8 PFB W1C200";
reg [39:0] prefix;reg [23:0] expected,ink;
integer ex0,ex1,ey0,ey1,lx,ly;reg expected_box;integer n=0,px,py,row,col,glyph,label_state,checked=0,gstate,estate,expected_mode;
reg [36:0] feature_value;reg [199:0] feature_text;reg [1:0] main_expected;reg valid_expected,review_expected;reg checking=0,gray_row;reg [71:0] status_text;
reg [2:0] hist_de=0,hist_hs=0,hist_vs=0;
initial begin $readmemh("osd_assets/osd_ascii_rom.hex",ascii_rows);$readmemh("osd_assets/osd_cjk_rom.hex",cjk_rows);end
always @(posedge clk) begin
 hist_de={hist_de[1:0],de};hist_hs={hist_hs[1:0],hs};hist_vs={hist_vs[1:0],vs};
 #1;if(rst && (od!==hist_de[2] || oh!==hist_hs[2] || ov!==hist_vs[2])) $fatal(1,"direct three pixel sync delay");
end
always @(negedge clk) if(checking && od) begin
 px=n%1024;py=n/1024;
 if(py>=8 && py<24 && ((px>=128 && px<232) || (px>=240 && px<344))) begin
  glyph=px<232 ? diagnostic_text[103-((px-128)/8)*8-:8] : version_text[103-((px-240)/8)*8-:8];
  col=px<232 ? (px-128)%8 : (px-240)%8;
  expected=ascii_rows[glyph*16+py-8][7-col] ? 24'hffffff : 24'h142336;
  if(color!==expected)$fatal(1,"direct version/diagnostic pixel");checked++;
 end
 if(py>=172 && py<428 && px>=256 && px<768) begin
  expected=24'h556677;
  if(px==256 || px==767 || py==172 || py==427) expected=24'h00ff40;
  if(px>=416 && px<608 && py>=228 && py<372 && (px==416 || px==607 || py==228 || py==371) && ((px==416 || px==607)?py%4==0:px%4==0))expected=24'h00ffff;
  if(expected_box && px>=ex0 && px<ex1 && py>=ey0 && py<ey1 && (px==ex0 || px==ex1-1 || py==ey0 || py==ey1-1))expected=24'h00ffff;
  if(px>=lx && px<lx+112 && py>=ly-56 && py<ly-4) begin
   gray_row=py<ly-30;row=gray_row ? py-(ly-56) : py-(ly-30);label_state=gray_row ? gstate : estate;
   ink=review_expected ? 24'hffcc55 : label_state==2 ? 24'h74dbc7 : label_state==3 ? 24'hffae64 : 24'hb0c0d4;
   expected=24'h142336;
   if(px<lx+40 || !gray_row || (gray_row && gstate<2 && valid_expected)) begin
    col=(px-lx)%8;
    if(px<lx+40) begin prefix=gray_row ? "MODEL" : review_expected ? "FIT  " : "EDGE ";glyph=prefix[39-((px-lx)/8)*8-:8];end
    else if(gray_row)begin status_text=gstate==0 ? "NO TARGET" : "UNCERTAIN";glyph=status_text[71-((px-lx-40)/8)*8-:8];end
    else if(review_expected)begin case((px-lx-40)/8)0:glyph="C";1:glyph="H";2:glyph="E";3:glyph="C";4:glyph="K";default:glyph=" ";endcase end
    else begin case((px-lx-40)/8) 0:glyph="O";1:glyph=expected_mode>=2 ? "N" : "F";2:glyph=expected_mode>=2 ? " " : "F";default:glyph=" ";endcase end
    row=row>=5 && row<21 ? row-5 : 0;
    if(ascii_rows[glyph*16+row][7-col]) expected=ink;
   end else begin
    col=(px-lx-40)%24;
    case(label_state)
     2:glyph=(px-lx-40)/24==0 ? 18 : (px-lx-40)/24==1 ? 19 : 0;
     3:glyph=(px-lx-40)/24==0 ? 20 : (px-lx-40)/24==1 ? 21 : 0;
     default:glyph=(px-lx-40)/24==0 ? 17 : (px-lx-40)/24==1 ? 34 : 35;
    endcase
    if(cjk_rows[glyph*32+row][23-col]) expected=ink;
   end
  end
  if(color!==expected)$fatal(1,"direct boxes/independent labels pixel (%0d,%0d) got %h expected %h",px,py,color,expected);checked++;
 end
 if(py>=540 && py<588 && px>=16 && px<208 && valid_expected && main_expected<2)begin
  status_text=main_expected==0 ? "NO TARGET" : "UNCERTAIN";
  glyph=(px-16)/16<9 && py<572 ? status_text[71-((px-16)/16)*8-:8] : " ";
  ink=main_expected==0 ? 24'hf7b955 : 24'hb0c0d4;
  expected=ascii_rows[glyph*16+(py-540)/2][7-((px-16)/2)%8] ? ink : 24'h142336;
  if(color!==expected)$fatal(1,"main shape status pixel x=%0d y=%0d",px,py);checked++;
 end
 if(py>=540 && py<588 && px>=16 && px<208 && valid_expected && main_expected>=2)begin
  glyph=(px-16)/48==0 ? (main_expected==2 ? 18 : 20) : (px-16)/48==1 ? (main_expected==2 ? 19 : 21) : 0;
  ink=review_expected ? 24'hffcc55 : main_expected==2 ? 24'h74dbc7 : 24'hffae64;
  expected=cjk_rows[glyph*32+(py-540)/2][23-((px-16)/2)%24] ? ink : 24'h142336;
  if(color!==expected)$fatal(1,"main presence/CHECK pixel x=%0d y=%0d",px,py);checked++;
 end
 if(py>=548 && py<564 && px>=808 && px<1008)begin
  feature_text=valid_expected ? "FG 0E58 W 44 H 36 T 100  " : "FG ---- W -- H -- T 100  ";
  glyph=feature_text[199-((px-808)/8)*8-:8];
  expected=ascii_rows[glyph*16+py-548][7-(px-808)%8] ? 24'hb0c0d4 : 24'h142336;
  if(color!==expected)$fatal(1,"native feature text pixel x=%0d y=%0d got=%h expected=%h",px,py,color,expected);checked++;
 end
 n++;
end
task raster(input integer m,v,brightness,count,strength,main_result,gray_result,edge_result,check_result,0);
 begin
  checking=0;mode=m;valid=v;mean=brightness;review_expected=check_result;feature_value={1'b0,1'(check_result),13'd3672,7'd68,7'd54,8'd100};ec=feature_value[12:0];gs=feature_value[36:13];classification=main_result;main_expected=main_result;
  valid_expected=v;expected_mode=m;expected_box=v;
  ex0=479+(m==2?20:0);ex1=546+(m==2?20:0);ey0=261+(m==2?12:0);ey1=340+(m==2?12:0);
  lx=expected_box ? ex0 : 416;ly=expected_box ? ey0 : 228;box_valid=v;bx0=100;bx1=120;by0=100;by1=120;gstate=gray_result;estate=1;
  vs=1;repeat(25) @(negedge clk);vs=0;repeat(40) @(negedge clk);bx0=ex0;bx1=ex1;by0=ey0;by1=ey1;n=0;checking=1;
  for(integer yy=0;yy<600;yy++) begin
   de=1;hs=1;for(integer xx=0;xx<1024;xx++) @(negedge clk);
   de=0;hs=0;repeat(20) @(negedge clk);
   if(yy==100) begin box_valid=0;bx0=100;bx1=120;by0=100;by1=120;mode=0;valid=0;mean=0;ec=0;gs=0;end
  end
  repeat(5) @(negedge clk);if(n!=614400)$fatal(1,"direct raster incomplete");checking=0;
 end
endtask
initial begin
 repeat(5) @(negedge clk);rst=1;
 raster(0,1,120,0,0,2,2,1,0);
 raster(2,1,40,96,32768,0,0,2,0);
 raster(3,1,120,0,0,1,1,3,0);
 raster(3,1,40,96,32768,3,3,2,0);
 raster(3,0,120,96,32768,1,1,1,0);
 raster(3,1,120,0,0,2,2,1,1);
 raster(0,1,120,0,0,2,2,1,0);
 $display("PASS local OSD: %0d pixels, LOCAL V7/D8, MODEL P/E/NO TARGET/UNCERTAIN, EDGE ON/OFF and FIT CHECK, warning color/recovery, native FG/W/H, invalidation, frame-bound moving box, search guide, blanking metadata update, no-box fallback and three-clock raster",checked);$finish;
end
initial begin #60000000;$fatal(1,"direct OSD watchdog");end
endmodule
