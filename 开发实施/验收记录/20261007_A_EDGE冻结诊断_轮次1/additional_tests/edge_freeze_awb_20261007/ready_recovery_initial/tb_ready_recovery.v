`timescale 1ns/1ps
// Real AWB + Sobel + packer + video_in FIFO credit loop. Ordered MC writes only.
module tb_ready_recovery;
localparam W=1024,H=16,BEATS=W*H/4,WORDS=W*H*3/16;
reg clk=0,ddr=0,rst=0,iv=0,early=0,il=0,read_busy=0;
reg [1:0] mode=0;
always #5 clk=~clk;
always #7.5 ddr=~ddr;
wire av,as,al,ae,ir;wire [95:0] ac;
awb #(.IMG_WIDTH(W),.IMG_HEIGHT(H)) awb_dut(
 .I_clk(clk),.I_rst_n(rst),.I_tlast(il),.I_tuser(early),.I_tdata({4{24'h646464}}),.I_tvalid(iv),.I_tready(ir),
 .O_tlast(al),.O_tuser(ae),.O_pixel_sof(as),.O_tdata(ac),.O_tvalid(av),.O_tready(1'b1));
wire ov,ol,oe,fb,credit;wire [95:0] color;wire [10:0] ox;wire [9:0] oy;
wire [12:0] cp,ec;wire [23:0] es;
roi_sobel_view #(.WIDTH(W),.HEIGHT(H)) view_dut(
 .clk(clk),.rst_n(rst),.pixel_valid(av),.pixel_sof(as),.pixel_last(al),.early_sof(ae),.rgb(ac),
 .mode(mode),.invalidate(1'b0),.view_ready(credit),.frame_bad(fb),.out_valid(ov),.out_last(ol),
 .out_early_sof(oe),.out_rgb(color),.out_x(ox),.out_y(oy),.core_pixels(cp),.edge_count(ec),.edge_sum(es));
wire pv,ps;wire [127:0] pd;
data_96bit_to_128bit pack(clk,rst,oe,ov,color,ps,pv,pd);
reg video_bad=0,video_good=0;integer native_count=0;
// Same early-FS cancellation and sticky view-error branches as isp_top.
// Native geometry is complete by construction; config/lane errors are absent.
always @(posedge clk or negedge rst) begin
 if(!rst) begin video_bad<=0;video_good<=0;native_count<=0;end
 else if(ae) begin video_bad<=0;video_good<=0;native_count<=0;end
 else if(fb) begin video_bad<=1;video_good<=0;end
 else if(av) begin
  native_count<=native_count+1;
  if(native_count==BEATS-1) video_good<=1;
 end
end
wire wr_en,wr_busy,completed,capture_ok;wire [127:0] wr_data;wire [24:0] wr_addr;
wire [1:0] completed_rp;wire [15:0] lost,overflow;
video_in #(.WIDTH(W),.HEIGHT(H)) vi(
 .I_rst_n(rst),.I_camera_clk(clk),.I_camera_frame_start(ps),.I_camera_valid(pv),.I_camera_data(pd),
 .I_mipi_rx_error(1'b0),.I_frame_good(video_good),.I_frame_bad(video_bad),.O_camera_ready(credit),
 .I_ddr_clk(ddr),.I_display_pause(1'b0),.I_video_out_rd_busy(read_busy),.I_active_valid(1'b0),.I_active_rp(2'd0),
 .O_video_in_wr_busy(wr_busy),.O_video_out_rp(),.O_completed_valid(completed),.O_completed_rp(completed_rp),
 .O_capture_ok(capture_ok),.O_lost_frames(lost),.O_overflow_frames(overflow),
 .O_ddr_user_wr_en(wr_en),.O_ddr_user_addr(wr_addr),.O_ddr_user_wr_data(wr_data),.I_ddr_user_ready(1'b1));
integer cycle=0,frame_no=0,release_after=0,first_sof=-1,first_bad=-1,writes=0,view_beats=0;
integer bad_row=-1,bad_read=-1,csv,ready_falls=0,ready_rises=0,first_release=-1;
reg active=0,credit_d=0,bad_d=0;integer bad_reassert=0;
task ticks;input integer n;begin repeat(n) @(negedge clk);#1;end endtask
always @(posedge clk) begin
 cycle=cycle+1;
 if(active && as && first_sof<0) first_sof=cycle;
 if(active && read_busy && release_after>0 && first_sof>=0 && cycle-first_sof>=release_after) begin
  read_busy=0;first_release=cycle;
  $fdisplay(csv,"release_read_busy,%0d,%0d,%b,%b,%b,%b,%0d,%0d,%0d",frame_no,cycle,credit,fb,video_bad,vi.camera_bad,vi.camera_used,view_dut.write_y,view_dut.read_y);
 end
 if(active && view_dut.cache_overrun && first_bad<0) begin
  first_bad=cycle;bad_row=view_dut.write_y;bad_read=view_dut.read_y;
  $fdisplay(csv,"cache_overrun,%0d,%0d,%b,%b,%b,%b,%0d,%0d,%0d",frame_no,cycle,credit,fb,video_bad,vi.camera_bad,vi.camera_used,bad_row,bad_read);
 end
 #1;
 if(active) begin
  if(ov) view_beats=view_beats+1;
  if(!bad_d && vi.camera_bad) begin
   bad_reassert=bad_reassert+1;
   $fdisplay(csv,"camera_bad_rise,%0d,%0d,%b,%b,%b,%b,%0d,%0d,%0d",frame_no,cycle,credit,fb,video_bad,vi.camera_bad,vi.camera_used,view_dut.write_y,view_dut.read_y);
  end
  if(credit!=credit_d || ps || ae) begin
   if(credit) ready_rises=ready_rises+1;else ready_falls=ready_falls+1;
   $fdisplay(csv,"credit_or_FS,%0d,%0d,%b,%b,%b,%b,%0d,%0d,%0d",frame_no,cycle,credit,fb,video_bad,vi.camera_bad,vi.camera_used,view_dut.write_y,view_dut.read_y);
  end
  credit_d=credit;bad_d=vi.camera_bad;
 end
end
always @(posedge ddr) if(active && wr_en) begin
 writes=writes+1;
 if(wr_data!=={16{8'h64}}) $fatal(1,"MC data mismatch frame=%0d word=%0d",frame_no,writes);
end
task frame;input integer v,release_clocks,expect_bad;
 begin
  active=0;iv=0;il=0;early=0;ticks(1200);
  frame_no=frame_no+1;mode=2'(v);release_after=release_clocks;read_busy=release_clocks!=0;
  first_sof=-1;first_bad=-1;first_release=-1;bad_row=-1;bad_read=-1;writes=0;view_beats=0;
  bad_reassert=0;credit_d=credit;bad_d=vi.camera_bad;ready_falls=0;ready_rises=0;active=1;
  early=1;ticks(1);early=0;ticks(20);
  if(video_bad || fb || vi.camera_bad) $fatal(1,"prior frame_bad survived new FS frame=%0d ISP=%b Sobel=%b VI=%b",frame_no,video_bad,fb,vi.camera_bad);
  for(integer y=0;y<H;y=y+1) begin
   for(integer b=0;b<W/4;b=b+1) begin iv=1;il=b==W/4-1;ticks(1);end
   iv=0;il=0;if(y!=H-1)ticks(384);
  end
  read_busy=0;ticks(1600);active=0;
  $display("OBS real credit frame=%0d mode=%0d release_after=%0d input_period=640 view=%0d writes=%0d published=%b capture_ok=%b Sobel_bad=%b ISP_bad=%b camera_bad=%b reassert=%0d first_bad_row=%0d read_y=%0d credit_fall/rise=%0d/%0d lost=%0d overflow=%0d",frame_no,mode,release_after,view_beats,writes,vi.published,capture_ok,fb,video_bad,vi.camera_bad,bad_reassert,bad_row,bad_read,ready_falls,ready_rises,lost,overflow);
  if(expect_bad) begin
   if(!fb || !vi.camera_bad || vi.published || writes==WORDS) $fatal(1,"late ready stall did not produce expected rejected frame %0d",frame_no);
  end else if(fb || video_bad || vi.camera_bad || !capture_ok || !vi.published || view_beats!=BEATS || writes!=WORDS || bad_reassert)
   $fatal(1,"real credit recovery did not complete frame=%0d",frame_no);
 end
endtask
initial begin
 csv=$fopen("credit_events.csv","w");
 $fdisplay(csv,"event,frame,cycle,credit,Sobel_bad,ISP_bad,camera_bad,FIFO_used,write_y,read_y");
 ticks(8);rst=1;ticks(8);
 frame(0,0,0);
 frame(2,2400,0);
 frame(2,3000,1);
 frame(2,0,0);
 frame(2,-1,1);
 frame(2,0,0);
 frame(0,0,0);
 $display("PASS actual AWB/video_in credit recovery: line period640, bounded stall succeeds, late stall aborts, next FS clears old bad and publishes EDGE, RAW transition recovers");
 $fclose(csv);$finish;
end
initial begin #10000000;$fatal(1,"AWB credit watchdog");end
endmodule
