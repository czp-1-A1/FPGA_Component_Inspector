# Routed constraint audit, native stage 2

TD6.2.178840, PH1P35MDG324 speed3, frozen build r4. Active constraint:
`td_project/camera_to_dsi_display.sdc`; the old empty timing.sdc is not active.
The candidate has core setup/hold TNS0, zero violating endpoints, WNS+0.143/+0.020ns.
This is **not approval of all board interfaces**. Overall acceptance remains open.

| Check | Routed result | Disposition |
|---|---:|---|
| No clock, invalid constraints, combinational loops | 0 each | Pass for checked fabric |
| Old DDR PLL frequency mismatch | 0 | PLL/ref/tCK/speed-bin metadata changed coherently; physical operation not proved |
| HDMI PLLs | 2 dedicated, total5/6 | Integer chain, independent main PLL; vendor-model74.250000/371.250001MHz |
| CDC and soft FIFO physical bounds | All valid; no missing soft-FIFO exception | Payloads held through handshake; bounds are not blanket asynchronous cuts |
| Shadowed exception groups | 5, ignored paths0 | General clock-to-clock budgets overlap tighter mailbox/FIFO constraints |
| Dummy nodes | 2 | Constant O_screen_pwm LUT output and pad IO_cam_sda.ts; source/primitive controls need vendor pad audit |
| No input delay | 39 ports | Detailed list retained in reports; not silently waived |
| No output delay | 63 ports | Detailed list retained in reports; not silently waived |
| Partial input delay | IO_rx_clk_pad_p | DPHY clock creation is not a complete differential electrical interface constraint |
| STA coverage | 95.31% | Not 100%, no all-path pass claim |

Input39 = GPIO/reset7, camera I2C SDA1, MIPI differential inputs9, DDR inouts22.
Output63 = camera I2C SDA1, MIPI bidirectional declarations10, camera reset/SCL2,
constant PWM1, TMDS4, DDR45. MIPI output declarations and DDR DM input declarations
do not describe active signal directions, so port-warning counts alone do not
identify the fabric endpoints affected. Button/SW asynchronous synchronizers have
existing false paths; those do not establish board I/O setup/hold. The clock input
is defined; electrical DPHY timing is inside the hard macro.

DDR DQ/DQS, command/address and TMDS source-synchronous electrical timing require
the vendor hard-PHY models/constraints and actual board/device timing budgets.
No fabricated zero input/output delays were added to make warnings disappear.
External I2C/reset budgets also remain to be justified. Physical DDR training,
write/read pattern integrity and sustained service at FHD must be checked before
declaring the base accepted. The ordered MC simulation does not exercise the
DDR PHY or model refresh command legality inside the controller.

The five shadowed general groups retain dominant paths240/112/118/192/4, with
overlaps38/54/18/160/106. Every explicit mailbox payload/request/ack group is
dominant; there are no ignored exceptions. Preserve exception.timing and full
constraint_coverage.txt for path-level review.

TD prints clock periods to1ps: serial371.333MHz corresponds to rounded2.693ns,
while exact integer-divider hardware/model gives371.25MHz. Clock mismatch audit
is zero. Ratios must be judged from PLL configuration and model/board measurements,
not the independently rounded clock-summary MHz columns.
