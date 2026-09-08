#!/usr/bin/env python3
"""Create/inspect versioned BrickBoy .BBP preset artifacts (standard library only)."""
import argparse
import json
from pathlib import Path
import struct

FIELDS = {
  "panel_enabled": [
    126,
    1
  ],
  "speaker": [
    127,
    1
  ],
  "bright": [
    0,
    3
  ],
  "warm": [
    3,
    3
  ],
  "grain": [
    6,
    3
  ],
  "real": [
    9,
    1
  ],
  "grid": [
    10,
    2
  ],
  "fill": [
    12,
    2
  ],
  "gap": [
    14,
    2
  ],
  "density": [
    16,
    2
  ],
  "ink_r": [
    24,
    3
  ],
  "ink_g": [
    27,
    3
  ],
  "ink_b": [
    30,
    3
  ],
  "offtint": [
    33,
    2
  ],
  "refsat": [
    35,
    2
  ],
  "brightness": [
    37,
    2
  ],
  "contrast": [
    39,
    2
  ],
  "saturation": [
    41,
    2
  ],
  "gamma": [
    43,
    2
  ],
  "blacklift": [
    45,
    2
  ],
  "shadow": [
    48,
    2
  ],
  "gradient": [
    50,
    2
  ],
  "vignette": [
    52,
    2
  ],
  "matte": [
    54,
    2
  ],
  "depth": [
    56,
    2
  ],
  "blur": [
    58,
    2
  ],
  "ghost": [
    72,
    2
  ],
  "gate": [
    74,
    2
  ],
  "ghost_gamma": [
    76,
    2
  ],
  "bleed": [
    78,
    2
  ],
  "xtalk": [
    80,
    2
  ],
  "xtnoise": [
    82,
    2
  ],
  "xtedge": [
    84,
    2
  ],
  "cold": [
    86,
    2
  ],
  "dimming": [
    96,
    2
  ],
  "frontlight": [
    98,
    2
  ],
  "backlight": [
    100,
    2
  ],
  "contrast_fade": [
    102,
    2
  ],
  "dust": [
    104,
    2
  ],
  "deadline": [
    106,
    2
  ],
  "flicker": [
    108,
    2
  ],
  "dead_edge": [
    110,
    2
  ],
  "dead_lit": [
    112,
    2
  ],
  "dead_rows": [
    114,
    2
  ]
}
MASK = sum(((1 << width) - 1) << offset for offset, width in FIELDS.values())

def encode(settings):
    unknown = set(settings) - FIELDS.keys()
    if unknown:
        raise ValueError("Unknown options: " + ", ".join(sorted(unknown)))
    value = 0
    for name, (offset, width) in FIELDS.items():
        item = settings.get(name, 0)
        if not isinstance(item, int) or not 0 <= item < (1 << width):
            raise ValueError(f"{name}: expected integer 0..{(1 << width)-1}")
        value |= item << offset
    header = b"BBP1" + struct.pack("<HH", 1, 16) + value.to_bytes(16, "little")
    checksum = (~sum(struct.unpack("<12H", header))) & 0xffff
    return header + struct.pack("<H", checksum) + bytes(486)

def decode(data):
    if len(data) != 512:
        raise ValueError("Preset must be exactly 512 bytes")
    if data[:8] != b"BBP1" + struct.pack("<HH", 1, 16):
        raise ValueError("Unknown preset signature/version/length")
    if (sum(struct.unpack("<256H", data)) & 0xffff) != 0xffff or any(data[26:]):
        raise ValueError("Bad checksum or reserved bytes")
    value = int.from_bytes(data[8:24], "little")
    if value & ~MASK:
        raise ValueError("Unknown/reserved option bits")
    return {name: (value >> offset) & ((1 << width)-1)
            for name, (offset, width) in FIELDS.items()}

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("command", choices=("create", "inspect"))
    p.add_argument("preset", type=Path)
    p.add_argument("--settings", type=Path, help="JSON option indices; omitted fields default to zero")
    args = p.parse_args()
    if args.command == "inspect":
        print(json.dumps(decode(args.preset.read_bytes()), indent=2))
    else:
        settings = json.loads(args.settings.read_text()) if args.settings else {}
        data = encode(settings)
        # Never silently overwrite an existing preset.
        with args.preset.open("xb") as target:
            target.write(data)
        print(f"Created {args.preset}: {len(data)} bytes")

if __name__ == "__main__":
    main()
