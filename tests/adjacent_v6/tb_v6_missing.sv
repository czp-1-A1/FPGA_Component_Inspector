`include "inputs/tb_adjacent_v6_transport.sv"
module tb_v6_missing;
tb_adjacent_v6_transport #(.NEGATIVE(1),.GAP(999)) t();
endmodule
