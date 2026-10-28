`timescale 1ns/1ps
module tb_velocity_bootstrap;
reg clk=0;always #5 clk=~clk;
reg rst_n=0,start_run=0,sample_new=0;reg [31:0] frame_id=0;reg [607:0] objects=0;
wire busy;wire [2:0] state;wire [3:0] reason;wire [8:0] total;
classified_pocket_counter #(.RECORD_ONLY(1),.HYST(4),.MOTION_RECOVERY(1),.TAIL_RECOVERY(1),.OBS_PER_REGION(4),.ORDERED_HANDOFF(1),.RECOVERABLE(1),.VELOCITY_ASSOC(1)) dut(
 .clk(clk),.rst_n(rst_n),.start_run(start_run),.finish_run(1'b0),.frame_bad(1'b0),.sample_new(sample_new),.frame_id(frame_id),.config_tag(64'd1),.objects(objects),.busy(busy),.state(state),.reason(reason),.total(total),.ledger_address(9'd511),.empty_address(9'd511));
integer f,k,x,direction=1,checks=0,failures=0,n;
function [75:0] object_at(input integer cx,kind);
 integer h;begin h=kind==3?4:19;object_at={1'b1,kind[1:0],4'd0,13'd100,7'd38,7'd38,11'(cx-h),11'(cx+h),10'd310,10'd330};end
endfunction
initial begin
 repeat(5)@(negedge clk);rst_n=1;
 for(direction=-1;direction<=1;direction+=2)begin
  @(negedge clk);start_run=1;@(negedge clk);start_run=0;
  for(f=0;f<4;f++)begin
   objects=0;
   for(k=0;k<4;k++)begin
    x=(direction>0?402:878)+direction*(20*f-50*k);
    if(x>=400 && x<880)objects[k*76+:76]=object_at(x,k==0?3:2);
   end
   @(negedge clk);sample_new=1;frame_id++;@(negedge clk);sample_new=0;repeat(2)@(negedge clk);n=0;
   while(busy)begin @(negedge clk);n++;if(n>3000)$fatal(1,"budget");end repeat(3)@(negedge clk);
   $display("BOOT dir%0d source%0d f%0d state%0d C%0d matched%0d prev%0d stable%0d",direction,frame_id,f,state,reason,dut.matched_count,dut.previous_dx,dut.stable_frames);
  end
  checks++;if(state!=2 || total!=0)failures++;
 end
`ifdef EXPECT_SENSITIVITY
 if(failures!=2)$fatal(1,"old counter must expose both20px first-E boot cases");
 $display("PASS bootstrap sensitivity: fixed20px first-E-only motion fails both directions before body anchor");
`else
 if(failures!=0)$fatal(1,"first-E bootstrap still fails %0d/%0d",failures,checks);
 $display("PASS bootstrap: first-E at entry,20px source motion, both directions, three real measured steps lock before crossing");
`endif
 $finish;
end
initial begin #100000000;$fatal(1,"watchdog");end
endmodule
