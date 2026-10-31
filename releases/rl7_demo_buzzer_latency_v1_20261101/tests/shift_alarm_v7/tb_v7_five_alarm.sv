`include "inputs/tb_v7_transport.sv"
module tb_v7_five_alarm;tb_v7_transport #(.PARTS(8),.CONSECUTIVE(5),.EXPECT_ALARM(1)) t();endmodule
