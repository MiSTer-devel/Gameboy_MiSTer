#!/usr/bin/env python3
"""
Medarot Katakana to Hash Mapping

Maps tile hashes from Medarot name entry screen to katakana characters
and their romanized English equivalents.

Based on VRAM extraction from medarot_1.ss savestate.
"""

# Tile hash to katakana mapping for Medarot
# Format: hash -> (katakana, romaji)
# Hashes extracted from VRAM tiles 0x80-0xCF

KATAKANA_MAP = {
    # Row 1: ア イ ウ エ オ
    0x3C53: ("ア", "A"),    # Tile 0x80 - bottom horizontal with angled lines
    0x75FD: ("", ""),       # Tile 0x81 - continuation/dakuten mark?
    0x95EB: ("イ", "I"),    # Tile 0x82 - vertical lines with horizontal
    0x2EC6: ("", ""),       # Tile 0x83 - continuation
    0x58E0: ("ウ", "U"),    # Tile 0x84 - horizontal bars pattern
    0x615B: ("", ""),       # Tile 0x85 - continuation
    0xCF9F: ("エ", "E"),    # Tile 0x86 - E-shape pattern
    0x93A0: ("オ", "O"),    # Tile 0x87 - T with legs

    # Row 2: カ キ ク ケ コ
    0xD47B: ("カ", "KA"),   # Tile 0x88 - ka shape
    0xE787: ("", ""),       # Tile 0x89
    0x2B00: ("キ", "KI"),   # Tile 0x8A - crossed lines
    0x7EF3: ("", ""),       # Tile 0x8B
    0xB9B6: ("ク", "KU"),   # Tile 0x8C - ku angle
    0x1448: ("", ""),       # Tile 0x8D
    0xC8F4: ("ケ", "KE"),   # Tile 0x8E - ke shape
    0x02E6: ("", ""),       # Tile 0x8F

    # Row 3: サ シ ス セ ソ
    0xC01D: ("コ", "KO"),   # Tile 0x90 - rectangle-ish
    0xBDB8: ("サ", "SA"),   # Tile 0x91 - sa crossed
    0xC754: ("", ""),       # Tile 0x92
    0x381F: ("シ", "SHI"),  # Tile 0x93 - three dots
    0x6B4F: ("", ""),       # Tile 0x94
    0xB576: ("ス", "SU"),   # Tile 0x95 - su angle
    0xC494: ("", ""),       # Tile 0x96
    0x9854: ("セ", "SE"),   # Tile 0x97 - se shape
    0xCB19: ("", ""),       # Tile 0x98
    0xAF36: ("ソ", "SO"),   # Tile 0x99 - so angle

    # Row 4: タ チ ツ テ ト
    0xAE7F: ("タ", "TA"),   # Tile 0x9A - ta shape
    0xE5F2: ("", ""),       # Tile 0x9B
    0x98C2: ("チ", "CHI"),  # Tile 0x9C - chi shape
    0x3518: ("", ""),       # Tile 0x9D
    0x3DE0: ("ツ", "TSU"),  # Tile 0x9E - three marks
    0x5063: ("", ""),       # Tile 0x9F
    0x7A04: ("テ", "TE"),   # Tile 0xA0 - te T-shape
    0x6ACA: ("", ""),       # Tile 0xA1
    0xF66F: ("ト", "TO"),   # Tile 0xA2 - to angle

    # Row 5: ナ ニ ヌ ネ ノ
    0x790E: ("ナ", "NA"),   # Tile 0xA3 - na shape
    0x5498: ("", ""),       # Tile 0xA4
    0x69EB: ("ニ", "NI"),   # Tile 0xA5 - two lines
    0x116C: ("ヌ", "NU"),   # Tile 0xA6 - nu crossed
    0x4ACB: ("", ""),       # Tile 0xA7
    0xD209: ("ネ", "NE"),   # Tile 0xA8 - ne shape
    0x8111: ("", ""),       # Tile 0xA9
    0x54AE: ("ノ", "NO"),   # Tile 0xAA - diagonal stroke

    # Row 6: ハ ヒ フ ヘ ホ
    0x0DB5: ("ハ", "HA"),   # Tile 0xAB - ha two strokes
    0xABE6: ("", ""),       # Tile 0xAC
    0xF8D0: ("ヒ", "HI"),   # Tile 0xAD - hi shape
    0xD472: ("", ""),       # Tile 0xAE
    0xA55A: ("フ", "FU"),   # Tile 0xAF - fu shape
    0x9A39: ("", ""),       # Tile 0xB0
    0xC791: ("ヘ", "HE"),   # Tile 0xB1 - he angle
    0xDC51: ("", ""),       # Tile 0xB2
    0x1E00: ("ホ", "HO"),   # Tile 0xB3 - ho tree

    # Row 7: マ ミ ム メ モ
    0xE1C9: ("マ", "MA"),   # Tile 0xB4 - ma shape
    0x6251: ("", ""),       # Tile 0xB5
    0xDB1B: ("ミ", "MI"),   # Tile 0xB6 - mi three lines
    0x64EA: ("ム", "MU"),   # Tile 0xB7 - mu shape
    0x8989: ("", ""),       # Tile 0xB8
    0x821B: ("メ", "ME"),   # Tile 0xB9 - me X-shape
    0xC348: ("", ""),       # Tile 0xBA
    0x5078: ("モ", "MO"),   # Tile 0xBB - mo shape

    # Row 8: ヤ ユ ヨ
    0x7C3B: ("ヤ", "YA"),   # Tile 0xBC - ya shape
    0x2706: ("", ""),       # Tile 0xBD
    0xC078: ("ユ", "YU"),   # Tile 0xBE - yu shape
    0x891C: ("", ""),       # Tile 0xBF
    0x3131: ("ヨ", "YO"),   # Tile 0xC0 - yo shape

    # Row 9: ラ リ ル レ ロ
    0x268F: ("ラ", "RA"),   # Tile 0xC1 - ra shape
    0xAEA2: ("リ", "RI"),   # Tile 0xC2 - ri two strokes
    0xA23B: ("", ""),       # Tile 0xC3
    0x87C5: ("ル", "RU"),   # Tile 0xC4 - ru shape
    0x328F: ("", ""),       # Tile 0xC5
    0xC996: ("レ", "RE"),   # Tile 0xC6 - re shape
    0x1908: ("", ""),       # Tile 0xC7
    0xA23E: ("ロ", "RO"),   # Tile 0xC8 - ro square

    # Row 10: ワ ヲ ン ー (and special)
    0xD7F5: ("ワ", "WA"),   # Tile 0xC9 - wa shape
    0xAE8A: ("ヲ", "WO"),   # Tile 0xCA - wo shape
    0xE288: ("ン", "N"),    # Tile 0xCB - n shape
    0x563C: ("ー", "-"),    # Tile 0xCC - long vowel mark
    0xF5FC: ("゛", ""),     # Tile 0xCD - dakuten
    0xADFB: ("゜", ""),     # Tile 0xCE - handakuten
    0xC207: ("", ""),       # Tile 0xCF
}

