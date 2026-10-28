`timescale 1ns/1ps
module tb_camera_gate;
 reg clk=0,rst=0,slave_low=0;always #5 clk=~clk;
 camera_cone dut();
 wire scl=dut.O_cam_scl_dup_3;
 wire master_sda=dut.\u_uicfgcs500/uii2c_inst/sda_o ;
 wire sda=master_sda && !slave_low;
 wire done=dut.\u_uicfgcs500/O_ae_cfg_done ;
 initial begin
  force dut.O_cam_24m_dup_1=clk;
  force dut.\u_ph1p35_324_ddr_wrapper/u_ddr2/ph1p_ddrmc_wrapper/ph1p_ddrmc_top/u_ddr_phy/u_ddrphy_top/sys_rst_n =rst;
  force dut.IO_cam_sda_dup_1=sda;
 end
 reg[31:0] expected[0:125];
 reg active=0;reg[7:0] shift=0;reg[31:0] packet=0;
 integer bits=0,bytes=0,count=0,epoch;
 always @(negedge sda)if(rst && scl===1'b1)begin active=1;bits=0;bytes=0;packet=0;end
 always @(negedge scl)slave_low=active && bits==8;
 always @(posedge scl)if(active)begin
  if(bits<8)begin shift={shift[6:0],sda};bits=bits+1;end
  else begin packet={packet[23:0],shift};bytes=bytes+1;bits=0;end
 end
 always @(posedge sda)if(rst && scl===1'b1 && active)begin
  active=0;
  if(bytes!=4 || count>=126)$fatal(1,"invalid I2C packet length/count");
  if(packet!==expected[count])$fatal(1,"write%0d actual%08h expected%08h",count+1,packet,expected[count]);
  count=count+1;$display("BUS %0d %08h",count,packet);
 end
 initial begin
  $readmemh("camera_expected.hex",expected);
  for(epoch=0;epoch<2;epoch=epoch+1)begin
   rst=0;active=0;slave_low=0;count=0;#200;rst=1;
   wait(done);#1000;
   if(count!=126)$fatal(1,"camera gate packet count mismatch");
   #1000;
  end
  $display("PASS CAMERA GATE BUS: 2 resets x126 complete serialized I2C packets, EXP1092 GAIN40 WB100/100; no optical sensor readback");
  $finish;
 end
 initial begin #100000000;$fatal(1,"startup timeout");end
endmodule
