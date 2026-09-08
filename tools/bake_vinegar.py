"""Bake source-authentic BrickBoy Vinegar fields into MiSTer ROMs.

Centre uses the original seed-7 field at native-dot nodes. Blobs stores three
unit-seed layouts (3, 7, 9) at half-native nodes; these broad fields are expanded
bilinearly by RTL to keep the complete layouts within the DE10-Nano's M10Ks.
"""
import math
from pathlib import Path

W, H = 160, 144
DEPTHS = (0.25, 0.50, 1.00)
CENTRE_SEED = 7.0
SEEDS = (3.0, 7.0, 9.0)


def fract(x): return x - math.floor(x)
def mix(a, b, t): return a + (b - a) * t
def clamp(x, a, b): return min(max(x, a), b)
def smoothstep(a, b, x):
    t = clamp((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def hsh(x, y): return fract(math.sin(x * 127.1 + y * 311.7) * 43758.5453)


def vnoise(x, y):
    ix, iy = math.floor(x), math.floor(y)
    fx, fy = fract(x), fract(y)
    fx, fy = fx * fx * (3.0 - 2.0 * fx), fy * fy * (3.0 - 2.0 * fy)
    a, b = hsh(ix, iy), hsh(ix + 1, iy)
    c, d = hsh(ix, iy + 1), hsh(ix + 1, iy + 1)
    return mix(mix(a, b, fx), mix(c, d, fx), fy)


def fbm(x, y):
    value, amp = 0.0, 0.5
    for _ in range(4):
        value += amp * vnoise(x, y)
        x, y, amp = x * 2.0, y * 2.0, amp * 0.5
    return value


def opacity(px, py, depth, mode, seed):
    # Exact FRAG_DEFECTS equations and the original four-native-dot margin.
    ux, uy = (px + 4.0) / 168.0, 1.0 - (py + 4.0) / 152.0
    cover = 0.0
    if mode == 1:
        dx, dy = abs(ux - 0.5) * 2.0, abs(uy - 0.5) * 2.0
        dist = (dx ** 2.6 + dy ** 2.6) ** (1.0 / 2.6) * 0.5
        wob = 0.045 * (fbm((ux - 0.5) * 5.0 + seed,
                           (uy - 0.5) * 5.0 + seed) - 0.5)
        front = depth * 0.66
        cover = 1.0 - smoothstep(front - 0.16 + wob, front + wob, dist)
        cover *= mix(1.0, 0.5, clamp(dist / max(front, 1e-3), 0.0, 1.0))
    else:
        for i in range(4):
            sx = hsh(seed + i * 3.1, 7.0)
            sy = hsh(seed + i * 5.7, 13.0)
            cx, cy = 0.5 + (sx - 0.5) * 0.7, 0.5 + (sy - 0.5) * 0.7
            thresh = 0.08 + i * 0.22
            grow = smoothstep(thresh, min(thresh + 0.5, 1.0), depth)
            if grow <= 0.0:
                continue
            dx, dy = (ux - cx) * (160.0 / 144.0), uy - cy
            ang = math.atan2(dy, dx)
            ragged = 0.45 + 0.55 * fbm(ang * 1.7 + sx * 9.0,
                                       ang * 0.6 + sy * 9.0)
            rad = (0.09 + 0.30 * grow) * ragged
            cover = max(cover, 1.0 - smoothstep(rad * 0.55, rad,
                                                math.hypot(dx, dy)))
    op = cover * (0.45 + 0.5 * cover) * clamp(depth * 1.3, 0.0, 0.94)
    return int(round(clamp(op, 0.0, 0.94) * 256.0))


def write_banks(out_dir, stem, maps, width, height):
    for px, py, suffix in ((0, 0, "ee"), (1, 0, "eo"),
                           (0, 1, "oe"), (1, 1, "oo")):
        out = out_dir / f"brick_vinegar_{stem}_{suffix}.hex"
        words = 0
        with out.open("w", newline="\n") as f:
            for m in maps:
                for y in range(py, height + 1, 2):
                    for x in range(px, width + 1, 2):
                        f.write(f"{m[y][x]:02x}\n")
                        words += 1
        print(f"wrote {words} 8-bit words to {out}")


def main():
    centre = [[[opacity(x, y, d, 1, CENTRE_SEED) for x in range(W + 1)]
               for y in range(H + 1)] for d in DEPTHS]
    half_w, half_h = W // 2, H // 2
    # Seed-major, then Mild/Strong/Ruined, matching the RTL selector.
    blobs = []
    for seed in SEEDS:
        for depth in DEPTHS:
            blobs.append([[opacity(x * 2, y * 2, depth, 0, seed)
                           for x in range(half_w + 1)]
                          for y in range(half_h + 1)])
    out_dir = Path(__file__).parents[1] / "rtl" / "brickboy"
    write_banks(out_dir, "centre", centre, W, H)
    write_banks(out_dir, "blob", blobs, half_w, half_h)


if __name__ == "__main__":
    main()
