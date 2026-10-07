`timescale 1ns/1ps
module tb_native_pll;
reg refclk=0,reset=1;always #10 refclk=~refclk;
wire pixel,serial,locked;
HDMI_PLL dut(refclk,pixel,serial,locked,reset);
realtime t0,t1,pixel_period,serial_period;
initial begin
 #200;reset=0;
 wait(locked);repeat(100)@(posedge pixel);
 @(posedge pixel);t0=$realtime;repeat(1000)@(posedge pixel);t1=$realtime;
 pixel_period=(t1-t0)/1000.0;
 @(posedge serial);t0=$realtime;repeat(5000)@(posedge serial);t1=$realtime;
 serial_period=(t1-t0)/5000.0;
 $display("PLL measured pixel=%f MHz serial=%f MHz ratio=%f",1000/pixel_period,1000/serial_period,pixel_period/serial_period);
 if($abs(1000/pixel_period-74.25)>0.01 || $abs(1000/serial_period-371.25)>0.05 || $abs(pixel_period/serial_period-5)>0.0002)
  $fatal(1,"PLL frequency mismatch");
 $display("PASS native PLL: actual vendor-model 74.25/371.25 MHz, 5:1");$finish;
end
initial begin #1000000;$fatal(1,"PLL lock watchdog");end
endmodule
