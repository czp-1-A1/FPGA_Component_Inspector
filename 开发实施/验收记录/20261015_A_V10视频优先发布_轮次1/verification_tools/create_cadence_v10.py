from pathlib import Path
p = Path('fpga/component_inspector/sim')
old = (p / 'tb_frame_process.v').read_text(encoding='utf-8')
header = old[:old.index('reg [349:0] slot_truth')]
header = header.replace('module tb_frame_process;', 'module tb_frame_cadence;')
header = header.replace('.METADATA_WAIT_CYCLES(1500000)', '.VIDEO_FIRST(1)')
body = r'''
integer frame_no=0,pattern=0,shift=0,move_y=0,row,b,l,pgm;
integer displays=0,checked_pixels=0,nonzero_pixels=0,accepted_frames=0,commits=0;
integer luma[0:614399];reg [75:0] aa,bb;
real frame_time,previous_fs=0,publish_time=0,result_time=0;
reg published_d=0,mready_d=0;
always @(posedge dclk)begin
 published_d<=writer.published;
 if(writer.published && !published_d)publish_time=$realtime;
end
always @(posedge procclk)begin
 mready_d<=mready;
 if(mready && !mready_d)result_time=$realtime;
end
always @(posedge clk)if(rst)begin
 if(dut.roi_commit)commits++;
 if(dut.roi_accept)for(integer k=0;k<4;k++)luma[dut.roi_y*1024+dut.roi_x+k]=
  (int'(dut.awb_O_tdata[95-k*24-:8])+2*int'(dut.awb_O_tdata[87-k*24-:8])+int'(dut.awb_O_tdata[79-k*24-:8]))/4;
end
function integer source(input integer px,py);
 begin
  source=80;
  if(pattern==3)source=px>=40 && px<984 && py>=180 && py<440 ? 80 : 960;
  if(px>=424 && px<488 && py>=262 && py<338)source=720;
  if(px>=520 && px<584 && py>=262 && py<338)source=720;
 end
endfunction
// Compare real rendered bytes to their selected DDR pixel slot, including word crossings.
function [23:0] expected_pixel(input integer slot,pixel);
 reg [23:0] value;integer byte_pos,word_pos,offset;
 begin
  for(integer k=0;k<3;k++)begin
   byte_pos=pixel*3+k;word_pos=slot*115200+byte_pos/16;offset=byte_pos%16;
   value[23-k*8-:8]=memory[word_pos][127-offset*8-:8];
  end
  expected_pixel=value;
 end
endfunction
reg previous_rd=0;integer next_pixel=0;reg [1:0] selected_slot;reg [349:0] selected_meta;
always @(posedge hclk)begin
 #1;
 if(rst && previous_rd)begin
  if(display_rgb!==expected_pixel(selected_slot,next_pixel))
   $fatal(1,"cadence display byte mismatch slot=%0d pixel=%0d got=%h expected=%h",selected_slot,next_pixel,display_rgb,expected_pixel(selected_slot,next_pixel));
  if(active_slot!==selected_slot || active_meta!==selected_meta)$fatal(1,"late tuple changed active pixels/results inside one raster");
  if(display_rgb!=0)nonzero_pixels++;
  next_pixel++;checked_pixels++;
 end
 previous_rd=rd;
end
initial begin
 wait(completed_valid);
 forever begin
  @(negedge hclk);vs=1;repeat(1000)@(negedge hclk);vs=0;repeat(30000)@(negedge hclk);
  if(!active_valid)$fatal(1,"cadence complete picture did not arm reader");
  selected_slot=active_slot;selected_meta=active_meta;next_pixel=0;
  for(integer yy=0;yy<600;yy++)begin
   for(integer xx=0;xx<1024;xx++)begin rd=1;@(negedge hclk);end
   rd=0;repeat(320)@(negedge hclk);
  end
  if(next_pixel!=614400 || underflows || !display_ok)$fatal(1,"cadence complete raster/underflow failure");
  displays++;
 end
end
task ticks(input integer count);begin repeat(count)@(negedge clk);end endtask
task frame(input integer kind,mode);
 real end_time;
 begin
  @(negedge clk);frame_time=$realtime;
  if(previous_fs!=0 && (frame_time-previous_fs<38450000 || frame_time-previous_fs>38470000))$fatal(1,"source cadence drifted from 26 FPS");
  previous_fs=frame_time;frame_no++;pattern=kind;request=mode;commits=0;publish_time=0;result_time=0;
  fs=1;ticks(1);fs=0;ticks(48);
  for(row=0;row<600;row++)begin
   hs=1;ticks(3);
   for(b=0;b<256;b++)begin
    if(kind==4 && row==200 && b==100)wb_request=32'h00016464;
    rv=1;for(l=0;l<4;l++)raw[39-l*10-:10]=10'(source(b*4+l,row));ticks(1);rv=0;ticks(b%4==3 ? 3 : 1);
   end
   hs=0;ticks(98);
   // Preserve native LP738 active edges, but stop recovered CSI between rows.
   // The continuous post-AWB clock should observe the photographed LP0CF0.
   if(row!=599)begin run_clk=0;#26560.656;run_clk=1;end
  end
  fe=1;ticks(1);fe=0;ticks(200);run_clk=0;end_time=$realtime;
  if(frame_no!=1)begin
   while(!writer.published && $realtime<end_time+100000)#10;
   if(!writer.published || !cap || bad || !good || writer.written!=115200)
    $fatal(1,"cadence video blocked frame=%0d P=%h words=%0d good=%b bad=%b",frame_no,writer.publish_seen,writer.written,good,bad);
  end
  if($realtime<frame_time+38459000)#(frame_time+38459000-$realtime);
  if(frame_no==1)begin if(writer.published || !bad)$fatal(1,"warmup frame escaped proof");end
  else begin
   if(commits!=1 || overflows || underflows)$fatal(1,"cadence native proof/transport failure");
   if(kind==4)begin if(mready || completed_meta!=0)$fatal(1,"WB-canceled result must leave live zero-label video");end
   else begin
    if(!mready || completed_meta!==meta || obs[114:83]!==wb_request || obs[45:28]!==request)
     $fatal(1,"analysis did not finish within real cadence frame=%0d phase=%0d ready=%b FG=%0d latency_ns=%0f",frame_no,dut.local_shape_detection.detector.phase,mready,dut.local_shape_detection.detector.capture_foreground,result_time-end_time);
    aa=meta[198+:76];bb=meta[274+:76];
    if(!aa[75] || !bb[75] || aa[74:73]!=2 || bb[74:73]!=2 || aa[41:31]>=bb[41:31])$fatal(1,"cadence dual result truth mismatch");
    pgm=$fopen($sformatf("cadence_%0d.pgm",frame_no),"w");$fwrite(pgm,"P2\n1024 600\n255\n");
    for(integer yy=0;yy<600;yy++)begin for(integer xx=0;xx<1024;xx++)$fwrite(pgm,"%0d ",luma[yy*1024+xx]);$fwrite(pgm,"\n");end
    $fclose(pgm);
    $display("REF cadence frame=%0d objects=%h state=%0d FG=%0d W=%0d H=%0d X0=%0d X1=%0d Y0=%0d Y1=%0d",frame_no,meta[349:198],dut.search_state,dut.search_fg,dut.search_w,dut.search_h,dut.search_x0,dut.search_x1,dut.search_y0,dut.search_y1);
   end
   if(dut.u_roi_sobel_view.line_min<3296 || dut.u_roi_sobel_view.line_min>3328)$fatal(1,"test does not match photographed wall-clock line period");
   accepted_frames++;
  end
  $display("CADENCE frame=%0d mode=%0d LP=%h active_ns=%0f publish_after_FE_ns=%0f result_after_FE_ns=%0f",frame_no,mode,dut.u_roi_sobel_view.line_min,end_time-frame_time,publish_time-end_time,result_time==0 ? -1.0 : result_time-end_time);
  if($realtime<frame_time+38460000)#(frame_time+38460000-$realtime);
  run_clk=1;ticks(20);
 end
endtask
initial begin
 ticks(8);rst=1;ticks(20);
 frame(0,0);frame(0,0);frame(4,0);frame(3,0);frame(3,3);
 wait(displays>=4);repeat(4)@(negedge hclk);
 if(accepted_frames!=4 || checked_pixels<2457600 || nonzero_pixels<2400000 || overflows || underflows)$fatal(1,"cadence final counts failed");
 $display("PASS frame cadence: native line-clock gaps, LP0CF0 wall-clock, 26-FPS source start-to-start, RAW and GRAY+EDGE, live WB-canceled zero-result video, same-slot late dual tuples, full exact RGB rasters=%0d pixels=%0d OF=%0d UF=%0d",displays,checked_pixels,overflows,underflows);$finish;
end
initial begin #240000000;$fatal(1,"frame cadence watchdog");end
endmodule
'''
(p / 'tb_frame_cadence.v').write_text(header + body, encoding='utf-8', newline='\n')
runner = p / 'run_modelsim.ps1'
text = runner.read_text(encoding='utf-8')
entry = next(line for line in text.splitlines() if 'Name="frame_process"' in line)
text = text.replace(entry, entry.replace('frame_process', 'frame_cadence').replace('PASS frame process:', 'PASS frame cadence:') + '\n' + entry)
# Apply the same vendor globals, narrow access and minimal wave logging as the original real-ISP fixture.
text = text.replace('"frame_stop", "frame_process"', '"frame_stop", "frame_process", "frame_cadence"')
runner.write_text(text, encoding='utf-8', newline='\n')
print('Created native line-gap/26-FPS integration fixture')
