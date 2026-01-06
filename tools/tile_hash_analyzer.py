#!/usr/bin/env python3
"""
Tile Hash Analyzer for GB/GBA Translation Overlay

Computes CRC-16-CCITT hashes for GB tile data, matching the RTL implementation.
Used to build translation dictionaries by mapping tile hashes to characters.

Usage:
    # Analyze ROM for potential font tiles
    uv run python tools/tile_hash_analyzer.py --rom ~/gaming/roms/GAMEBOY/medarot.gb --scan

    # Compute hash for specific tile data
    uv run python tools/tile_hash_analyzer.py --hex "00 00 7E 7E 42 42 42 42 42 42 42 42 7E 7E 00 00"

    # Interactive mode - enter hashes seen on screen
    uv run python tools/tile_hash_analyzer.py --interactive
"""

import argparse
import struct
from pathlib import Path


def crc16_ccitt(data: bytes, init: int = 0xFFFF) -> int:
    """
    CRC-16-CCITT (polynomial 0x1021) - matches RTL tile_hash_generator.sv

    This is the same algorithm used in the FPGA:
    - Polynomial: x^16 + x^12 + x^5 + 1 (0x1021)
    - Initial value: 0xFFFF
    - No final XOR
    - MSB first processing
    """
    crc = init
    for byte in data:
        crc ^= (byte << 8)
        for _ in range(8):
            if crc & 0x8000:
                crc = ((crc << 1) ^ 0x1021) & 0xFFFF
            else:
                crc = (crc << 1) & 0xFFFF
    return crc


def tile_to_pixels(tile_data: bytes) -> list[list[int]]:
    """
    Convert GB 2bpp tile (16 bytes) to 8x8 pixel array.
    Each pixel is 0-3 representing the palette index.
    """
    if len(tile_data) != 16:
        raise ValueError(f"Tile must be 16 bytes, got {len(tile_data)}")

    pixels = []
    for row in range(8):
        low_byte = tile_data[row * 2]
        high_byte = tile_data[row * 2 + 1]
        row_pixels = []
        for bit in range(7, -1, -1):
            low_bit = (low_byte >> bit) & 1
            high_bit = (high_byte >> bit) & 1
            pixel = (high_bit << 1) | low_bit
            row_pixels.append(pixel)
        pixels.append(row_pixels)
    return pixels


def print_tile(tile_data: bytes, label: str = ""):
    """Print ASCII art representation of a tile."""
    pixels = tile_to_pixels(tile_data)
    chars = [' ', '░', '▒', '█']  # 0=transparent, 3=darkest

    if label:
        print(f"--- {label} ---")
    print("┌────────┐")
    for row in pixels:
        print("│" + "".join(chars[p] for p in row) + "│")
    print("└────────┘")


def scan_rom_for_fonts(rom_path: Path, min_nonzero: int = 4) -> list[tuple[int, int, bytes]]:
    """
    Scan ROM for potential font tiles.
    Returns list of (offset, hash, tile_data) tuples.

    Heuristics for font detection:
    - Tiles with moderate complexity (not all zeros, not random noise)
    - Sequential tiles (fonts are usually stored together)
    """
    rom_data = rom_path.read_bytes()
    results = []

    # GB tiles are 16 bytes each
    for offset in range(0, len(rom_data) - 16, 16):
        tile = rom_data[offset:offset + 16]

        # Skip empty tiles
        if all(b == 0 for b in tile):
            continue

        # Skip tiles with too few unique bytes (likely not font)
        unique_bytes = len(set(tile))
        if unique_bytes < min_nonzero:
            continue

        tile_hash = crc16_ccitt(tile)
        results.append((offset, tile_hash, tile))

    return results


def find_font_regions(tiles: list[tuple[int, int, bytes]], min_consecutive: int = 20) -> list[tuple[int, int]]:
    """Find regions with consecutive non-empty tiles (likely font data)."""
    if not tiles:
        return []

    regions = []
    region_start = tiles[0][0]
    last_offset = tiles[0][0]

    for offset, _, _ in tiles[1:]:
        if offset - last_offset > 32:  # Gap of more than 2 tiles
            if (last_offset - region_start) // 16 >= min_consecutive:
                regions.append((region_start, last_offset + 16))
            region_start = offset
        last_offset = offset

    # Check last region
    if (last_offset - region_start) // 16 >= min_consecutive:
        regions.append((region_start, last_offset + 16))

    return regions


