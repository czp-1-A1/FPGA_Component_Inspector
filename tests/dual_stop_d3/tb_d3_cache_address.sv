`timescale 1ns/1ps
module tb_d3_cache_address;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,cancel=0,we=0;reg [10:0] x=0;reg [9:0] y=0;reg [31:0] data=0;
 local_edge_surface_check #(.DUAL_STOP(1)) dut(
  .clk(clk),.rst_n(rst_n),.cancel(cancel),.write_enable(we),.write_x(x),.write_y(y),.write_data(data),
  .measure(1'b0),.measure_empty(1'b0),.measure_station(1'b0),.xmin(10'd0),.xmax(10'd0),.ymin(10'd0),.ymax(10'd0),.trace_enable(1'b0));
 integer commits=0,mem_checks=0,xx,yy,j;
 reg [19:0] expected[0:20439];reg [20439:0] visited=0;
 reg v0=0,v1=0;integer a0=0,a1=0;reg [19:0] d0=0,d1=0;
 function integer address(input integer xx,yy);
  begin
   address=-1;
   if(xx>=384 && xx<896 && yy>=224 && yy<616)address=((yy-224)/2)*64+(xx-384)/8;
   else if(xx>=48 && xx<384 && yy>=228 && yy<412)address=12544+((yy-228)/2)*42+(xx-48)/8;
   else if(xx>=48 && xx<384 && yy>=420 && yy<612)address=12544+3864+((yy-420)/2)*42+(xx-48)/8;
  end
 endfunction
 always @(posedge clk)begin
  if(!rst_n || cancel)begin v0=0;v1=0;end
  else begin
   if(dut.committed_capture!==v1)$fatal(1,"cache enable latency mismatch");
   if(v1)begin
    if(dut.exact_cache_banks.committed_address!==a1[14:0] || dut.exact_cache_banks.committed_data!==d1)
     $fatal(1,"address/data mismatch address=%0d expected=%0d",dut.exact_cache_banks.committed_address,a1);
    expected[a1]=d1;visited[a1]=1;commits++;
   end
   v1=v0;a1=a0;d1=d0;
   v0=we && address(x,y)>=0;a0=address(x,y);d0={data[31:27],data[23:19],data[15:11],data[7:3]};
  end
 end
 reg check_memory=0;
 genvar b;generate for(b=0;b<20;b++)begin : memory_check
  integer k,idx;
  always @(posedge check_memory)for(k=0;k<1024;k++)begin
   idx=b*1024+k;
   if(idx<20440 && visited[idx])begin
    if(dut.exact_cache_banks.banks[b].memory[k]!==expected[idx])$fatal(1,"bank%0d word%0d data mismatch",b,k);
    mem_checks++;
   end
  end
 end endgenerate
 task tick;@(negedge clk);endtask
 initial begin
  repeat(5)tick();rst_n=1;repeat(3)tick();
  // Full raster including boundaries, the inter-row gap, and idle cycles.
  for(yy=1;yy<720;yy+=2)for(xx=4;xx<1280;xx+=8)begin
   we=1;x=xx;y=yy;data=(yy*1280+xx)*32'h1f234567;tick();
   if((xx/8)%17==0)begin we=0;tick();end
  end
  we=0;repeat(5)tick();
  if(commits!=20440 || dut.captured!=20440 || !(&visited))$fatal(1,"incomplete cache commits%0d captured%0d",commits,dut.captured);
  check_memory=1;tick();check_memory=0;if(mem_checks!=20440)$fatal(1,"bank coverage");
  // Flush each stage, then resume: stale pending writes may not commit.
  we=1;x=68;y=249;data=32'hab123456;tick();cancel=1;we=0;tick();cancel=0;repeat(4)tick();
  if(dut.captured!=0 || commits!=20440)$fatal(1,"first-stage cancel leaked a write");
  we=1;tick();we=0;tick();cancel=1;tick();cancel=0;repeat(4)tick();
  if(dut.captured!=0 || commits!=20440)$fatal(1,"second-stage cancel leaked a write");
  we=1;tick();we=0;repeat(4)tick();if(dut.captured!=1 || commits!=20441)$fatal(1,"restart failed");
  $display("PASS D3_CACHE_ADDRESS: all 20440 words/20 banks, independent address+data oracle, every boundary/gap, idle cycles, two-stage cancel/restart");$finish;
 end
endmodule
