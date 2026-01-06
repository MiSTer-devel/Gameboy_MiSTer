#!/usr/bin/env python3
"""
Hash Mapper - Maps captured tile hashes to Japanese characters

Usage:
    # Start mapping session
    uv run python tools/hash_mapper.py --session medarot

    # Resume session
    uv run python tools/hash_mapper.py --load mappings/medarot.json

    # Generate RTL from mappings
    uv run python tools/hash_mapper.py --load mappings/medarot.json --generate-rtl
"""

import argparse
import json
from pathlib import Path
from typing import Dict, List, Optional

# Standard katakana grid as seen in many Japanese games
KATAKANA_GRID = [
    ['ア', 'イ', 'ウ', 'エ', 'オ'],
    ['カ', 'キ', 'ク', 'ケ', 'コ'],
    ['サ', 'シ', 'ス', 'セ', 'ソ'],
    ['タ', 'チ', 'ツ', 'テ', 'ト'],
    ['ナ', 'ニ', 'ヌ', 'ネ', 'ノ'],
    ['ハ', 'ヒ', 'フ', 'ヘ', 'ホ'],
    ['マ', 'ミ', 'ム', 'メ', 'モ'],
    ['ヤ', '(', 'ユ', ')', 'ヨ'],  # Some games use parens for empty slots
    ['ラ', 'リ', 'ル', 'レ', 'ロ'],
    ['ワ', 'ヲ', 'ン', 'ー', ' '],
]

# Romaji equivalents for display
KATAKANA_TO_ROMAJI = {
    'ア': 'A', 'イ': 'I', 'ウ': 'U', 'エ': 'E', 'オ': 'O',
    'カ': 'KA', 'キ': 'KI', 'ク': 'KU', 'ケ': 'KE', 'コ': 'KO',
    'サ': 'SA', 'シ': 'SHI', 'ス': 'SU', 'セ': 'SE', 'ソ': 'SO',
    'タ': 'TA', 'チ': 'CHI', 'ツ': 'TSU', 'テ': 'TE', 'ト': 'TO',
    'ナ': 'NA', 'ニ': 'NI', 'ヌ': 'NU', 'ネ': 'NE', 'ノ': 'NO',
    'ハ': 'HA', 'ヒ': 'HI', 'フ': 'FU', 'ヘ': 'HE', 'ホ': 'HO',
    'マ': 'MA', 'ミ': 'MI', 'ム': 'MU', 'メ': 'ME', 'モ': 'MO',
    'ヤ': 'YA', 'ユ': 'YU', 'ヨ': 'YO',
    'ラ': 'RA', 'リ': 'RI', 'ル': 'RU', 'レ': 'RE', 'ロ': 'RO',
    'ワ': 'WA', 'ヲ': 'WO', 'ン': 'N', 'ー': '-',
    # Dakuten variants
    'ガ': 'GA', 'ギ': 'GI', 'グ': 'GU', 'ゲ': 'GE', 'ゴ': 'GO',
    'ザ': 'ZA', 'ジ': 'JI', 'ズ': 'ZU', 'ゼ': 'ZE', 'ゾ': 'ZO',
    'ダ': 'DA', 'ヂ': 'DI', 'ヅ': 'DU', 'デ': 'DE', 'ド': 'DO',
    'バ': 'BA', 'ビ': 'BI', 'ブ': 'BU', 'ベ': 'BE', 'ボ': 'BO',
    'パ': 'PA', 'ピ': 'PI', 'プ': 'PU', 'ペ': 'PE', 'ポ': 'PO',
}


def load_mappings(path: Path) -> Dict[int, str]:
    """Load existing hash mappings from JSON file."""
    if path.exists():
        with open(path) as f:
            data = json.load(f)
            return {int(k, 16): v for k, v in data.items()}
    return {}


def save_mappings(mappings: Dict[int, str], path: Path):
    """Save hash mappings to JSON file."""
    path.parent.mkdir(parents=True, exist_ok=True)
    data = {f"{k:04X}": v for k, v in sorted(mappings.items())}
    with open(path, 'w') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print(f"Saved {len(mappings)} mappings to {path}")


def parse_hash_display(display: str) -> List[int]:
    """
    Parse hash display from MiSTer screenshot.
    Format: "NN XXXX XXXX XXXX XXXX" (count + 4 hashes)
    """
    parts = display.strip().upper().split()
    hashes = []
    for part in parts:
        if len(part) == 4:
            try:
                h = int(part, 16)
                if h != 0:  # Skip empty slots
                    hashes.append(h)
            except ValueError:
                pass
    return hashes


