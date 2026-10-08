`timescale 1ns/1ps
module tb_hdmi_tpg;
reg refclk=0,reset_n=0;always #10 refclk=~refclk;
wire blue_pin,green_pin,red_pin,clock_pin;
hdmi_tpg_top dut(refclk,reset_n,blue_pin,green_pin,red_pin,clock_pin);
`include "hdmi_decode.vh"
integer cycles=0,h_old_edge=-1,v_old_edge=-1,h_low=-1,v_low=-1;
integer h_checks=0,v_checks=0,clock_checks=0,islands=0,terc_checks=0;
integer island_preamble=0;
reg acquired=0,island=0,hs_old=0,vs_old=0;
reg locked_old=0;
reg [2:0] cb,cg,cr;reg[4:0] tb;reg valid_sync;reg [1:0] sync_bits;
realtime previous_clock=-1,clock_period;
always @(posedge clock_pin)if(reset_n && dut.reset_sync[2] && cycles>100)begin
 if(previous_clock>=0)begin
  clock_period=$realtime-previous_clock;
  if(clock_period<13.45 || clock_period>13.49)$fatal(1,"TPG TMDS clock period %f",clock_period);
  clock_checks=clock_checks+1;
 end
 previous_clock=$realtime;
end
always @(posedge dut.pixel)begin
 #0.001;
 if(!dut.rst)begin
  cycles=cycles+1;
  if(dut.video_locked!==locked_old)begin
   $display("OBS TPG video_locked=%b cycle=%0d",dut.video_locked,cycles);
   locked_old=dut.video_locked;
   // A lock transition rephases the core counters. Do not time a pulse or
   // frame spanning acquisition. Reference lengths remain unchanged; the
   // strict post-lock test must still observe a whole VS-to-VS frame.
   acquired=0;h_old_edge=-1;v_old_edge=-1;h_low=-1;v_low=-1;
   h_checks=0;v_checks=0;
  end
  cb=hdmi_control(dut.blue);cg=hdmi_control(dut.green);cr=hdmi_control(dut.red);
  tb=hdmi_terc4(dut.blue);valid_sync=0;
  if(cb[2] && cg[2] && cr[2])begin
   island=0;sync_bits=cb[1:0];valid_sync=1;
   if(cg[1:0]==2'b01 && cr[1:0]==2'b01)island_preamble=island_preamble+1;
   else island_preamble=0;
  end else begin
   // Guard words can also occur in video data. Enter an island only after
   // its eight-control-symbol preamble on channels 1 and 2.
   if(island_preamble>=8 && dut.green==10'b0100110011 && dut.red==10'b0100110011 && !island)begin
    island=1;islands=islands+1;
   end
   island_preamble=0;
   if(island)begin
    if(!tb[4])$fatal(1,"Invalid TERC4 inside data island");
    sync_bits=tb[1:0];valid_sync=1;terc_checks=terc_checks+1;
   end
  end
  if(valid_sync && dut.video_locked)begin
   if(!acquired)begin hs_old=sync_bits[0];vs_old=sync_bits[1];acquired=1;end
   // Audit the vendor-generated polarity explicitly. These are LOW pulses;
   // count checks do not certify VIC34 positive sync polarity or hardware.
   if(!sync_bits[0] && hs_old)begin
    if(cycles>90000 && cycles<115000)$display("OBS HS falling cycle=%0d period=%0d island=%b cb=%b cg=%b cr=%b locked=%b",cycles,cycles-h_old_edge,island,cb,cg,cr,dut.video_locked);
    if(h_old_edge>=0)begin
     if(cycles-h_old_edge!=2200)$fatal(1,"TPG horizontal period %0d",cycles-h_old_edge);
     h_checks=h_checks+1;
    end
    h_old_edge=cycles;h_low=cycles;
   end
   if(sync_bits[0] && !hs_old && h_low>=0)begin
    if(cycles-h_low!=44)$fatal(1,"TPG horizontal LOW pulse %0d",cycles-h_low);
    if(h_checks<3)$display("OBS TPG HS LOW width44; HIGH width2156; period2200");
   end
   if(!sync_bits[1] && vs_old)begin
    if(v_old_edge>=0)begin
     if(cycles-v_old_edge!=2475000)$fatal(1,"TPG vertical period %0d",cycles-v_old_edge);
     v_checks=v_checks+1;
    end
    v_old_edge=cycles;v_low=cycles;
   end
   if(sync_bits[1] && !vs_old && v_low>=0)begin
    if(cycles-v_low!=11000)$fatal(1,"TPG vertical LOW pulse %0d",cycles-v_low);
    $display("OBS TPG VS LOW width11000; frame2475000 pixel clocks");
   end
   hs_old=sync_bits[0];vs_old=sync_bits[1];
  end
  if(cycles%250000==0)$display("OBS TPG progress pixel_cycles=%0d Hchecks=%0d Vchecks=%0d",cycles,h_checks,v_checks);
  if(v_checks>=1)begin
   if(h_checks<1125 || clock_checks<1000 || islands<1000 || terc_checks<1000)$fatal(1,"Missing TPG observations");
`ifdef HDMI_TPG_IDEAL_PLL
   $display("PASS TPG transport counts: ideal clocks, actual encrypted core and vendor ODDR, clock74.25 MHz, H2200/LOW44 V2475000/LOW11000; negative sync observed. Diagnostic only; physical PLL, VIC34 polarity and board acceptance remain open.");
`else
   $display("PASS TPG transport counts: actual vendor PLL/core/ODDR, clock74.25 MHz, H2200/LOW44 V2475000/LOW11000; negative sync observed. Diagnostic only; VIC34 polarity and board acceptance remain open.");
`endif
   $finish;
  end
 end
end
initial begin #10000;reset_n=1;end
initial begin #100000000;$fatal(1,"TPG watchdog");end
endmodule
