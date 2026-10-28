`include "inputs/tb_adjacent_v6_transport.sv"
module tb_v6_wrong_kind;
tb_adjacent_v6_transport #(.NEGATIVE(1),.GAP(999),.WRONG_KIND(1)) t();
endmodule
