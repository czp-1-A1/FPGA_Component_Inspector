`timescale 1ns/1ps
// Real vendor-RAM ISP, writer and an independent pixel/byte reference for
// post-AWB RAW/GRAY and ROI. AWB/demosaic numerical accuracy is a separate test.
module tb_fhd_isp;
reg clk=0,ddr=0,rst=0,fs=0,fe=0,hs=0,rv=0;
reg [39:0] raw=0;reg [17:0] request=0;
always #5 clk=~clk;always #7.5 ddr=~ddr;
wire av,aso,al;wire [39:0] ad;wire [127:0] pd;wire pv,ps,pl,ir,good,bad,sv;
wire [7:0] mean,mn,mx;wire [1:0] cs;wire [82:0] record;wire [27:0] display_record;
wire row_credit,completed,capture,wren;wire [1:0] completed_slot;
wire [15:0] lost,overflow;wire [24:0] addr;wire [127:0] wd;
uial2axis #(.IMG_WIDTH(1920),.IMG_HEIGHT(1080),.INPUT_DATA_WIDTH(40)) bridge(clk,rst,raw,rv,fs,fe,av,ad,aso,al);
isp_top #(.WIDTH(1920),.HEIGHT(1080),.ENABLE_EDGE(0),
 .VIEW_X0(704),.VIEW_X1(1216),.VIEW_Y0(412),.VIEW_Y1(668),
 .ROI_X0(920),.ROI_X1(1000),.ROI_Y0(500),.ROI_Y1(580)) dut(
 .axi4s_video_aclk(clk),.I_rst_n(rst),.I_tlast(al),.I_tuser(aso),.I_tdata(ad),.I_tvalid(av),
 .I_tdest(10'd0),.O_tready(1'b1),.I_tready(ir),.O_tdata(pd),.O_tvalid(pv),.O_tuser(ps),.O_tlast(pl),
 .raw_start(fs),.raw_end(fe),.hs_valid(hs),.raw_valid(rv),.lane_error(2'b0),.config_ok(1'b1),
 .view_ready(row_credit),.video_frame_good(good),.video_frame_bad(bad),.video_diagnostics(),
 .observation_request(request),.observation_record(record),.calibration_ok(1'b0),.present_high(1'b1),.threshold(8'd0),
 .class_state(cs),.sample_valid(sv),.sample_mean(mean),.sample_min(mn),.sample_max(mx),.display_record(display_record));
video_in #(.WIDTH(1920),.HEIGHT(1080)) writer(
 .I_rst_n(rst),.I_camera_clk(clk),.I_camera_frame_start(ps),.I_camera_valid(pv),.I_camera_data(pd),
 .I_mipi_rx_error(1'b0),.I_frame_good(good),.I_frame_bad(bad),.O_camera_ready(row_credit),
 .I_ddr_clk(ddr),.I_display_pause(1'b0),.I_video_out_rd_busy(1'b0),.I_active_valid(1'b0),.I_active_rp(2'd0),
 .O_video_in_wr_busy(),.O_video_out_rp(),.O_completed_valid(completed),.O_completed_rp(completed_slot),
 .O_capture_ok(capture),.O_lost_frames(lost),.O_overflow_frames(overflow),
 .O_ddr_user_wr_en(wren),.O_ddr_user_addr(addr),.O_ddr_user_wr_data(wd),.I_ddr_user_ready(1'b1));
reg [23:0] pixels[0:2073599];reg [127:0] reference_words[0:388799];
reg [127:0] accumulator=0;integer byte_count=0,ref_words=0,pack_count=0,write_count=0;
integer awb_count=0,view_count=0,roi_count=0,roi_sum=0,roi_min=255,roi_max=0,frame_mode=0;
integer x,y,j,g,value;reg [23:0] expected;reg checking_full=0;
always @(posedge clk)if(rst)begin
 if(dut.awb_pixel_sof)begin
  awb_count=0;view_count=0;roi_count=0;roi_sum=0;roi_min=255;roi_max=0;
  ref_words=0;pack_count=0;write_count=0;byte_count=0;accumulator=0;frame_mode=request[0];
 end
 if(dut.awb_O_tvalid)begin
  x=awb_count%1920;y=awb_count/1920;
  if(dut.awb_O_tlast!==(x==1916))$fatal(1,"FHD AWB last at %0d",awb_count);
  for(j=0;j<4;j=j+1)begin
   pixels[awb_count+j]=dut.awb_O_tdata[95-j*24-:24];
   if(checking_full && (^pixels[awb_count+j])===1'bx)$fatal(1,"unknown FHD ISP pixel %0d",awb_count+j);
   if(x+j>=920 && x+j<1000 && y>=500 && y<580)begin
    value=(int'(pixels[awb_count+j][23:16])+2*int'(pixels[awb_count+j][15:8])+int'(pixels[awb_count+j][7:0]))/4;
    roi_count=roi_count+1;roi_sum=roi_sum+value;
    if(value<roi_min)roi_min=value;if(value>roi_max)roi_max=value;
   end
  end
  awb_count=awb_count+4;
 end
 if(dut.view_valid)begin
  x=view_count%1920;y=view_count/1920;
  for(j=0;j<4;j=j+1)begin
   expected=pixels[view_count+j];
   if(frame_mode && x+j>=704 && x+j<1216 && y>=412 && y<668)begin
    value=(int'(expected[23:16])+2*int'(expected[15:8])+int'(expected[7:0]))/4;expected={3{8'(value)}};
   end
   if(dut.view_rgb[95-j*24-:24]!==expected)$fatal(1,"FHD view pixel %0d",view_count+j);
   for(g=0;g<3;g=g+1)begin
    accumulator={accumulator[119:0],expected[23-g*8-:8]};byte_count=byte_count+1;
    if(byte_count==16)begin reference_words[ref_words]=accumulator;ref_words=ref_words+1;byte_count=0;end
   end
  end
  view_count=view_count+4;
 end
 if(pv)begin
  if(pack_count>=ref_words || pd!==reference_words[pack_count])$fatal(1,"FHD packed word %0d",pack_count);
  pack_count=pack_count+1;
 end
end
always @(posedge ddr)if(wren)begin
 if(write_count>=ref_words || wd!==reference_words[write_count])$fatal(1,"FHD DDR word %0d",write_count);
 if(addr!=(frame_mode ? 14000000 : 21000000)+write_count*8)$fatal(1,"MC address unit/order %0d %0d",write_count,addr);
 write_count=write_count+1;
end
task ticks(input integer n);repeat(n)@(negedge clk);endtask
task frame(input integer mode,input integer rows);begin
 checking_full=(rows==1080);
 request=mode;fs=1;ticks(1);fs=0;ticks(25);
 for(integer row=0;row<rows;row=row+1)begin
  hs=1;
  for(integer b=0;b<480;b=b+1)begin
   // Distinct per-lane and per-row values exercise packing order.
   for(integer k=0;k<4;k=k+1)raw[k*10+:10]=10'(160+((row*3+b*4+k)%700));
   rv=1;ticks(1);rv=0;ticks(b%4==3 ? 3 : 1);
  end
  hs=0;ticks(192);
 end
 fe=1;ticks(1);fe=0;ticks(1500);
 if(rows<1080)begin
  if(!bad || capture)$fatal(1,"cold-start missing-line prefix published");
  $display("PASS FHD ISP cold-start incomplete prefix rejected; native blank span learned before full frames");
 end else begin
 if(awb_count!=2073600 || view_count!=2073600 || pack_count!=388800 || write_count!=388800 || byte_count!=0)
  $fatal(1,"FHD totals %0d %0d %0d %0d",awb_count,view_count,pack_count,write_count);
 if(!good || bad || !capture || !sv || roi_count!=6400 || dut.u_roi_statistics.sample_sum!=roi_sum || mean!=roi_sum/6400 || mn!=roi_min || mx!=roi_max || cs!=0)
  $fatal(1,"FHD publication/ROI good=%b bad=%b capture=%b sv=%b cs=%d sum=%d/%d",good,bad,capture,sv,cs,dut.u_roi_statistics.sample_sum,roi_sum);
 $display("PASS FHD ISP mode=%0d: real ISP/vendor RAM, 2073600 view pixels and 388800 packed/DDR words, independent post-AWB reference, ROI6400, complete-frame publish",mode);
 end
end endtask
initial begin ticks(16);rst=1;ticks(20);frame(0,4);frame(0,1080);frame(1,1080);$finish;end
initial begin #40000000;$fatal(1,"FHD ISP timeout");end
endmodule
