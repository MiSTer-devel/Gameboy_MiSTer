#!/usr/bin/env python3
"""Bake selectable BrickBoy dead-line edge, row and stuck-dark masks."""

import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SEED = 7
SD = SEED * 1013
SEV = (0.0, 0.032770, 0.065539, 0.4735)
EDGE = (1.0, 0.0, 0.25, 0.50)
ROWS = (0.15, 0.0, 0.50, 1.0)
LIT = (0.06, 0.0, 0.25, 0.50)
MASK32 = 0xFFFFFFFF


def mix32(value: int) -> int:
    value &= MASK32
    value ^= value >> 16
    value = (value * 0x7FEB352D) & MASK32
    value ^= value >> 15
    value = (value * 0x846CA68B) & MASK32
    return (value ^ (value >> 16)) & MASK32


def rand(a: int, b: int) -> float:
    return mix32(((a & MASK32) * 0x9E3779B9 & MASK32) ^ mix32(b)) / 4294967296.0


def noise(t: float, salt: int) -> float:
    i = math.floor(t)
    f = t - i
    f = f * f * (3.0 - 2.0 * f)
    return rand(i, salt) + (rand(i + 1, salt) - rand(i, salt)) * f


def edge_weight(index: int, span: int, bias: float) -> float:
    x = index / (span - 1.0)
    length, amp, base, mean = 0.14, 0.230, 0.040, 0.10435
    weight = amp * (math.exp(-x / length) + math.exp(-(1.0 - x) / length)) + base
    return 1.0 + (weight / mean - 1.0) * bias


def col_dead(index: int, severity: float, edge: float) -> bool:
    u = rand(index, SD ^ 23473)
    clump = min(max(0.35 + 1.3 * noise(index * 0.18, SD ^ 7991), 0.0), 2.0)
    return u < severity * 0.94 * edge_weight(index, 160, edge) * clump


def row_dead(index: int, severity: float, ratio: float) -> bool:
    u = rand(index, SD ^ 55127)
    clump = min(max(0.35 + 1.3 * noise(index * 0.22, SD ^ 13109), 0.0), 2.0)
    return u < severity * 0.94 * ratio * clump


def shader_hash(x: float, y: float) -> float:
    value = math.sin(x * 127.1 + y * 311.7) * 43758.5453
    return value - math.floor(value)


def mask(span: int, predicate) -> int:
    value = 0
    for i in range(span):
        if predicate(i):
            value |= 1 << i
    return value


def emit(name: str, span: int, values, path: Path) -> None:
    width = (span + 3) // 4
    lines = [f"localparam bit [{span-1}:0] {name}[0:{len(values)-1}] = '{{"]
    for i, value in enumerate(values):
        lines.append(f"  {span}'h{value:0{width}x}" + ("," if i + 1 < len(values) else ""))
    lines.append("};")
    path.write_text("\n".join(lines) + "\n", encoding="ascii")


def emit_state(name: str, span: int, row: bool, path: Path) -> None:
    values = []
    for i in range(span):
        if row:
            drop = 0.86 + 0.14 * rand(i, SD ^ 60659)
            ga = 0.55 + 0.45 * shader_hash(i * 1.9, SEED + 6.0)
            gb = 0.55 + 0.45 * shader_hash(i * 2.7, SEED + 12.0)
        else:
            drop = 0.86 + 0.14 * rand(i, SD ^ 41221)
            ga = 0.55 + 0.45 * shader_hash(i * 1.7, SEED + 4.0)
            gb = 0.55 + 0.45 * shader_hash(i * 2.3, SEED + 8.0)
        d = round(drop * 127)
        a = round((ga - 0.55) / 0.45 * 15)
        b = round((gb - 0.55) / 0.45 * 15)
        values.append((a << 12) | (b << 8) | d)
    lines = [f"localparam bit [15:0] {name}[0:{span-1}] = '{{"]
    for i in range(0, span, 8):
        part = ", ".join(f"16'h{v:04x}" for v in values[i:i + 8])
        lines.append("  " + part + ("," if i + 8 < span else ""))
    lines.append("};")
    path.write_text("\n".join(lines) + "\n", encoding="ascii")


def main() -> None:
    cols = [mask(160, lambda i, e=e, s=s: col_dead(i, s, e))
            for e in EDGE for s in SEV]
    # Rows intentionally repeat across the edge selector: the source gives
    # horizontal failures independent salts and explicitly no edge bias.
    rows = [mask(144, lambda i, r=r, s=s: row_dead(i, s, r))
            for e in EDGE for r in ROWS for s in SEV]
    col_lit = [mask(160, lambda i, p=p: rand(i, SD ^ 9001) < p) for p in LIT]
    row_lit = [mask(144, lambda i, p=p: rand(i, SD ^ 24677) < p) for p in LIT]
    out = ROOT / "rtl" / "brickboy"
    emit("DL_COL_OPT", 160, cols, out / "brick_dl_col_opt.svh")
    emit("DL_ROW_OPT", 144, rows, out / "brick_dl_row_opt.svh")
    emit("DL_COL_LIT_OPT", 160, col_lit, out / "brick_dl_col_lit_opt.svh")
    emit("DL_ROW_LIT_OPT", 144, row_lit, out / "brick_dl_row_lit_opt.svh")
    emit_state("DL_COL_ST", 160, False, out / "brick_dl_col_st.svh")
    emit_state("DL_ROW_ST", 144, True, out / "brick_dl_row_st.svh")
    print("wrote selectable dead-line masks")


if __name__ == "__main__":
    main()
