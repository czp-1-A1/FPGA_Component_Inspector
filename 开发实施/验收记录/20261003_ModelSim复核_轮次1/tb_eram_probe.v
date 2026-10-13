`timescale 1ns/1ps
module tb_eram_probe;
reg clk=0, we=0;
reg [10:0] wa=0, ra=0;
reg [95:0] data=0;
wire [95:0] floating_out, tied_out, web_only_out;
always #5 clk=~clk;
blk_mem_gen_awb_delay_signal floating(.clka(clk),.clkb(clk),.wea(we),.addra(wa),.addrb(ra),.dia(data),.dob(floating_out));
blk_mem_gen_awb_delay_signal tied(.clka(clk),.clkb(clk),.wea(we),.addra(wa),.addrb(ra),.dia(data),.dob(tied_out),.web(1'b0),.dib(96'd0));
blk_mem_gen_awb_delay_signal web_only(.clka(clk),.clkb(clk),.wea(we),.addra(wa),.addrb(ra),.dia(data),.dob(web_only_out),.web(1'b0));
integer i;
initial begin
  repeat(16) @(negedge clk);
  for(i=0;i<4;i=i+1) begin
    we=1;wa=i;data=96'h111111222222333333444444+i;@(negedge clk);
  end
  we=0;
  for(i=0;i<4;i=i+1) begin
    ra=i; repeat(3) @(negedge clk);
    $display("OBS ERAM addr=%0d floating=%h tied=%h web_only=%h",i,floating_out,tied_out,web_only_out);
    if(tied_out !== (96'h111111222222333333444444+i) || web_only_out !== tied_out)
      $fatal(1,"ERAM readback mismatch");
  end
  $display("PASS ERAM port diagnosis: web=0 permits correct readback, dib may remain open during read-only operation");
  $finish;
end
endmodule
