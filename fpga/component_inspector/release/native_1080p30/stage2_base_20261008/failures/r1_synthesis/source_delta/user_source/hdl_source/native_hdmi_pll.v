// 50 MHz reference; vendor fractional calculator: VCO=1113.7500000186265 MHz.
// Actual outputs 74.2500000012418 / 371.2500000062088 MHz (ratio 5).
/************************************************************\
**	Copyright (c) 2012-2025 Anlogic Inc.
**	All Right Reserved.
\************************************************************/
/************************************************************\
**	Build time: Mar 26 2026 17:03:43
**	TD version	:	6.2.168116
************************************************************/
`timescale 1 ns / 100 fs 

module HDMI_PLL
(
  input                         refclk,
  output                        clk0_out,
  output                        clk1_out,
  output                        lock,
  input                         reset
);
  wire							  clk0_buf;
PH1P_LOGIC_BUFG bufg_feedback (
 .i(clk0_buf), 
 .o(clk0_out) 
 ); 

 


 
 


  ph1p_phy_pll_wrapper_25a56e5ce2f9
  #(
      .FBKCLK("VCO_PHASE0"),
      .FBKCLK_INT("VCO_PHASE0"),
      .FIN("50.000000000"),
      .REFCLK_DIV(4),
      .FBCLK_DIV(89),
      .CLKC0_ENABLE("ENABLE"),
      .CLKC0_DIV(15),
      .CLKC0_CPHASE(14),
      .CLKC0_FPHASE(0),
      .CLKC0_FPHASE_RSTSEL(0),
      .CLKC0_DUTY50("ENABLE"),
      .CLKC0_DUTY_INT(8),
      .CLKC1_ENABLE("ENABLE"),
      .CLKC1_DIV(3),
      .CLKC1_CPHASE(2),
      .CLKC1_FPHASE(0),
      .CLKC1_FPHASE_RSTSEL(0),
      .CLKC1_DUTY50("ENABLE"),
      .CLKC1_DUTY_INT(2),
      .CLKC4_ENABLE("DISABLE"),
      .CLKC4_DIV(25),
      .CLKC4_CPHASE(24),
      .CLKC4_FPHASE(0),
      .CLKC4_FPHASE_RSTSEL(0),
      .CLKC4_DUTY50("ENABLE"),
      .CLKC4_DUTY_INT(13),
      .CLKC5_ENABLE("DISABLE"),
      .CLKC5_DIV(5),
      .CLKC5_CPHASE(4),
      .CLKC5_FPHASE(0),
      .CLKC5_FPHASE_RSTSEL(0),
      .CLKC5_DUTY50("ENABLE"),
      .CLKC5_DUTY_INT(3),
      .FRAC_ENABLE("ENABLE"),
      .SDM_FRAC(26843546),
      .PLL_USR_RST("ENABLE"),
      .PLL_FEED_TYPE("INTERNAL"),
      .PLL_FASTLOOP("DISABLE"),
      .LPF_RES(3),
      .LPF_CAP(16),
      .ICP_CUR(0),
      .PHASE_PATH_SEL(0),
      .DYN_PHASE_PATH_SEL("DISABLE"),
      .DYN_FPHASE_EN("DISABLE"),
      .PI_OUT_SEL("NORMAL"),
      .PI_FRAC_EN("DISABLE"),
      .CLKC0_PI_SHIFT_EN("DISABLE"),
      .FEEDBK_MODE("NOCOMP"),
      .DYN_CPHASE_EN("DISABLE")
  )ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst
  (
      .clk2_en(1'b0),
      .clk2_out(),
      .clkb2_out(),
      .clk3_en(1'b0),
      .clk3_out(),
      .clkb3_out(),
      .clk6_en(1'b0),
      .clk6_out(),
      .clkb6_out(),
      .refclk(refclk),
      .drp_clk(1'b0),
      .drp_rstn(1'b1),
      .drp_sel(1'b0),
      .drp_rd(1'b0),
      .drp_wr(1'b0),
      .drp_addr(8'b00000000),
      .drp_wdata(8'b00000000),
      .drp_err(),
      .drp_rdy(),
      .drp_rdata(),
      .psclk(1'b0),
      .psclksel(3'b000),
      .psstep(1'b0),
      .psdown(1'b0),
      .cps_step(1'b0),
      .psdone(),
      .ssc_reset(1'b0),
	  .clkc_rst(2'b00),
      .pllpd(1'b0),
      .fbclk(1'b0),
      .wakeup(1'b1),
      .refclk_rst(1'b0),
      .clk0_en(1'b1),
      .clkb0_out(),
      .clk0_out(clk0_buf),
      .clk1_en(1'b1),
      .clkb1_out(),
      .clk1_out(clk1_out),
      .clk4_en(1'b0),
      .clkb4_out(),
      .clk4_out(),
      .clk5_en(1'b0),
      .clkb5_out(),
      .clk5_out(),
      .lock(lock),
      .reset(reset)
  );
endmodule