def generate_sv_lookup_entries():
    """Generate SystemVerilog hash lookup table entries."""
    entries = []
    for hash_val, (kana, romaji) in KATAKANA_MAP.items():
        if romaji:  # Only include entries with translations
            # First char of romaji as char_code
            char_code = ord(romaji[0]) if romaji else 0x20
            # 41-bit entry: {valid[1], hash[16], char_code[8], trans_ptr[16]}
            entries.append({
                'hash': hash_val,
                'char_code': char_code,
                'romaji': romaji,
                'kana': kana
            })
    return entries


def print_sv_table():
    """Print SystemVerilog hash table initialization."""
    entries = generate_sv_lookup_entries()

    print("// Medarot katakana hash lookup table")
    print("// Auto-generated from tile analysis")
    print(f"// {len(entries)} entries")
    print()
    print("// Entry format: {valid[1], hash[16], char_code[8], trans_ptr[16]}")
    print()

    for i, e in enumerate(entries):
        # Pack: 1-bit valid, 16-bit hash, 8-bit char_code, 16-bit ptr
        print(f"    hash_rom[{i:3d}] = 41'h1_{e['hash']:04X}_{e['char_code']:02X}_0000;  "
              f"// {e['kana']} -> {e['romaji']}")

    print()
    print(f"    // Total: {len(entries)} entries")


def print_hash_list():
    """Print compact hash list for debugging."""
    print("Katakana hashes:")
    for hash_val, (kana, romaji) in sorted(KATAKANA_MAP.items()):
        if romaji:
            print(f"  {hash_val:04X} -> {kana} ({romaji})")


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "--sv":
        print_sv_table()
    else:
        print_hash_list()
        print()
        print("Use --sv to generate SystemVerilog code")
