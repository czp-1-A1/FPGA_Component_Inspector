`timescale 1ns/1ps
module tb_r58_frame_latency_chain;
 localparam W=1280,H=16,WORDS=W*H*3/16;
 reg cam=0,ddr=0,pix=0,refclk=0;
 always #4.444 cam=~cam;always #4 ddr=~ddr;always #6.734 pix=~pix;always #5 refclk=~refclk;
 reg rst=0,fs=0,cv=0,good=0,bad=0,mready=0;
 reg [127:0] data=0;reg [31:0] metadata=0,latest=0;
 reg [64:0] capture_info=0;
 wire camera_ready,wrbusy,rdbusy,complete,active,wr_en,rd_en,display_ok;
 wire [1:0] complete_slot,active_slot;wire [24:0] wr_addr,rd_addr;
 wire [127:0] wr_data;wire [31:0] complete_meta,active_meta;
 wire [64:0] complete_capture,active_capture;
 wire [31:0] gray,cam_us;wire cam_time_valid;
 contest_latency_clock timer(refclk,rst,gray);
 contest_latency_capture clock_capture(cam,rst,gray,cam_us,cam_time_valid);
 reg read_stall=0;reg [127:0] rd_data=0;reg rd_valid=0;
 video_in #(.MEASURE_LATENCY(1),.WIDTH(W),.HEIGHT(H),.METADATA(1),.META_WIDTH(32),.METADATA_REQUIRED(0),.VIDEO_FIRST(1)) writer(
  .I_rst_n(rst),.I_camera_clk(cam),.I_camera_frame_start(fs),.I_camera_valid(cv),.I_camera_data(data),.I_mipi_rx_error(1'b0),
  .I_frame_good(good),.I_frame_bad(bad),.O_camera_ready(camera_ready),.I_ddr_clk(ddr),.I_display_pause(1'b0),
  .I_video_out_rd_busy(rdbusy),.I_active_valid(active),.I_active_rp(active_slot),.O_video_in_wr_busy(wrbusy),
  .O_completed_valid(complete),.O_completed_rp(complete_slot),.O_ddr_user_wr_en(wr_en),.O_ddr_user_addr(wr_addr),
  .O_ddr_user_wr_data(wr_data),.I_ddr_user_ready(1'b1),.I_frame_metadata(metadata),.I_frame_metadata_ready(mready),
  .O_completed_metadata(complete_meta),.I_capture_info(capture_info),.O_completed_capture(complete_capture));
 reg vs=0,de=0;reg [11:0] x=0;reg [10:0] y=0;
 wire [23:0] video_rgb;
 video_out #(.MEASURE_LATENCY(1),.WIDTH(W),.HEIGHT(H),.META_WIDTH(32)) reader(
  .I_rst_n(rst),.I_ddr_clk(ddr),.O_video_out_rd_busy(rdbusy),.I_video_in_wr_busy(wrbusy),
  .I_video_out_rp(complete_slot),.I_completed_valid(complete),.I_completed_rp(complete_slot),
  .O_active_valid(active),.O_active_rp(active_slot),.O_ddr_user_rd_en(rd_en),.O_ddr_user_addr(rd_addr),
  .I_ddr_user_ready(1'b1),.I_ddr_user_rd_valid(rd_valid),.I_ddr_user_rd_data(rd_data),
  .I_dsi_clk(pix),.I_video_vsync(vs),.I_video_rd_en(de),.O_vdieo_data(video_rgb),.O_display_ok(display_ok),
  .I_completed_metadata(complete_meta),.O_active_metadata(active_meta),.I_completed_capture(complete_capture),.O_active_capture(active_capture));
 reg [127:0] memory[0:WORDS*4-1];reg [24:0] request_queue[0:WORDS*4-1];integer qw=0,qr=0;
 function integer index_of(input [24:0] address);
  integer slot,offset;begin slot=address/7000000;offset=(address-slot*7000000)/8;
   if(slot>3 || offset>=WORDS)$fatal(1,"bad memory address %0d",address);
   return slot*WORDS+offset;end
 endfunction
 always @(posedge ddr)begin
  if(!rst)begin qw=0;qr=0;rd_valid<=0;end
  else begin
   if(wr_en)begin if(^wr_data===1'bx)$fatal(1,"unknown write data address%0d time%0t",wr_addr,$time);memory[index_of(wr_addr)]<=wr_data;end
   if(rd_en)begin if(qw-qr>=WORDS*4)$fatal(1,"mock DDR request queue overflow");request_queue[qw%(WORDS*4)]=rd_addr;qw++;end
   rd_valid<=0;
   if(!read_stall && qr<qw)begin rd_data<=memory[index_of(request_queue[qr%(WORDS*4)])];qr++;rd_valid<=1;end
  end
 end
 wire [99:0] bundle;
 status_cdc #(.WIDTH(100)) selected(.S_clk(ddr),.D_clk(pix),.rst_n(rst),
  .S_data({active_capture,active,active_slot,active_meta}),.D_data(bundle));
 wire [31:0] latest_display;
 status_cdc #(.WIDTH(32)) source_cross(.S_clk(cam),.D_clk(pix),.rst_n(rst),.S_data(latest),.D_data(latest_display));
 wire osd_vs,osd_de,final_vs,final_de;wire [23:0] final_rgb;
 native_i60_phase phase(.clk(pix),.rst_n(rst),.x(x),.y(y),.source_x(x[10:0]),.source_y(y),.vs(vs),.hs(1'b0),.de(de),.pair_vs(vs),.osd_vs(osd_vs),.osd_de(osd_de));
 compact_inspector_osd #(.WIDTH(W),.HEIGHT(H),.ENABLE(0)) osd(.clk(pix),.rst_n(rst),.vs(osd_vs),.hs(1'b0),.de(osd_de),.rgb(video_rgb),.out_vs(final_vs),.out_de(final_de),.out_rgb(final_rgb));
 wire sample_new,sample_valid;wire [15:0] ms10,lag;wire [31:0] source;wire [39:0] source_bcd;wire [19:0] ms_bcd;wire [11:0] lag_bcd;
 contest_latency_display measure(.clk(pix),.rst_n(rst),.us_gray(gray),.vs(final_vs),.de(final_de),.frame_valid(display_ok && bundle[34]),
  .capture_info(bundle[99:35]),.latest_source(latest_display),.sample_new(sample_new),.sample_valid(sample_valid),
  .latency_ms10(ms10),.frame_lag(lag),.source_frame(source),.source_bcd(source_bcd),.latency_bcd(ms_bcd),.lag_bcd(lag_bcd));
 integer frames=0,samples=0,seen=0,checks=0;reg checking=0,expect_valid=0;
 reg [23:0] expect_rgb=0;reg [31:0] expect_source=0,sampled_elapsed=0,sampled_lag=0,last_ms=0;
 reg [63:0] selected_tag=0;
 realtime capture_at[int],age_external;integer external_units;
 function [31:0] binary(input [31:0] g);integer k;begin binary[31]=g[31];for(k=30;k>=0;k--)binary[k]=binary[k+1]^g[k];end endfunction
 always @(posedge pix)begin
  if(rst && final_de && checking && seen==0)begin
   age_external=$realtime-capture_at[expect_source];external_units=$rtoi(age_external/100000.0);sampled_lag=latest-expect_source;
   selected_tag=bundle[98:35];
  end
  if(rst && final_de && checking)begin
   seen++;
   if(expect_valid && final_rgb!==expect_rgb)$fatal(1,"actual selected pixels mismatch at%0d RGB%h expected%h",seen,final_rgb,expect_rgb);
   if(expect_valid && bundle[98:35]!==selected_tag)$fatal(1,"mid-raster source tuple changed");
  end
  #1;
  if(rst && sample_new && checking)begin
   samples++;checks++;
   if(sample_valid!==expect_valid)$fatal(1,"frame validity mismatch #%0d got%b",frames,sample_valid);
   if(sample_valid && (source!=expect_source || (ms10<external_units-1 || ms10>external_units+1) || lag!=sampled_lag))
    $fatal(1,"capture/slot/pixels/OSD-time not same frame gotSRC%0d age%0d lag%0d expectedSRC%0d age%0d lag%0d",source,ms10,lag,expect_source,external_units,sampled_lag);
   last_ms=ms10;
  end
 end
 function [127:0] packed_word(input integer w,input [23:0] color);
  integer bitno;begin for(bitno=0;bitno<128;bitno++)packed_word[127-bitno]=color[23-((w*128+bitno)%24)];end
 endfunction
 task capture(input integer id,input [23:0] color,input bit incomplete);
  integer w;begin
   @(negedge cam);capture_at[id]=$realtime;latest=id;capture_info={cam_time_valid,32'(id),cam_us};good=0;bad=0;mready=0;metadata=0;
   fs=1;@(negedge cam);fs=0;repeat(30)@(negedge cam);
   for(w=0;w<(incomplete ? WORDS/3 : WORDS);w++)begin
    while(!camera_ready)@(negedge cam);
    data=packed_word(w,color);cv=1;@(negedge cam);cv=0;@(negedge cam);
   end
   if(incomplete)begin bad=1;repeat(30)@(negedge cam);end
   else begin
    good=1;repeat(1500)@(negedge cam);
    if(!complete || complete_capture!==capture_info)$fatal(1,"writer published wrong capture descriptor ID%0d tuple%h",id,complete_capture);
    for(integer q=0;q<WORDS;q++)if(memory[complete_slot*WORDS+q]!==packed_word(q,color))$fatal(1,"published slot%0d memory word%0d mismatch got%h wanted%h ID%0d",complete_slot,q,memory[complete_slot*WORDS+q],packed_word(q,color),id);
    // Late classification may enrich only its own slot, never replace the image timestamp.
    metadata=id;mready=1;repeat(50)@(negedge cam);
    if(complete_meta!=id || complete_capture!==capture_info)$fatal(1,"late metadata changed capture identity");
   end
  end
 endtask
 task raster(input integer id,input [23:0] color,input bit valid_frame);
  integer xx,yy;begin
   frames++;expect_source=id;expect_rgb=color;expect_valid=valid_frame;seen=0;samples=0;
   @(negedge pix);vs=1;de=0;checking=0;repeat(10)@(negedge pix);vs=0;
   repeat(1400)@(negedge pix);checking=1;
   for(yy=0;yy<H;yy++)begin y=yy;de=1;
    for(xx=0;xx<W;xx++)begin x=xx;@(negedge pix);end
    de=0;repeat(24)@(negedge pix);
   end
   repeat(20)@(negedge pix);checking=0;
   if(seen!=W*H || samples!=1)$fatal(1,"not exactly one latency sample/raster pixels%0d samples%0d",seen,samples);
  end
 endtask
 integer old_age;reg [64:0] saved;
 initial begin
  repeat(10)@(negedge cam);rst=1;repeat(50)@(negedge cam);
  raster(0,0,0);
  capture(65537,24'h110001,0);saved=complete_capture;
  fork
   raster(65537,24'h110001,1);
   begin repeat(6000)@(negedge pix);capture(65538,24'h220002,0);end
  join
  raster(65538,24'h220002,1);old_age=last_ms;
  raster(65538,24'h220002,1);if(last_ms<=old_age)$fatal(1,"repeated image did not age");
  saved=complete_capture;capture(65539,24'h330003,1);
  if(complete_capture!==saved)$fatal(1,"canceled frame replaced completed tag");
  raster(65538,24'h220002,1);
  for(integer n=65540;n<65545;n++)begin capture(n,24'(n),0);raster(n,24'(n),1);end
  read_stall=1;raster(65544,0,0);read_stall=0;repeat(3000)@(negedge pix);
  raster(65544,24'(65544),1);
  rst=0;repeat(10)@(negedge cam);rst=1;repeat(50)@(negedge cam);raster(0,0,0);
  $display("PASS R58 FRAME LATENCY CHAIN: %0d actual DDR/FIFO/phase/OSD rasters, %0d independently timed first-output-pixel samples,32bit IDs, concurrent capture, late metadata, repeat age, canceled frame, slot reuse, underrun, recovery and reset",frames,checks);$finish;
 end
 initial begin #20000000;$fatal(1,"frame latency chain watchdog");end
endmodule
