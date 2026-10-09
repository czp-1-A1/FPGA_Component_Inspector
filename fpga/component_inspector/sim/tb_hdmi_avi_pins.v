// Independent receiver reference, frozen before D build/tests. No DUT x/y,
// mode or packet-ROM access. Actual serial pins, inverse TMDS/TERC4/BCH.
// Fixed CTA34 raster and HDMI preamble/guard/AVI semantic expectations.
`timescale 1ns/1fs
module tb_hdmi_avi_pins;
 localparam HT=2200,VT=1125,HA=1920,VA=1080,HS0=2008,HS1=2052;
 localparam FRAME_WORDS=2475000,FRAME_PIXELS=2073600;
 reg refclk=0,reset_n=0;always #10 refclk=~refclk;
 wire bp,gp,rp,cp;
 avi_fhd30_top dut(refclk,reset_n,bp,gp,rp,cp);
 `include "hdmi_decode.vh"
 reg [9:0] wb=0,wg=0,wr=0,wc=0;
 reg [9:0] ib[0:35],ig[0:35],ir[0:35];
 reg [2:0] cb,cg,cr;
 reg [4:0] t0,t1,t2;
 reg [1:0] sync_bits;
 reg sync_valid,hs_old=0,vs_old=0,h_acquired=0,v_acquired=0,frame_active=0;
 integer bits=0,words=0,rx_x=0,rx_y=0,hs_begin=-1,vs_begin=-1;
 integer frame_words=0,frame_pixels=0,frame_avis=0,frames=0,lines=0,line_pixels=0;
 integer pre_di=0,island_words=0,total_avis=0,control_run=0;
 reg island_active=0;
 reg [31:0] header;
 reg [63:0] sub[0:3];
 reg [7:0] pb[0:27],ecc;
 reg [23:0] rgb;
 integer j,k,b,sum,mode_ref,dispb=0,dispg=0,dispr=0;
 realtime last_clock=-1,period;
 function automatic [7:0] inverse_tmds(input [9:0] w);
  reg [7:0] q;integer i;
  begin q=w[7:0]^{8{w[9]}};inverse_tmds[0]=q[0];
   for(i=1;i<8;i=i+1)inverse_tmds[i]=q[i]^q[i-1]^!w[8];
  end
 endfunction
 function automatic integer disparity(input [9:0] w);
  integer i,n;
  begin n=0;for(i=0;i<10;i=i+1)n=n+w[i];disparity=2*n-10;end
 endfunction
 function automatic [23:0] pixel_reference(input integer coord);
  begin case(coord/240)
   0:pixel_reference=24'hffffff;1:pixel_reference=24'hffff00;
   2:pixel_reference=24'h00ffff;3:pixel_reference=24'h00ff00;
   4:pixel_reference=24'hff00ff;5:pixel_reference=24'hff0000;
   6:pixel_reference=24'h0000ff;default:pixel_reference=24'h000000;
  endcase end
 endfunction
 function automatic [7:0] crc_bit(input [7:0] state_value,input bit_value);
  crc_bit=(state_value>>1)^((state_value[0]^bit_value)?8'h83:8'h00);
 endfunction
 task automatic decode_packet;
 begin
  if(island_words!=36)$fatal(1,"DI size %0d, expected2+32+2",island_words);
  for(j=0;j<2;j=j+1)begin
   if(ig[j]!=10'b0100110011 || ir[j]!=10'b0100110011 || ig[35-j]!=10'b0100110011 || ir[35-j]!=10'b0100110011)
    $fatal(1,"DI guard words");
   t0=hdmi_terc4(ib[j]);if(!t0[4] || t0[3:2]!=3)$fatal(1,"DI blue guard");
   t0=hdmi_terc4(ib[35-j]);if(!t0[4] || t0[3:2]!=3)$fatal(1,"DI blue trailing guard");
  end
  header=0;for(j=0;j<4;j=j+1)sub[j]=0;
  for(k=0;k<32;k=k+1)begin
   t0=hdmi_terc4(ib[k+2]);t1=hdmi_terc4(ig[k+2]);t2=hdmi_terc4(ir[k+2]);
   if(!t0[4] || !t1[4] || !t2[4] || t0[3]!=1)$fatal(1,"Invalid DI payload coding");
   header[k]=t0[2];
   for(j=0;j<4;j=j+1)begin sub[j][2*k]=t1[j];sub[j][2*k+1]=t2[j];end
  end
  ecc=0;for(b=0;b<24;b=b+1)ecc=crc_bit(ecc,header[b]);
  if(ecc!==header[31:24] || header[23:0]!==24'h0d0282)$fatal(1,"AVI header/ECC %h",header);
  // Pre-frozen independent polynomial long-division result, rather than
  // accepting only the transmitter's reflected shift/XOR algorithm.
  if(header[31:24]!==8'he4)$fatal(1,"Independent header BCH reference");
  for(j=0;j<4;j=j+1)begin
   ecc=0;for(b=0;b<56;b=b+1)ecc=crc_bit(ecc,sub[j][b]);
   if(ecc!==sub[j][63:56])$fatal(1,"AVI subpacket ECC %0d",j);
   if(sub[j][63:56]!==((j==0)?8'h37:8'h00))$fatal(1,"Independent subpacket BCH reference");
   for(b=0;b<7;b=b+1)pb[7*j+b]=sub[j][8*b+:8];
  end
  sum=header[7:0]+header[15:8]+header[23:16];
  for(b=0;b<=13;b=b+1)sum=sum+pb[b];
  if((sum&255)!=0)$fatal(1,"AVI checksum");
  if(pb[0]!==8'h2d || pb[1]!==0 || pb[2]!==8'h20 || pb[3]!==0 || pb[4]!==34 || pb[5]!==0)
   $fatal(1,"AVI RGB/16:9/default quantization/VIC34/repetition mismatch");
  for(b=6;b<28;b=b+1)if(pb[b]!==0)$fatal(1,"AVI reserved/bar field nonzero");
  total_avis=total_avis+1;if(frame_active)frame_avis=frame_avis+1;
  $display("OBS pin AVI #%0d RGB 16:9 VIC34 defaultQ noRepeat, checksum2D/header and4 subpacket ECC valid",total_avis);
 end
 endtask
 always @(posedge cp)if(reset_n && !dut.rst)begin
  if(last_clock>=0)begin period=$realtime-last_clock;
   if(period<13.45 || period>13.49)$fatal(1,"TMDS clock pin period %f",period);
  end
  last_clock=$realtime;
 end
 always @(posedge dut.serial or negedge dut.serial)begin
  #0.05;
  if(dut.rst)begin bits=0;wc=0;end
  else begin
   wb={bp,wb[9:1]};wg={gp,wg[9:1]};wr={rp,wr[9:1]};wc={cp,wc[9:1]};bits=bits+1;
   if(bits>=10 && wc==10'b1111100000)begin
    words=words+1;cb=hdmi_control(wb);cg=hdmi_control(wg);cr=hdmi_control(wr);
    if(h_acquired)rx_x=(rx_x==HT-1)?0:rx_x+1;
    if(v_acquired && h_acquired && rx_x==0)rx_y=(rx_y==VT-1)?0:rx_y+1;
    sync_valid=0;
    if(cb[2] && cg[2] && cr[2])begin
     sync_bits=cb[1:0];sync_valid=1;
     if(island_active)begin decode_packet();island_active=0;island_words=0;end
     if(cg[1:0]==1 && cr[1:0]==1)pre_di=pre_di+1;else pre_di=0;
     control_run=control_run+1;
    end else begin
     if(control_run>0)begin
      if(v_acquired && control_run<12)$fatal(1,"Control interval shorter than12: %0d",control_run);
      control_run=0;
     end
     if(!island_active && pre_di>0)begin
      if(pre_di!=8)$fatal(1,"DI preamble length %0d",pre_di);
      island_active=1;island_words=0;
     end
     pre_di=0;
     if(island_active)begin
      if(island_words>=36)$fatal(1,"DI too long");
      ib[island_words]=wb;ig[island_words]=wg;ir[island_words]=wr;island_words=island_words+1;
      t0=hdmi_terc4(wb);if(!t0[4])$fatal(1,"DI sync coding");
      sync_bits=t0[1:0];sync_valid=1;
     end
    end
    if(sync_valid)begin
     if(sync_bits[0] && !hs_old)begin
      if(h_acquired && rx_x!=HS0)$fatal(1,"HS rise x%0d",rx_x);
      rx_x=HS0;h_acquired=1;
      if(hs_begin>=0 && words-hs_begin!=HT)$fatal(1,"HS period");hs_begin=words;
     end
     if(!sync_bits[0] && hs_old && h_acquired && rx_x!=HS1)$fatal(1,"HS end/width");
     if(sync_bits[1] && !vs_old)begin
      if(!sync_bits[0] || hs_old || rx_x!=HS0 || (v_acquired && rx_y!=1083))$fatal(1,"VS leading alignment");
      rx_y=1083;v_acquired=1;
      if(vs_begin>=0 && words-vs_begin!=FRAME_WORDS)$fatal(1,"VS period");vs_begin=words;
      if(frame_active)begin
       if(frame_words!=FRAME_WORDS || frame_pixels!=FRAME_PIXELS || lines!=VA || frame_avis!=1)
        $fatal(1,"Frame words%0d pixels%0d lines%0d AVI%0d",frame_words,frame_pixels,lines,frame_avis);
       frames=frames+1;
       if(frames==2)begin
        $display("PASS HDMI AVI serial: frames2 each2475000 words/2073600 RGB pixels/1080 lines; H2200 positive44 V1125 positive5 aligned, preambles/guards/control intervals, one RGB16:9 VIC34 AVI per frame/ECC/checksum2D, clock=%f MHz. Ideal PLL and vendor ODDR only.",1000.0/period);$finish;
       end
      end
      frame_active=1;frame_words=0;frame_pixels=0;lines=0;frame_avis=0;
     end
     if(!sync_bits[1] && vs_old && v_acquired)
      if(rx_y!=1088 || rx_x!=HS0 || !sync_bits[0] || hs_old || words-vs_begin!=5*HT)$fatal(1,"VS trailing alignment/width");
     if(h_acquired && v_acquired)
      if((rx_x>=HS0 && rx_x<HS1)!==sync_bits[0] || (rx_y*HT+rx_x>=1083*HT+HS0 && rx_y*HT+rx_x<1088*HT+HS0)!==sync_bits[1])$fatal(1,"Sync at x%0d y%0d",rx_x,rx_y);
     hs_old=sync_bits[0];vs_old=sync_bits[1];
    end
    if(h_acquired && v_acquired)begin
     // Receiver's fixed wire-format schedule, never taken from DUT mode.
     mode_ref=0;
     if(rx_x<HA && rx_y<VA)mode_ref=6;
     else if((rx_y+1)%VT<VA && rx_x>=2190)mode_ref=(rx_x<2198)?1:2;
     else if(rx_y==1080 && rx_x>=1924 && rx_x<1968)begin
      if(rx_x<1932)mode_ref=3;else if(rx_x<1934 || rx_x>=1966)mode_ref=4;else mode_ref=5;
     end
     case(mode_ref)
      0,1,3:begin
       if(!cb[2] || !cg[2] || !cr[2])$fatal(1,"Missing control/pre at x%0d y%0d",rx_x,rx_y);
       if(cg[1:0]!=((mode_ref==0)?0:1) || cr[1:0]!=((mode_ref==3)?1:0))$fatal(1,"Preamble/control bits");
      end
      2:if(wb!==10'b1011001100 || wg!==10'b0100110011 || wr!==10'b1011001100)$fatal(1,"Video guard words");
      4:begin t0=hdmi_terc4(wb);if(!t0[4] || t0[3:2]!=3 || wg!==10'b0100110011 || wr!==10'b0100110011)$fatal(1,"DI guard at reference coordinate");end
      5:begin t0=hdmi_terc4(wb);t1=hdmi_terc4(wg);t2=hdmi_terc4(wr);if(!island_active || !t0[4] || !t1[4] || !t2[4])$fatal(1,"DI packet absent");end
      6:begin
       if(cb[2] || cg[2] || cr[2])$fatal(1,"Control inside active video");
       rgb={inverse_tmds(wr),inverse_tmds(wg),inverse_tmds(wb)};
       if(rgb!==pixel_reference(rx_x))$fatal(1,"RGB mismatch x%0d y%0d got%h",rx_x,rx_y,rgb);
       dispb=dispb+disparity(wb);dispg=dispg+disparity(wg);dispr=dispr+disparity(wr);
       if(dispb>8 || dispb< -8 || dispg>8 || dispg< -8 || dispr>8 || dispr< -8)$fatal(1,"Video disparity");
       if(frame_active)begin frame_pixels=frame_pixels+1;line_pixels=line_pixels+1;end
      end
     endcase
     if(mode_ref!=6)begin dispb=0;dispg=0;dispr=0;end
    end
    if(frame_active)begin
     frame_words=frame_words+1;
     if(rx_x==HA && rx_y<VA)begin
      if(line_pixels!=HA)$fatal(1,"Line pixel count%0d",line_pixels);line_pixels=0;lines=lines+1;
     end
    end
    if(words%500000==0)$display("OBS HDMI AVI serial words%0d frame%0d pixels%0d",words,frames,frame_pixels);
   end
  end
 end
 initial begin #10000;reset_n=1;end
 initial begin #150000000;$fatal(1,"HDMI AVI pin watchdog");end
endmodule
