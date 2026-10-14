`timescale 1ns/1ps
module tb_shape_osd;
reg clk=0,rst=0,vs=0,hs=0,de=0,valid=1;
reg [1:0] mode=0,classification=2;
reg [7:0] mean=120;reg [12:0] ec=0;reg [23:0] gs=0;
always #5 clk=~clk;
wire ov,oh,od;wire [23:0] color;
experiment_osd #(.DIRECT_DETECTION(1),.SHAPE_MODEL(1)) dut(
 .clk(clk),.rst_n(rst),.vs(vs),.hs(hs),.de(de),.rgb(24'h556677),
 .exposure(16'd2244),.gain(16'd48),.wb_r(8'd100),.wb_b(8'd100),.wb_tune(1'b0),.wb_pending(1'b0),
 .view_mode(mode),.edge_count(ec),.edge_sum(gs),.roi_valid(valid),.roi_mean(mean),.roi_min(8'd20),.roi_max(8'd180),.roi_state(classification),
 .width(16'd1024),.height(16'd600),.fps(16'd27),.lane_errors(16'd0),.format_errors(16'd0),.i2c_errors(16'd0),.gaps(16'd0),
 .frames(32'd3),.uptime(32'd8),.cfg_done(1'b1),.overflow_frames(16'd0),.lost_frames(16'd0),.underflow_frames(16'd0),.diagnostics(36'd0),
 .publish_diagnostic({1'b0,8'hfb,17'h1c200}),.track_valid(1'b0),.track_x0(11'd0),.track_x1(11'd0),.track_reason(4'd2),.track_rows(3'd0),
 .pocket_records(340'd0),.pocket_enable(1'b0),.out_vs(ov),.out_hs(oh),.out_de(od),.out_rgb(color));
reg [7:0] ascii_rows[0:2047];reg [23:0] cjk_rows[0:2047];
reg [103:0] version_text="SHAPE EXP V5 ",diagnostic_text="D6 PFB W1C200";
reg [39:0] prefix;reg [23:0] expected,ink;
integer n=0,px,py,row,col,glyph,label_state,checked=0,gstate,estate,expected_mode;
reg valid_expected;reg checking=0,gray_row;reg [71:0] status_text;
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
  if(px>=472 && px<552 && py>=260 && py<340 && (px==472 || px==551 || py==260 || py==339)) expected=24'h00ffff;
  if(px>=472 && px<584 && py>=204 && py<256) begin
   gray_row=py<230;row=gray_row ? py-204 : py-230;label_state=gray_row ? gstate : estate;
   ink=label_state==2 ? 24'h74dbc7 : label_state==3 ? 24'hffae64 : 24'hb0c0d4;
   expected=24'h142336;
   if(px<512 || !gray_row || (gray_row && gstate<2 && valid_expected)) begin
    col=(px-472)%8;
    if(px<512) begin prefix=gray_row ? "MODEL" : "EDGE ";glyph=prefix[39-((px-472)/8)*8-:8];end
    else if(gray_row)begin status_text=gstate==0 ? "NO TARGET" : "UNCERTAIN";glyph=status_text[71-((px-512)/8)*8-:8];end
    else begin case((px-512)/8) 0:glyph="O";1:glyph=expected_mode>=2 ? "N" : "F";2:glyph=expected_mode>=2 ? " " : "F";default:glyph=" ";endcase end
    row=row>=5 && row<21 ? row-5 : 0;
    if(ascii_rows[glyph*16+row][7-col]) expected=ink;
   end else begin
    col=(px-512)%24;
    case(label_state)
     2:glyph=(px-512)/24==0 ? 18 : (px-512)/24==1 ? 19 : 0;
     3:glyph=(px-512)/24==0 ? 20 : (px-512)/24==1 ? 21 : 0;
     default:glyph=(px-512)/24==0 ? 17 : (px-512)/24==1 ? 34 : 35;
    endcase
    if(cjk_rows[glyph*32+row][23-col]) expected=ink;
   end
  end
  if(color!==expected)$fatal(1,"direct boxes/independent labels pixel (%0d,%0d) got %h expected %h",px,py,color,expected);checked++;
 end
 n++;
end
task raster(input integer m,v,brightness,count,strength,main_result,gray_result,edge_result);
 begin
  checking=0;mode=m;valid=v;mean=brightness;ec=count;gs=strength;classification=main_result;
  valid_expected=v;expected_mode=m;gstate=gray_result;estate=edge_result;
  vs=1;repeat(25) @(negedge clk);vs=0;repeat(40) @(negedge clk);n=0;checking=1;
  for(integer yy=0;yy<600;yy++) begin
   de=1;hs=1;for(integer xx=0;xx<1024;xx++) @(negedge clk);
   de=0;hs=0;repeat(20) @(negedge clk);
   if(yy==100) begin mode=0;valid=0;mean=0;ec=0;gs=0;end
  end
  repeat(5) @(negedge clk);if(n!=614400)$fatal(1,"direct raster incomplete");checking=0;
 end
endtask
initial begin
 repeat(5) @(negedge clk);rst=1;
 raster(0,1,120,0,0,2,2,1);
 raster(2,1,40,96,32768,0,0,2);
 raster(3,1,120,0,0,1,1,3);
 raster(3,1,40,96,32768,3,3,2);
 raster(3,0,120,96,32768,1,1,1);
 $display("PASS shape OSD: %0d pixels, SHAPE V5/D6, full Chinese GRAY/EDGE labels, OFF/invalidation, conflicting results stay independent, fixed core and three-clock/frame-held raster",checked);$finish;
end
initial begin #40000000;$fatal(1,"direct OSD watchdog");end
endmodule
