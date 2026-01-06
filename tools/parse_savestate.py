#!/usr/bin/env python3
"""
Parse MiSTer Gameboy savestate and extract VRAM tile hashes.
"""

import sys
from pathlib import Path


def crc16_ccitt(data: bytes, init: int = 0xFFFF) -> int:
    """CRC-16-CCITT - matches RTL tile_hash_generator.sv"""
    crc = init
    for byte in data:
        crc ^= (byte << 8)
        for _ in range(8):
            if crc & 0x8000:
                crc = ((crc << 1) ^ 0x1021) & 0xFFFF
            else:
                crc = (crc << 1) & 0xFFFF
    return crc


def tile_to_ascii(tile_data: bytes) -> list[str]:
    """Convert 16-byte tile to ASCII art lines."""
    chars = [' ', '.', '+', '#']
    lines = []
    for row in range(8):
        low = tile_data[row * 2]
        high = tile_data[row * 2 + 1]
        line = ""
        for bit in range(7, -1, -1):
            pixel = ((high >> bit) & 1) << 1 | ((low >> bit) & 1)
            line += chars[pixel]
        lines.append(line)
    return lines


def is_interesting_tile(tile_data: bytes) -> bool:
    """Check if tile has meaningful content (not empty, not solid)."""
    if all(b == 0 for b in tile_data):
        return False
    if all(b == 0xFF for b in tile_data):
        return False
    # Check for some variation
    unique = len(set(tile_data))
    return unique >= 2


def main():
    if len(sys.argv) < 2:
        print("Usage: parse_savestate.py <savestate.ss> [vram_offset]")
        sys.exit(1)

    ss_path = Path(sys.argv[1])
    data = ss_path.read_bytes()

    # Try to find VRAM - typically at a known offset
    # MiSTer GB savestate format varies, let's search for tile-like data

    # Common VRAM offsets to try
    vram_offsets = [0x8200, 0x8000, 0x2000, 0x4000, 0x10000]

    if len(sys.argv) >= 3:
        vram_offsets = [int(sys.argv[2], 0)]

    for vram_offset in vram_offsets:
        print(f"\n=== Trying VRAM offset 0x{vram_offset:04X} ===")

        if vram_offset + 0x1800 > len(data):
            print(f"  Offset too large for file size {len(data)}")
            continue

        # GB VRAM tile data: 0x8000-0x97FF (6144 bytes = 384 tiles)
        # We'll extract from the savestate's VRAM section
        vram_tiles = data[vram_offset:vram_offset + 0x1800]  # 6KB of tile data

        hashes = []
        tiles_info = []

        for i in range(0, len(vram_tiles), 16):
            tile = vram_tiles[i:i+16]
            if len(tile) < 16:
                break

            tile_hash = crc16_ccitt(tile)
            tile_idx = i // 16

            if is_interesting_tile(tile):
                hashes.append(tile_hash)
                tiles_info.append((tile_idx, tile_hash, tile))

        print(f"  Found {len(hashes)} interesting tiles")

        if len(hashes) > 20:
            print(f"\n  First 20 tile hashes:")
            for idx, h, tile in tiles_info[:20]:
                ascii_art = tile_to_ascii(tile)
                print(f"    Tile {idx:3d}: {h:04X}  {ascii_art[0]} {ascii_art[1]}")

            # Print all hashes in a compact format
            print(f"\n  All {len(hashes)} hashes (for copy/paste):")
            for i in range(0, len(hashes), 16):
                chunk = hashes[i:i+16]
                print("    " + " ".join(f"{h:04X}" for h in chunk))

            # Try to identify katakana region (usually tiles 0x80-0xFF or similar)
            print(f"\n  Potential font tiles (indices 0x80-0xFF):")
            font_tiles = [(idx, h, t) for idx, h, t in tiles_info if 0x80 <= idx < 0x100]
            for idx, h, tile in font_tiles[:30]:
                ascii_art = tile_to_ascii(tile)
                print(f"    Tile 0x{idx:02X}: {h:04X}")
                for line in ascii_art:
                    print(f"      |{line}|")

            break  # Found good data, stop trying other offsets


if __name__ == "__main__":
    main()
