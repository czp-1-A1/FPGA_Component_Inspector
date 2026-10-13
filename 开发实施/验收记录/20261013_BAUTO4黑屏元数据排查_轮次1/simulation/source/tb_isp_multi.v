`timescale 1ns/1ps
// Real RAW10 bridge, demosaic, vendor ERAM, manual WB, Sobel and divider.
module tb_isp_multi;
reg clk=0,rst=0,fs=0,fe=0,hs=0,rv=0;reg [39:0] raw=0;
always #5 clk=~clk;
wire av,asof,alast;wire [39:0] adata;
uial2axis #(.IMG_WIDTH(1024),.IMG_HEIGHT(600),.INPUT_DATA_WIDTH(40)) bridge(clk,rst,raw,rv,fs,fe,av,adata,asof,alast);
wire sv,mready,good,bad;wire [7:0] mean;wire [517:0] meta;wire [114:0] obs;
reg [17:0] request=1;
isp_top #(.MULTI_POCKETS(1),.TRACKING(1),.HOLE_Y(380),.LATE_HOLE(1)) dut(
 .axi4s_video_aclk(clk),.I_rst_n(rst),.I_tlast(alast),.I_tuser(asof),.I_tdata(adata),.I_tvalid(av),.I_tdest(10'd0),.O_tready(1'b1),
 .O_tdata(),.O_tlast(),.O_tuser(),.O_tvalid(),.I_tready(),.view_ready(1'b1),.video_frame_good(good),.video_frame_bad(bad),.video_diagnostics(),
 .raw_start(fs),.raw_end(fe),.hs_valid(hs),.raw_valid(rv),.config_ok(1'b1),.lane_error(2'd0),
 .sample_valid(sv),.sample_mean(mean),.sample_min(),.sample_max(),.calibration_ok(1'b1),.present_high(1'b1),.threshold(8'd58),.class_state(),
 .observation_request(request),.wb_request(32'h00004040),.wb_active(),.observation_record(obs),.display_record(),
 .image_config({16'd2244,16'd48}),.frame_metadata(meta),.frame_metadata_ready(mready));
integer row,b,l,x,h,c,v,shift=0,present=1,holes=1,frame_no=0;
integer total[0:3],cnt[0:3],low[0:3],high[0:3],edge_n[0:3],edge_c[0:3],edge_s[0:3];
integer luma,px,py;
always @(posedge clk) if(rst) begin
 if(dut.awb_pixel_sof) for(integer p=0;p<4;p++) begin total[p]=0;cnt[p]=0;low[p]=255;high[p]=0;edge_n[p]=0;edge_c[p]=0;edge_s[p]=0;end
 if(dut.roi_accept) for(integer p=0;p<4;p++) for(integer k=0;k<4;k++) begin
  px=dut.pocket_x0[p*11+:11];py=dut.pocket_y0[p*10+:10];
  if(dut.pocket_mask[p] && dut.roi_x+k>=px && dut.roi_x+k<px+80 && dut.roi_y>=py && dut.roi_y<py+80) begin
   luma=(int'(dut.awb_O_tdata[95-k*24-:8])+2*int'(dut.awb_O_tdata[87-k*24-:8])+int'(dut.awb_O_tdata[79-k*24-:8]))/4;
   total[p]+=luma;cnt[p]++;if(luma<low[p]) low[p]=luma;if(luma>high[p]) high[p]=luma;
  end
 end
 if(dut.gradient_valid) for(integer p=0;p<4;p++) for(integer k=0;k<4;k++) begin
  px=dut.pocket_x0[p*11+:11];py=dut.pocket_y0[p*10+:10];
  if(dut.pocket_mask[p] && dut.gradient_neighborhood[k] && dut.gradient_x+k>=px && dut.gradient_x+k<px+80 && dut.gradient_y>=py && dut.gradient_y<py+80) begin
   edge_n[p]++;edge_s[p]+=dut.gradient_magnitudes[k*11+:11];if(dut.gradient_magnitudes[k*11+:11]>=80) edge_c[p]++;
  end
 end
end
task ticks(input integer n);begin repeat(n) @(negedge clk);end endtask
task frame(input integer move,input integer part,input integer have_holes,input integer expected_lock,input integer mode);
 begin
  frame_no=frame_no+1;shift=move;present=part;holes=have_holes;request=mode;
  fs=1;ticks(1);fs=0;ticks(48);
  for(row=0;row<600;row=row+1) begin
   hs=1;ticks(3);
   for(b=0;b<256;b=b+1) begin
    rv=1;
    for(l=0;l<4;l=l+1) begin
     x=b*4+l;v=80;
     if(holes && row>=364 && row<397) begin
      for(h=-2;h<=2;h=h+1) begin
       c=392+shift+96*h;
       if(x>=c-16 && x<c+16) v=800;
      end
     end
     for(h=-2;h<=2;h=h+1) begin
      c=392+shift+96*h+48;
      if((h%2)==0 && present && row>=264 && row<336 && x>=c-36 && x<c+36) v=(x/4+row/4)%2 ? 700 : 1000;
     end
     raw[39-l*10-:10]=v;
    end
    ticks(1);rv=0;ticks(1);
   end
   hs=0;ticks(80);
  end
  fe=1;ticks(1);fe=0;ticks(700);
  if(frame_no==1) begin
   $display("OBS ISP initial line-span learning frame good=%b bad=%b ready=%b",good,bad,mready);
  end else begin
  if(!mready || !good || bad) $fatal(1,"actual ISP tracking frame incomplete %0d",frame_no);
  if(meta[137]!==expected_lock) $fatal(1,"actual ISP lock %0d expected %0d got %b",frame_no,expected_lock,meta[137]);
  if(meta[169:138]!={16'd2244,16'd48} || meta[114:0]!==obs || meta[136:126]!=dut.track_x0 || meta[125:115]!=dut.track_x1) $fatal(1,"actual ISP metadata mixed epochs/coords/results");
  for(integer p=0;p<4;p++) begin
   if(meta[178+p*85+63]!==expected_lock) $fatal(1,"actual ISP pocket validity frame=%0d bank=%0d got=%b diag=%h",frame_no,p,meta[178+p*85+63],meta[177:170]);
   if(expected_lock) begin
    if(cnt[p]!=6400 || meta[178+p*85+53+:8]!=total[p]/6400 || meta[178+p*85+45+:8]!=low[p] || meta[178+p*85+37+:8]!=high[p]) $fatal(1,"actual ISP independent bank features");
    if(mode>=2 && (edge_n[p]!=6400 || meta[178+p*85+24+:13]!=edge_c[p] || meta[178+p*85+:24]!=edge_s[p])) $fatal(1,"actual ISP edge bank features");
    if(mode<2 && meta[178+p*85+61+:2]!=(total[p]>=6400*58 ? 2 : 3)) $fatal(1,"actual ISP bank class");
   end else if(meta[178+p*85+61+:2]!=1) $fatal(1,"invalid actual ISP bank retained classification");
  end
  if(meta[178+:340]!==dut.pocket_records) $fatal(1,"multi metadata mixed epoch");
  $display("OBS actual multi frame=%0d mode=%0d move=%0d lock=%0d mask=%b verified=%b first_mean=%0d",frame_no,mode,move,expected_lock,dut.pocket_mask,dut.pocket_verified,mean);
  end
 end
endtask
initial begin
 ticks(8);rst=1;ticks(20);
 frame(0,1,1,0,1); // Original demosaic learns the line span in this first frame.
 frame(0,1,1,0,1);frame(0,1,1,1,1);frame(4,1,1,1,1);frame(8,0,1,1,2);
 frame(4,0,1,1,3);frame(0,1,1,1,0);frame(0,1,0,0,1);
 frame(0,0,1,0,1);frame(0,0,1,1,1);
 frame(12,1,1,0,1);frame(0,1,1,0,1);frame(0,1,1,1,1);
 $display("PASS actual ISP multi: RAW10/vendor RAM/full frames, frame-held moving ROI with current-frame lower-hole verification, four views, empty, lost/recovery, coherent metadata");$finish;
end
initial begin #100000000;$fatal(1,"actual ISP tracking watchdog");end
endmodule
