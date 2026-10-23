`timescale 1ns/1ps
module line_ram_equivalence_case #(parameter WIDTH=1920, CASE_ID=0)(output reg done=0);
 localparam WORDS=WIDTH/4;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,valid=0,sof=0,last=0;
 reg [95:0] pixels=0;
 wire av0,av1,as0,as1,lv0,lv1,zv0,zv1,zs0,zs1,zl0,zl1;
 wire [95:0] ad0,ad1;wire [32:0] ld0,ld1;wire [31:0] zd0,zd1;
 integer cycle=0,checks=0,acount=0,lcount=0,zcount=0;
 signal_delay #(.IMG_WIDTH(WIDTH),.IMG_HEIGHT(8)) a1(clk,rst_n,sof,valid,pixels,av1,ad1,as1);
 resource_R12_signal_delay #(.IMG_WIDTH(WIDTH),.IMG_HEIGHT(8)) a0(clk,rst_n,sof,valid,pixels,av0,ad0,as0);
 line_buffer_demosaic #(.IMG_WIDTH(WIDTH),.IMG_HEIGHT(8)) l1(clk,rst_n,sof,valid,{sof,pixels[31:0]},lv1,ld1);
 resource_R12_line_buffer_demosaic #(.IMG_WIDTH(WIDTH),.IMG_HEIGHT(8)) l0(clk,rst_n,sof,valid,{sof,pixels[31:0]},lv0,ld0);
 zhenghe #(.IMG_WIDTH(WIDTH),.IMG_HEIGHT(8),.DATA_WIDTH(32),.data_complete_delay(50)) z1(
  .I_clk(clk),.I_rst_n(rst_n),.I_tlast(last),.I_tuser(sof),.I_tdata(pixels[31:0]),.I_tvalid(valid),
  .O_tlast(zl1),.O_tuser(zs1),.O_tdata(zd1),.O_tvalid(zv1));
 resource_R12_zhenghe #(.IMG_WIDTH(WIDTH),.IMG_HEIGHT(8),.DATA_WIDTH(32),.data_complete_delay(50)) z0(
  .I_clk(clk),.I_rst_n(rst_n),.I_tlast(last),.I_tuser(sof),.I_tdata(pixels[31:0]),.I_tvalid(valid),
  .O_tlast(zl0),.O_tuser(zs0),.O_tdata(zd0),.O_tvalid(zv0));

 always @(posedge clk)begin
  cycle=cycle+1;
  #1;
  if(rst_n)begin
   if({av0,as0,lv0,zv0,zs0,zl0} !== {av1,as1,lv1,zv1,zs1,zl1})
    $fatal(1,"control difference width=%0d cycle=%0d old=%b new=%b",WIDTH,cycle,{av0,as0,lv0,zv0,zs0,zl0},{av1,as1,lv1,zv1,zs1,zl1});
   if(av0)begin
    if(ad0 !== ad1 || (^ad1===1'bx))$fatal(1,"AWB pixel difference/unknown width=%0d cycle=%0d",WIDTH,cycle);
    acount=acount+1;
   end
   if(lv0)begin
    if(ld0 !== ld1 || (^ld1===1'bx))$fatal(1,"RAW pixel difference/unknown width=%0d cycle=%0d",WIDTH,cycle);
    lcount=lcount+1;
   end
   if(zv0)begin
    if(zd0 !== zd1 || (^zd1===1'bx))$fatal(1,"merge pixel difference/unknown width=%0d cycle=%0d",WIDTH,cycle);
    zcount=zcount+1;
   end
   if(a1.addra>=WORDS || a1.addrb>=WORDS || l1.addra>=WORDS || l1.addrb>=WORDS || z1.addra>=WORDS || z1.addrb>=WORDS)
    $fatal(1,"address exceeded true line extent width=%0d cycle=%0d",WIDTH,cycle);
   if(a0.addra!==a1.addra || a0.addrb!==a1.addrb || l0.addra!==l1.addra || l0.addrb!==l1.addrb || z0.addra!==z1.addra || z0.addrb!==z1.addrb)
    $fatal(1,"old/new address sequence differs width=%0d cycle=%0d",WIDTH,cycle);
   checks=checks+1;
  end
 end
 function [95:0] pattern;
  input integer frame,row,word;
  reg [31:0] seed;
  begin
   seed=32'h9e3779b9 ^ (frame*32'h01010101) ^ (row*32'h00010001) ^ word ^ (CASE_ID<<28);
   pattern={seed+32'h794a7c15,seed^32'ha5c3197d,seed};
  end
 endfunction
 task beat;
  input v,s,e;input [95:0] p;
  begin @(negedge clk);valid=v;sof=s;last=e;pixels=p;end
 endtask
 integer f,r,w,g;
 initial begin
  repeat(30+CASE_ID)@(negedge clk);rst_n=1;
  if(a1.RAM_ADDR_BITS!=$clog2(WORDS) || l1.RAM_ADDR_BITS!=$clog2(WORDS) || z1.RAM_ADDR_BITS!=$clog2(WORDS))
   $fatal(1,"capacity is not tied to actual line width");
  if(a0.blk_mem_gen_awb_delay_signal_d.RAM_ADDR_BITS!=11 || l0.blk_mem_gen_demosaic_r0.RAM_ADDR_BITS!=11 || z0.blk_mem_gen_zhenghe_d1.RAM_ADDR_BITS!=11)
   $fatal(1,"immutable reference no longer uses original2048 capacity");
  for(f=0;f<5;f=f+1)begin
   for(r=0;r<8;r=r+1)begin
    for(w=0;w<WORDS;w=w+1)begin
     if(f[0] && w%13==(CASE_ID+3))for(g=0;g<3;g=g+1)beat(0,0,0,96'hfedcba9876543210deadc0de);
     beat(1,r==0 && w==0,w==WORDS-1,pattern(f,r,w));
    end
    if(f==1)repeat((r+CASE_ID)%7)beat(0,0,0,96'd0);
   end
   if(f==1)begin
    // Genuine partial row followed by early new-frame SOF: no RAM reset.
    for(w=0;w<WORDS/2;w=w+1)beat(1,0,0,pattern(50,2,w));
    beat(0,1,0,0);repeat(5)beat(0,0,0,0);
   end else if(f==2)begin
    // Reset after some committed pixels; contents survive but addresses restart.
    for(w=0;w<37;w=w+1)beat(1,0,0,pattern(51,1,w));
    @(negedge clk);rst_n=0;valid=0;sof=0;last=0;
    repeat(5)@(negedge clk);rst_n=1;
   end else repeat(3+CASE_ID)beat(0,0,0,0);
  end
  repeat(2*WORDS+100)beat(0,0,0,0);
  if(acount<8*WORDS || lcount<8*WORDS || zcount<8*WORDS)$fatal(1,"vacuous valid comparison");
  $display("PASS line RAM case width=%0d cycles=%0d checks=%0d AWB=%0d RAW=%0d MERGE=%0d capacity=%0d",WIDTH,cycle,checks,acount,lcount,zcount,1<<a1.RAM_ADDR_BITS);
  done=1;
 end
endmodule

module tb_line_ram_equivalence;
 wire [2:0] done;
 line_ram_equivalence_case #(.WIDTH(1920),.CASE_ID(0)) full_width(done[0]);
 line_ram_equivalence_case #(.WIDTH(1280),.CASE_ID(1)) scaled_width(done[1]);
 line_ram_equivalence_case #(.WIDTH(1024),.CASE_ID(2)) legacy_width(done[2]);
 initial begin
  wait(&done);#20;
  $display("PASS line RAM equivalence:3 widths vendor DP models, 4-state controls/pixels, address wrap, gaps, early SOF and reset");
  $finish;
 end
 initial begin #10000000;$fatal(1,"line RAM equivalence timeout");end
endmodule
