`timescale 1ns/1ps
module tb_clock_probe_units;
 reg refclk=0,pixel=0,rst_n=0,locked=0,mode=0,run_pixel=1;
 always #10 refclk=~refclk;
 always #6.734006734 if(run_pixel)pixel=~pixel;
 reg [31:0] ep=0,eh=0,ev=0;
 integer stimulus_step=0;
 always @(negedge pixel)if(rst_n)stimulus_step=stimulus_step+1;
 wire line_end=stimulus_step%17==16,frame_end=stimulus_step%113==112;
 wire [31:0] pg,hg,vg;
 clock_probe_counter source(pixel,!rst_n,line_end,frame_end,pg,hg,vg);
 always @(posedge pixel)if(rst_n)begin
  ep=ep+1;if(line_end)eh=eh+1;if(frame_end)ev=ev+1;
  #0.01;
  if(pg!==((ep>>1)^ep) || hg!==((eh>>1)^eh) || vg!==((ev>>1)^ev))$fatal(1,"Gray source counter/reference mismatch");
 end
 wire [193:0] measured,wrapped;
 // Offset near wrap exercises modulo subtraction without touching DUT registers.
 wire [31:0] wp=32'hffffff00+ep,wh=32'hffffff00+eh,wv=32'hffffff00+ev;
 clock_probe_measure #(.WINDOW_CYCLES(1000)) probe(refclk,rst_n,locked,mode,pg,hg,vg,measured);
 clock_probe_measure #(.WINDOW_CYCLES(1000)) wrap_probe(refclk,rst_n,locked,mode,(wp>>1)^wp,(wh>>1)^wh,(wv>>1)^wv,wrapped);
 reg measure_done=0,osd_done=0,mail_done=0;
 reg [95:0] saved_hd,saved_fhd;
 task check_counts(input [95:0] d);
  begin
   // 20us independently specified at74.25MHz; asynchronous aperture <=4 pixels.
   if(d[95:64]<1481 || d[95:64]>1489 || d[63:32]<86 || d[63:32]>89 || d[31:0]<12 || d[31:0]>14)
    $fatal(1,"Bad independent window counts P%0d H%0d V%0d",d[95:64],d[63:32],d[31:0]);
  end
 endtask
 initial begin
  #107;rst_n=1;locked=1;
  #21000;if(measured[193:192]!==0)$fatal(1,"First window must be discarded");
  #60000;check_counts(measured[95:0]);check_counts(wrapped[95:0]);
  if(measured[193:192]!==1)$fatal(1,"HD valid flag");
  saved_hd=measured[95:0];mode=1;
  #18000;if(measured[193])$fatal(1,"Mixed mode window published FHD");
  #42000;check_counts(measured[191:96]);check_counts(wrapped[191:96]);
  if(measured[193:192]!==3 || measured[95:0]!==saved_hd)$fatal(1,"Per-mode history corrupted");
  saved_fhd=measured[191:96];mode=0;
  #60000;check_counts(measured[95:0]);
  if(measured[191:96]!==saved_fhd)$fatal(1,"Return to HD lost FHD record");
  @(negedge pixel);run_pixel=0;
  #60000;if(measured[95:0]!==0)$fatal(1,"Stopped pixel clock must measure zero");
  locked=0;
  #100;if(measured[193:192]!==0)$fatal(1,"Ref domain failed to invalidate with pixel stopped");
  #700;locked=1;#40;locked=0;#200;locked=1;run_pixel=1;
  #19000;if(measured[193:192]!==0)$fatal(1,"Lock chatter/partial window accepted");
  #42000;check_counts(measured[95:0]);
  rst_n=0;#73;
  if(measured!==0)$fatal(1,"Common reset did not clear probe");
  $display("PASS F measurement: Gray event reference, first/mixed windows, per-mode retention, wrap subtraction, stopped pixel clock, lock chatter/recovery/reset. Unit window1000 cycles.");
  measure_done=1;
 end

 reg osclk=0,osrst=1;always #5 osclk=~osclk;
 reg [11:0] x=0;reg [10:0] y=0;reg [23:0] rgb=0;
 reg de=0,hs=0,vs=0;
 reg [193:0] data;
 wire [23:0] out_rgb;wire od,oh,ov;
 clock_probe_osd osd(osclk,osrst,x,y,rgb,de,hs,vs,data,out_rgb,od,oh,ov);
 `include "clock_probe_reference.vh"
 reg [26:0] queue [0:2];integer xx,yy,m,i,ht,vt,ha,va,n=0;
 initial begin
  for(i=0;i<3;i=i+1)queue[i]=0;
  data={2'b11,32'h89abcdef,32'h01234567,32'hfedcba98,32'h76543210,32'h13579bdf,32'h2468ace0};
  #21;osrst=0;
  for(m=0;m<2;m=m+1)begin
   ht=m?2200:1650;vt=m?1125:750;ha=m?1920:1280;va=m?1080:720;
   for(yy=0;yy<vt;yy=yy+1)for(xx=0;xx<ht;xx=xx+1)begin
    @(negedge osclk);x=xx;y=yy;rgb={xx[7:0],yy[7:0],8'h57};
    de=xx<ha && yy<va;hs=xx>ha;vs=yy>=va;
    queue[2]=queue[1];queue[1]=queue[0];queue[0]={osd_reference(xx,yy,rgb,data),de,hs,vs};
    @(posedge osclk);#0.1;
    if(n>=2 && {out_rgb,od,oh,ov}!==queue[2])$fatal(1,"OSD independent raster mismatch m%0d x%0d y%0d actual%h expected%h",m,xx,yy,{out_rgb,od,oh,ov},queue[2]);
    n=n+1;
   end
  end
  $display("PASS F OSD:720+FHD complete raster%0d samples, nonzero hex fields/all digits/labels/font, background and equal RGB/DE/HS/VS three-stage delay.",n);
  osd_done=1;
 end

 reg destclk=0,dest_run=1,mail_reset=0;always #7 if(dest_run)destclk=~destclk;
 reg [31:0] token=0;reg [193:0] bundle=0;wire [193:0] received;
 status_cdc #(.WIDTH(194)) mailbox(refclk,destclk,mail_reset,bundle,received);
 always @(negedge refclk)if(mail_reset)begin token=token+1;bundle={2'b11,token,~token,token,~token,token,~token};end
 always @(negedge destclk)if(mail_reset && received!=0)
  if(received[193:192]!==3 || received[191:160]!==received[127:96] || received[191:160]!==received[63:32] ||
   received[159:128]!==~received[191:160] || received[95:64]!==received[159:128] || received[31:0]!==received[159:128])$fatal(1,"Torn CDC snapshot");
 initial begin
  #51;mail_reset=1;#3000;@(negedge destclk);dest_run=0;
  #6000;dest_run=1;#3000;mail_reset=0;#33;
  if(received!==0)$fatal(1,"Stopped destination/common reset mailbox");
  mail_reset=1;#3000;
  $display("PASS F mailbox:194-bit atomic snapshots, destination stopped/resumed, common reset.");mail_done=1;
 end
 initial begin wait(measure_done && osd_done && mail_done);$display("PASS F units complete");$finish;end
 initial begin #50000000;$fatal(1,"F units watchdog");end
endmodule
