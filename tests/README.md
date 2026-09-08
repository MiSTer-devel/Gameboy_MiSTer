# BrickBoy regression tests

From the repository root on Linux or WSL, with Python 3, Verilator (tested with
5.020), Make and a C++ compiler:

```sh
python3 tools/test_brickboy.py
```

No ROM, network connection, MiSTer, or Quartus installation is needed. Logs are
retained in `.brickboy-tests/` (ignored by Git); temporary builds are cleaned up.
For software/schema tests only: `python3 tools/test_brickboy.py --python-only`.
Existing imported RTL warnings are nonfatal; compilation failures and testbench
assertions still fail the command.

| Suite | Coverage |
| --- | --- |
| Python preset tests | 1,000 seeded round trips, corruption at every byte, sizes/bounds, all option connections and menu-bank coverage |
| Banked editor | Ascending 16-bit status transfers, independent banks, rapid navigation, invalid section recovery, native status preservation, notification arbitration, actions and preset restore |
| Preset controller | Read/write round trip, stable write snapshot, checksum/truncated/reserved-bit rejection, read-only/size guards, unrelated buffer traffic, timeout and mid-read remount |
| Raster | 896 clocks/line, 561,792 clocks/frame, 640×576 active area while effect inputs change, three-cycle Vinegar bypass |

These are module-level simulations. They do not run MiSTer Main, a real HPS SD
transfer, the CPU/game workload, or physical HDMI/analog output. Hardware
regressions remain required. The retained Vinegar reference benches concern
the imported optional implementation and are not part of the active no-Vinegar
integration suite.

## FPGA build

The root Quartus project is `Gameboy`. The measured build used Quartus Lite
17.0.0, the existing QSF/device/seed, and these stages:

```sh
quartus_sh -t sys/build_id.tcl quartus_map Gameboy Gameboy
quartus_map Gameboy
quartus_fit Gameboy
quartus_sta Gameboy
quartus_asm Gameboy
```

Inspect `output_files/Gameboy.sta.summary` for negative slack before using the
RBF: a tool exit code alone is not timing sign-off. Keep generated output and
Quartus-expanded QSF assignments out of the PR. See `BASELINE_COMPARISON.md`
for the completed build results and preserved summaries.
