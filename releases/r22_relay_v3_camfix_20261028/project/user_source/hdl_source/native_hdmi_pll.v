// Dedicated HDMI clock chain; main camera/system PLL is unchanged.
// Integer ratios avoid the conflicting fractional-N semantics in TD/models.
// Stage A: 50/5*108=1080 MHz VCO, /32=33.75 MHz.
// Stage B: 33.75*33=1113.75 MHz VCO, /15=74.25, /3=371.25 MHz.
module HDMI_PLL(input refclk,output clk0_out,clk1_out,lock,input reset);
 wire intermediate,ref_locked,out_locked;
 HDMI_PLL_STAGE #(.FIN_MHZ("50.000000000"),.N(5),.M(108),.C0(32),.C1(32),.CAP(16),.ENABLE_C1("DISABLE"))
  u_ref(.refclk(refclk),.clk0_out(intermediate),.clk1_out(),.lock(ref_locked),.reset(reset));
 HDMI_PLL_STAGE u_output(.refclk(intermediate),.clk0_out(clk0_out),.clk1_out(clk1_out),
  .lock(out_locked),.reset(reset || !ref_locked));
 assign lock=ref_locked && out_locked;
endmodule

/************************************************************\
**	Copyright (c) 2012-2025 Anlogic Inc.
**	All Right Reserved.
\************************************************************/
/************************************************************\
**	Build time: Mar 26 2026 17:03:43
**	TD version	:	6.2.168116
************************************************************/
`timescale 1 ns / 100 fs 

module HDMI_PLL_STAGE #(parameter FIN_MHZ="33.750000000",N=1,M=33,C0=15,C1=3,CAP=0,ENABLE_C1="ENABLE")
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
      .FIN(FIN_MHZ),
      .REFCLK_DIV(N),
      .FBCLK_DIV(M),
      .CLKC0_ENABLE("ENABLE"),
      .CLKC0_DIV(C0),
      .CLKC0_CPHASE(C0-1),
      .CLKC0_FPHASE(0),
      .CLKC0_FPHASE_RSTSEL(0),
      .CLKC0_DUTY50("ENABLE"),
      .CLKC0_DUTY_INT((C0+1)/2),
      .CLKC1_ENABLE(ENABLE_C1),
      .CLKC1_DIV(C1),
      .CLKC1_CPHASE(C1-1),
      .CLKC1_FPHASE(0),
      .CLKC1_FPHASE_RSTSEL(0),
      .CLKC1_DUTY50("ENABLE"),
      .CLKC1_DUTY_INT((C1+1)/2),
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
      .FRAC_ENABLE("DISABLE"),
      .SDM_FRAC(0),
      .PLL_USR_RST("ENABLE"),
      .PLL_FEED_TYPE("INTERNAL"),
      .PLL_FASTLOOP("DISABLE"),
      .LPF_RES(3),
      .LPF_CAP(CAP),
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
      .clk1_en(ENABLE_C1=="ENABLE"),
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
