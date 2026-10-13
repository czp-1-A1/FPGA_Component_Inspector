`timescale 1ns/1ps
module tb_video_transport #(parameter W=32,H=161);
localparam WORDS=W*H*3/16,PIXELS=W*H,MAX_QUEUE=8*WORDS+1024;
reg rst_n=0,camera_clk=0,ddr_clk=0,pixel_clk=0;
always #4.444 camera_clk=~camera_clk;
always #7.5 ddr_clk=~ddr_clk;
always #9.615 pixel_clk=~pixel_clk;
reg camera_start=0,camera_valid=0,frame_good=0,frame_bad=0;
reg [127:0] camera_data=0;
reg ready=1,return_pause=0,vs=0,de=0;
wire camera_ready,completed_valid,capture_ok,active_valid,display_ok;
wire [1:0] completed_rp,active_rp,rp_alias;
wire [15:0] lost_frames,overflow_frames,underflow_frames;
wire vi_busy,vo_busy,wr_en,rd_en;
wire [24:0] wr_addr,rd_addr;
wire [127:0] wr_data;
reg rd_valid=0;
reg [127:0] rd_data=0;
wire [23:0] rgb;
video_in #(.WIDTH(W),.HEIGHT(H)) vi(
 .I_rst_n(rst_n),.I_camera_clk(camera_clk),.I_camera_frame_start(camera_start),
 .I_camera_valid(camera_valid),.I_camera_data(camera_data),.I_mipi_rx_error(1'b0),
 .I_frame_good(frame_good),.I_frame_bad(frame_bad),
 .I_ddr_clk(ddr_clk),.I_display_pause(1'b0),.I_video_out_rd_busy(vo_busy),
 .O_video_in_wr_busy(vi_busy),.O_video_out_rp(rp_alias),
 .I_active_valid(active_valid),.I_active_rp(active_rp),
 .O_camera_ready(camera_ready),.O_completed_valid(completed_valid),.O_completed_rp(completed_rp),
 .O_capture_ok(capture_ok),.O_lost_frames(lost_frames),.O_overflow_frames(overflow_frames),
 .O_ddr_user_wr_en(wr_en),.O_ddr_user_addr(wr_addr),.O_ddr_user_wr_data(wr_data),.I_ddr_user_ready(ready));
video_out #(.WIDTH(W),.HEIGHT(H)) vo(
 .I_rst_n(rst_n),.I_ddr_clk(ddr_clk),.O_video_out_rd_busy(vo_busy),.I_video_in_wr_busy(vi_busy),
 .I_video_out_rp(rp_alias),.I_completed_valid(completed_valid),.I_completed_rp(completed_rp),
 .O_active_valid(active_valid),.O_active_rp(active_rp),.O_display_ok(display_ok),.O_underflow_frames(underflow_frames),
 .O_ddr_user_rd_en(rd_en),.O_ddr_user_addr(rd_addr),.I_ddr_user_ready(ready),
 .I_ddr_user_rd_valid(rd_valid),.I_ddr_user_rd_data(rd_data),
 .I_dsi_clk(pixel_clk),.I_video_vsync(vs),.I_video_rd_en(de),.O_vdieo_data(rgb));

function [23:0] pixel_data(input integer frame,input integer pixel);
 pixel_data={8'h20+8'(frame),8'(pixel),8'(pixel>>8)^8'ha7};
endfunction
function [127:0] word_data(input integer frame,input integer word_number);
 integer j,b,p,c;reg [23:0] px;
 begin
  word_data=0;
  for(j=0;j<16;j=j+1) begin
   b=word_number*16+j;p=b/3;c=b%3;px=pixel_data(frame,p);
   case(c)
    0:word_data[127-j*8 -:8]=px[23:16];
    1:word_data[127-j*8 -:8]=px[15:8];
    2:word_data[127-j*8 -:8]=px[7:0];
   endcase
  end
 end
endfunction
function integer address_slot(input [24:0] address);
 begin
  if(address>=21000000) address_slot=3;
  else if(address>=14000000) address_slot=2;
  else if(address>=7000000) address_slot=1;
  else address_slot=0;
 end
endfunction
function integer address_word(input [24:0] address);
 integer s;
 begin s=address_slot(address);address_word=(address-s*7000000)/8;end
endfunction

reg [127:0] memory[0:3][0:WORDS-1];
integer written[0:3],writes=0,reads=0,returned=0;
integer q_slot[0:MAX_QUEUE-1],q_word[0:MAX_QUEUE-1],q_due[0:MAX_QUEUE-1];
integer q_head=0,q_tail=0,ddr_cycles=0,s,k,j,f,r_offset;
integer budget=8;reg ready_d=1;
integer publications=0,expected_publication_frame=0;
reg completed_d=0;reg [1:0] rp_d=0;
integer published_frame[0:3];
always @(posedge ddr_clk) begin
 if(!rst_n) begin
  rd_valid<=0;q_head=0;q_tail=0;ddr_cycles=0;
  writes=0;reads=0;returned=0;budget=8;ready_d=1;
  completed_d=0;rp_d=0;publications=0;
  for(j=0;j<4;j=j+1) begin written[j]=0;published_frame[j]=0;end
 end else begin
  ddr_cycles=ddr_cycles+1;rd_valid<=0;
  if(ready) budget=8;
  else if(wr_en || rd_en) begin
   budget=budget-1;
   if(budget<0) $fatal(1,"ready-low acceptance exceeded 8-word MC reserve");
  end
  if(wr_en && rd_en) $fatal(1,"simultaneous shared MC read and write");
  if(wr_en) begin
   s=address_slot(wr_addr);k=address_word(wr_addr);
   if(k<0 || k>=WORDS || wr_addr[2:0]!=0) $fatal(1,"write outside image: %0d",wr_addr);
   if(active_valid && s==active_rp) $fatal(1,"writer overwrites active display slot %0d",s);
   if(completed_valid && s==completed_rp) $fatal(1,"writer overwrites retained completed slot %0d",s);
   if(k==0) written[s]=0;
   if(written[s]!=k) $fatal(1,"write address discontinuity slot=%0d expected=%0d actual=%0d",s,written[s],k);
   r_offset=(3-((k*16)%3))%3;f=wr_data[127-r_offset*8 -:8]-8'h20;
   if(f<1 || f>9 || wr_data!==word_data(f,k)) $fatal(1,"packed word corruption slot=%0d word=%0d frame=%0d data=%h",s,k,f,wr_data);
   memory[s][k]<=wr_data;written[s]=written[s]+1;writes=writes+1;
  end
  if(rd_en) begin
   s=address_slot(rd_addr);k=address_word(rd_addr);
   if(k<0 || k>=WORDS || rd_addr[2:0]!=0) $fatal(1,"read outside completed image: %0d",rd_addr);
   if(!active_valid || s!=active_rp) $fatal(1,"DDR read not from pinned active slot");
   q_slot[q_tail]=s;q_word[q_tail]=k;q_due[q_tail]=ddr_cycles+6;q_tail=q_tail+1;reads=reads+1;
   if(q_tail>=MAX_QUEUE) $fatal(1,"test queue overflow");
  end
  if(!return_pause && q_head<q_tail && q_due[q_head]<=ddr_cycles) begin
   rd_valid<=1;rd_data<=memory[q_slot[q_head]][q_word[q_head]];q_head=q_head+1;returned=returned+1;
  end
  #2;
  if(completed_valid && (!completed_d || completed_rp!=rp_d)) begin
   s=completed_rp;
   if(written[s]!=WORDS) $fatal(1,"published incomplete frame: %0d of %0d",written[s],WORDS);
   for(k=0;k<WORDS;k=k+1)
    if(memory[s][k]!==word_data(expected_publication_frame,k)) $fatal(1,"published wrong frame expected=%0d word=%0d",expected_publication_frame,k);
   publications=publications+1;published_frame[s]=expected_publication_frame;
   $display("PUBLICATION number=%0d frame=%0d slot=%0d words=%0d",publications,expected_publication_frame,s,WORDS);
  end
  completed_d=completed_valid;rp_d=completed_rp;ready_d=ready;
 end
end

integer compare_mode=0,compare_frame=0,pixel_number=0,checked_pixels=0,black_pixels=0;
reg de_d=0;integer pixel_d=0;reg observed_bad=0;
always @(posedge pixel_clk) begin
 #1;
 if(rst_n && de_d) begin
  if(compare_mode==1 && rgb!==pixel_data(compare_frame,pixel_d))
   $fatal(1,"pixel mismatch frame=%0d pixel=%0d expected=%h got=%h display_ok=%b",compare_frame,pixel_d,pixel_data(compare_frame,pixel_d),rgb,display_ok);
  if(compare_mode==2 && rgb!==24'd0) $fatal(1,"invalid frame not black at pixel=%0d rgb=%h",pixel_d,rgb);
  if(compare_mode==3) begin
   if(!display_ok) observed_bad=1;
   if(observed_bad && rgb!==24'd0) $fatal(1,"pixels after underflow not black pixel=%0d rgb=%h",pixel_d,rgb);
   if(!observed_bad && rgb!==pixel_data(compare_frame,pixel_d)) $fatal(1,"pre-underflow pixel corrupt %0d expected=%h got=%h display_ok=%b",pixel_d,pixel_data(compare_frame,pixel_d),rgb,display_ok);
  end
  if(compare_mode!=0) begin checked_pixels=checked_pixels+1;if(rgb==0) black_pixels=black_pixels+1;end
 end
 de_d=de;pixel_d=pixel_number;
 if(de) pixel_number=pixel_number+1;
end

task camera_fs;
 begin
  @(negedge camera_clk);camera_valid=0;frame_good=0;frame_bad=0;camera_start=1;
  @(negedge camera_clk);camera_start=0;
  repeat(16) @(negedge camera_clk);
 end
endtask
task send_words(input integer frame,input integer n,input integer pace);
 integer w,timeout;
 begin
  for(w=0;w<n;w=w+1) begin
   if(pace!=0 && w%(W*3/16)==0) begin
    camera_valid=0;repeat(pace) @(negedge camera_clk);timeout=0;
    while(!camera_ready && W!=1024) begin
     @(negedge camera_clk);timeout=timeout+1;
     if(timeout>10000) $fatal(1,"camera_ready timeout frame=%0d word=%0d",frame,w);
    end
   end
   camera_data=word_data(frame,w);camera_valid=1;@(negedge camera_clk);
   if(W==1024 && w%3==2) begin camera_valid=0;@(negedge camera_clk);end
  end
  camera_valid=0;
 end
endtask
task send_good(input integer frame);
 begin
  camera_fs();expected_publication_frame=frame;send_words(frame,WORDS,W==1024 ? 512 : 20);frame_good=1;
 end
endtask
task wait_publication(input integer n);
 integer timeout;
 begin
  timeout=0;
  while(publications<n) begin @(negedge ddr_clk);timeout=timeout+1;if(timeout>30000) $fatal(1,"publication timeout want=%0d got=%0d",n,publications);end
  repeat(20) @(negedge ddr_clk);
 end
endtask
task display_vs;
 begin
  @(negedge pixel_clk);de=0;compare_mode=0;pixel_number=0;observed_bad=0;vs=1;
  repeat(12) @(negedge pixel_clk);vs=0;
 end
endtask
task display_pixels(input integer mode,input integer frame);
 integer y,x,checked_before;
 begin
  @(negedge pixel_clk);
  compare_mode=mode;compare_frame=frame;pixel_number=0;checked_before=checked_pixels;
  for(y=0;y<H;y=y+1) begin
   for(x=0;x<W;x=x+1) begin de=1;@(negedge pixel_clk);end
   de=0;repeat(20) @(negedge pixel_clk);
  end
  repeat(3) @(negedge pixel_clk);compare_mode=0;
  if(checked_pixels-checked_before!=PIXELS) $fatal(1,"did not check complete display raster");
  $display("DISPLAY mode=%0d frame=%0d checked=%0d black_total=%0d underflow_count=%0d",mode,frame,PIXELS,black_pixels,underflow_frames);
 end
endtask
integer old_publications,old_lost,old_overflow,old_underflow,old_reads;
reg [1:0] pinned;
initial begin
 for(s=0;s<4;s=s+1) for(k=0;k<WORDS;k=k+1) memory[s][k]=0;
 repeat(10) @(negedge camera_clk);rst_n=1;
 repeat(30) @(negedge pixel_clk);
 if($test$plusargs("FULL_ONCE")) begin
  fork
   send_good(1);
   begin
    wait(writes>WORDS/2);@(negedge ddr_clk);ready=0;
    repeat(300) @(negedge ddr_clk);ready=1;
   end
  join
  wait_publication(1);
  display_vs();repeat(1200) @(negedge pixel_clk);display_pixels(1,1);
  if(!capture_ok || !display_ok || overflow_frames!=0 || underflow_frames!=0)
   $fatal(1,"full raster quality or FIFO error");
  $display("PASS video_transport FULL_RASTER width=%0d height=%0d words=%0d writes=%0d reads=%0d returned=%0d pixels=%0d ready_pause=300",W,H,WORDS,writes,reads,returned,checked_pixels);
  $finish;
 end
 display_vs();repeat(500) @(negedge pixel_clk);display_pixels(2,0);
 if(completed_valid) $fatal(1,"cold boot published an image");
 send_good(1);wait_publication(1);
 if(!capture_ok) $fatal(1,"complete source not marked capture_ok");
 display_vs();repeat(1200) @(negedge pixel_clk);display_pixels(1,1);
 // A truncated source must not replace the retained frame. The following FS
 // is deliberately issued while a finite DDR write burst is in progress.
 old_lost=lost_frames;old_publications=publications;
 camera_fs();send_words(2,400,0);
 wait(wr_en===1'b1);camera_fs();expected_publication_frame=3;
 if(publications!=old_publications) $fatal(1,"short source published");
 send_words(3,WORDS,20);frame_good=1;wait_publication(2);
 if(lost_frames<=old_lost) $fatal(1,"aborted short frame was not recorded");
 display_vs();repeat(1200) @(negedge pixel_clk);display_pixels(1,3);
 // No backpressure exists for RAW input: source ignores camera_ready here.
 old_overflow=overflow_frames;old_publications=publications;
 @(negedge ddr_clk);ready=0;
 camera_fs();send_words(4,WORDS,0);frame_good=1;
 repeat(500) @(negedge ddr_clk);ready=1;
 repeat(2000) @(negedge ddr_clk);
 if(publications!=old_publications) $fatal(1,"overflow source published");
 if(overflow_frames<=old_overflow || capture_ok) $fatal(1,"overflow not visible/quality not revoked");
 send_good(5);wait_publication(3);
 display_vs();repeat(1200) @(negedge pixel_clk);
 old_underflow=underflow_frames;
 @(negedge ddr_clk);return_pause=1;
 display_pixels(3,5);
 if(!observed_bad || underflow_frames<=old_underflow) $fatal(1,"underflow not detected");
 // A new complete source may arrive while old display returns are held.
 // Subsequent VS must wait for those old returns before changing address.
 @(negedge ddr_clk);ready=1;
 send_good(6);wait_publication(4);
 if(q_tail<=q_head) $fatal(1,"test did not leave old display returns outstanding");
 pinned=active_rp;old_reads=reads;
 display_vs();repeat(60) @(negedge ddr_clk);
 if(q_tail>q_head && active_rp!=pinned) $fatal(1,"changed display buffer with old returns outstanding");
 if(reads!=old_reads) $fatal(1,"new read commands while prior frame returns outstanding");
 @(negedge ddr_clk);return_pause=0;
 repeat(1500) @(negedge pixel_clk);
 display_pixels(1,6);
 if(!display_ok || !capture_ok) $fatal(1,"quality failed to recover on complete source/display");
 $display("PASS video_transport publications=%0d writes=%0d reads=%0d returned=%0d lost=%0d overflow=%0d underflow=%0d checked_pixels=%0d",publications,writes,reads,returned,lost_frames,overflow_frames,underflow_frames,checked_pixels);
 $finish;
end
initial begin #50000000;$fatal(1,"global test timeout");end
endmodule
