`timescale 1ns/1ps
// A stationary RAW image must not translate when only CSI timing changes.
// This is a repeatability oracle, independent of the demosaic coefficients:
// compare every ordered output pixel after warmup, never DUT-generated DDR data.
module tb_base_picture_repeatability;
reg clk=0,run_clk=1,rst=0,fs=0,fe=0,hs=0,rv=0;
reg [39:0] raw=0;
always #4.444 if(run_clk)clk=~clk;
reg procclk=0;always #5 procclk=~procclk;
wire av,asof,alast,cav,casof,calast;
wire [39:0] adata,cadata;
reg packet_open=0;
always @(posedge clk or negedge rst)
 if(!rst)packet_open<=0;else if(fs)packet_open<=1;else if(fe)packet_open<=0;
uial2axis #(.IMG_WIDTH(1920),.IMG_HEIGHT(1080),.INPUT_DATA_WIDTH(40)) bridge(
 clk,rst,raw,rv && packet_open && !fe,fs,fe,av,adata,asof,alast);
image_correction correction(.I_clk(clk),.I_rst_n(rst),.I_raw_data(adata),
 .I_raw_valid(av),.I_raw_frame_start(asof),.I_raw_frame_end(alast),
 .O_raw_tdata(cadata),.O_raw_tlast(calast),.O_raw_tvalid(cav),
 .O_raw_tuser(casof),.O_raw_tready(1'b1));
wire [127:0] video;wire vv,vsof,good,bad;
isp_top #(.INPUT_WIDTH(1920),.INPUT_HEIGHT(1080),.WIDTH(1280),.HEIGHT(720),
 .SCALE_DISPLAY(1),.ASYNC_PROCESSING(1),.DIRECT_DETECTION(1),.SHAPE_MODEL(1),
 .LOCAL_SEARCH(1),.REGIONS(1),.CALIBRATION(1),.TRACKING(0),.MULTI_POCKETS(0)) dut(
 .processing_clk(procclk),.axi4s_video_aclk(clk),.I_rst_n(rst),
 .I_tlast(calast),.I_tuser(casof),.I_tdata(cadata),.I_tvalid(cav),
 .I_tdest(10'd0),.O_tready(1'b1),.O_tdata(video),.O_tlast(),.O_tuser(vsof),
 .O_tvalid(vv),.I_tready(),.view_ready(1'b1),.video_frame_good(good),
 .video_frame_bad(bad),.raw_start(fs),.raw_end(fe),.hs_valid(hs),.raw_valid(rv),
 .config_ok(1'b1),.lane_error(2'd0),.calibration_ok(1'b1),.present_high(1'b1),
 .threshold(8'd58),.observation_request(18'd0),.wb_request(32'h00006464),
 .image_config(32'h04440028));
function integer source(input integer x,y);
 begin
  source=160+((x*3+y*5)%128);
  if((x>=181 && x<389 && y>=223 && y<479) ||
     (x>=1051 && x<1509 && y>=621 && y<859))source=760;
  if((x>=329 && x<355 && y>=239 && y<301) ||
     (x>=1217 && x<1265 && y>=687 && y<751))source=80;
 end
endfunction
reg [95:0] reference[0:230399];
integer epoch=0,groups=0,rows=0,compared=0,commits=0,video_words=0;
integer mismatches=0,first_changed=-1,last_changed=-1;
integer changed_per_row[0:719];
integer dump_baseline,dump_changed;
initial begin
 dump_baseline=$fopen("static_baseline_rgb.txt","w");
 dump_changed=$fopen("static_changed_rgb.txt","w");
 for(integer n=0;n<720;n++)changed_per_row[n]=0;
end
integer row,beat,lane,gap;
always @(posedge procclk)begin
 if(rst)begin
  if(dut.post_start)begin epoch=epoch+1;groups=0;rows=0;commits=0;video_words=0;end
  if(dut.post_accept)begin
   if(groups>=230400 || dut.post_x!==11'((groups%320)*4) || dut.post_y!==10'(groups/320))
    $fatal(1,"static raster order epoch%0d group%0d x%0d y%0d",epoch,groups,dut.post_x,dut.post_y);
   if(dut.post_last!==(groups%320==319))$fatal(1,"static row boundary");
   if(epoch==1)reference[groups]=dut.post_rgb;
   else if(epoch==2 && dut.post_rgb!==reference[groups])
    $fatal(1,"cold-frame RGB differs from nominal next frame group%0d",groups);
   else if(epoch>=3)begin
    if(dut.post_rgb!==reference[groups])begin
     if(mismatches<8)$display("DIFF static epoch%0d x%0d y%0d got%h baseline%h",epoch,(groups%320)*4,groups/320,dut.post_rgb,reference[groups]);
     if(first_changed<0)first_changed=groups;
     last_changed=groups;mismatches=mismatches+1;changed_per_row[groups/320]++;
    end
    compared=compared+4;
   end
   if(epoch==2)$fwrite(dump_baseline,"%024h\n",dut.post_rgb);
   if(epoch==3)$fwrite(dump_changed,"%024h\n",dut.post_rgb);
   groups=groups+1;if(dut.post_last)rows=rows+1;
  end
  if(dut.post_commit)commits=commits+1;
  if(vv)video_words=video_words+1;
 end
end
task ticks(input integer n);begin repeat(n)@(negedge clk);end endtask
task frame(input integer schedule);
 begin
  fs=1;ticks(1);fs=0;ticks(64);
  for(row=0;row<1080;row=row+1)begin
   hs=1;ticks(3);
   for(beat=0;beat<480;beat=beat+1)begin
    rv=1;for(lane=0;lane<4;lane=lane+1)raw[39-lane*10-:10]=10'(source(beat*4+lane,row));
    ticks(1);rv=0;
    case(schedule)
     0:gap=beat%4==3 ? 3 : 1;
     1:gap=(beat+row)%7==0 ? 6 : 1;
     2:gap=beat%2==0 ? 0 : 3;
     default:gap=(beat*13+row*7)%5;
    endcase
    ticks(gap);
   end
   hs=0;ticks(98+row%5);
   if(row!=1079)begin
    run_clk=0;
    case(schedule)
     0:#12000;
     1:#(10000+(row%7)*500);
     2:#13000;
     default:#(11000+(row%11)*200);
    endcase
    run_clk=1;
   end
  end
  fe=1;ticks(1);fe=0;ticks(500);
  run_clk=0;#2000000;run_clk=1;ticks(50);
  if(epoch>=1 && (bad || !good || groups!=230400 || rows!=720 || commits!=1 || video_words!=172800))
   $fatal(1,"static frame proof schedule%0d epoch%0d bad%0d good%0d groups%0d rows%0d commits%0d words%0d",schedule,epoch,bad,good,groups,rows,commits,video_words);
  $display("OBS static frame epoch%0d schedule%0d groups%0d rows%0d words%0d mismatched_groups%0d first%0d last%0d",epoch,schedule,groups,rows,video_words,mismatches,first_changed,last_changed);
  if(epoch==3)begin
   for(integer n=0;n<720;n++)if(changed_per_row[n]!=0)$display("DIFFROW y%0d groups%0d",n,changed_per_row[n]);
   $fclose(dump_baseline);$fclose(dump_changed);
   if(mismatches!=0)$fatal(1,"stationary RAW differs: %0d groups; no threshold or truth relaxed",mismatches);
  end
 end
endtask
initial begin
 ticks(8);rst=1;ticks(30);
 frame(0);frame(0);frame(1);frame(2);frame(3);frame(0);
 if(mismatches!=0)$fatal(1,"stationary RAW differs across later schedules: %0d groups",mismatches);
 if(compared!=3686400)$fatal(1,"static comparison coverage%0d",compared);
 $display("PASS base picture repeatability: cold plus5 full FHD source frames, four CSI gap/clock-stop schedules,3686400 identical ordered1280x720 pixels, unchanged RAW geometry,720 rows/172800 video words; physical capture not modeled");
 $finish;
end
initial begin #400000000;$fatal(1,"static picture watchdog");end
endmodule
