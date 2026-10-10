// Independent fixed B/C wire-format reference, frozen before E tests.
// Reads serial pins only for pixels/raster. Never DUT x/y/mode/request.
// SW20ms qualifier is checked with wall time, rather than RTL counter bits.
`timescale 1ns/1fs
module tb_dual_mode_pins;
 reg refclk=0,reset_n=0,sw=0;always #10 refclk=~refclk;
 wire bp,gp,rp,cp;
 dual_mode_top dut(refclk,reset_n,sw,bp,gp,rp,cp);
 `include "hdmi_decode.vh"
 reg [9:0] wb=0,wg=0,wr=0,wc=0;
 reg [2:0] cb,cg,cr;
 reg acquired=0,hs_old=0,vs_old=0,frame_active=0;
 integer bits=0,words=0,rx_x=0,rx_y=0,mode_ref=0;
 integer ht=1650,ha=1280,hs0=1390,hs1=1430,vt=750,va=720,bar=160;
 integer hs_begin=-1,vs_begin=-1;
 integer frame_words=0,frame_pixels=0,line_pixels=0,lines=0;
 integer hd_frames=0,fhd_frames=0,transitions=0;
 integer db=0,dg=0,dr=0;
 reg [1:0] sync_bits;
 reg [23:0] rgb;
 realtime last_clock=-1,period,sw_since=0,elapsed;
 reg last_mode;
 event request_fhd,request_hd;
 reg up_sent=0,down_sent=0;
 function automatic [7:0] inverse_tmds(input [9:0] w);
  reg [7:0] q;integer i;
  begin q=w[7:0]^{8{w[9]}};inverse_tmds[0]=q[0];
   for(i=1;i<8;i=i+1)inverse_tmds[i]=q[i]^q[i-1]^!w[8];
  end
 endfunction
 function automatic [23:0] pixel_reference(input integer coord,input integer bar_width);
  begin case(coord/bar_width)
   0:pixel_reference=24'hffffff;1:pixel_reference=24'hffff00;
   2:pixel_reference=24'h00ffff;3:pixel_reference=24'h00ff00;
   4:pixel_reference=24'hff00ff;5:pixel_reference=24'hff0000;
   6:pixel_reference=24'h0000ff;default:pixel_reference=24'h000000;
  endcase end
 endfunction
 function automatic integer disparity(input [9:0] w);
  integer i,n;
  begin n=0;for(i=0;i<10;i=i+1)n=n+w[i];disparity=2*n-10;end
 endfunction
 always @(sw)sw_since=$realtime;
 initial begin
  @request_fhd;
  #421.3;sw=1;#733.1;sw=0;#513.7;sw=1; // Contact bounce, final up.
 end
 initial begin
  @request_hd;
  #317.7;sw=0;#491.1;sw=1;#827.3;sw=0; // Final down, asynchronous.
 end
 always @(posedge cp)if(reset_n && !dut.rst)begin
  if(last_clock>=0)begin period=$realtime-last_clock;
   if(period<13.45 || period>13.49)$fatal(1,"E TMDS clock period %f",period);
  end
  last_clock=$realtime;
 end
 always @(posedge dut.rst)if(reset_n)$fatal(1,"E mode switch asserted display reset");
 always @(negedge dut.locked)if(reset_n)$fatal(1,"E mode switch lost PLL lock");
 always @(posedge dut.serial or negedge dut.serial)begin
  #0.05;
  if(dut.rst)begin bits=0;wc=0;end
  else begin
   wb={bp,wb[9:1]};wg={gp,wg[9:1]};wr={rp,wr[9:1]};wc={cp,wc[9:1]};bits=bits+1;
   if(bits>=10 && wc==10'b1111100000)begin
    words=words+1;cb=hdmi_control(wb);cg=hdmi_control(wg);cr=hdmi_control(wr);
    if(acquired)begin
     if(rx_x==ht-1)begin
      rx_x=0;
      if(rx_y==vt-1)begin
       rx_y=0;frame_active=1;frame_words=0;frame_pixels=0;lines=0;line_pixels=0;
       elapsed=$realtime-sw_since;
       if(elapsed>=20001000.0)begin
        last_mode=mode_ref;mode_ref=sw;
        if(mode_ref!=last_mode)begin
         transitions=transitions+1;hs_begin=-1;vs_begin=-1;
         $display("OBS E accepted SW at frame boundary mode%0d elapsed%fns",mode_ref,elapsed);
        end
       end else if(elapsed>=20000000.0)$fatal(1,"Stimulus fell in1us CDC/debounce ambiguity window");
       if(mode_ref==0)begin ht=1650;ha=1280;hs0=1390;hs1=1430;vt=750;va=720;bar=160;end
       else begin ht=2200;ha=1920;hs0=2008;hs1=2052;vt=1125;va=1080;bar=240;end
      end else rx_y=rx_y+1;
     end else rx_x=rx_x+1;
    end
    if(cb[2])begin
     if(!cg[2] || !cr[2] || cg[1:0]!=0 || cr[1:0]!=0)$fatal(1,"E DVI control channels");
     sync_bits=cb[1:0];
     if(sync_bits[0] && !hs_old)begin
      if(acquired && rx_x!=hs0)$fatal(1,"E HS rise x%0d mode%0d",rx_x,mode_ref);
      if(hs_begin>=0 && words-hs_begin!=ht)$fatal(1,"E H period");
      rx_x=hs0;acquired=1;hs_begin=words;
     end
     if(!sync_bits[0] && hs_old && rx_x!=hs1)$fatal(1,"E HS width");
     if(sync_bits[1] && !vs_old)begin
      if((mode_ref==0 && (rx_y!=725 || rx_x!=0)) ||
         (mode_ref==1 && (rx_y!=1083 || rx_x!=2008 || hs_old || !sync_bits[0])))$fatal(1,"E VS rise/phase");
      if(vs_begin>=0 && words-vs_begin!=ht*vt)$fatal(1,"E V period");vs_begin=words;
     end
     if(!sync_bits[1] && vs_old)begin
      if((mode_ref==0 && (rx_y!=730 || rx_x!=0)) ||
         (mode_ref==1 && (rx_y!=1088 || rx_x!=2008 || hs_old || !sync_bits[0])))$fatal(1,"E VS end/phase");
      if(words-vs_begin!=5*ht)$fatal(1,"E VS width");
     end
     if(acquired)begin
      if((rx_x>=hs0 && rx_x<hs1)!==sync_bits[0] ||
         ((mode_ref==0)?(rx_y>=725 && rx_y<730):
           (rx_y*ht+rx_x>=1083*ht+2008 && rx_y*ht+rx_x<1088*ht+2008))!==sync_bits[1])$fatal(1,"E sync interval");
      if(rx_x<ha && rx_y<va)$fatal(1,"E control in active video");
     end
     hs_old=sync_bits[0];vs_old=sync_bits[1];db=0;dg=0;dr=0;
    end else if(acquired)begin
     if(cg[2] || cr[2] || rx_x>=ha || rx_y>=va)$fatal(1,"E video outside rectangle");
     rgb={inverse_tmds(wr),inverse_tmds(wg),inverse_tmds(wb)};
     if(rgb!==pixel_reference(rx_x,bar))$fatal(1,"E RGB mismatch mode%0d x%0d y%0d",mode_ref,rx_x,rx_y);
     db=db+disparity(wb);dg=dg+disparity(wg);dr=dr+disparity(wr);
     if(db>8 || db< -8 || dg>8 || dg< -8 || dr>8 || dr< -8)$fatal(1,"E video disparity");
     if(frame_active)begin frame_pixels=frame_pixels+1;line_pixels=line_pixels+1;end
    end
    if(frame_active)begin
     frame_words=frame_words+1;
     if(rx_x==ha && rx_y<va)begin
      if(line_pixels!=ha)$fatal(1,"E line pixels%0d",line_pixels);line_pixels=0;lines=lines+1;
     end
     if(rx_x==ht-1 && rx_y==vt-1)begin
      if(frame_words!=ht*vt || frame_pixels!=ha*va || lines!=va)$fatal(1,"E complete frame counts");
      if(mode_ref==0)hd_frames=hd_frames+1;else fhd_frames=fhd_frames+1;
      $display("OBS E full frame mode%0d words%0d pixels%0d lines%0d, HD%0d FHD%0d transitions%0d",mode_ref,frame_words,frame_pixels,lines,hd_frames,fhd_frames,transitions);
      if(mode_ref==0 && !up_sent)begin up_sent=1;->request_fhd;end
      if(mode_ref==1 && !down_sent)begin down_sent=1;->request_hd;end
      if(mode_ref==0 && transitions==2 && fhd_frames>=1)begin
       $display("PASS E dual-mode pins:720p60 to1080p30 to720p60, all complete frame RGB/sync/order/counts, bounced SW20ms qualifier/frame-boundary commit, common continuous clock%fMHz and serializer, no reset/lock interruption. Ideal PLL+vendor ODDR; physical pending.",1000.0/period);$finish;
      end
     end
    end
    if(words%500000==0)$display("OBS E pin words%0d mode%0d",words,mode_ref);
   end
  end
 end
 initial begin #10000;reset_n=1;end
 initial begin #180000000;$fatal(1,"E pin watchdog");end
endmodule
