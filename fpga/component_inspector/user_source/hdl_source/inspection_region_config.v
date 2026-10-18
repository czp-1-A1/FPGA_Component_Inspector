// Compile-time inspection zones and taught feature recipes. Coordinates are
// 1280x720 processing pixels by default. No automatic model identification.
module inspection_region_config #(
 parameter WIDTH=1280,HEIGHT=720,COMPACT=0,
 parameter [15:0] MODEL0=3528,MODEL1=3528,
 parameter X00=COMPACT ? WIDTH/2-80 : WIDTH*5/16,X01=COMPACT ? WIDTH/2+80 : WIDTH*11/16,
 Y00=COMPACT ? HEIGHT/2-112 : HEIGHT/3,Y01=COMPACT ? HEIGHT/2-8 : HEIGHT*5/9,
 parameter X10=COMPACT ? WIDTH/2-80 : WIDTH*5/16,X11=COMPACT ? WIDTH/2+80 : WIDTH*11/16,
 Y10=COMPACT ? HEIGHT/2+8 : HEIGHT*3/5,Y11=COMPACT ? HEIGHT/2+112 : HEIGHT*5/6,
 // Low byte first: body Lmin,Lmax,Smin,Smax,review Lmax,Smax;
 // empty Lmin,Lmax,Smin,Smax; feed-hole Lmin,Lmax,Smin,Smax; dark reference.
 // Geometry is measured in the detector's half-resolution mask.
 // 28 labeled observer photos: geometry trial, not native gray calibration.
 // One half-cell phase margin for a small normal body (L19/S15).
 // Empty3..6 and locating L7..10/S6..10 remain disjoint in long side.
 // Keep T100/T80 and the broad PRESENT+review envelope; do not widen NORMAL
 // to accept standing/flipped bodies. Native field validation is pending.
 parameter [119:0] RECIPE0={8'd240,8'd10,8'd6,8'd10,8'd7,8'd6,8'd3,8'd6,8'd3,8'd38,8'd43,8'd36,8'd15,8'd39,8'd19},
 parameter [119:0] RECIPE1={8'd240,8'd10,8'd6,8'd10,8'd7,8'd6,8'd3,8'd6,8'd3,8'd38,8'd43,8'd36,8'd15,8'd39,8'd19}
)(
 output wire [83:0] bounds,output wire [31:0] models,
 output wire [239:0] recipes,output wire [1:0] supported
);
localparam [10:0] AX0=X00,AX1=X01,BX0=X10,BX1=X11;
localparam [9:0] AY0=Y00,AY1=Y01,BY0=Y10,BY1=Y11;
assign bounds={BX0,BX1,BY0,BY1,AX0,AX1,AY0,AY1};
assign models={MODEL1,MODEL0};
assign recipes={RECIPE1,RECIPE0};
// Only this same white 3528 has a recipe. Unknown IDs cannot classify as empty.
assign supported={MODEL1==3528,MODEL0==3528};
endmodule
