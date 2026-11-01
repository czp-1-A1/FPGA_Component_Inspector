"""Independent pixel truth for the four declared dual-ROI label results."""
from pathlib import Path
import argparse, hashlib, json

def verify(sim):
    ascii_font=[int(x,16) for x in (sim/'compact_assets/compact_ascii_rom.hex').read_text().split()]
    cjk_font=[int(x,16) for x in (sim/'compact_assets/compact_cjk_rom.hex').read_text().split()]
    declarations=[(550,272,'N008',[1,2],0x70ffdd),
                  (650,345,'N009',[3,4],0xffe080),
                  (550,442,'N021',[5,6,7],0xffb070),
                  (690,515,'N022',[1,2],0x70ffdd)]
    checked=0;files={}
    for frame in range(3):
        path=sim/f'two_region_ui_{frame}.hex'
        raw=bytes.fromhex(path.read_text())
        assert len(raw)==1280*720*3
        files[path.name]=hashlib.sha256(raw).hexdigest()
        for region,(x0,y0,label,glyphs,ink) in enumerate(declarations):
            prefix=region<2 or frame==0
            width=112 if prefix else 72
            for y in range(24):
                for x in range(width):
                    lit=False
                    if prefix and x<40:
                        char=(label+' ')[x//8]
                        lit=y<16 and bool(ascii_font[ord(char)*16+y]&(1<<(7-x%8)))
                    else:
                        gx=x-(40 if prefix else 0)
                        glyph_index=gx//24
                        if glyph_index<len(glyphs):
                            lit=bool(cjk_font[glyphs[glyph_index]*32+y]&(1<<(23-gx%24)))
                    expected=ink if lit else 0x142336
                    index=((y0+y)*1280+x0+x)*3
                    observed=int.from_bytes(raw[index:index+3],'big')
                    assert observed==expected,(frame,region,x,y,hex(observed),hex(expected))
                    checked+=1
    result={'status':'PASS_INDEPENDENT_FOUR_LABEL_PIXEL_TRUTH',
            'checked_label_pixels':checked,'full_rasters':3,'rgb_sha256':files}
    (sim/'two_region_ui_verification.json').write_text(json.dumps(result,indent=2),encoding='utf8')
    print(result['status'],checked,'label pixels;3 full raster sizes verified')
    return result

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('sim',type=Path)
    verify(parser.parse_args().sim.resolve())
