///////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2011-2021 Anlogic, Inc.
// All Right Reserved.
///////////////////////////////////////////////////////////////////////////////
//
//
//   Vendor : Anlogic
//   Version : 0.1
//   Description : Anlogic Functional Simulation Library Component
//              lut1 lut2 lut3 lut4 lut5 lut6
//   Filename : al_map_lut.v
//   Timestamp : Mon Nov  4 14:20:41 CST 2013
//
///////////////////////////////////////////////////////////////////////////////
//
// Revision:
//    11/04/13 - Initial version.
//
///////////////////////////////////////////////////////////////////////////////

`timescale  1 ps / 1 ps

// Note: EQN parameter is not used in describing the behavior.
// Only to suppress the warning in compiling map.v

module AL_MAP_LUT1 (o, a);

    parameter EQN = "(A)";

    parameter INIT = 2'h0;

    input a;

    output o;
    
    wire o;

    assign o = (INIT[0] == INIT[1]) ? INIT[0] : INIT[a];


    specify
        (a => o) = (0:0:0, 0:0:0);
    endspecify
endmodule


module AL_MAP_LUT2 (o, a, b);

    parameter EQN = "(A)";

    parameter INIT = 4'h0;

    input a, b;

    output o;

    reg  o;
    wire [1:0] s;

    assign s = {b, a};

    always @(s)
       if ((s[1]^s[0] ==1) || (s[1]^s[0] ==0))
           o = INIT[s];
         else if ((INIT[0] == INIT[1]) && (INIT[2] == INIT[3]) && (INIT[0] == INIT[2])) 
           o = INIT[0];
         else if ((s[1] == 0) && (INIT[0] == INIT[1]))
           o = INIT[0];
         else if ((s[1] == 1) && (INIT[2] == INIT[3])) 
           o = INIT[2];
         else if ((s[0] == 0) && (INIT[0] == INIT[2])) 
           o = INIT[0];
         else if ((s[0] == 1) && (INIT[1] == INIT[3]))
           o = INIT[1];
         else
           o = 1'bx;

    specify
        (a => o) = (0:0:0, 0:0:0);
        (b => o) = (0:0:0, 0:0:0);
    endspecify
endmodule


module AL_MAP_LUT3 (o, a, b, c);

    parameter EQN = "(A)";

    parameter INIT = 8'h00;

    input a, b, c;

    output o;

    reg o;
    reg tmp;
  
    always @(  c or  b or  a )  begin
      tmp =  a ^ b  ^ c;
      if ( tmp == 0 || tmp == 1)
           o = INIT[{c, b, a}];
      else
           o = lut3_mux4 ( {1'b0, 1'b0, lut3_mux4 (INIT[7:4], {b, a}),
                          lut3_mux4 (INIT[3:0], {b, a}) }, {1'b0, c});
    end

  function lut3_mux4;
  input [3:0] d;
  input [1:0] s;

  begin
       if ((s[1]^s[0] ==1) || (s[1]^s[0] ==0))
           lut3_mux4 = d[s];
         else if ((d[0] === d[1]) && (d[2] === d[3]) && (d[0] === d[2]))
           lut3_mux4 = d[0];
         else if ((s[1] == 0) && (d[0] === d[1]))
           lut3_mux4 = d[0];
         else if ((s[1] == 1) && (d[2] === d[3]))
           lut3_mux4 = d[2];
         else if ((s[0] == 0) && (d[0] === d[2]))
           lut3_mux4 = d[0];
         else if ((s[0] == 1) && (d[1] === d[3]))
           lut3_mux4 = d[1];
         else
           lut3_mux4 = 1'bx;
   end
   endfunction

    specify
        (a => o) = (0:0:0, 0:0:0);
        (b => o) = (0:0:0, 0:0:0);
        (c => o) = (0:0:0, 0:0:0);
    endspecify
endmodule


module AL_MAP_LUT4 (o, a, b, c, d);

    parameter EQN = "(A)";

  parameter INIT = 16'h0000;

  input a, b, c, d;

  output o;

  reg o;
  reg tmp;

  always @(  d or  c or  b or  a )  begin
 
    tmp =  a ^ b  ^ c ^ d;

    if ( tmp == 0 || tmp == 1)

        o = INIT[{d, c, b, a}];

    else 
    
      o =  lut4_mux4 ( {lut4_mux4 ( INIT[15:12], {b, a}),
                          lut4_mux4 ( INIT[11:8], {b, a}),
                          lut4_mux4 ( INIT[7:4], {b, a}),
                          lut4_mux4 ( INIT[3:0], {b, a}) }, {d, c});
  end

  function lut4_mux4;
  input [3:0] d;
  input [1:0] s;
   
  begin

       if ((s[1]^s[0] ==1) || (s[1]^s[0] ==0))
           
           lut4_mux4 = d[s];

         else if ((d[0] === d[1]) && (d[2] === d[3]) && (d[0] === d[2])) 
           lut4_mux4 = d[0];
         else if ((s[1] == 0) && (d[0] === d[1]))
           lut4_mux4 = d[0];
         else if ((s[1] == 1) && (d[2] === d[3])) 
           lut4_mux4 = d[2];
         else if ((s[0] == 0) && (d[0] === d[2])) 
           lut4_mux4 = d[0];
         else if ((s[0] == 1) && (d[1] === d[3]))
           lut4_mux4 = d[1];
         else
           lut4_mux4 = 1'bx;
   end
  endfunction

  specify
    (a => o) = (0:0:0, 0:0:0);
    (b => o) = (0:0:0, 0:0:0);
    (c => o) = (0:0:0, 0:0:0);
    (d => o) = (0:0:0, 0:0:0);
  endspecify
endmodule


module AL_MAP_LUT5 (o, a, b, c, d, e);

    parameter EQN = "(A)";

  parameter INIT = 32'h00000000;

  output o;
  input a, b, c, d, e;

  wire a0, a1, a2, a3, a4;
  wire o_out_tmp;

  buf b0 (a0, a);
  buf b1 (a1, b);
  buf b2 (a2, c);
  buf b3 (a3, d);
  buf b4 (a4, e);
  buf b5 (o, o_out_tmp);

  reg o_out;
  reg tmp;

  assign o_out_tmp= o_out;

  always @( a4 or a3 or  a2 or  a1 or  a0 )  begin

    tmp =  a0 ^ a1  ^ a2 ^ a3 ^ a4;

    if ( tmp == 0 || tmp == 1)

        o_out = INIT[{a4, a3, a2, a1, a0}];

    else

      o_out =  lut4_mux4 (
                        { lut6_mux8 ( INIT[31:24], {a2, a1, a0}),
                          lut6_mux8 ( INIT[23:16], {a2, a1, a0}),
                          lut6_mux8 ( INIT[15:8], {a2, a1, a0}),
                          lut6_mux8 ( INIT[7:0], {a2, a1, a0}) }, { a4, a3});
  end


  specify

	(a => o) = (0:0:0, 0:0:0);
	(b => o) = (0:0:0, 0:0:0);
	(c => o) = (0:0:0, 0:0:0);
	(d => o) = (0:0:0, 0:0:0);
	(e => o) = (0:0:0, 0:0:0);
	specparam PATHPULSE$ = 0;

  endspecify


  function lut6_mux8;
  input [7:0] d;
  input [2:0] s;
   
  begin

       if ((s[2]^s[1]^s[0] ==1) || (s[2]^s[1]^s[0] ==0))
           
           lut6_mux8 = d[s];

         else
           if ( ~(|d))
                 lut6_mux8 = 1'b0;
           else if ((&d))
                 lut6_mux8 = 1'b1;
           else if (((s[1]^s[0] ==1'b1) || (s[1]^s[0] ==1'b0)) && (d[{1'b0,s[1:0]}]==d[{1'b1,s[1:0]}]))
                 lut6_mux8 = d[{1'b0,s[1:0]}];
           else if (((s[2]^s[0] ==1) || (s[2]^s[0] ==0)) && (d[{s[2],1'b0,s[0]}]==d[{s[2],1'b1,s[0]}]))
                 lut6_mux8 = d[{s[2],1'b0,s[0]}];
           else if (((s[2]^s[1] ==1) || (s[2]^s[1] ==0)) && (d[{s[2],s[1],1'b0}]==d[{s[2],s[1],1'b1}]))
                 lut6_mux8 = d[{s[2],s[1],1'b0}];
           else if (((s[0] ==1) || (s[0] ==0)) && (d[{1'b0,1'b0,s[0]}]==d[{1'b0,1'b1,s[0]}]) &&
              (d[{1'b0,1'b0,s[0]}]==d[{1'b1,1'b0,s[0]}]) && (d[{1'b0,1'b0,s[0]}]==d[{1'b1,1'b1,s[0]}]))
                 lut6_mux8 = d[{1'b0,1'b0,s[0]}];
           else if (((s[1] ==1) || (s[1] ==0)) && (d[{1'b0,s[1],1'b0}]==d[{1'b0,s[1],1'b1}]) &&
              (d[{1'b0,s[1],1'b0}]==d[{1'b1,s[1],1'b0}]) && (d[{1'b0,s[1],1'b0}]==d[{1'b1,s[1],1'b1}]))
                 lut6_mux8 = d[{1'b0,s[1],1'b0}];
           else if (((s[2] ==1) || (s[2] ==0)) && (d[{s[2],1'b0,1'b0}]==d[{s[2],1'b0,1'b1}]) &&
              (d[{s[2],1'b0,1'b0}]==d[{s[2],1'b1,1'b0}]) && (d[{s[2],1'b0,1'b0}]==d[{s[2],1'b1,1'b1}]))
                 lut6_mux8 = d[{s[2],1'b0,1'b0}];
           else
                 lut6_mux8 = 1'bx;
   end
  endfunction


  function lut4_mux4;
  input [3:0] d;
  input [1:0] s;
   
  begin

       if ((s[1]^s[0] ==1) || (s[1]^s[0] ==0))

           lut4_mux4 = d[s];

         else if ((d[0] ^ d[1]) == 0 && (d[2] ^ d[3]) == 0 && (d[0] ^ d[2]) == 0)
           lut4_mux4 = d[0];
         else if ((s[1] == 0) && (d[0] == d[1]))
           lut4_mux4 = d[0];
         else if ((s[1] == 1) && (d[2] == d[3]))
           lut4_mux4 = d[2];
         else if ((s[0] == 0) && (d[0] == d[2]))
           lut4_mux4 = d[0];
         else if ((s[0] == 1) && (d[1] == d[3]))
           lut4_mux4 = d[1];
         else
           lut4_mux4 = 1'bx;

   end
  endfunction

  specify
    (a => o) = (0:0:0, 0:0:0);
    (b => o) = (0:0:0, 0:0:0);
    (c => o) = (0:0:0, 0:0:0);
    (d => o) = (0:0:0, 0:0:0);
    (e => o) = (0:0:0, 0:0:0);
  endspecify
endmodule


module AL_MAP_LUT6 (o, a, b, c, d, e, f);

    parameter EQN = "(A)";

  parameter INIT = 64'h0000000000000000;

  input a, b, c, d, e, f;

  output o;

  reg o;
  reg tmp;

  always @( f or e or d or  c or  b or  a )  begin
 
    tmp =  a ^ b  ^ c ^ d ^ e ^ f;

    if ( tmp == 0 || tmp == 1)

        o = INIT[{f, e, d, c, b, a}];

    else 
    
      o =  lut6_mux8 ( {lut6_mux8 ( INIT[63:56], {c, b, a}),
                          lut6_mux8 ( INIT[55:48], {c, b, a}),
                          lut6_mux8 ( INIT[47:40], {c, b, a}),
                          lut6_mux8 ( INIT[39:32], {c, b, a}),
                          lut6_mux8 ( INIT[31:24], {c, b, a}),
                          lut6_mux8 ( INIT[23:16], {c, b, a}),
                          lut6_mux8 ( INIT[15:8], {c, b, a}),
                          lut6_mux8 ( INIT[7:0], {c, b, a}) }, {f, e, d});
  end

  function lut6_mux8;
  input [7:0] d;
  input [2:0] s;
   
  begin

   if ((s[2]^s[1]^s[0] ==1) || (s[2]^s[1]^s[0] ==0))
           
       lut6_mux8 = d[s];

     else
       if ( ~(|d))
             lut6_mux8 = 1'b0;
       else if ((&d))
             lut6_mux8 = 1'b1;
       else if (((s[1]^s[0] ==1'b1) || (s[1]^s[0] ==1'b0)) && (d[{1'b0,s[1:0]}]==d[{1'b1,s[1:0]}]))
             lut6_mux8 = d[{1'b0,s[1:0]}];
       else if (((s[2]^s[0] ==1) || (s[2]^s[0] ==0)) && (d[{s[2],1'b0,s[0]}]==d[{s[2],1'b1,s[0]}]))
             lut6_mux8 = d[{s[2],1'b0,s[0]}];
       else if (((s[2]^s[1] ==1) || (s[2]^s[1] ==0)) && (d[{s[2],s[1],1'b0}]==d[{s[2],s[1],1'b1}]))
             lut6_mux8 = d[{s[2],s[1],1'b0}];
       else if (((s[0] ==1) || (s[0] ==0)) && (d[{1'b0,1'b0,s[0]}]==d[{1'b0,1'b1,s[0]}]) &&
          (d[{1'b0,1'b0,s[0]}]==d[{1'b1,1'b0,s[0]}]) && (d[{1'b0,1'b0,s[0]}]==d[{1'b1,1'b1,s[0]}]))
             lut6_mux8 = d[{1'b0,1'b0,s[0]}];
       else if (((s[1] ==1) || (s[1] ==0)) && (d[{1'b0,s[1],1'b0}]==d[{1'b0,s[1],1'b1}]) &&
          (d[{1'b0,s[1],1'b0}]==d[{1'b1,s[1],1'b0}]) && (d[{1'b0,s[1],1'b0}]==d[{1'b1,s[1],1'b1}]))
             lut6_mux8 = d[{1'b0,s[1],1'b0}];
       else if (((s[2] ==1) || (s[2] ==0)) && (d[{s[2],1'b0,1'b0}]==d[{s[2],1'b0,1'b1}]) &&
          (d[{s[2],1'b0,1'b0}]==d[{s[2],1'b1,1'b0}]) && (d[{s[2],1'b0,1'b0}]==d[{s[2],1'b1,1'b1}]))
             lut6_mux8 = d[{s[2],1'b0,1'b0}];
       else
             lut6_mux8 = 1'bx;
   end
  endfunction

  specify
    (a => o) = (0:0:0, 0:0:0);
    (b => o) = (0:0:0, 0:0:0);
    (c => o) = (0:0:0, 0:0:0);
    (d => o) = (0:0:0, 0:0:0);
    (e => o) = (0:0:0, 0:0:0);
    (f => o) = (0:0:0, 0:0:0);
  endspecify
endmodule

module AL_MAP_LUT6P (o, o5, a, b, c, d, e, m, f);
parameter EQN = "(A)";
parameter EMUX = "M"; // "M" or "E"
parameter INIT = 64'h0000000000000000;
input a, b, c, d, e, m, f;
output o, o5;

wire lut5a, lut5b; 
wire emux = (EMUX == "M") ? m : e;
AL_MAP_LUT5 #(.INIT(INIT[31:0]))   u_lut5a(lut5a, a, b, c, d, emux); // f = 0 
AL_MAP_LUT5 #(.INIT(INIT[63:32])) u_lut5b(lut5b, a, b, c, d, e);    // f = 1

assign o5 = lut5a;
assign o  = f ? lut5b : lut5a;

specify
  // output o
  (a => o) = (0:0:0, 0:0:0);
  (b => o) = (0:0:0, 0:0:0);
  (c => o) = (0:0:0, 0:0:0);
  (d => o) = (0:0:0, 0:0:0);
  (e => o) = (0:0:0, 0:0:0);
  (m => o) = (0:0:0, 0:0:0);
  (f => o) = (0:0:0, 0:0:0);

  // output o5
  (a => o5) = (0:0:0, 0:0:0);
  (b => o5) = (0:0:0, 0:0:0);
  (c => o5) = (0:0:0, 0:0:0);
  (d => o5) = (0:0:0, 0:0:0);
  (e => o5) = (0:0:0, 0:0:0);
  (m => o5) = (0:0:0, 0:0:0);
endspecify
endmodule // AL_MAP_LUT6P

module AL_MAP_LUT6X (o, o5, o4a, o4b, a, b, c, d, e, f);
parameter EQN = "(A)";
parameter INIT = 64'h0000000000000000;
input a, b, c, d, e, f;
output o, o5, o4a, o4b;
tri1 a, b, c, d, e, f;
AL_MAP_LUT4 #(.INIT(INIT[15:0] )) u_lut4a0(lut4a0, a, b, c, d);
AL_MAP_LUT4 #(.INIT(INIT[31:16])) u_lut4a1(lut4a1, a, b, c, d);
AL_MAP_LUT4 #(.INIT(INIT[47:32])) u_lut4b0(lut4b0, a, b, c, d);
AL_MAP_LUT4 #(.INIT(INIT[63:48])) u_lut4b1(lut4b1, a, b, c, d);
wire lut5a = e ? lut4a1 : lut4a0;
wire lut5b = e ? lut4b1 : lut4b0;
wire lut6 = f ? lut5b : lut5a;
assign o   = lut6;
assign o5  = lut5a;
assign o4a = lut4a0;
assign o4b = lut4b0;

specify
  // output o lut6
  (a => o) = (0:0:0, 0:0:0);
  (b => o) = (0:0:0, 0:0:0);
  (c => o) = (0:0:0, 0:0:0);
  (d => o) = (0:0:0, 0:0:0);
  (e => o) = (0:0:0, 0:0:0);
  (f => o) = (0:0:0, 0:0:0);

  // output o5 lut5a
  (a => o5) = (0:0:0, 0:0:0);
  (b => o5) = (0:0:0, 0:0:0);
  (c => o5) = (0:0:0, 0:0:0);
  (d => o5) = (0:0:0, 0:0:0);
  (e => o5) = (0:0:0, 0:0:0);

  // output o4a lut4a0
  (a => o4a) = (0:0:0, 0:0:0);
  (b => o4a) = (0:0:0, 0:0:0);
  (c => o4a) = (0:0:0, 0:0:0);
  (d => o4a) = (0:0:0, 0:0:0);

  // output o4a lut4b0
  (a => o4b) = (0:0:0, 0:0:0);
  (b => o4b) = (0:0:0, 0:0:0);
  (c => o4b) = (0:0:0, 0:0:0);
  (d => o4b) = (0:0:0, 0:0:0);
endspecify

endmodule // AL_MAP_LUT6X

module AL_MAP_LLMUX (i, s, o);

input [1:0] i;
input s;
output o;

assign o = s ? i[1] : i[0];

specify
  (i[0] => o) = (0:0:0, 0:0:0);
  (i[1] => o) = (0:0:0, 0:0:0);
  (s    => o) = (0:0:0, 0:0:0);
endspecify
endmodule

module AL_MAP_F7MUX (i, s, o);
input [1:0] i;
input       s;
output      o;
assign o = s ? i[1] : i[0];
specify
  (i[0] => o) = (0:0:0, 0:0:0);
  (i[1] => o) = (0:0:0, 0:0:0);
  (s => o) = (0:0:0, 0:0:0);
endspecify
endmodule // AL_MAP_F7MUX

module AL_MAP_F8MUX (i, s, o);
input [1:0] i;
input       s;
output      o;
assign o = s ? i[1] : i[0];
specify
  (i[0] => o) = (0:0:0, 0:0:0);
  (i[1] => o) = (0:0:0, 0:0:0);
  (s => o) = (0:0:0, 0:0:0);
endspecify
endmodule // AL_MAP_F8MUX

module AL_MAP_CARRY4 (co, fco, gen, prog, ci, fci);
output [3:0] co;
output fco;
input [3:0] gen;
input [3:0] prog;
input ci;
input fci;
assign co[0] = prog[0] ? ci : gen[0];
assign co[1] = prog[1] ? co[0] : gen[1];
assign co[2] = prog[2] ? co[1] : gen[2];
assign co[3] = prog[3] ? co[2] : gen[3];
assign fco = co[3];
specify
  // reference tlib
  //output co[0]
  (ci      => co[0]) = (0:0:0, 0:0:0);
  (gen[0]  => co[0]) = (0:0:0, 0:0:0);
  (prog[0] => co[0]) = (0:0:0, 0:0:0);

  //output co[1]
  (ci      => co[1]) = (0:0:0, 0:0:0);
  (gen[0]  => co[1]) = (0:0:0, 0:0:0);
  (gen[1]  => co[1]) = (0:0:0, 0:0:0);
  (prog[0] => co[1]) = (0:0:0, 0:0:0);
  (prog[1] => co[1]) = (0:0:0, 0:0:0);

  //output co[2]
  (ci      => co[2]) = (0:0:0, 0:0:0);
  (gen[0]  => co[2]) = (0:0:0, 0:0:0);
  (gen[1]  => co[2]) = (0:0:0, 0:0:0);
  (gen[2]  => co[2]) = (0:0:0, 0:0:0);
  (prog[0] => co[2]) = (0:0:0, 0:0:0);
  (prog[1] => co[2]) = (0:0:0, 0:0:0);
  (prog[2] => co[2]) = (0:0:0, 0:0:0);

  //output co[3]
  (ci      => co[3]) = (0:0:0, 0:0:0);
  (gen[0]  => co[3]) = (0:0:0, 0:0:0);
  (gen[1]  => co[3]) = (0:0:0, 0:0:0);
  (gen[2]  => co[3]) = (0:0:0, 0:0:0);
  (gen[3]  => co[3]) = (0:0:0, 0:0:0);
  (prog[0] => co[3]) = (0:0:0, 0:0:0);
  (prog[1] => co[3]) = (0:0:0, 0:0:0);
  (prog[2] => co[3]) = (0:0:0, 0:0:0);
  (prog[3] => co[3]) = (0:0:0, 0:0:0);

  //output fco
  (gen[0]  => fco) = (0:0:0, 0:0:0);
  (gen[1]  => fco) = (0:0:0, 0:0:0);
  (gen[2]  => fco) = (0:0:0, 0:0:0);
  (gen[3]  => fco) = (0:0:0, 0:0:0);
  (prog[0] => fco) = (0:0:0, 0:0:0);
  (prog[1] => fco) = (0:0:0, 0:0:0);
  (prog[2] => fco) = (0:0:0, 0:0:0);
  (prog[3] => fco) = (0:0:0, 0:0:0);
  (fci     => fco) = (0:0:0, 0:0:0);
endspecify
endmodule // AL_MAP_CARRY4

`pragma protect begin_protected
`pragma protect version = 1
`pragma protect encrypt_agent = "Anlogic"
`pragma protect encrypt_agent_info = "Anlogic Encryption Tool anlogic_2019"
`pragma protect key_keyowner = "Synopsys", key_keyname = "SNPS-VCS-RSA-1"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 128)
`pragma protect key_block
su4MlKU8+402CR6LDS9cxwTZKAbsI23atz+mD9jtwCUG7eacE+xXQkUYzN0yJjpg
FFAj5jbDdCzvJvxmkkIGXG8s1C/fENg6HHyaaITD11bUqngugvF+okTDH7FAqFB5
YcKHb8Vlz1iGqKMJ3RZGyeFvWPNf6wusp0y+o8Zh3j4=
`pragma protect key_keyowner = "Synopsys", key_keyname = "SNPS-VCS-RSA-2"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 128)
`pragma protect key_block
f52n19Q4urMvPA1qKx/AvVPCfJ0yZuzrsm98WHnkcOQlG/glV16QDR7S37iyPxbK
qJ6Mq4qZS8TFMon9XwQ5mamrKQ2wYYqeX1G9oi3C8D/wETXUNLVWLbJGs57SByCP
eMsvjeZ4BAgumHa+5qZA/ByP+5ynklqMFAOXYRoArX4=
`pragma protect key_keyowner = "Cadence Design Systems.", key_keyname = "CDS_RSA_KEY_VER_1"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 256)
`pragma protect key_block
pTJ+eXstmGdQcwTO/QGESBpnJ7eRVHKjZvnAOtjDi/AC7c0RzAGnWaRBPSm/UqND
2TpgsuvccOorAUHyIhor3qkv8jtWIr3y9W36nRj4JEO9ijXdvhJXpOQ0+vgo/Tbg
rr3+x9jIzDf4T7CUSpuIqsQW1Fdg7vweZ12PaKHSTU/JTvbSca8jO7tOPwV5KUg3
cutVLwqPAK7sCeAf72D1+eBArtDqZgGSht+D7UxxYrv8RmXUsCGbpO/j8F48U++U
rXTNWYNTJMq0w1/VpcESphLsb8b2TqhkoomVtTmG7YcunwKJpsKaKTl6l48EQvHD
J4DLqYP+wYbFrcnEyEewZg==
`pragma protect key_keyowner = "Mentor Graphics Corporation", key_keyname = "MGC-VERIF-SIM-RSA-1"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 128)
`pragma protect key_block
ZvfzAf7PRkuRm6nsiXQV6BdDpJobl4DYrcQzc86UOyrt/gUme+6RKKiIUiggiGnx
YRvC9KUC4xQI12YYNCPT1rMkcbc3QFfoSbLaVElJDxrf9FahbvTuy/efU/5aIEsa
RBKnW012FMo3+OlUcoKdNOD5K11yix0Y1iIuP0s+xF8=
`pragma protect key_keyowner = "Mentor Graphics Corporation", key_keyname = "MGC-VERIF-SIM-RSA-2"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 256)
`pragma protect key_block
Mq9t6Xrtikv4COKcSVZ3ZshBLHqoVAYuf0jbOug5+ExESnVQkpWhHqHpk9+wI2rg
3/9ZTT8FD4KJVL0+RRUB1UxCVUsCOqDa2+zg1V4Hk0m2ZEBH8Kw4rIT+Y3kBaDWz
wQ5YekxLURcV34ut6OmK7AT5k7UHM2gwt0NSqphPsF0gkGGM1AY8BdLS0T7r/L8j
vnB4ld5WCHGFeLa98WfUte5AiT0TK7XYVf6Dm3HRBziFq9H3oasVOyXvPXvw9BN5
MO37YZq2r2EzGnULbpbUJV9jmpFdgFxNajhKOs5fXSn/Ku/6KbpR6Ty+UKH4ZSUV
9w+dZZBBSQABuSqj0RoDcw==
`pragma protect key_keyowner = "Univista", key_keyname = "UV-ENC-RSA-1"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 256)
`pragma protect key_block
d2lnGYQDieLPRG+78shxbu3QjfNQDUwoe8TYcHXlDthRQgqRCTTGtfNi0HPFs/zh
iaCLIbHbkdc5jWR2W0IXvxJ/OqLBK765y+MvasdyxnAAjn9u4e6SvBpRvjnbUwZT
byEhK5VtRAygzKFgg10UP9kWEmgf3gY3uB3LsilDqkg1xW1LpMCZBW80SNkwpDGy
hTHkLC9pt1MR/BNZiEKy6X0p0nuDQXdBZW8GBg5Mx8SH7nQia/n/2czlE31680lJ
opneOj5gWawQHxg4GEd6YMiqYoPKwWTXH79KFfVFuge8OSevh1nylBWqUMnP89Hs
uDqv1GxFTlUVmR5hQ0ddKw==
`pragma protect data_method = "AES128-CBC"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 48)
`pragma protect data_block
x8CRoYDY1tGjhtOIgQ9QdhJG7AyClCYRNVYsYgZuuXzlxwgg9X7WDtYnFu8Fp13u
`pragma protect end_protected
