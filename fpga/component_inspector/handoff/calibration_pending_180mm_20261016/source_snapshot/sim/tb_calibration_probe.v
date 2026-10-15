`timescale 1ns/1ps
module tb_calibration_probe;
reg clk=0,rst=0,fs=0,cancel=0,av=0,commit=0;reg [10:0] x=0;reg [9:0] y=0;
reg [95:0] rgb=0;reg [1:0] mode=0;wire [127:0] record;
always #5 clk=~clk;
calibration_probes dut(clk,rst,fs,cancel,av,commit,x,y,rgb,mode,record);
reg [127:0] reference[0:8];integer pattern=0,checked=0;
initial $readmemh("calibration_probe_reference.hex",reference);
function [23:0] pixel(input integer xx,yy);
 integer dx,dy,z,r,g,b,v;begin
  z=yy>=484;dx=xx-608;dy=yy-(z ? 484 : 288);v=20+(xx+yy)%5;r=v;g=v;b=v;
  case(pattern)
   0:begin
    if(!z && dx>=16 && dx<48 && dy>=18 && dy<46)begin r=150+xx%13;g=110+yy%11;b=70+(xx+yy)%7;end
    if(z && (dx-32)*(dx-32)+(dy-32)*(dy-32)<=144)begin v=90+(xx+yy)%21;r=v;g=v;b=v;end
   end
   1:begin r=120;g=120;b=120;end
   2:begin v=(dx+dy)%2 ? 255 : 0;r=v;g=v;b=v;end
   3:begin r=0;g=0;b=0;end
   4:begin v=dx>=62 && dy>=62 ? 255 : 0;r=v;g=v;b=v;end
  endcase
  pixel={r[7:0],g[7:0],b[7:0]};
 end endfunction
task tick;begin @(negedge clk);end endtask
task send(input integer test_pattern,test_mode,missing);
 begin
  pattern=test_pattern;mode=test_mode;fs=1;tick;fs=0;
  if(record!==0)$fatal(1,"new frame retained calibration record");
  for(integer z=0;z<2;z++)for(integer yy=0;yy<64;yy++)for(integer xx=0;xx<64;xx+=4)begin
   x=608+xx;y=(z ? 484 : 288)+yy;
   for(integer l=0;l<4;l++)rgb[95-l*24-:24]=pixel(x+l,y);
   av=!(missing && z==0 && yy==0 && xx==0);tick;
   if(xx%12==0)begin av=0;repeat(2)tick;end
  end
  av=0;repeat(4)tick;commit=1;tick;commit=0;repeat(3)tick;
 end
endtask
initial begin
 repeat(4)tick;rst=1;repeat(4)tick;
 for(integer c=0;c<9;c++)begin
  case(c)
   0:send(0,0,0);1:send(0,1,0);2:send(0,2,0);3:send(0,3,0);
   4:send(1,1,0);5:send(2,2,0);6:send(2,3,0);7:send(3,0,0);8:send(4,0,0);
  endcase
  if(record!==reference[c])$fatal(1,"case%0d got%h expected%h",c,record,reference[c]);checked++;
 end
 send(0,0,1);if(record[63] || !record[127])$fatal(1,"incomplete upper probe accepted or lower invalidated");
 cancel=1;tick;cancel=0;if(record!==0)$fatal(1,"bad frame retained data");
 fs=1;tick;fs=0;repeat(10)tick;if(record!==0)$fatal(1,"no new frame must remain waiting");
 send(0,0,0);if(record!==reference[0])$fatal(1,"recovery mismatch");
 rst=0;tick;if(record!==0)$fatal(1,"reset retained calibration");
 $display("PASS calibration probe: %0d independent references; four thresholds, exact RGB gray, 2x2 averaging, saturation, empty mask, clip, x>511, bubbles, missing pixels, invalidate, reset/recovery",checked);$finish;
end
initial begin #10000000;$fatal(1,"probe timeout");end
endmodule
