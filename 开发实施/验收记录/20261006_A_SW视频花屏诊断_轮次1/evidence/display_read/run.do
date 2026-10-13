onerror {quit -code 1}
vlib work
vlog ../../fpga/component_inspector/user_source/hdl_source/video_out.v ../../fpga/component_inspector/user_source/ip_source/w128_d512_fifo/w128_d512_fifo.v ../../fpga/component_inspector/user_source/ip_source/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v tb_video_out_underflow.v
vsim -c -voptargs=+acc work.tb_video_out_underflow
run -all
quit -code 0