def interactive_mode():
    """Interactive mode for mapping hashes to characters."""
    print("=== Interactive Hash Mapper ===")
    print("Enter hashes seen on the MiSTer display (format: XXXX)")
    print("Then type the character that was on screen when you saw that hash.")
    print("Type 'save' to save mappings, 'quit' to exit.\n")

    mappings = {}

    while True:
        try:
            line = input("Hash (or command): ").strip().upper()
        except EOFError:
            break

        if line == 'QUIT':
            break
        elif line == 'SAVE':
            save_path = Path("tile_mappings.txt")
            with open(save_path, "w") as f:
                for h, char in sorted(mappings.items()):
                    f.write(f"{h:04X} {char}\n")
            print(f"Saved {len(mappings)} mappings to {save_path}")
            continue
        elif line == 'SHOW':
            print("\nCurrent mappings:")
            for h, char in sorted(mappings.items()):
                print(f"  {h:04X} -> '{char}'")
            print()
            continue

        try:
            hash_val = int(line, 16)
            if hash_val > 0xFFFF:
                print("Hash must be 16-bit (0000-FFFF)")
                continue
        except ValueError:
            print("Invalid hash format. Use hex (e.g., A1B2)")
            continue

        char = input(f"Character for hash {hash_val:04X}: ").strip()
        if char:
            mappings[hash_val] = char
            print(f"Mapped {hash_val:04X} -> '{char}'")


def generate_sv_lookup_table(mappings: dict[int, str], output_path: Path):
    """Generate SystemVerilog code for the hash lookup table."""
    lines = [
        "// Auto-generated hash lookup table",
        "// Format: {valid, hash[15:0], char_code[7:0], trans_ptr[15:0]}",
        "",
        "localparam NUM_ENTRIES = {};".format(len(mappings)),
        "",
        "// Hash table entries",
        "logic [40:0] hash_table [0:NUM_ENTRIES-1];",
        "",
        "initial begin",
    ]

    for i, (hash_val, char) in enumerate(sorted(mappings.items())):
        char_code = ord(char) if len(char) == 1 else ord('?')
        # Format: {valid, hash, char_code, trans_ptr}
        entry = f"    hash_table[{i}] = 41'h1_{hash_val:04X}_{char_code:02X}_0000;"
        lines.append(entry + f"  // '{char}'")

    lines.append("end")

    output_path.write_text("\n".join(lines))
    print(f"Generated {output_path}")


def main():
    parser = argparse.ArgumentParser(description="GB Tile Hash Analyzer")
    parser.add_argument("--rom", type=Path, help="Path to GB ROM file")
    parser.add_argument("--scan", action="store_true", help="Scan ROM for font tiles")
    parser.add_argument("--hex", type=str, help="Compute hash for hex tile data")
    parser.add_argument("--interactive", action="store_true", help="Interactive mapping mode")
    parser.add_argument("--offset", type=str, help="ROM offset to analyze (hex)")
    parser.add_argument("--count", type=int, default=10, help="Number of tiles to show")

    args = parser.parse_args()

    if args.hex:
        # Parse hex string and compute hash
        hex_bytes = bytes.fromhex(args.hex.replace(" ", ""))
        if len(hex_bytes) != 16:
            print(f"Error: Tile must be 16 bytes, got {len(hex_bytes)}")
            return

        tile_hash = crc16_ccitt(hex_bytes)
        print(f"Hash: {tile_hash:04X}")
        print_tile(hex_bytes)
        return

    if args.interactive:
        interactive_mode()
        return

    if args.rom:
        if not args.rom.exists():
            print(f"ROM file not found: {args.rom}")
            return

        if args.scan:
            print(f"Scanning {args.rom} for potential font tiles...")
            tiles = scan_rom_for_fonts(args.rom)
            print(f"Found {len(tiles)} non-empty tiles")

            regions = find_font_regions(tiles)
            print(f"\nPotential font regions (>= 20 consecutive tiles):")
            for start, end in regions:
                count = (end - start) // 16
                print(f"  0x{start:06X} - 0x{end:06X} ({count} tiles)")

            if regions:
                # Show first region
                start, end = regions[0]
                print(f"\nFirst {min(args.count, (end-start)//16)} tiles from 0x{start:06X}:")
                rom_data = args.rom.read_bytes()
                for i in range(min(args.count, (end-start)//16)):
                    offset = start + i * 16
                    tile = rom_data[offset:offset+16]
                    tile_hash = crc16_ccitt(tile)
                    print(f"\nOffset 0x{offset:06X}, Hash: {tile_hash:04X}")
                    print_tile(tile)

        elif args.offset:
            offset = int(args.offset, 16)
            rom_data = args.rom.read_bytes()
            print(f"Tiles starting at 0x{offset:06X}:")
            for i in range(args.count):
                tile_offset = offset + i * 16
                if tile_offset + 16 > len(rom_data):
                    break
                tile = rom_data[tile_offset:tile_offset+16]
                tile_hash = crc16_ccitt(tile)
                print(f"\nOffset 0x{tile_offset:06X}, Hash: {tile_hash:04X}")
                print_tile(tile)


if __name__ == "__main__":
    main()
