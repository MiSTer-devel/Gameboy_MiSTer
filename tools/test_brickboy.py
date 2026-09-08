#!/usr/bin/env python3
"""Run BrickBoy software/RTL regressions on Linux or WSL; no Quartus required."""
import argparse
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--python-only', action='store_true')
    args = parser.parse_args()
    subprocess.run([sys.executable, '-m', 'unittest', 'discover', '-s', 'tests',
                    '-p', 'test_brickboy_presets.py'], cwd=ROOT, check=True)
    if args.python_only:
        return
    if not shutil.which('verilator'):
        parser.error('Install Verilator and a C++ toolchain; run this script in Linux/WSL.')
    logs = ROOT / '.brickboy-tests'
    logs.mkdir(exist_ok=True)
    suites = {
        'brick_banked_tb': ['rtl/brickboy/brick_settings.sv'],
        'brick_preset_tb': ['rtl/brickboy/brick_preset.sv'],
        'brick_raster_tb': sorted(str(p.relative_to(ROOT)) for p in (ROOT/'rtl/brickboy').glob('*.sv')),
    }
    # Builds stay within an exclusively created temporary directory. Reports
    # are retained locally; generated binaries never enter the source tree.
    with tempfile.TemporaryDirectory(prefix='brickboy-tests-') as temporary:
        for top, sources in suites.items():
            build = Path(temporary) / top
            command = ['verilator', '--binary', '--timing', '-j', '4',
                       '-Wno-fatal', '-Irtl/brickboy',
                       '--top-module', top, '--Mdir', str(build)]
            if top != 'brick_raster_tb':
                command += ['--unroll-count', '1', '-CFLAGS', '-O0']
            command += sources + [f'tests/{top}.sv']
            logfile = logs / f'{top}.log'
            print(f'Running {top} (log: {logfile})', flush=True)
            try:
                with logfile.open('w') as log:
                    log.write('Command: '+repr(command)+'\n'); log.flush()
                    subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, check=True)
                    subprocess.run([str(build/f'V{top}')], cwd=ROOT,
                                   stdout=log, stderr=subprocess.STDOUT, check=True)
            except subprocess.CalledProcessError:
                print('\n'.join(logfile.read_text().splitlines()[-30:]))
                raise
            for line in logfile.read_text().splitlines():
                if line.startswith('PASS:'):
                    print(line, flush=True)
    print('All active BrickBoy regressions passed.', flush=True)

if __name__ == '__main__':
    main()
