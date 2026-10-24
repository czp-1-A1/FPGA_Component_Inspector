`timescale 1ns/1ps
module tb_review_reference_slots;
reg clk=0,rst_n=0;always #5 clk=~clk;
wire [127:0] record;wire ready;
frame_shape_search #(.REVIEW_PROBE(1),.WIDTH(1280),.HEIGHT(720),.REGIONS(1),.COUNT_CANDIDATES(1)) dut(
 .clk(clk),.rst_n(rst_n),.frame_start(1'b0),.pixel_sof(1'b0),.pixel_accept(1'b0),.invalidate(1'b0),
 .pixel_x(11'd0),.pixel_y(10'd0),.rgb(96'd0),.recorder_hold_valid(1'b0),.recorder_hold_x(11'd0),.recorder_hold_y(10'd0),
 .probe_record(record),.probe_ready(ready));
task check(input [17:0] upper,lower);
 begin
  #1;
  if(dut.review_measurement.references!=={lower,upper})
   $fatal(1,"reference/slot mismatch got%h expected%h",dut.review_measurement.references,{lower,upper});
 end
endtask
initial begin
 repeat(5)@(negedge clk);rst_n=1;repeat(2)@(negedge clk);
 force dut.state_bank[0]=2;force dut.state_bank[1]=2;force dut.state_bank[4]=2;force dut.state_bank[5]=2;
 force dut.weak_bank[0]=0;force dut.weak_bank[1]=1;force dut.weak_bank[4]=0;force dut.weak_bank[5]=1;
 force dut.dark_bank[0]=16'h1122;force dut.dark_bank[1]=16'haabb;
 force dut.dark_bank[4]=16'h3344;force dut.dark_bank[5]=16'hccdd;
 force dut.xmin_bank[0]=100;force dut.xmin_bank[1]=300;
 force dut.xmin_bank[4]=100;force dut.xmin_bank[5]=300;
 // Fallback is required even when the invalid slot retains a smaller old X.
 force dut.found_bank[0]=0;force dut.found_bank[1]=1;
 force dut.found_bank[4]=0;force dut.found_bank[5]=1;
 check({1'b1,1'b1,16'haabb},{1'b1,1'b1,16'hccdd});
 // Both valid: use the same X ordering as the published object pair.
 force dut.found_bank[0]=1;force dut.found_bank[4]=1;
 check({1'b0,1'b1,16'h1122},{1'b0,1'b1,16'h3344});
 force dut.xmin_bank[1]=50;force dut.xmin_bank[5]=50;
 check({1'b1,1'b1,16'haabb},{1'b1,1'b1,16'hccdd});
 // An invalid second slot must not win by its stale coordinate.
 force dut.found_bank[1]=0;force dut.found_bank[5]=0;
 check({1'b0,1'b1,16'h1122},{1'b0,1'b1,16'h3344});
 $display("PASS review_reference_slots:8 ROI bank selections; missing first slot, X ordering, stale invalid slot and distinct source/dark fields");$finish;
end
initial begin #10000;$fatal(1,"timeout");end
endmodule
