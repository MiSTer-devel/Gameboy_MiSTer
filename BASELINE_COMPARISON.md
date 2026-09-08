# Upstream versus BrickBoy Mods

Measured from completed fits using Quartus Lite 17.0.0 Build 595, Cyclone V
`5CSEBA6U23I7`, seed 1, and upstream project settings. Both use source base
`7a5ff50528cd9c1d13ffb675e7df8506bffaa078` and build date `260908`.
The baseline has no HDL modifications; the candidate includes the banked
42-control editor and preset storage, with Vinegar disabled.

| Resource | Capacity | Upstream | BrickBoy Mods | Increase | Free |
| --- | ---: | ---: | ---: | ---: | ---: |
| ALMs | 41,910 | 21,617 | 33,964 | 12,347 | 7,946 |
| M10Ks | 553 | 401 | 532 | 131 | 21 |
| DSPs | 112 | 35 | 77 | 42 | 35 |
| Registers | — | 27,784 | 37,405 | 9,621 | — |
| Block-memory bits | 5,662,720 | 3,125,941 | 4,083,121 | 957,180 | — |

RAM-block allocation, not merely stored bit count, limits headroom: 532/553
M10Ks are used. Turning an effect off in the menu does not remove its hardware.
Net changes include whole-design packing/optimization differences, not just
the sum of isolated component costs.

| Worst configured timing slack | Upstream | BrickBoy Mods |
| --- | ---: | ---: |
| Setup | +0.593 ns | +0.561 ns |
| Hold | +0.178 ns | +0.245 ns |

All 36 candidate timing-summary checks have nonnegative slack. These results
cover the project's configured timing analysis; they do not establish
multicorner or hardware qualification. The original project QSF is unchanged.

## Evidence

- [Baseline fit](docs/brickboy/validation/baseline-fit.txt)
- [Baseline timing](docs/brickboy/validation/baseline-timing.txt)
- [Candidate fit](docs/brickboy/validation/brickboy-fit.txt)
- [Candidate timing](docs/brickboy/validation/brickboy-timing.txt)

Candidate fitter completed on 2026-09-08 at 14:49:16, after 25:01.
TimeQuest and assembly completed successfully. Test artifact:
`output_files/Gameboy.rbf`, 4,349,548 bytes.

SHA-256:
`b45378e6d29f611d0ee745ff5958ba411ca51c61a282c21be6315cc22664f820`.

Default preset: 512 bytes, SHA-256:
`df310790e3a834c785cecc3291465207aa2d461e3bded1ae4812c5095f9e347d`.

The RBF is a locally built test artifact, not an upstream release. It has been
deployed for user evaluation, but hardware pass/fail results are still pending.
PR preparation changes documentation/tests only; the deployed RTL is preserved.
