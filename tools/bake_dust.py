#!/usr/bin/env python3
"""Bake BrickBoy's seeded defects.slang dust decisions for MiSTer."""

import math
from pathlib import Path

W, H = 160, 144
SEED = 7.0


def shader_hash(x: float, y: float) -> float:
    value = math.sin(x * 127.1 + y * 311.7) * 43758.5453
    return value - math.floor(value)


def category(dn: float) -> int:
    if dn > 0.9875:  # visible at dust=.25, .50 and 1.0
        return 3
    if dn > 0.975:   # visible at dust=.50 and 1.0
        return 2
    if dn > 0.95:    # visible at dust=1.0
        return 1
    return 0


def main() -> None:
    out = Path(__file__).resolve().parents[1] / "rtl" / "brickboy" / "brick_dust_map.hex"
    ox, oy = SEED * 3.1, SEED * 5.7
    values = [category(shader_hash(x + ox, y + oy)) for y in range(H) for x in range(W)]
    packed = [sum(values[i + j] << (2 * j) for j in range(4))
              for i in range(0, len(values), 4)]
    out.write_text("\n".join(format(v, "02x") for v in packed) + "\n", encoding="ascii")
    print(f"wrote {out}: " + ", ".join(f"{v}={values.count(v)}" for v in range(4)))


if __name__ == "__main__":
    main()
