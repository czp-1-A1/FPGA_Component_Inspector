`timescale 1ns/1ps
module tb_camera_gate;
 reg clk=0,rst=0,slave_low=0;always #5 clk=~clk;
 camera_cone dut();
 wire scl=dut.O_cam_scl_dup_3;
 wire master_sda=dut.\u_uicfgcs500/uii2c_inst/sda_o ;
 wire sda=master_sda && !slave_low;
 initial begin
  force dut.O_cam_24m_dup_1=clk;
  force dut.\u_ph1p35_324_ddr_wrapper/u_ddr2/ph1p_ddrmc_wrapper/ph1p_ddrmc_top/u_ddr_phy/u_ddrphy_top/sys_rst_n =rst;
  force dut.IO_cam_sda_dup_1=sda;
  force dut.\count_controls$controls/button_meta_b =4'b0000;
  force dut.\count_controls$controls/tick =1'b0;
  #200;rst=1;
 end
 wire done=dut.\u_uicfgcs500/O_ae_cfg_done ;
 reg active=0;reg [7:0] shift=0;reg [31:0] packet=0;
 integer bits=0,bytes=0,count=0;
 always @(negedge sda)if(rst && scl===1'b1)begin active=1;bits=0;bytes=0;packet=0;end
 always @(negedge scl)slave_low=active && bits==8;
 always @(posedge scl)if(active)begin
  if(bits<8)begin shift={shift[6:0],sda};bits++;end
  else begin packet={packet[23:0],shift};bytes++;bits=0;end
 end
 always @(posedge sda)if(rst && scl===1'b1 && active)begin
  active=0;
  if(bytes!=4)$fatal(1,"I2C transaction length%0d",bytes);
  count++;$display("BUS %0d %08h",count,packet);
  if(packet[31:24]!==8'h6c)$fatal(1,"sensor address wrong");
  case(count)
   122:if(packet!==32'h6c3e0000)$fatal(1,"EXP high wrong");
   123:if(packet!==32'h6c3e0144)$fatal(1,"EXP middle wrong");
   124:if(packet!==32'h6c3e0240)$fatal(1,"EXP low wrong");
   125:if(packet!==32'h6c3e0803)$fatal(1,"GAIN high wrong");
   126:if(packet!==32'h6c3e0938)$fatal(1,"GAIN low wrong");
  endcase
 end
 initial begin wait(rst);wait(done);#1000;
  if(count!=126)$fatal(1,"configuration writes %0d",count);
  $display("PASS ACTUAL V2 SYNTH CAMERA BUS:126 serialized I2C writes, EXP1092/GAIN40 correct; no sensor optical readback");$finish;
 end
 initial begin #100000000;$fatal(1,"camera cone timeout writes%0d",count);end
endmodule
