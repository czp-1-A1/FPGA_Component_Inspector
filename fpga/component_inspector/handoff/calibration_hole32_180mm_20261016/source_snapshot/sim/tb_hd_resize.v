`timescale 1ns/1ps
module tb_hd_resize;
 reg clk=0,rst_n=0,sof=0,valid=0,last=0;reg [95:0] rgb=0;
 always #5 clk=~clk;
 wire os,ov,ol,bad,psof,pv;wire [95:0] scaled;wire [127:0] packet_word;
 rgb_resize_2_3 resize(clk,rst_n,sof,valid,last,rgb,os,ov,ol,scaled,bad);
 rgb96_packetizer packer(clk,rst_n,os,ov,scaled,psof,pv,packet_word);
 integer frame=0,pixels=0,words=0,rows=0,x,y,g,j,k;
 function automatic [23:0] source(input integer f,x,y);
  source={8'((x*13+y*7+f*11)%256),8'((x+y*3+f*9)%256),8'(x^y^f)};
 endfunction
 function automatic [23:0] h_reference(input integer f,x,y);
  integer sx,c,a,b;reg [23:0] p,q;
  begin sx=(x/2)*3+x%2;p=source(f,sx,y);q=source(f,sx+1,y);
   for(c=0;c<3;c=c+1)begin a=p[23-c*8-:8];b=q[23-c*8-:8];
    h_reference[23-c*8-:8]=(x%2==0?(3*a+b):(a+3*b))/4;end
  end
 endfunction
 function automatic [23:0] reference(input integer f,x,y);
  integer sy,c,a,b;reg [23:0] p,q;
  begin sy=(y/2)*3+y%2;p=h_reference(f,x,sy);q=h_reference(f,x,sy+1);
   for(c=0;c<3;c=c+1)begin a=p[23-c*8-:8];b=q[23-c*8-:8];
    reference[23-c*8-:8]=(y%2==0?(3*a+b):(a+3*b))/4;end
  end
 endfunction
 function automatic [127:0] reference_word(input integer f,w);
  integer b,pixel_index;reg [23:0] p;
  begin for(b=0;b<16;b=b+1)begin pixel_index=(w*16+b)/3;
   p=reference(f,pixel_index%1280,pixel_index/1280);
   reference_word[127-b*8-:8]=p[23-((w*16+b)%3)*8-:8];end
  end
 endfunction
 always @(posedge clk)begin
  #1;
  if(ov)begin
   for(integer lane=0;lane<4;lane=lane+1)
    if(scaled[95-lane*24-:24]!==reference(frame,(pixels+lane)%1280,(pixels+lane)/1280))
     $fatal(1,"J resize pixel%0d got%h expected%h",pixels+lane,scaled[95-lane*24-:24],reference(frame,(pixels+lane)%1280,(pixels+lane)/1280));
   pixels=pixels+4;
   if(ol!=(pixels%1280==0))$fatal(1,"J resize EOL pixel%0d",pixels);
   if(ol)rows=rows+1;
  end
  if(pv)begin
   if(packet_word!==reference_word(frame,words))$fatal(1,"J gap-safe RGB packet word%0d",words);
   words=words+1;
  end
 end
 task start;begin
  @(negedge clk);sof=1;valid=0;last=0;
  @(negedge clk);sof=0;pixels=0;words=0;rows=0;
  repeat(20)@(negedge clk);
 end endtask
 initial begin
  repeat(4)@(negedge clk);rst_n=1;
  for(frame=0;frame<3;frame=frame+1)begin
   start;
   for(y=0;y<1080;y=y+1)begin
    for(g=0;g<480;g=g+1)begin
     valid=1;last=g==479;
     for(j=0;j<4;j=j+1)rgb[95-j*24-:24]=source(frame,g*4+j,y);
     @(negedge clk);
     if(frame!=0 && (g*7+y*3)%11==0)begin valid=0;last=0;repeat(3)@(negedge clk);end
    end
    valid=0;last=0;repeat(7)@(negedge clk);
   end
   repeat(20)@(negedge clk);
   if(bad || pixels!=921600 || words!=172800 || rows!=720)
    $fatal(1,"J full resize accounting bad%0d pixels%0d words%0d rows%0d",bad,pixels,words,rows);
   $display("PASS J resize frame%0d: all921600 bilinear pixels/720 EOL/172800 packed words, input gaps preserved",frame);
  end
  // A short source row must become bad and a fresh FS must recover the epoch.
  start;valid=1;last=1;@(negedge clk);valid=0;last=0;
  repeat(8)@(negedge clk);if(!bad)$fatal(1,"J short line accepted");
  start;repeat(4)@(negedge clk);if(bad || ov || pv)$fatal(1,"J reset/FS recovery failed");
  rst_n=0;repeat(4)@(negedge clk);if(ov || pv || bad)$fatal(1,"J reset flush failed");
  $display("PASS hd resize: independent scalar reference, full FHD source, continuous/gapped input, short-line rejection and fresh-FS/reset recovery");$finish;
 end
 initial begin #100000000;$fatal(1,"J resize watchdog");end
endmodule
