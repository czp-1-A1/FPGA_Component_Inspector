`timescale 1ns/1fs
// Frozen HDMI-only diagnostic: actual encrypted transmitter and vendor ODDR.
// Ideal target clocks isolate framing/serialization from the board PLL/DDR.
// The expected raster is the independently fixed CTA VIC34 contract.
// This probe acquires a complete frame at VS, like a receiver. The earlier
// strict startup-line failure is retained separately; it is not repaired by
// passing the steady-state probe, nor is the first partial frame accepted.
module tb_fhd_hdmi;
`include "hdmi_decode.vh"
reg pixel=0,serial=0,rst=1;
// Exact 5:1 after time quantization; target-frequency error is only 1 ppm.
always #6.734000 pixel=~pixel;
always #1.346800 serial=~serial;
wire vs,hs,de,user,last;wire clock_pin,blue_pin,green_pin,red_pin;
uivtc #(.H_ActiveSize(1920),.H_FrameSize(2200),.H_SyncStart(2008),.H_SyncEnd(2052),
 .V_ActiveSize(1080),.V_FrameSize(1125),.V_SyncStart(1084),.V_SyncEnd(1089)) vtc(
 .I_vtc_rstn(!rst),.I_vtc_clk(pixel),.O_vtc_vs(vs),.O_vtc_hs(hs),
 .O_vtc_de_valid(de),.O_vtc_user(user),.O_vtc_last(last));
