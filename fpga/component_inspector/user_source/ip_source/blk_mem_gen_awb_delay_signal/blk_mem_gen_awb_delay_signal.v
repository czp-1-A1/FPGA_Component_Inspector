/************************************************************\
**	Copyright (c) 2012-2024 Anlogic Inc.
**	All Right Reserved.
\************************************************************/
/************************************************************\
**	Build time: Mar 06 2025 10:18:38
**	TD version	:	6.1.126561
************************************************************/
`timescale 1ns/1ps
// Parameterized capacity; original RAM modes/default2048 retained.
module blk_mem_gen_awb_delay_signal #(parameter RAM_ADDR_BITS=11) (
  output  [95:0]                doa,
  input   [95:0]                dia,
  input   [RAM_ADDR_BITS-1:0]                addra,
  input                         wea,
  input                         clka,
  output  [95:0]                dob,
  input   [RAM_ADDR_BITS-1:0]                addrb,
  input                         clkb,
  input   [95:0]                dib,
  input                         web
);

  ram_f84573da5ab5
  #(
      .DATA_WIDTH_A(96),
      .ADDR_WIDTH_A(RAM_ADDR_BITS),
      .DATA_DEPTH_A(1<<RAM_ADDR_BITS),
      .DATA_WIDTH_B(96),
      .ADDR_WIDTH_B(RAM_ADDR_BITS),
      .DATA_DEPTH_B(1<<RAM_ADDR_BITS),
      .REGMODE_A("NOREG"),
      .WRITEMODE_A("NORMAL"),
      .RESETMODE_A("ASYNC"),
      .INIT_FILE("NONE"),
      .REGMODE_B("NOREG"),
      .FILL_ALL("NONE"),
      .WRITEMODE_B("READBEFOREWRITE"),
      .RESETMODE_B("ASYNC")
  )ram_f84573da5ab5_Inst
  (
      .doa(doa),
      .dia(dia),
      .addra(addra),
      .wea(wea),
      .clka(clka),
      .dob(dob),
      .addrb(addrb),
      .clkb(clkb),
      .dib(dib),
      .web(web)
  );
endmodule
