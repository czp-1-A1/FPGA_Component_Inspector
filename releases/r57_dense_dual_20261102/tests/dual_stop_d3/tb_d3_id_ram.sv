`timescale 1ns/1ps
module tb_d3_id_ram;
 reg clk=0;always #5 clk=~clk;
 reg [1:0] wr=0;
 reg [8:0] addr[0:1],count[0:1],total[0:1];
 wire [8:0] got[0:1],refq[0:1];
 reg [8:0] model[0:1][0:299],expect_q[0:1],held[0:1];
 integer checks=0,seed=32'h37fb915c;
 genvar lane;generate for(lane=0;lane<2;lane++)begin : lanes
  candidate_id_ram dut(.clk(clk),.wr(wr[lane]),.empty_address(addr[lane]),.empty_total(count[lane]),.total(total[lane]),.empty_id(got[lane]));
  reference_id_ram refdut(.clk(clk),.wr(wr[lane]),.empty_address(addr[lane]),.empty_total(count[lane]),.total(total[lane]),.empty_id(refq[lane]));
 end endgenerate
 always @(posedge clk)begin
  for(integer l=0;l<2;l++)begin
   expect_q[l]=addr[l]<count[l] ? model[l][addr[l]] : 9'd0;
   if(wr[l])model[l][count[l]]=total[l]+9'd1;
  end
  #2;
  for(integer l=0;l<2;l++)begin
   if(got[l]!==refq[l] || got[l]!==expect_q[l])$fatal(1,"ID RAM lane%0d addr%0d count%0d got%0d ref%0d expected%0d",l,addr[l],count[l],got[l],refq[l],expect_q[l]);
   checks++;
  end
 end
 initial begin
  for(integer l=0;l<2;l++)begin addr[l]=511;count[l]=0;total[l]=0;end
  repeat(3)@(negedge clk);
  for(integer i=0;i<300;i++)begin
   wr=3;count[0]=i;count[1]=i;addr[0]=i;addr[1]=i;
   total[0]=i;total[1]=299-i;@(negedge clk);
  end
  wr=0;count[0]=300;count[1]=300;
  for(integer i=0;i<512;i++)begin addr[0]=i;addr[1]=511-i;@(negedge clk);end
  for(integer i=0;i<5000;i++)begin
   for(integer l=0;l<2;l++)begin
    held[l]=got[l];addr[l]=$urandom(seed)%512;count[l]=$urandom(seed)%301;
    total[l]=$urandom(seed)%511;wr[l]=count[l]<300 && ($urandom(seed)%3==0);
   end
   #2;
   for(integer l=0;l<2;l++)if(got[l]!==held[l])$fatal(1,"ID RAM output changed between edges during clear/address update");
   @(negedge clk);
  end
  wr=0;count[0]=0;count[1]=0;repeat(2)@(negedge clk);
  $display("PASS ID RAM exact original read latency: %0d lane-clock comparisons; all 300 entries including IDs256/300, addresses0..511, same-slot write masking, independent lanes, random writes/reads, count clear/new-run and between-edge output hold",checks);$finish;
 end
 initial begin #100000;$fatal(1,"ID RAM watchdog");end
endmodule
