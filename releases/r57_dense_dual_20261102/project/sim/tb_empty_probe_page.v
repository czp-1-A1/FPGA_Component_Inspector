`timescale 1ns/1ps
module tb_empty_probe_page;
 reg clk=0,rst_n=0,vs=0,hs=0,de=0,eligible=1;
 always #5 clk=~clk;
 reg [255:0] live=0,packet=0;wire ov,oh,od,logo;wire [23:0] rgb;
 classified_count_renderer dut(.clk(clk),.rst_n(rst_n),.vs(vs),.hs(hs),.de(de),.rgb(24'h556677),
  .live_record(live),.frame_record(packet),.objects(304'd0),.eligible(eligible),
  .exposure(16'd1092),.gain(16'd40),.fps(16'd27),.out_vs(ov),.out_hs(oh),.out_de(od),.original_logo(logo),.out_rgb(rgb));
 reg [7:0] font[0:2047];initial $readmemh("osd_assets/osd_ascii_rom.hex",font);
 integer px=0,py=0,checks=0,frame=0,character_index;reg [63:0] expected;
 reg [7:0] code,font_row;reg [23:0] want,e0,e1,e2;reg [2:0] valid_pipe=0;
 always @*begin
  character_index=(px-424)/8;code=character_index>=0 && character_index<8 ? expected[63-character_index*8-:8] : 32;
  font_row=font[code*16+(py%16)];
  want=font_row[7-((px-424)%8)] ? 24'h70ffdd : 24'h142336;
 end
 always @(posedge clk)begin
  valid_pipe<={valid_pipe[1:0],(rst_n && de && px>=424 && px<488 && py>=704 && py<720)};
  e0<=want;e1<=e0;e2<=e1;
 end
 always @(negedge clk)if(valid_pipe[2])begin
  if(!od || rgb!==e2)$fatal(1,"diagnostic font/source snapshot pixel frame%0d got%06h want%06h",frame,rgb,e2);
  checks++;
 end
 task ticks(input integer n);repeat(n)@(negedge clk);endtask
 task raster(input integer n,input [63:0] word_text);
  begin
   frame=n;expected=word_text;de=0;vs=1;ticks(10);vs=0;ticks(2000);
   for(py=0;py<720;py++)begin
    for(px=0;px<1280;px++)begin
     if(py==400 && px==0)begin
      if(n==1)packet[255:224]=32'h8c61cfff;
      if(n==2)eligible=0;
     end
     de=1;ticks(1);
    end de=0;ticks(370);
   end ticks(5);
  end
 endtask
 initial begin
  ticks(5);rst_n=1;ticks(5);live[50:48]=2;packet[50:48]=2;packet[255:224]=32'h8a51cfc0;
  raster(1,"8A51CFC0");raster(2,"8C61CFFF");raster(3,"--------");
  eligible=1;packet[255:224]=0;raster(4,"--------");
  if(checks!=4096)$fatal(1,"probe font pixel coverage %0d",checks);
  $display("PASS empty probe page: 4 full rasters4096 independent font pixels,correct hex position,same-display-frame snapshot,midframe eligible held,invalid dashes");$finish;
 end
 initial begin #100000000;$fatal(1,"probe page watchdog");end
endmodule
