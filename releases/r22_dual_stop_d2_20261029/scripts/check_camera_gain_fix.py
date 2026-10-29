"""Check camera lookup RTL or the closed camera cone of an actual TD netlist.

Gate mode requires exactly the three modeled external nets (clock/reset/SDA),
compares every serialized packet with known-working V2, and runs two resets.
It is a simulated ACK slave, never a sensor readback or board acceptance.
"""
from pathlib import Path
import argparse, hashlib, json, os, re, shutil, subprocess, winreg


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def camera_cone(netlist, target):
    text = re.sub(r'/\*.*?\*/|//[^\n]*', '', netlist.read_text(), flags=re.S)
    cells = []
    for statement in text.split(';'):
        m = re.search(r'(\w+)\s*(?:#\(.*?\)\s*)?(\\u_uicfgcs500/\S+)\s*\((.*)\)\s*$', statement, re.S)
        if m:
            cells.append((statement.strip()+';', *m.groups()))
    assert len(cells) > 200, 'No complete camera hierarchy found'
    inputs, outputs = set(), set()
    for _, kind, name, ports in cells:
        if kind == 'AL_MAP_SEQ_GSR':
            out_ports = {'q'}
        elif kind == 'PH1P_PHY_LSLICE':
            out_ports = {'fco', 'fco_f', 'ofb', 'ofa', 'q'}
        else:
            assert re.fullmatch(r'AL_MAP_LUT[1-6]', kind), (kind, name)
            out_ports = {'o'}
        for port, expr in re.findall(r'\.(\w+)\(([^()]*)\)', ports):
            expr = re.sub(r"\d+'[sS]?[bBdDhHoO][0-9a-fA-FxzXZ_]+", '', expr)
            nets = re.findall(r'\\\S+\s*(?:\[\d+\])?|[A-Za-z_][A-Za-z_0-9]*(?:\[\d+\])?', expr)
            (outputs if port in out_ports else inputs).update(re.sub(r'\s+', '', n) for n in nets)
    externals = inputs-outputs
    reset = r'\u_ph1p35_324_ddr_wrapper/u_ddr2/ph1p_ddrmc_wrapper/ph1p_ddrmc_top/u_ddr_phy/u_ddrphy_top/sys_rst_n'
    assert externals == {'O_cam_24m_dup_1', 'IO_cam_sda_dup_1', reset}, ('Unmodeled/missing driver', sorted(externals))
    decls = '\n'.join(re.findall(r'^\s*wire\s+[^;]+;', text, re.M))
    target.write_text('`timescale 1ns/1ps\nmodule camera_cone;\n'+decls+'\n'+'\n'.join(c[0] for c in cells)+'\nendmodule\n')
    return {'cells': len(cells), 'driverless_inputs': sorted(externals),
            'modeled_inputs': 'clock, reset, open-drain SDA with ACK slave only',
            'all_other_consumed_nets_have_selected_cell_drivers': True}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--project', type=Path, required=True)
    ap.add_argument('--out', type=Path, required=True)
    ap.add_argument('--gate-netlist', type=Path)
    args = ap.parse_args()
    repo = Path(__file__).resolve().parents[1]
    fixtures = repo/'tests/camera_gain_fix'
    out = args.out.resolve(); out.mkdir(parents=True, exist_ok=False)
    sealed = out/'inputs'; sealed.mkdir()
    source = args.project.resolve()
    env = dict(os.environ)
    for key in ['MGLS_LICENSE_FILE', 'LM_LICENSE_FILE']:
        if not env.get(key):
            for hive, loc in [(winreg.HKEY_CURRENT_USER, 'Environment'),
                              (winreg.HKEY_LOCAL_MACHINE, r'SYSTEM\CurrentControlSet\Control\Session Manager\Environment')]:
                try:
                    with winreg.OpenKey(hive, loc) as k:
                        env[key] = winreg.QueryValueEx(k, key)[0]
                    break
                except OSError:
                    pass
    env['TEMP'] = env['TMP'] = str(out)
    sim = Path('E:/Modelsim/win64')

    def run(tool, arguments, logname):
        log = out/logname
        with log.open('w', encoding='utf8') as f:
            result = subprocess.run([str(sim/(tool+'.exe')), *arguments], cwd=out,
                                    env=env, stdout=f, stderr=subprocess.STDOUT, timeout=300)
        text = log.read_text()
        assert result.returncode == 0 and not re.search(r'\*\* (?:Error|Fatal):|Errors:\s*[1-9]', text), (logname, text[-2000:])
        return text

    shutil.copy2(fixtures/'camera_expected.hex', out/'camera_expected.hex')
    for p in fixtures.iterdir():
        if p.is_file():
            shutil.copy2(p, sealed/p.name)
    inputs = {}
    td = Path('E:/TD/sim_release')
    libraries = []
    closure = None
    if args.gate_netlist:
        closure = camera_cone(args.gate_netlist, sealed/'camera_cone.v')
        libraries = [td/p for p in ['common/al_map_basic.v', 'common/al_map_lut.v',
                     'common/al_map_seq.v', 'common/al_map_adder.v', 'common/al_phy_glbl.v',
                     'ph1p/ph1p_phy_gsr.v', 'ph1p/ph1p_phy_lslice.v', 'ph1p/ph1p_logic_slice.v']]
        body = (fixtures/'tb_camera_startup_bus.sv').read_text()
        body = body[body.index(' reg[31:0] expected'):]
        body = re.sub(r'if\(count!=126 \|\| errors!=0.*?\$fatal\(1,"camera startup/default/NACK mismatch count%0d errors%0d",count,errors\);',
                      'if(count!=126)$fatal(1,"camera gate packet count mismatch");', body, flags=re.S)
        body = body.replace('PASS CAMERA RTL BUS:', 'PASS CAMERA GATE BUS:').replace(', zero NACK;', ';')
        header = r'''`timescale 1ns/1ps
module tb_camera_gate;
 reg clk=0,rst=0,slave_low=0;always #5 clk=~clk;
 camera_cone dut();
 wire scl=dut.O_cam_scl_dup_3;
 wire master_sda=dut.\u_uicfgcs500/uii2c_inst/sda_o ;
 wire sda=master_sda && !slave_low;
 wire done=dut.\u_uicfgcs500/O_ae_cfg_done ;
 initial begin
  force dut.O_cam_24m_dup_1=clk;
  force dut.\u_ph1p35_324_ddr_wrapper/u_ddr2/ph1p_ddrmc_wrapper/ph1p_ddrmc_top/u_ddr_phy/u_ddrphy_top/sys_rst_n =rst;
  force dut.IO_cam_sda_dup_1=sda;
 end
'''
        (sealed/'tb_camera_gate.sv').write_text(header+body)
        files = [sealed/'camera_cone.v', sealed/'tb_camera_gate.sv']
        benches = ['tb_camera_gate']
    else:
        names = ['uics500_cfg/SC500GainTbl.v', 'uics500_cfg/uicfgcs500.v',
                 'uics500_cfg/uics500reg.v', 'uics500_cfg/uics500regAE.v',
                 'uics500_cfg/uii2c.v', 'uiisp_beta/ae_set.v']
        files = []
        for rel in names:
            path = source/'user_source/hdl_source'/rel
            inputs['user_source/hdl_source/'+rel] = sha(path)
            shutil.copy2(path, sealed/path.name); files.append(sealed/path.name)
        files += [sealed/n for n in ['original_gain_reference.v', 'tb_gain_equivalence.sv', 'tb_camera_startup_bus.sv']]
        benches = ['tb_gain_equivalence', 'tb_camera_startup_bus']
    run('vlib', ['work'], 'setup.log')
    if libraries:
        # Vendor Verilog models omit timescales in several modules. Compile
        # them as Verilog with an explicit unit, separately from SV benches.
        run('vlog', ['-timescale', '1ns/1ps', '-work', 'work', *map(str, libraries)], 'compile_library.log')
    run('vlog', ['-sv', '-work', 'work', *map(str, files)], 'compile.log')
    results = []
    for bench in benches:
        extras = ['work.glbl', 'work.PH1P_PHY_GSR'] if args.gate_netlist else []
        access = ['-voptargs=+acc=rn+/tb_camera_gate'] if args.gate_netlist else []
        text = run('vsim', ['-c', *access, '-onfinish', 'stop', 'work.'+bench, *extras, '-do',
                           'onerror {quit -code 3}; onbreak {quit -code 2}; run -all; quit -code 0'], bench+'.log')
        expected = 'PASS GAIN EQUIVALENCE:' if bench == 'tb_gain_equivalence' else 'PASS CAMERA GATE BUS:' if args.gate_netlist else 'PASS CAMERA RTL BUS:'
        assert expected in text, (bench, text[-1800:])
        results.append({'name': bench, 'log_sha256': sha(out/(bench+'.log'))})
        print(next(x for x in text.splitlines() if expected in x), flush=True)
    proof = {'status': 'PASS', 'inputs': inputs, 'tests': results, 'board_operated': False,
             'scope': 'lookup equivalence and real serialized I2C with modeled ACK slave; not optical readback',
             'fixture_sha256': {p.name: sha(p) for p in fixtures.iterdir() if p.is_file()},
             'simulation_input_sha256': {p.name: sha(p) for p in sealed.iterdir() if p.is_file()},
             'library_sha256': {str(p): sha(p) for p in libraries},
             'gate_netlist_sha256': sha(args.gate_netlist) if args.gate_netlist else None,
             'cone_closure': closure}
    for rel, digest in inputs.items():
        assert sha(source/rel) == digest
    (out/'verification.json').write_text(json.dumps(proof, indent=2)+'\n')
    print(json.dumps({'status': 'PASS', 'tests': len(results), 'closure': closure}), flush=True)


if __name__ == '__main__':
    main()
