// Frozen phase/load-cadence probe of D, using the actual vendor PLL model.
// Independent receiver of 16 complete early active rows; not a full frame,
// AVI/VS or analog-quality test. No DUT raster/mode/packet-ROM access.
`timescale 1ns/1fs
module tb_native_pll_pins;
 reg refclk=0,reset_n=0;always #10 refclk=~refclk;
 wire bp,gp,rp,cp;
 avi_fhd30_top dut(refclk,reset_n,bp,gp,rp,cp);
 `include "hdmi_decode.vh"
 reg [9:0] wb=0,wg=0,wr=0,wc=0;
 reg [2:0] cb,cg,cr;
 reg acquired=0,hs_old=0,row_active=0;
 integer bits=0,words=0,rx_x=0,hs_begin=-1,rows=0,row_pixels=0,pixels=0;
 integer serial_edges=0,last_pixel_serial=-1,clock_samples=0;
 integer db=0,dg=0,dr=0;
 reg [23:0] rgb;
 realtime clock_last=-1,clock_period,first_release=-1;
 integer pin_clock_observations=0;
 always @(dut.rst) $display("OBS native reset=%b lock=%b ref_lock=%b out_lock=%b at%f ns",dut.rst,dut.locked,dut.u_pll.ref_locked,dut.u_pll.out_locked,$realtime);
 // A PLL loss asserts D's reset. A clock period cannot span this disabled
 // interval; abandon partial rows and acquire16 consecutive fresh rows.
 // The same13.45..13.49ns period/5:1/all-pixel assertions remain unchanged.
 always @(posedge dut.rst)begin
  clock_last=-1;last_pixel_serial=-1;first_release=-1;clock_samples=0;
  pin_clock_observations=0;acquired=0;hs_old=0;hs_begin=-1;rx_x=0;
  row_active=0;rows=0;row_pixels=0;pixels=0;db=0;dg=0;dr=0;
 end
 function automatic [7:0] inverse_tmds(input [9:0] w);
  reg [7:0] q;integer i;
  begin q=w[7:0]^{8{w[9]}};inverse_tmds[0]=q[0];
   for(i=1;i<8;i=i+1)inverse_tmds[i]=q[i]^q[i-1]^!w[8];
  end
 endfunction
 function automatic [23:0] pixel_reference(input integer coord);
  begin case(coord/240)
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
 always @(posedge dut.serial)serial_edges=serial_edges+1;
 always @(posedge dut.pixel)begin
  #0.1;
  if(dut.rst)last_pixel_serial=-1;
  else begin
   if(first_release<0)begin first_release=$realtime;$display("OBS native pixel reset released %f ns",first_release);end
   if(last_pixel_serial>=0 && serial_edges-last_pixel_serial!=5)$fatal(1,"Native serial load cadence %0d",serial_edges-last_pixel_serial);
   last_pixel_serial=serial_edges;
  end
 end
 always @(posedge cp)if(reset_n && !dut.rst)begin
  if(pin_clock_observations<5)begin
   $display("OBS TMDS clock rise at%f ns previous%f ns",$realtime,clock_last);
   pin_clock_observations=pin_clock_observations+1;
  end
  if(clock_last>=0)begin clock_period=$realtime-clock_last;
   if(clock_period<13.45 || clock_period>13.49)$fatal(1,"Native TMDS clock period %f",clock_period);
   clock_samples=clock_samples+1;
  end
  clock_last=$realtime;
 end
 always @(posedge dut.serial or negedge dut.serial)begin
  #0.05;
  if(dut.rst)begin bits=0;wc=0;end
  else begin
   wb={bp,wb[9:1]};wg={gp,wg[9:1]};wr={rp,wr[9:1]};wc={cp,wc[9:1]};bits=bits+1;
   if(bits>=10 && wc==10'b1111100000)begin
    words=words+1;cb=hdmi_control(wb);cg=hdmi_control(wg);cr=hdmi_control(wr);
    if(acquired)begin rx_x=(rx_x==2199)?0:rx_x+1;if(rx_x==0)row_active=1;end
    if(cb[2] && cg[2] && cr[2])begin
     if(cb[0] && !hs_old)begin
      if(acquired && rx_x!=2008)$fatal(1,"Native HS rise x%0d",rx_x);
      if(hs_begin>=0 && words-hs_begin!=2200)$fatal(1,"Native HS period");
      rx_x=2008;acquired=1;hs_begin=words;
     end
     if(!cb[0] && hs_old && acquired && rx_x!=2052)$fatal(1,"Native HS width");
     if(cb[1])$fatal(1,"Unexpected VS during early-row probe");
     if(acquired && cb[0]!=(rx_x>=2008 && rx_x<2052))$fatal(1,"Native HS interval");
     hs_old=cb[0];
    end
    if(acquired)begin
     if(rx_x<1920)begin
      if(cb[2] || cg[2] || cr[2])$fatal(1,"Native control inside video");
      rgb={inverse_tmds(wr),inverse_tmds(wg),inverse_tmds(wb)};
      if(rgb!==pixel_reference(rx_x))$fatal(1,"Native RGB mismatch row%0d x%0d got%h",rows,rx_x,rgb);
      db=db+disparity(wb);dg=dg+disparity(wg);dr=dr+disparity(wr);
      if(db>8 || db< -8 || dg>8 || dg< -8 || dr>8 || dr< -8)$fatal(1,"Native video disparity");
      if(row_active)begin row_pixels=row_pixels+1;pixels=pixels+1;end
     end else begin
      db=0;dg=0;dr=0;
      if(rx_x<2198)begin
       if(!cb[2] || !cg[2] || !cr[2] || cr[1:0]!=0 || cg[1:0]!=((rx_x>=2190)?1:0))$fatal(1,"Native control/video preamble");
      end else if(wb!==10'b1011001100 || wg!==10'b0100110011 || wr!==10'b1011001100)$fatal(1,"Native video guard");
     end
     if(row_active && rx_x==2199)begin
      if(row_pixels!=1920)$fatal(1,"Native complete row pixels%0d",row_pixels);
      rows=rows+1;row_pixels=0;
      $display("OBS native PLL pin rows%0d pixels%0d",rows,pixels);
      if(rows==16)begin
       if(pixels!=30720 || clock_samples<35200)$fatal(1,"Native probe coverage");
       $display("PASS native PLL pins:16 complete active rows/30720 RGB pixels, H2200 positive44, HDMI video preamble/guards,5:1 cadence, TMDSclock%fMHz. Vendor PLL/ODDR; full frame/AVI/VS/physical quality untested.",1000.0/clock_period);$finish;
      end
     end
    end
   end
  end
 end
 initial begin #10000;reset_n=1;end
 initial begin #2000000;$fatal(1,"Native PLL pins watchdog");end
endmodule
