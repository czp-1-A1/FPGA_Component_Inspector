"""Reproducible, reversible display-only R55 changes from the R50 baseline."""
import re

FILES = ['design_top_wrapper.v', 'observation_controls.v', 'isp/isp_top.v', 'roi_sobel_view.v']


def replace_once(text, old, new):
    assert text.count(old) == 1, old[:100]
    return text.replace(old, new, 1)


def rewrite(name, text, inverse=False):
    pairs = {
        'design_top_wrapper.v': [
            ('parameter ENABLE_AUTO_RELAY=1,', 'parameter ENABLE_AUTO_RELAY=1,RAW_EDGE_ONLY=1,'),
            ('observation_controls u_observation_controls(', 'observation_controls #(.RAW_EDGE_ONLY(RAW_EDGE_ONLY)) u_observation_controls('),
            ('isp_top #(.AUTO_RELAY(ENABLE_AUTO_RELAY),', 'isp_top #(.RAW_EDGE_ONLY(RAW_EDGE_ONLY),.AUTO_RELAY(ENABLE_AUTO_RELAY),')],
        'observation_controls.v': [
            ('// SW1=bit0 gray, SW2=bit1 edge.', '// RAW_EDGE_ONLY: SW2 selects RAW / black-and-white edges; SW1 is ignored.\n// Legacy: SW1=bit0 gray, SW2=bit1 edge.'),
            ('parameter STABLE_CYCLES=1000000', 'parameter RAW_EDGE_ONLY=0,STABLE_CYCLES=1000000'),
            ('sync0<=switches;', "sync0<=RAW_EDGE_ONLY ? {switches[1],1'b0} : switches;")],
        'isp/isp_top.v': [
            ('HEIGHT=INPUT_HEIGHT,SCALE_DISPLAY=0,', 'HEIGHT=INPUT_HEIGHT,SCALE_DISPLAY=0,RAW_EDGE_ONLY=0,'),
            ('roi_sobel_view #(.CACHE_ADDRESS_XOR(RESULT_RECORDER),', 'roi_sobel_view #(.RAW_EDGE_ONLY(RAW_EDGE_ONLY),.CACHE_ADDRESS_XOR(RESULT_RECORDER),')]
    }
    if name in pairs:
        for before, after in pairs[name]:
            text = replace_once(text, after if inverse else before, before if inverse else after)
        return text
    assert name == 'roi_sobel_view.v'
    old_parameter = 'parameter EDGE_THRESHOLD=80,CACHE_ADDRESS_XOR=0'
    new_parameter = old_parameter + ',RAW_EDGE_ONLY=0'
    middle = 'wire [95:0] middle_rgb=rgb_read_q ^ cache_read_mask;\n'
    if inverse:
        text = replace_once(text, new_parameter, old_parameter)
        pattern = r'// R55_COLOR_CACHE_BEGIN\nwire \[95:0\] middle_rgb;\ngenerate if\(!RAW_EDGE_ONLY\)begin : color_cache\n(.*?)assign middle_rgb=rgb_read_q \^ cache_read_mask;\nend else begin : no_color_cache\n assign middle_rgb=96\x27d0;\nend endgenerate\n// R55_COLOR_CACHE_END\n'
        match = re.search(pattern, text, re.S)
        assert match
        text = text[:match.start()] + match[1] + text[match.end():]
        text = replace_once(text, 'function [7:0] gray;\n', middle + 'function [7:0] gray;\n')
        pattern = r'   // R55_EDGE_OUTPUT_BEGIN\n.*?   end else begin : legacy_output\n(.*?)   end\n   // R55_EDGE_OUTPUT_END\n'
        match = re.search(pattern, text, re.S)
        assert match
        return text[:match.start()] + match[1] + text[match.end():]
    text = replace_once(text, old_parameter, new_parameter)
    start = text.index('localparam RGB_WORDS=')
    end = text.index('wire [31:0] gray_q', start)
    original = text[start:end]
    block = ("// R55_COLOR_CACHE_BEGIN\nwire [95:0] middle_rgb;\n"
             "generate if(!RAW_EDGE_ONLY)begin : color_cache\n" + original +
             "assign middle_rgb=rgb_read_q ^ cache_read_mask;\n"
             "end else begin : no_color_cache\n assign middle_rgb=96'd0;\n"
             "end endgenerate\n// R55_COLOR_CACHE_END\n")
    text = text[:start] + block + text[end:]
    text = replace_once(text, middle, '')
    start = text.index('   if(!(pixel_sof ? mode[1] : frame_mode[1]) || bypass_tail)\n')
    end = text.index('\n  end\n  count_valid<=v4;', start)
    original = text[start:end] + '\n'
    block = ("   // R55_EDGE_OUTPUT_BEGIN\n"
             "   if(RAW_EDGE_ONLY)begin\n"
             "    if(!(pixel_sof ? mode[1] : frame_mode[1]))\n"
             "     out_rgb[95-lane*24-:24]<=rgb[95-lane*24-:24];\n"
             "    else out_rgb[95-lane*24-:24]<=!bypass_tail && inside4[lane] && neighborhood4[lane] && edges[lane] ? 24'hffffff : 24'h000000;\n"
             "   end else begin : legacy_output\n" + original +
             "   end\n   // R55_EDGE_OUTPUT_END\n")
    return text[:start] + block.rstrip('\n') + text[end:]
