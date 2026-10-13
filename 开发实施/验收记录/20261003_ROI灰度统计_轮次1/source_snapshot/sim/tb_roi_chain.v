`timescale 1ns/1ps
// Actual native RAW10 -> uial2axis -> selected demosaic/AWB/RAM/packer/ROI.
module tb_roi_chain;
reg clk=0,rst=0,fs=0,fe=0,hs=0,rv=0,cfg=1,ready=1;
reg [39:0] raw=0;
reg [1:0] lane=0;
always #5 clk=~clk;
wire av,asof,alast;
wire [39:0] adata;
wire [127:0] packed_data;
wire packed_valid,packed_sof,packed_last,in_ready,sv;
wire [7:0] mean,minimum,maximum;
uial2axis #(.IMG_WIDTH(1024),.IMG_HEIGHT(600),.INPUT_DATA_WIDTH(40)) bridge(
 clk,rst,raw,rv,fs,fe,av,adata,asof,alast);
isp_top dut(.axi4s_video_aclk(clk),.I_rst_n(rst),.I_tlast(alast),.I_tuser(asof),
 .I_tdata(adata),.I_tvalid(av),.I_tdest(10'd0),.O_tready(ready),
 .O_tdata(packed_data),.O_tlast(packed_last),.O_tuser(packed_sof),.O_tvalid(packed_valid),.I_tready(in_ready),
 .raw_start(fs),.raw_end(fe),.hs_valid(hs),.raw_valid(rv),.lane_error(lane),.config_ok(cfg),
 .sample_valid(sv),.sample_mean(mean),.sample_min(minimum),.sample_max(maximum));
integer row,b,k,v,frame_no=0,commits=0,beat=0,reference_count=0;
integer reference_sum=0,reference_min=255,reference_max=0,r,g,blue,gray;
integer xx,yy;
always @(posedge clk) begin
 if(!rst) begin beat=0;commits=0;end
 else begin
  if(dut.awb_pixel_sof) begin
   if(!dut.awb_O_tvalid) $fatal(1,"SOF without valid");
   beat=0;reference_count=0;reference_sum=0;reference_min=255;reference_max=0;
  end
  if(dut.awb_O_tvalid) begin
   xx=(beat%256)*4;yy=beat/256;
   if(dut.awb_O_tlast != (beat%256==255)) $fatal(1,"AWB EOL boundary frame %0d beat %0d",frame_no,beat);
   if(dut.roi_accept && (dut.roi_x!=xx || dut.roi_y!=yy)) $fatal(1,"ROI coordinate frame %0d beat %0d",frame_no,beat);
   for(k=0;k<4;k=k+1) if(xx+k>=384 && xx+k<640 && yy>=236 && yy<364) begin
    r=dut.awb_O_tdata[95-k*24-:8];g=dut.awb_O_tdata[87-k*24-:8];blue=dut.awb_O_tdata[79-k*24-:8];
    if((^dut.awb_O_tdata[95-k*24-:24])===1'bx) $fatal(1,"unknown ROI pixel");
    gray=(r+2*g+blue)/4;
    reference_sum=reference_sum+gray;reference_count=reference_count+1;
    if(gray<reference_min) reference_min=gray;if(gray>reference_max) reference_max=gray;
   end
   beat=beat+1;
  end
  if(dut.roi_commit) commits=commits+1;
 end
end
task ticks;input integer n;begin repeat(n) @(negedge clk);end endtask
task frame;input integer mode,level;
begin
 frame_no=frame_no+1;commits=0;fs=1;ticks(1);fs=0;ticks(25);
 for(row=0;row<600;row=row+1) begin
  hs=1;
  for(b=0;b<((mode==1 && row==100)?192:256);b=b+1) begin
   if(mode==2 && row==100 && b==100) begin rv=0;ticks(240);end
   raw={4{10'(level*4)}};rv=1;ready=!(row==300 && b>=60 && b<120);
   ticks(1);rv=0;ticks((b%2)==0 ? 1 : 2);
  end
  hs=0;ready=1;ticks(160);
 end
 fe=1;ticks(1);fe=0;ticks(150);
 $display("OBS actual ROI chain frame=%0d mode=%0d commits=%0d sample_valid=%b AWBbeats=%0d mean/min/max=%0d/%0d/%0d",frame_no,mode,commits,sv,beat,mean,minimum,maximum);
end endtask
task expect_good;begin
 if(commits!=1 || !sv || beat!=153600 || reference_count!=32768 ||
    dut.u_roi_statistics.sample_sum!=reference_sum || mean!=reference_sum/32768 ||
    minimum!=reference_min || maximum!=reference_max)
  $fatal(1,"full-frame ROI comparison failed frame %0d count=%0d sum=%0d reference=%0d",frame_no,reference_count,dut.u_roi_statistics.sample_sum,reference_sum);
end endtask
initial begin
 ticks(16);rst=1;ticks(16);
 frame(0,100); // Legacy first-line span is learned from the first frame.
 frame(0,120);expect_good;
 frame(1,80);if(commits!=0 || sv) $fatal(1,"short native row accepted");
 frame(0,100);expect_good;
 frame(2,100);if(commits!=0 || sv) $fatal(1,"long pause/replay accepted");
 frame(0,120);expect_good;
 cfg=0;ticks(3);if(sv) $fatal(1,"configuration did not invalidate sample");cfg=1;
 frame(0,100);expect_good;
 $display("PASS actual ROI chain: 1024x600, bubbled RAW10, real demosaic/AWB/vendor RAM, independent stats, ready-low, malformed/replay rejection and recovery");
 $finish;
end
initial begin #50000000; $fatal(1,"ROI chain watchdog");end
endmodule
