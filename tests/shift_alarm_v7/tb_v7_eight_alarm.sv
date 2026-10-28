`include "inputs/tb_v7_transport.sv"
module tb_v7_eight_alarm;tb_v7_transport #(.PARTS(11),.CONSECUTIVE(8),.EXPECT_ALARM(1)) t();endmodule
