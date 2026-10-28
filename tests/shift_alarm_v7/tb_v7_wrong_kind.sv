`include "inputs/tb_v7_transport.sv"
module tb_v7_wrong_kind;tb_v7_transport #(.NEGATIVE(1),.GAP(999),.WRONG_KIND(1)) t();endmodule
