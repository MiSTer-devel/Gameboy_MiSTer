# Credits and attribution

This experimental Gameboy_MiSTer branch imports the optional BrickBoy DMG panel
experience from the independent BrickBoy MiSTer port. This file identifies the upstream projects,
authors, and generated assets included in or used by the repository.

## BrickBoy

- **BrickBoy DMG FPGA core** — Kathoc, [kathoc/brickboy-dmg-fpgacore](https://github.com/kathoc/brickboy-dmg-fpgacore).
  The panel, reflector, speaker, and display-model work in `rtl/brickboy/` is
  derived from this project and is distributed under its GPL-3.0-or-later
  terms.
- **BrickBoy software shader reference** — Kathoc,
  [kathoc/brickboy-dmg-shader](https://github.com/kathoc/brickboy-dmg-shader).
  The colour, optics, ageing, STN, dead-line, dust, and Vinegar equations are
  based on the published shader specification. The fixed-point ROM generators
  in `tools/` are port-specific generated-data tooling; they do not replace
  the upstream shader attribution.

## MiSTer and Game Boy foundations

- **MiSTer Gameboy core and platform integration** — the
  [MiSTer-devel/Gameboy_MiSTer](https://github.com/MiSTer-devel/Gameboy_MiSTer)
  project and its contributors.
- **Game Boy core origins** — Till Harbaum and Sorgelig, as identified in
  `Gameboy.sv`, `rtl/gb.v`, `rtl/video.v`, `rtl/sprites.v`, and the associated
  source headers.
- **MiSTer platform support** — Sorgelig, Alexey Melnikov, Grabulosaure,
  bellwood420, Mike Simone, and the other copyright holders named in the
  headers under `sys/` and `rtl/`. Those notices remain in the individual
  source files and are part of this distribution.

## Third-party components

- **T80 Z80-compatible CPU** — Daniel Wallner, OpenCores, in `rtl/T80/`.
  The original BSD-style license and copyright notice are retained in the
  VHDL files.
- **hq2x scaler** — Ludvig Strigeus and subsequent MiSTer contributors, in
  `sys/hq2x.sv`; see its source header for the applicable license and notices.
- **Intel/Altera generated PLL sources** — Intel Corporation, in `rtl/pll.v`,
  `sys/pll_audio.v`, `sys/pll_cfg/`, and `sys/pll_hdmi.v`. These files retain
  the generated-source notices supplied by Quartus.
- **SameBoy boot ROM sources** — LIJI32 and SameBoy contributors. The open
  bootstrap ROM sources and their MIT license are documented in
  [`BootROMs/README.md`](BootROMs/README.md); the original notices remain with
  those assets.
- **Quartus Prime** — Intel FPGA development tools are used to synthesize and
  assemble test/release RBFs. Quartus is not bundled with this repository.

## This port

The imported MiSTer-specific work—including the `GAMEBOY` content-folder integration,
BrickBoy OSD controls, fixed-point shader ROM generation, Vinegar seed-layout
selection, randomize/reset actions, timing closure, release packaging, and
documentation—comes from **kandowontu and
contributors** in [BrickBoy_MiSTer](https://github.com/kandowontu/BrickBoy_MiSTer).

The current Gameboy_MiSTer integration adds the banked **BrickBoy Mods** editor,
versioned preset storage, status-notification arbitration, and regression tests.
Vinegar source/reference assets are retained for provenance but are not
instantiated by this integration. No ROM or proprietary firmware is added by
the BrickBoy changes.

No endorsement by Kathoc, MiSTer-devel, SameBoy, OpenCores, Intel, or any
other upstream project is implied. This repository is not an official release
of those projects.

## License summary

The combined GPL-covered source distribution is provided under
[`rtl/brickboy/LICENSE`](rtl/brickboy/LICENSE), subject to the original license terms and notices of
the included third-party components. Individual files may carry more specific
license terms; those terms take precedence for the relevant file or asset.
