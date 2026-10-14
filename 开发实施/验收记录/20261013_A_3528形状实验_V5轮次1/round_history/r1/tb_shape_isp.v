`timescale 1ns/1ps
// Actual native RAW10 -> uial2axis -> selected demosaic/AWB/RAM/packer/ROI.
module tb_shape_isp;
reg clk=0,rst=0,fs=0,fe=0,hs=0,rv=0,cfg=1,ready=1;
reg [39:0] raw=0;
reg [1:0] lane=0;
always #5 clk=~clk;
wire av,asof,alast;
wire [39:0] adata;
wire [127:0] packed_data;
wire packed_valid,packed_sof,packed_last,in_ready,sv;
wire [7:0] mean,minimum,maximum;
wire [1:0] class_state;
wire [27:0] display_record;
reg [17:0] request=1;reg [31:0] wb_request=32'h00004040;
wire [114:0] observation_record;
uial2axis #(.IMG_WIDTH(1024),.IMG_HEIGHT(600),.INPUT_DATA_WIDTH(40)) bridge(
 clk,rst,raw,rv,fs,fe,av,adata,asof,alast);
isp_top #(.DIRECT_DETECTION(1),.SHAPE_MODEL(1)) dut(.wb_request(wb_request),.wb_active(),.axi4s_video_aclk(clk),.I_rst_n(rst),.I_tlast(alast),.I_tuser(asof),
 .view_ready(1'b1),.video_frame_good(),.video_frame_bad(),
 .I_tdata(adata),.I_tvalid(av),.I_tdest(10'd0),.O_tready(ready),
 .O_tdata(packed_data),.O_tlast(packed_last),.O_tuser(packed_sof),.O_tvalid(packed_valid),.I_tready(in_ready),
 .raw_start(fs),.raw_end(fe),.hs_valid(hs),.raw_valid(rv),.lane_error(lane),.config_ok(cfg),
 .observation_request(request),.observation_record(observation_record),
 .calibration_ok(1'b1),.threshold(8'd58),.present_high(1'b1),.class_state(class_state),
 .sample_valid(sv),.sample_mean(mean),.sample_min(minimum),.sample_max(maximum),.display_record(display_record));
integer row,b,k,v,frame_no=0,commits=0,beat=0,reference_count=0;
integer reference_sum=0,reference_min=255,reference_max=0,r,g,blue,gray;
integer xx,yy,ref_fg,ref_x0,ref_y0,ref_x1,ref_y1,ref_w,ref_h;
function integer stimulus(input integer pattern,px,py);
 integer dx,dy;begin
 dx=px-512;dy=py-300;stimulus=30;
 case(pattern)
  0:if(px>=478 && px<546 && py>=273 && py<327)stimulus=180;
  1:if(dx*dx+dy*dy<=100)stimulus=150;
  2:if(dx*dx+dy*dy<=256)stimulus=150;
  3:stimulus=240;
  4:stimulus=30;
 endcase
 end
endfunction
reg [23:0] pixels [0:614399];
integer luminance [0:614399];
integer output_beat=0,expected_edges=0,expected_strength=0,packed_beats=0,clock_no=0,early_clock=0;
integer vx,vy,li,gx,gy,mag,expected_rgb,frame_mode;
integer left_reference,right_reference,left_dark_reference,right_dark_reference;
reg expected_scene;
reg [1:0] expected_gray_state,expected_edge_state,expected_class_state;
always @(posedge clk) begin
 clock_no=clock_no+1;
 if(!rst) begin beat=0;commits=0;end
 else begin
  if(dut.awb_pixel_sof) begin
   if(!dut.awb_O_tvalid) $fatal(1,"SOF without valid");
   ref_fg=0;ref_x0=999;ref_y0=999;ref_x1=-1;ref_y1=-1;beat=0;reference_count=0;reference_sum=0;reference_min=255;reference_max=0;
   output_beat=0;packed_beats=0;expected_edges=0;expected_strength=0;frame_mode=dut.observation_tag[1:0];
   left_reference=0;right_reference=0;left_dark_reference=0;right_dark_reference=0;
  end
  if(dut.awb_O_tvalid) begin
   xx=(beat%256)*4;yy=beat/256;
   if(dut.awb_O_tlast != (beat%256==255)) $fatal(1,"AWB EOL boundary frame %0d beat %0d",frame_no,beat);
   if(dut.roi_accept && (dut.roi_x!=xx || dut.roi_y!=yy)) $fatal(1,"ROI coordinate frame %0d beat %0d",frame_no,beat);
   for(k=0;k<4;k=k+1) begin
    r=dut.awb_O_tdata[95-k*24-:8];g=dut.awb_O_tdata[87-k*24-:8];blue=dut.awb_O_tdata[79-k*24-:8];
    gray=(r+2*g+blue)/4;
    pixels[yy*1024+xx+k]=dut.awb_O_tdata[95-k*24-:24];luminance[yy*1024+xx+k]=gray;
    if(yy>=260 && yy<340) begin
     if(xx+k>=456 && xx+k<472) begin left_reference=left_reference+1;if(gray<=100)left_dark_reference=left_dark_reference+1;end
     if(xx+k>=552 && xx+k<568) begin right_reference=right_reference+1;if(gray<=100)right_dark_reference=right_dark_reference+1;end
    end
    if(xx+k>=472 && xx+k<552 && yy>=260 && yy<340) begin
    if((^dut.awb_O_tdata[95-k*24-:24])===1'bx) $fatal(1,"unknown ROI pixel");
    if(gray>=100)begin
     ref_fg++;if(xx+k<ref_x0)ref_x0=xx+k;if(xx+k>ref_x1)ref_x1=xx+k;if(yy<ref_y0)ref_y0=yy;if(yy>ref_y1)ref_y1=yy;
    end
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
task ticks;input integer n;begin repeat(n) @(negedge clk);end endtask
task frame;input integer mode,level;
begin
 frame_no=frame_no+1;commits=0;fs=1;#1;if(class_state!==1) $fatal(1,"old result survived new FS");ticks(1);fs=0;ticks(25);
 for(row=0;row<600;row=row+1) begin
  hs=1;
  for(b=0;b<((mode==1 && row==100)?192:256);b=b+1) begin
   if(mode==2 && row==100 && b==100) begin rv=0;ticks(240);end
   if(mode==3 && row==200 && b==100) request=request+18'd5;
   if(mode==4 && row==200 && b==100) wb_request=32'h00016020;
   for(integer lane_raw=0;lane_raw<4;lane_raw++) raw[39-lane_raw*10-:10]=10'(4*stimulus(level,b*4+lane_raw,row));rv=1;ready=!(row==300 && b>=60 && b<120);
   ticks(1);rv=0;ticks((b%2)==0 ? 1 : 2);
  end
  hs=0;ready=1;ticks(160);
 end
 fe=1;ticks(1);fe=0;ticks(700);
 $display("OBS actual ROI chain frame=%0d mode=%0d commits=%0d sample_valid=%b AWBbeats=%0d mean/min/max=%0d/%0d/%0d",frame_no,mode,commits,sv,beat,mean,minimum,maximum);
end endtask
task expect_good(input integer truth);begin
 if(commits!=1 || !sv || beat!=153600 || reference_count!=6400 || dut.u_roi_statistics.sample_pixels!=6400 ||
    dut.u_roi_statistics.sample_sum!=reference_sum || mean!=reference_sum/6400 ||
    minimum!=reference_min || maximum!=reference_max)
  $fatal(1,"full-frame ROI comparison failed frame %0d count=%0d sum=%0d reference=%0d",frame_no,reference_count,dut.u_roi_statistics.sample_sum,reference_sum);
expected_scene=left_reference==1280 && right_reference==1280 && left_dark_reference>=960 && right_dark_reference>=960;
ref_w=ref_fg==0 ? 0 : ref_x1-ref_x0+1;ref_h=ref_fg==0 ? 0 : ref_y1-ref_y0+1;
if(!dut.shape_valid || dut.shape_foreground!=ref_fg || dut.shape_width!=ref_w || dut.shape_height!=ref_h)
 $fatal(1,"native shape metrics mismatch FG=%0d/%0d W=%0d/%0d H=%0d/%0d",dut.shape_foreground,ref_fg,dut.shape_width,ref_w,dut.shape_height,ref_h);
if(dut.scene_ok!==expected_scene || class_state!==truth) $fatal(1,"native model classification truth=%0d actual=%0d FG=%0d W=%0d H=%0d scene=%b",truth,class_state,ref_fg,ref_w,ref_h,expected_scene);
if(display_record[26:0]!=={class_state,1'b1,mean,minimum,maximum}) $fatal(1,"actual ISP snapshot publication");
if(output_beat!=153600 || packed_beats!=115200 || (frame_mode[1] ? (dut.edge_pixels!=6400 || dut.edge_count!=expected_edges || dut.edge_sum!=expected_strength) : (dut.edge_pixels!=0 || dut.edge_count!=0 || dut.edge_sum!=0)))
 $fatal(1,"actual Sobel frame/count/pack mismatch %0d edges=%0d/%0d sum=%0d/%0d",frame_no,dut.edge_count,expected_edges,dut.edge_sum,expected_strength);
if(observation_record!=={wb_request,2'b0,13'(ref_fg),7'(ref_w),7'(ref_h),8'd100,request,display_record}) $fatal(1,"shape atomic feature/tag publication");
 $display("OBS actual Sobel frame=%0d view=%0d pixels=%0d packed=%0d edges=%0d sum=%0d",frame_no,frame_mode,output_beat*4,packed_beats,expected_edges,expected_strength);
end endtask
initial begin
 ticks(16);rst=1;ticks(16);
 frame(0,3); // Demosaic learning frame.
 for(integer m=0;m<4;m++)begin
  request=request+4;request[1:0]=m;
  frame(0,0);expect_good(2);
  frame(0,1);expect_good(3);
  frame(0,2);expect_good(0);
  frame(0,3);expect_good(0);
  frame(0,4);expect_good(1);
 end
 frame(1,0);if(sv || observation_record[24])$fatal(1,"short frame accepted");
 frame(0,0);expect_good(2);
 frame(3,0);if(sv || observation_record[24])$fatal(1,"mode change accepted");
 frame(0,0);expect_good(2);
 frame(4,0);if(sv || observation_record[24] || output_beat!=153600 || packed_beats!=115200)$fatal(1,"WB cancellation damaged video");
 frame(0,0);expect_good(2);
 $display("PASS shape ISP: native RAW10/vendor RAM, 4 views x 5 truths, independent native FG/bbox and Sobel pixels, atomic snapshot, short/mode/WB cancellation/recovery");$finish;
end
initial begin #140000000;$fatal(1,"shape ISP watchdog");end
endmodule
