// Frozen receiver reference: LSB-first pin deserialization, inverse TMDS,
// and independent fixed CTA34 coordinate expectations. No DUT x/y access.
`timescale 1ns/1fs
module tb_positive_pins;
`ifdef HDMI720P
 localparam HA=1280,HT=1650,HS0=1390,HS1=1430,VA=720,VT=750,VS0=725,VS1=730;
 localparam FRAME_WORDS=1237500,FRAME_PIXELS=921600,BAR=160;
`else
 localparam HA=1920,HT=2200,HS0=2008,HS1=2052,VA=1080,VT=1125,VS0=1084,VS1=1089;
 localparam FRAME_WORDS=2475000,FRAME_PIXELS=2073600,BAR=240;
`endif
 reg refclk=0,reset_n=0;
 always #10 refclk=~refclk;
 wire bp,gp,rp,cp;
`ifdef HDMI720P
 positive_top #(.MODE_HD60(1)) dut(refclk,reset_n,bp,gp,rp,cp);
`else
 positive_top #(.MODE_HD60(0)) dut(refclk,reset_n,bp,gp,rp,cp);
`endif
 `include "hdmi_decode.vh"
 reg [9:0] wb=0,wg=0,wr=0,wc=0;
 integer bits=0,words=0,frame_words=0,frame_pixels=0,frames=0;
 integer rx_x=0,rx_y=0,h_edges=0,hs_begin=-1,vs_begin=-1;
 integer line_pixels=0,lines=0,dispb=0,dispg=0,dispr=0;
 reg hs_old=0,vs_old=0,h_acquired=0,v_acquired=0,frame_active=0;
 reg [2:0] cb,cg,cr;
 reg [23:0] rgb,expected;
 reg [1:0] sync_bits;
 realtime last_clock=-1,period,nominal;
 function automatic [7:0] inverse_tmds(input [9:0] w);
  reg [7:0] q;
  integer j;
  begin
   q=w[7:0]^{8{w[9]}};
   inverse_tmds[0]=q[0];
   for(j=1;j<8;j=j+1)inverse_tmds[j]=q[j]^q[j-1]^!w[8];
  end
 endfunction
 function automatic integer physical_disparity(input [9:0] w);
  integer j,n;
  begin n=0;for(j=0;j<10;j=j+1)n=n+w[j];physical_disparity=2*n-10;end
 endfunction
 function automatic [23:0] pixel_reference(input integer coord);
  begin
   case(coord/BAR)
    0:pixel_reference=24'hffffff;1:pixel_reference=24'hffff00;
    2:pixel_reference=24'h00ffff;3:pixel_reference=24'h00ff00;
    4:pixel_reference=24'hff00ff;5:pixel_reference=24'hff0000;
    6:pixel_reference=24'h0000ff;default:pixel_reference=24'h000000;
   endcase
  end
 endfunction
 initial begin
  nominal=1000.0/74.25;
  #10000;reset_n=1;
 end
 always @(posedge cp)if(reset_n && !dut.rst)begin
  if(last_clock>=0)begin
   period=$realtime-last_clock;
   if(period<nominal*0.999 || period>nominal*1.001)
    $fatal(1,"TMDS clock pin period %f expected %f",period,nominal);
  end
  last_clock=$realtime;
 end
 always @(posedge dut.serial or negedge dut.serial) begin
  #0.05;
  if(dut.rst)begin bits=0;wc=0;end
  else begin
   wb={bp,wb[9:1]};wg={gp,wg[9:1]};wr={rp,wr[9:1]};wc={cp,wc[9:1]};bits=bits+1;
   if(bits>=10 && wc==10'b1111100000)begin
    words=words+1;
    cb=hdmi_control(wb);cg=hdmi_control(wg);cr=hdmi_control(wr);
    if(h_acquired)rx_x=(rx_x==HT-1)?0:rx_x+1;
    if(v_acquired && h_acquired && rx_x==0)rx_y=(rx_y==VT-1)?0:rx_y+1;
    if(cb[2])begin
     if(!cg[2] || !cr[2] || cg[1:0]!=0 || cr[1:0]!=0)$fatal(1,"Invalid DVI control channels");
     sync_bits=cb[1:0];
     if(sync_bits[0] && !hs_old)begin
      if(h_acquired && rx_x!=HS0)$fatal(1,"HS rising at x=%0d",rx_x);
      rx_x=HS0;h_acquired=1;
      if(hs_begin>=0 && words-hs_begin!=HT)$fatal(1,"Pin H period %0d",words-hs_begin);
      hs_begin=words;h_edges=h_edges+1;
     end
     if(!sync_bits[0] && hs_old && h_acquired && rx_x!=HS1)$fatal(1,"Positive HS width/end x=%0d",rx_x);
     if(sync_bits[1] && !vs_old)begin
      if(v_acquired && rx_y!=VS0)$fatal(1,"VS rising y=%0d",rx_y);
      rx_y=VS0;v_acquired=1;
      if(vs_begin>=0 && words-vs_begin!=FRAME_WORDS)$fatal(1,"Pin V period %0d",words-vs_begin);
      vs_begin=words;
      if(frame_active)begin
       if(frame_words!=FRAME_WORDS || frame_pixels!=FRAME_PIXELS || lines!=VA)
        $fatal(1,"Full pin frame words=%0d pixels=%0d lines=%0d",frame_words,frame_pixels,lines);
       frames=frames+1;
       $display("PASS positive pin frame: words%0d pixels%0d lines%0d, RGB all pixels, H%0d positive%0d V%0d positive5, clock=%f MHz, frames=%0d",frame_words,frame_pixels,lines,HT,HS1-HS0,VT,1000.0/period,frames);
       $finish;
      end
      frame_active=1;frame_words=0;frame_pixels=0;lines=0;
     end
     if(!sync_bits[1] && vs_old && v_acquired && rx_y!=VS1)$fatal(1,"Positive VS end y=%0d",rx_y);
     if(h_acquired && v_acquired)begin
      if((rx_x>=HS0 && rx_x<HS1)!==sync_bits[0] || (rx_y>=VS0 && rx_y<VS1)!==sync_bits[1])
       $fatal(1,"Pin sync at x%0d y%0d value%b",rx_x,rx_y,sync_bits);
      if(rx_x<HA && rx_y<VA)$fatal(1,"Control inside active rectangle");
     end
     hs_old=sync_bits[0];vs_old=sync_bits[1];
     dispb=0;dispg=0;dispr=0;
    end else if(h_acquired && v_acquired)begin
     if(cg[2] || cr[2] || rx_x>=HA || rx_y>=VA)$fatal(1,"Invalid video at x%0d y%0d",rx_x,rx_y);
     rgb={inverse_tmds(wr),inverse_tmds(wg),inverse_tmds(wb)};
     expected=pixel_reference(rx_x);
     if(rgb!==expected)$fatal(1,"Pin RGB mismatch x%0d y%0d got%h expected%h",rx_x,rx_y,rgb,expected);
     dispb=dispb+physical_disparity(wb);dispg=dispg+physical_disparity(wg);dispr=dispr+physical_disparity(wr);
     if(dispb>8 || dispb< -8 || dispg>8 || dispg< -8 || dispr>8 || dispr< -8)$fatal(1,"TMDS disparity out of bounds");
     if(frame_active)begin frame_pixels=frame_pixels+1;line_pixels=line_pixels+1;end
    end
    if(frame_active)begin
     frame_words=frame_words+1;
     if(rx_x==HA && rx_y<VA)begin
      if(line_pixels!=HA)$fatal(1,"Pin line pixels%0d",line_pixels);
      line_pixels=0;lines=lines+1;
     end
    end
    if(words%500000==0)$display("OBS positive pins words%0d pixels%0d",words,frame_pixels);
   end
  end
 end
 initial begin #100000000;$fatal(1,"Pin test watchdog");end
endmodule
