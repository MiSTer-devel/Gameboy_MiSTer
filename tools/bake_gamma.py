#!/usr/bin/env python3
"""Bake selectable BrickBoy colour and persistence gamma tables."""

import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COLOR_GAMMAS = (1.10, 1.00, 1.50, 2.00)
GHOST_GAMMAS = (2.20, 1.00, 1.60, 3.00)


def q(value: float, maximum: int) -> int:
    return min(max(int(round(value * maximum)), 0), maximum)


def main() -> None:
    color = [q((i / 255.0) ** gamma, 255)
             for gamma in COLOR_GAMMAS for i in range(256)]
    forward = [q((i / 255.0) ** gamma, 65535)
               for gamma in GHOST_GAMMAS for i in range(256)]
    inverse_pairs = []
    for gamma in GHOST_GAMMAS:
        for i in range(512):
            lo = q(((i << 7) / 65535.0) ** (1.0 / gamma), 255)
            hi_i = min((i + 1) << 7, 65535)
            hi = q((hi_i / 65535.0) ** (1.0 / gamma), 255)
            inverse_pairs.append((hi << 8) | lo)

    targets = (
        ("brick_color_gamma.hex", color, "02x"),
        ("brick_ghost_fwd.hex", forward, "04x"),
        ("brick_ghost_inv.hex", inverse_pairs, "04x"),
    )
    for name, values, fmt in targets:
        path = ROOT / "rtl" / "brickboy" / name
        path.write_text("\n".join(format(v, fmt) for v in values) + "\n", encoding="ascii")
        print(f"wrote {path}: {len(values)} entries")


if __name__ == "__main__":
    main()
