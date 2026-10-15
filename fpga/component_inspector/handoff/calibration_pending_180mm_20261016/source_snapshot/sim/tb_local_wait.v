`timescale 1ns/1ps
module tb_local_wait;
reg [8:0] gates=0;wire valid;wire [3:0] reason;
local_search_display_status dut(gates[8],gates[7],gates[6],gates[5],gates[4],gates[3],gates[2],gates[1],gates[0],valid,reason);
integer expected,checks=0;
initial begin
 for(integer n=0;n<512;n++)begin
  gates=n;#1;
  if(valid!==(gates[8] && (&gates[6:0])))$fatal(1,"original local valid gate changed");
  expected=!gates[8] || !gates[7] ? 1 : !gates[6] ? 2 : !gates[5] ? 3 : !gates[4] ? 4 : !gates[3] ? 5 : !gates[2] ? 6 : !gates[1] ? 7 : !gates[0] ? 8 : 0;
  if(reason!==expected)$fatal(1,"reason priority mismatch %b",gates);checks++;
 end
 $display("PASS local WAIT: %0d combinations, exact original validity and each diagnostic gate; metadata absence distinguished",checks);$finish;
end
endmodule
