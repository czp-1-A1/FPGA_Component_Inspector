// Independent HDMI 1.4 control/TERC4 tables, Section 5.4.2/5.4.3.
// Source cross-check: hdl-util/hdmi/src/tmds_channel.sv (2026-10-08).
// TERC4 sync bits MUST be decoded inside data islands/guard bands.
function automatic [2:0] hdmi_control(input [9:0] word_value);
 case(word_value)
  10'b1101010100:hdmi_control=3'b100;
  10'b0010101011:hdmi_control=3'b101;
  10'b0101010100:hdmi_control=3'b110;
  10'b1010101011:hdmi_control=3'b111;
  default:hdmi_control=0;
 endcase
endfunction
function automatic [4:0] hdmi_terc4(input [9:0] word_value);
 case(word_value)
  10'b1010011100:hdmi_terc4=5'h10;
  10'b1001100011:hdmi_terc4=5'h11;
  10'b1011100100:hdmi_terc4=5'h12;
  10'b1011100010:hdmi_terc4=5'h13;
  10'b0101110001:hdmi_terc4=5'h14;
  10'b0100011110:hdmi_terc4=5'h15;
  10'b0110001110:hdmi_terc4=5'h16;
  10'b0100111100:hdmi_terc4=5'h17;
  10'b1011001100:hdmi_terc4=5'h18;
  10'b0100111001:hdmi_terc4=5'h19;
  10'b0110011100:hdmi_terc4=5'h1a;
  10'b1011000110:hdmi_terc4=5'h1b;
  10'b1010001110:hdmi_terc4=5'h1c;
  10'b1001110001:hdmi_terc4=5'h1d;
  10'b0101100011:hdmi_terc4=5'h1e;
  10'b1011000011:hdmi_terc4=5'h1f;
  default:hdmi_terc4=0;
 endcase
endfunction
