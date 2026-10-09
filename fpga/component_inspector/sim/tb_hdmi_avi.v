`timescale 1ns/1ps
// Independent receiver of actual encrypted-core parallel TMDS symbols.
// Mapping/ECC/AVI cross-check: hdl-util/hdmi packet_assembler.sv and
// auxiliary_video_information_info_frame.sv, fetched 2026-10-09.
// This observes metadata; it is not a physical PLL or serial-pin acceptance.
module tb_hdmi_avi;
reg refclk=0,reset_n=0;always #10 refclk=~refclk;
wire bp,gp,rp,cp;
hdmi_tpg_top dut(refclk,reset_n,bp,gp,rp,cp);
`include "hdmi_decode.vh"
reg [9:0] bw[0:599],gw[0:599],rw[0:599];
reg [2:0] cb,cg,cr;
reg [4:0] t0,t1,t2;
reg [31:0] header;
reg [63:0] sub[0:3];
reg [7:0] pb[0:27],ecc;
integer preamble=0,n=0,cycles=0,packets=0,avis=0,islands=0;
integer p,k,j,b,sum,logfd;
reg receiving=0;
function automatic [7:0] crc_bit(input [7:0] state_value,input bit_value);
 crc_bit=(state_value>>1)^((state_value[0]^bit_value)?8'h83:8'h00);
endfunction
task automatic decode_island;
begin
 if(n<36 || (n-4)%32!=0)$fatal(1,"Invalid island length %0d",n);
 for(j=0;j<2;j=j+1)begin
  if(gw[j]!=10'b0100110011 || rw[j]!=10'b0100110011 ||
     gw[n-1-j]!=10'b0100110011 || rw[n-1-j]!=10'b0100110011)
   $fatal(1,"Data island guard length/word mismatch");
 end
 for(p=2;p<n-2;p=p+32)begin
  header=0;for(j=0;j<4;j=j+1)sub[j]=0;
  for(k=0;k<32;k=k+1)begin
   t0=hdmi_terc4(bw[p+k]);t1=hdmi_terc4(gw[p+k]);t2=hdmi_terc4(rw[p+k]);
   if(!t0[4] || !t1[4] || !t2[4])$fatal(1,"Non-TERC4 packet symbol");
   header[k]=t0[2];
   for(j=0;j<4;j=j+1)begin sub[j][2*k]=t1[j];sub[j][2*k+1]=t2[j];end
  end
  ecc=0;for(b=0;b<24;b=b+1)ecc=crc_bit(ecc,header[b]);
  if(ecc!==header[31:24])$fatal(1,"Header ECC header=%h expected=%h",header,ecc);
  for(j=0;j<4;j=j+1)begin
   ecc=0;for(b=0;b<56;b=b+1)ecc=crc_bit(ecc,sub[j][b]);
   if(ecc!==sub[j][63:56])$fatal(1,"Subpacket ECC header=%h sub%0d=%h expected=%h",header,j,sub[j],ecc);
   for(b=0;b<7;b=b+1)pb[7*j+b]=sub[j][8*b+:8];
  end
  packets=packets+1;
  if(header[7:0]!=8'h00 || packets<8)begin
   $fwrite(logfd,"cycle=%0d HB=%02h %02h %02h ECC=%02h PB=",cycles,header[7:0],header[15:8],header[23:16],header[31:24]);
   for(b=0;b<28;b=b+1)$fwrite(logfd,"%02h ",pb[b]);
   $fwrite(logfd,"\n");
  end
  if(header[7:0]==8'h82)begin
   if(header[23:8]!=16'h0d02)$fatal(1,"AVI version/length %h",header);
   sum=header[7:0]+header[15:8]+header[23:16];
   for(b=0;b<=13;b=b+1)sum=sum+pb[b];
   if((sum&255)!=0)$fatal(1,"AVI checksum sum=%0d",sum);
   if(pb[1][6:5]!=0 || pb[4]!=34 || pb[5][3:0]!=0)
    $fatal(1,"AVI target mismatch RGB=%0d VIC=%0d repetition=%0d",pb[1][6:5],pb[4],pb[5][3:0]);
   avis=avis+1;
   $display("OBS AVI #%0d HB=%h checksum=%h PB1=%h PB2=%h PB3=%h VIC=%0d PB5=%h ECC_OK",avis,header[23:0],pb[0],pb[1],pb[2],pb[3],pb[4],pb[5]);
  end
 end
 islands=islands+1;
end
endtask
always @(posedge dut.pixel)begin
 #0.001;
 if(dut.rst || !dut.video_locked)begin preamble=0;receiving=0;n=0;end
 else begin
  cycles=cycles+1;
  cb=hdmi_control(dut.blue);cg=hdmi_control(dut.green);cr=hdmi_control(dut.red);
  if(cb[2] && cg[2] && cr[2])begin
   if(receiving)begin decode_island();receiving=0;n=0;end
   if(cg[1:0]==1 && cr[1:0]==1)preamble=preamble+1;else preamble=0;
  end else begin
   if(!receiving && preamble>=8)begin
    if(dut.green!=10'b0100110011 || dut.red!=10'b0100110011)
     $fatal(1,"Preamble followed by invalid leading guard");
    receiving=1;n=0;
   end
   preamble=0;
   if(receiving)begin
    if(n>=600)$fatal(1,"Island exceeds receiver capacity");
    bw[n]=dut.blue;gw[n]=dut.green;rw[n]=dut.red;n=n+1;
   end
  end
  if(avis>=2 && packets>=1000)begin
   $display("PASS AVI actual encrypted core: %0d islands, %0d packets ECC-valid, %0d AVI with RGB/VIC34/no repetition/checksum valid. Parallel symbols and ideal clock only.",islands,packets,avis);
   $fclose(logfd);$finish;
  end
 end
end
initial begin logfd=$fopen("avi_packets.txt","w");#10000;reset_n=1;end
initial begin #120000000;$fatal(1,"AVI watchdog: cycles=%0d packets=%0d avis=%0d",cycles,packets,avis);end
endmodule