def interactive_session(session_name: str, mappings_dir: Path):
    """Interactive mode for mapping hashes to characters."""
    mappings_file = mappings_dir / f"{session_name}.json"
    mappings = load_mappings(mappings_file)

    print(f"=== Hash Mapper for {session_name} ===")
    print(f"Loaded {len(mappings)} existing mappings from {mappings_file}")
    print()
    print("Commands:")
    print("  <hash> <char>  - Map hash to character (e.g., 'A1B2 ア')")
    print("  paste <text>   - Parse hash display from screenshot")
    print("  show           - Show all mappings")
    print("  grid           - Show katakana reference grid")
    print("  unmapped       - Show captured but unmapped hashes")
    print("  save           - Save mappings")
    print("  gen            - Generate RTL lookup table")
    print("  quit           - Save and exit")
    print()

    captured_hashes = set(mappings.keys())

    while True:
        try:
            line = input("> ").strip()
        except (EOFError, KeyboardInterrupt):
            break

        if not line:
            continue

        parts = line.split(maxsplit=1)
        cmd = parts[0].lower()

        if cmd == 'quit':
            save_mappings(mappings, mappings_file)
            break

        elif cmd == 'save':
            save_mappings(mappings, mappings_file)

        elif cmd == 'show':
            print("\nCurrent mappings:")
            for h, char in sorted(mappings.items()):
                romaji = KATAKANA_TO_ROMAJI.get(char, char)
                print(f"  {h:04X} -> {char} ({romaji})")
            print(f"\nTotal: {len(mappings)} mappings")

        elif cmd == 'grid':
            print("\nKatakana reference:")
            for row in KATAKANA_GRID:
                print("  " + " ".join(row))
            print()

        elif cmd == 'unmapped':
            unmapped = captured_hashes - set(mappings.keys())
            if unmapped:
                print(f"\nUnmapped hashes ({len(unmapped)}):")
                for h in sorted(unmapped):
                    print(f"  {h:04X}")
            else:
                print("All captured hashes are mapped!")

        elif cmd == 'paste' and len(parts) > 1:
            text = parts[1]
            hashes = parse_hash_display(text)
            new_count = 0
            for h in hashes:
                if h not in captured_hashes:
                    captured_hashes.add(h)
                    new_count += 1
                    print(f"  New: {h:04X}")
            print(f"Added {new_count} new hashes, total captured: {len(captured_hashes)}")

        elif cmd == 'gen':
            generate_rtl(mappings, mappings_dir / f"{session_name}_lookup.sv")

        else:
            # Try to parse as "HASH CHAR" mapping
            try:
                if len(parts) == 2:
                    hash_str, char = parts
                    h = int(hash_str, 16)
                    if h > 0xFFFF:
                        print("Hash must be 16-bit (0000-FFFF)")
                        continue
                    mappings[h] = char
                    captured_hashes.add(h)
                    romaji = KATAKANA_TO_ROMAJI.get(char, char)
                    print(f"Mapped {h:04X} -> {char} ({romaji})")
                else:
                    print("Usage: <hash> <char> or use a command")
            except ValueError:
                print("Invalid hash format. Use hex (e.g., A1B2)")


def generate_rtl(mappings: Dict[int, str], output_path: Path):
    """Generate SystemVerilog lookup table from mappings."""
    lines = [
        "// Auto-generated hash lookup table",
        f"// Generated from {len(mappings)} character mappings",
        "// Format: {{valid[1], hash[16], char_code[8], trans_ptr[16]}}",
        "",
        f"localparam NUM_DICT_ENTRIES = {len(mappings)};",
        "",
        "// Initialize dictionary ROM",
        "initial begin",
    ]

    for i, (hash_val, char) in enumerate(sorted(mappings.items())):
        # Use Unicode code point for Japanese chars, ASCII for others
        char_code = ord(char) & 0xFF
        # For display purposes, we might want to map to ASCII approximations
        romaji = KATAKANA_TO_ROMAJI.get(char, char)
        ascii_char = romaji[0] if romaji else '?'
        ascii_code = ord(ascii_char)

        # Entry format: {valid, hash[15:0], char_code[7:0], trans_ptr[15:0]}
        entry = f"    dict_rom[{i}] = 41'h1_{hash_val:04X}_{ascii_code:02X}_0000;"
        lines.append(entry + f"  // {char} -> '{ascii_char}'")

    lines.append("end")
    lines.append("")

    output_path.write_text("\n".join(lines))
    print(f"Generated {output_path}")


def main():
    parser = argparse.ArgumentParser(description="Hash Mapper for translation overlay")
    parser.add_argument("--session", type=str, help="Start new mapping session")
    parser.add_argument("--load", type=Path, help="Load existing mappings file")
    parser.add_argument("--generate-rtl", action="store_true", help="Generate RTL from mappings")
    parser.add_argument("--mappings-dir", type=Path, default=Path("mappings"),
                        help="Directory for mapping files")

    args = parser.parse_args()

    if args.load:
        mappings = load_mappings(args.load)
        if args.generate_rtl:
            output = args.load.with_suffix('.sv')
            generate_rtl(mappings, output)
        else:
            print(f"Loaded {len(mappings)} mappings from {args.load}")
            for h, char in sorted(mappings.items()):
                romaji = KATAKANA_TO_ROMAJI.get(char, char)
                print(f"  {h:04X} -> {char} ({romaji})")
    elif args.session:
        interactive_session(args.session, args.mappings_dir)
    else:
        print("Usage: hash_mapper.py --session <name> | --load <file>")
        print("\nStart a new session:")
        print("  uv run python tools/hash_mapper.py --session medarot")


if __name__ == "__main__":
    main()