hdmi_tx #(.WIDTH(1920),.HEIGHT(1080),.HTOTAL(2200),.VTOTAL(1125),
 .HFP(88),.HSA(44),.HBP(148),.VFP(4),.VSA(5),.VBP(36),.VIC(34)) tx(
 .I_pixel_clk(pixel),.I_serial_clk(serial),.I_rst(rst),.I_key_in(1'b0),
 .I_edid_read_trig(1'b0),.O_edid_read_valid(),.O_edid_read_data(),
 .I_video_rgb_enable(1'b1),.I_video_in_de(de),.I_video_in_vs(vs),
 .I_video_in_user(1'b0),.I_video_in_valid(1'b0),.I_video_in_last(1'b0),
 .O_video_in_ready(),.I_video_in_data(24'h204080),
 .I_audio_valid(1'b0),.I_audio_left_data(24'd0),.I_audio_right_data(24'd0),
 .I_i2s_BCLK(1'b0),.I_i2s_LRCK(1'b0),.I_i2s_DOUT(1'b0),
 .O_ddc_scl(),.IO_ddc_sda(),.O_hdmi_clk_p(),.O_hdmi_tx_p(),
 .O_tmds_ch0_p(blue_pin),.O_tmds_ch1_p(green_pin),.O_tmds_ch2_p(red_pin),.O_tmds_clk_p(clock_pin));
integer cycles=0,source_vs_edges=0,source_pixels=0,source_lines=0,line_pixels=0;
integer previous_source_vs_cycle=-1,decoded_hs_rise=-1,decoded_vs_rise=-1;
integer decoded_hs_checked=0,decoded_vs_checked=0,clock_edges=0,ctrl_count=0;
integer observed_h_edges=0;reg control_acquired=0;
reg source_vs_old=0,source_de_old=0,decoded_hs=0,decoded_vs=0;
reg control_valid;reg [1:0] control_bits;realtime previous_clock_edge=-1,period;
reg island=0;reg[2:0] cb,cg,cr;reg[4:0] terc_value;
integer island_preamble=0;
always @(posedge clock_pin) if(!rst && cycles>100)begin
 if(previous_clock_edge>=0)begin
  period=$realtime-previous_clock_edge;
  if(period<13.467 || period>13.469)$fatal(1,"TMDS clock pin period %0.9f ns",period);
  clock_edges=clock_edges+1;
 end
 previous_clock_edge=$realtime;
end
always @(posedge pixel)begin
 #0.001;
 if(!rst)begin
  cycles=cycles+1;
  if(de)begin source_pixels=source_pixels+1;line_pixels=line_pixels+1;end
  if(source_de_old && !de)begin
   if(previous_source_vs_cycle>=0 && line_pixels!=1920)$fatal(1,"VTC line pixels %0d",line_pixels);
   if(previous_source_vs_cycle<0 && line_pixels!=1920)
    $display("OBS startup line invalid: %0d pixels; first incomplete frame excluded from steady-state acquisition",line_pixels);
   source_lines=source_lines+1;line_pixels=0;
  end
  if(vs && !source_vs_old)begin
   if(previous_source_vs_cycle>=0)begin
    if(cycles-previous_source_vs_cycle!=2475000 || source_pixels!=2073600 || source_lines!=1080)
     $fatal(1,"VTC frame contract period=%0d pixels=%0d lines=%0d",cycles-previous_source_vs_cycle,source_pixels,source_lines);
    source_vs_edges=source_vs_edges+1;
   end
   previous_source_vs_cycle=cycles;source_pixels=0;source_lines=0;
  end
  source_vs_old=vs;source_de_old=de;
  cb=hdmi_control(tx.S_ch0_tmds_data);cg=hdmi_control(tx.S_ch1_tmds_data);cr=hdmi_control(tx.S_ch2_tmds_data);
  terc_value=hdmi_terc4(tx.S_ch0_tmds_data);control_valid=0;
  if(cb[2] && cg[2] && cr[2])begin
   island=0;control_valid=1;control_bits=cb[1:0];
   if(cg[1:0]==2'b01 && cr[1:0]==2'b01)island_preamble=island_preamble+1;
   else island_preamble=0;
  end else begin
   if(island_preamble>=8 && tx.S_ch1_tmds_data==10'b0100110011 && tx.S_ch2_tmds_data==10'b0100110011)island=1;
   island_preamble=0;
   if(island)begin
    if(!terc_value[4])$fatal(1,"Invalid HDMI TERC4 symbol");
    control_valid=1;control_bits=terc_value[1:0];
   end
  end
  if(cycles>100 && control_valid)begin
   ctrl_count=ctrl_count+1;
   if(!control_acquired)begin
    // A receiver cannot time a pulse which was already high when sampling
    // began. Seed the levels; retain exact checks for all subsequent edges.
    decoded_hs=control_bits[0];decoded_vs=control_bits[1];control_acquired=1;
    $display("OBS first control at cycle=%0d HS=%0d VS=%0d",cycles,decoded_hs,decoded_vs);
   end
   if(control_bits[0]!=decoded_hs && observed_h_edges<10)begin
    $display("OBS encoded HS transition cycle=%0d level=%0d",cycles,control_bits[0]);
    observed_h_edges=observed_h_edges+1;
   end
   if(control_bits[0] && !decoded_hs)begin
    if(decoded_hs_rise>=0)begin
     if(cycles-decoded_hs_rise!=2200 && !$test$plusargs("observe"))$fatal(1,"encrypted core H period %0d",cycles-decoded_hs_rise);
     decoded_hs_checked=decoded_hs_checked+1;
    end
    decoded_hs_rise=cycles;
   end
   if(!control_bits[0] && decoded_hs && decoded_hs_rise>=0 && cycles-decoded_hs_rise!=44 && !$test$plusargs("observe"))
    $fatal(1,"encrypted core H pulse %0d",cycles-decoded_hs_rise);
   if(control_bits[1] && !decoded_vs)begin
    if(decoded_vs_rise>=0)begin
     if(cycles-decoded_vs_rise!=2475000 && !$test$plusargs("observe"))$fatal(1,"encrypted core V period %0d",cycles-decoded_vs_rise);
     decoded_vs_checked=decoded_vs_checked+1;
    end
    decoded_vs_rise=cycles;
   end
   if(control_bits[1]!=decoded_vs)
    $display("OBS encoded VS transition cycle=%0d level=%0d",cycles,control_bits[1]);
   if(!control_bits[1] && decoded_vs && decoded_vs_rise>=0 && cycles-decoded_vs_rise!=11000 && !$test$plusargs("observe"))
    $fatal(1,"encrypted core V pulse %0d",cycles-decoded_vs_rise);
   decoded_hs=control_bits[0];decoded_vs=control_bits[1];
  end
  if(source_vs_edges>=1 && decoded_vs_checked>=1 && !$test$plusargs("observe"))begin
   if(decoded_hs_checked<1125 || clock_edges<1000 || ctrl_count<1000)$fatal(1,"missing HDMI observations");
   $display("PASS FHD HDMI: steady-state actual encrypted core and vendor ODDR; source2073600 pixels/1080 rows; encoded HS44/2200 VS11000/2475000; TMDS clock74.25 MHz, ideal5:1 clocks. Startup failure and physical PLL/monitor compatibility not resolved.");
   $finish;
  end
 end
end
initial begin repeat(20)@(negedge pixel);rst=0;end
initial begin
 if($test$plusargs("observe"))begin
  #1000000;$display("OBS HDMI probe complete: observations only; no timing or board acceptance");$finish;
 end
end
initial begin #150000000;$fatal(1,"FHD HDMI watchdog source=%0d decoded=%0d controls=%0d",source_vs_edges,decoded_vs_checked,ctrl_count);end
endmodule
