`timescale 1ns/1ps
// Actual native RAW10 -> uial2axis -> selected demosaic/AWB/RAM/packer/ROI.
module tb_roi_transport_proof;
reg clk=0,rst=0,fs=0,fe=0,hs=0,rv=0,cfg=1,ready=1;
reg [39:0] raw=0;
reg [1:0] lane=0;
always #5 clk=~clk;
wire av,asof,alast;
wire [39:0] adata;
wire [127:0] packed_data;
wire packed_valid,packed_sof,packed_last,in_ready,sv; wire video_good,video_bad;
wire [7:0] mean,minimum,maximum;
wire [1:0] class_state;
wire [27:0] display_record;
reg [17:0] request=1;
wire [82:0] observation_record;
uial2axis #(.IMG_WIDTH(1024),.IMG_HEIGHT(600),.INPUT_DATA_WIDTH(40)) bridge(
 clk,rst,raw,rv,fs,fe,av,adata,asof,alast);
isp_top dut(.axi4s_video_aclk(clk),.I_rst_n(rst),.I_tlast(alast),.I_tuser(asof),
 .view_ready(1'b1),.video_frame_good(video_good),.video_frame_bad(video_bad),
 .I_tdata(adata),.I_tvalid(av),.I_tdest(10'd0),.O_tready(ready),
 .O_tdata(packed_data),.O_tlast(packed_last),.O_tuser(packed_sof),.O_tvalid(packed_valid),.I_tready(in_ready),
 .raw_start(fs),.raw_end(fe),.hs_valid(hs),.raw_valid(rv),.lane_error(lane),.config_ok(cfg),
 .observation_request(request),.observation_record(observation_record),
 .calibration_ok(1'b1),.threshold(8'd110),.present_high(1'b1),.class_state(class_state),
 .sample_valid(sv),.sample_mean(mean),.sample_min(minimum),.sample_max(maximum),.display_record(display_record));
integer row,b,k,v,frame_no=0,commits=0,beat=0,reference_count=0;
integer reference_sum=0,reference_min=255,reference_max=0,r,g,blue,gray;
integer xx,yy;
reg [23:0] pixels [0:614399];
integer luminance [0:614399];
integer output_beat=0,expected_edges=0,expected_strength=0,packed_beats=0,clock_no=0,early_clock=0;
integer vx,vy,li,gx,gy,mag,expected_rgb,frame_mode;
always @(posedge clk) begin
 clock_no=clock_no+1;
 if(!rst) begin beat=0;commits=0;end
 else begin
  if(dut.awb_pixel_sof) begin
   if(!dut.awb_O_tvalid) $fatal(1,"SOF without valid");
   beat=0;reference_count=0;reference_sum=0;reference_min=255;reference_max=0;
   output_beat=0;packed_beats=0;expected_edges=0;expected_strength=0;frame_mode=dut.observation_tag[1:0];
  end
  if(dut.awb_O_tvalid) begin
   xx=(beat%256)*4;yy=beat/256;
   if(dut.awb_O_tlast != (beat%256==255)) $fatal(1,"AWB EOL boundary frame %0d beat %0d",frame_no,beat);
   if(dut.roi_accept && (dut.roi_x!=xx || dut.roi_y!=yy)) $fatal(1,"ROI coordinate frame %0d beat %0d",frame_no,beat);
   for(k=0;k<4;k=k+1) begin
    r=dut.awb_O_tdata[95-k*24-:8];g=dut.awb_O_tdata[87-k*24-:8];blue=dut.awb_O_tdata[79-k*24-:8];
    gray=(r+2*g+blue)/4;
    pixels[yy*1024+xx+k]=dut.awb_O_tdata[95-k*24-:24];luminance[yy*1024+xx+k]=gray;
    if(xx+k>=472 && xx+k<552 && yy>=260 && yy<340) begin
    if((^dut.awb_O_tdata[95-k*24-:24])===1'bx) $fatal(1,"unknown ROI pixel");
    reference_sum=reference_sum+gray;reference_count=reference_count+1;
    if(gray<reference_min) reference_min=gray;if(gray>reference_max) reference_max=gray;
    end
   end
   beat=beat+1;
  end
  if(dut.roi_commit) commits=commits+1;
  if(packed_sof) begin
   if(packed_valid) $fatal(1,"DDR reset notification overlaps packed data");
   early_clock=clock_no;
  end
  if(packed_valid) packed_beats=packed_beats+1;
  if(dut.view_valid) begin
   vx=(output_beat%256)*4;vy=output_beat/256;
   if(output_beat==0 && clock_no-early_clock<32) $fatal(1,"DDR reset margin insufficient");
   if(dut.view_last!=(vx==1020)) $fatal(1,"view EOL alignment");
   for(li=0;li<4;li=li+1) begin
    expected_rgb=pixels[vy*1024+vx+li];mag=0;
    if(vx+li>256 && vx+li<767 && vy>172 && vy<427) begin
     gx=luminance[(vy-1)*1024+vx+li+1]+2*luminance[vy*1024+vx+li+1]+luminance[(vy+1)*1024+vx+li+1]
       -luminance[(vy-1)*1024+vx+li-1]-2*luminance[vy*1024+vx+li-1]-luminance[(vy+1)*1024+vx+li-1];
     gy=luminance[(vy+1)*1024+vx+li-1]+2*luminance[(vy+1)*1024+vx+li]+luminance[(vy+1)*1024+vx+li+1]
       -luminance[(vy-1)*1024+vx+li-1]-2*luminance[(vy-1)*1024+vx+li]-luminance[(vy-1)*1024+vx+li+1];
     mag=(gx<0 ? -gx : gx)+(gy<0 ? -gy : gy);
    end
    if(vx+li>=256 && vx+li<768 && vy>=172 && vy<428) begin
     if(frame_mode&1) expected_rgb={3{8'(luminance[vy*1024+vx+li])}};
     if((frame_mode&2) && mag>=80) expected_rgb=24'hffae64;
    end
    if(dut.view_rgb[95-li*24-:24]!==expected_rgb[23:0]) $fatal(1,"actual ISP view mismatch frame=%0d x=%0d y=%0d",frame_no,vx+li,vy);
    if(vx+li>=472 && vx+li<552 && vy>=260 && vy<340) begin
     expected_strength=expected_strength+mag;if(mag>=80) expected_edges=expected_edges+1;
    end
   end
   output_beat=output_beat+1;
  end
 end
end
// Concatenated byte stream scoreboard, independent of packer phase/case logic.
reg [223:0] packing_bits=0;
integer packing_count=0,packing_words=0,proof_commits=0,proof_epochs=0;
reg proof_native_end=0;
reg proof_early;
always @(posedge clk) begin
 if(!rst) begin packing_bits=0;packing_count=0;packing_words=0;end
 else if(packed_sof) begin
  if(packed_valid) $fatal(1,"new packed epoch overlaps a previous word");
  packing_bits=0;packing_count=0;packing_words=0;
 end else begin
  if(packed_valid) begin
   if(packing_count<128) $fatal(1,"word emitted without 128 view bits frame=%0d bits=%0d",frame_no,packing_count);
   if(packed_data !== packing_bits[packing_count-1 -:128])
    $fatal(1,"actual packed content mismatch frame=%0d word=%0d actual=%h expected=%h",frame_no,packing_words,packed_data,packing_bits[packing_count-1 -:128]);
   packing_count=packing_count-128;
   packing_bits=packing_count==0 ? 0 : packing_bits & ((224'd1<<packing_count)-1);
   packing_words=packing_words+1;
  end
  if(dut.view_valid) begin
   if(packing_count>128) $fatal(1,"packer failed to drain byte stream frame=%0d bits=%0d",frame_no,packing_count);
   packing_bits=(packing_bits<<96)|dut.view_rgb;packing_count=packing_count+96;
  end
 end
end
// A good proof needs a full native end and a complete real AWB/ROI commit.
always @(posedge clk) begin
 if(!rst) begin proof_commits=0;proof_native_end=0;proof_epochs=0;end
 else begin
  proof_early=dut.awb_O_tuser;
  if(proof_early) begin proof_commits=0;proof_native_end=0;proof_epochs=proof_epochs+1;end
  else begin
   if(fe) proof_native_end=1;
   if(dut.roi_commit) begin
    if(!proof_native_end || beat!=153600 || reference_count!=6400) $fatal(1,"video proof commit precedes complete native/AWB frame");
    proof_commits=proof_commits+1;
   end
  end
  #1;
  if(proof_early && (video_good || video_bad)) $fatal(1,"old good/bad survived AWB early epoch");
  if(video_good && (video_bad || proof_commits!=1 || !proof_native_end))
   $fatal(1,"video_good appeared without complete current frame proof");
 end
end
task ticks;input integer n;begin repeat(n) @(negedge clk);end endtask
task frame;input integer mode,level;
begin
 frame_no=frame_no+1;commits=0;fs=1;#1;if(class_state!==1) $fatal(1,"old result survived new FS");ticks(1);fs=0;ticks(25);
 for(row=0;row<600;row=row+1) begin
  hs=1;
  for(b=0;b<((mode==1 && row==100)?192:256);b=b+1) begin
   if(mode==2 && row==100 && b==100) begin rv=0;ticks(240);end
   if(mode==3 && row==200 && b==100) request=request+18'd5;
   raw={4{10'((level+((b>=130) ? 50 : 0)+((row>=300) ? 30 : 0))*4)}};rv=1;ready=!(row==300 && b>=60 && b<120);
   ticks(1);rv=0;ticks((b%2)==0 ? 1 : 2);
  end
  hs=0;ready=1;ticks(160);
 end
 fe=1;ticks(1);fe=0;ticks(700);
 $display("OBS actual ROI chain frame=%0d mode=%0d commits=%0d sample_valid=%b AWBbeats=%0d mean/min/max=%0d/%0d/%0d",frame_no,mode,commits,sv,beat,mean,minimum,maximum);
end endtask
task expect_good;begin
 if(!video_good || video_bad || proof_commits!=1 || packing_count!=0 || packing_words!=115200)
  $fatal(1,"good transport proof/byte stream rejected frame=%0d good=%b bad=%b commits=%0d residue=%0d exactwords=%0d",frame_no,video_good,video_bad,proof_commits,packing_count,packing_words);
 if(commits!=1 || !sv || beat!=153600 || reference_count!=6400 || dut.u_roi_statistics.sample_pixels!=6400 ||
    dut.u_roi_statistics.sample_sum!=reference_sum || mean!=reference_sum/6400 ||
    minimum!=reference_min || maximum!=reference_max)
  $fatal(1,"full-frame ROI comparison failed frame %0d count=%0d sum=%0d reference=%0d",frame_no,reference_count,dut.u_roi_statistics.sample_sum,reference_sum);
if(class_state!==(mean>=110 ? 2'd2 : 2'd3)) $fatal(1,"actual chain classification");
if(display_record[26:0]!=={class_state,1'b1,mean,minimum,maximum}) $fatal(1,"actual ISP snapshot publication");
if(output_beat!=153600 || packed_beats!=115200 || (frame_mode[1] ? (dut.edge_pixels!=6400 || dut.edge_count!=expected_edges || dut.edge_sum!=expected_strength) : (dut.edge_pixels!=0 || dut.edge_count!=0 || dut.edge_sum!=0)))
 $fatal(1,"actual Sobel frame/count/pack mismatch %0d edges=%0d/%0d sum=%0d/%0d",frame_no,dut.edge_count,expected_edges,dut.edge_sum,expected_strength);
if(observation_record!=={24'(frame_mode[1] ? expected_strength : 0),13'(frame_mode[1] ? expected_edges : 0),request,display_record}) $fatal(1,"actual tagged observation snapshot");
 $display("OBS actual Sobel frame=%0d view=%0d pixels=%0d packed=%0d edges=%0d sum=%0d",frame_no,frame_mode,output_beat*4,packed_beats,expected_edges,expected_strength);
end endtask
initial begin
 ticks(16);rst=1;ticks(16);
 frame(0,100); // Legacy first-line span is learned from the first frame.
 request=18'd4;frame(0,120);expect_good;
 frame(1,80);if(!video_bad || video_good) $fatal(1,"short native row missing bad proof");if(commits!=0 || sv || class_state!==1 || display_record[24]) $fatal(1,"short native row accepted");
 request=18'd11;frame(0,100);expect_good;
 frame(2,100);if(!video_bad || video_good) $fatal(1,"long pause missing bad proof");if(commits!=0 || sv || class_state!==1 || display_record[24]) $fatal(1,"long pause/replay accepted");
 request=18'd14;frame(0,120);expect_good;
 cfg=0;ticks(3);if(!video_bad || video_good) $fatal(1,"config revoke missing bad proof");if(sv || class_state!==1) $fatal(1,"configuration did not invalidate sample");cfg=1;
 request=18'd17;frame(0,100);expect_good;
 request=18'd20;frame(3,100);if(!video_bad || video_good) $fatal(1,"SW epoch mismatch missing bad proof");
 if(sv || display_record[24] || observation_record[24] || dut.observation_tag!=18'd20 || frame_mode!=0)
  $fatal(1,"mid-frame mode request accepted or changed active frame view");
 frame(0,120);expect_good;
 $display("PASS actual ISP transport proof: exact 128-bit concatenated content, native proof lifecycle, config/short-row/pause/mode mismatch error epochs and recovery; inherited actual ROI chain: 1024x600, bubbled RAW10, real demosaic/AWB/vendor RAM, independent stats, ready-low, malformed/replay rejection and recovery");
 $finish;
end
initial begin #50000000; $fatal(1,"ROI chain watchdog");end
endmodule
