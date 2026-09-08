import importlib.util
from pathlib import Path
import random
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('presets', ROOT/'tools/brickboy_presets.py')
p = importlib.util.module_from_spec(spec)
spec.loader.exec_module(p)

class Presets(unittest.TestCase):
    def test_roundtrips(self):
        rng = random.Random(817)
        occupied = 0
        for offset, width in p.FIELDS.values():
            mask = ((1 << width)-1) << offset
            self.assertFalse(mask & occupied)
            occupied |= mask
        for _ in range(1000):
            values = {name: rng.randrange(1 << width) for name, (_, width) in p.FIELDS.items()}
            self.assertEqual(values, p.decode(p.encode(values)))

    def test_corruption(self):
        default = p.encode({})
        for i in range(512):
            broken = bytearray(default)
            broken[i] ^= 1
            with self.assertRaises(ValueError):
                p.decode(broken)
        for size in (0, 26, 511, 513, 1024):
            with self.assertRaises(ValueError):
                p.decode(bytes(size))

    def test_validation(self):
        for fields in ({'unknown': 1}, {'bright': 8}, {'speaker': -1}, {'warm': 0.2}):
            with self.assertRaises(ValueError):
                p.encode(fields)

    def test_every_control_connected(self):
        wiring = (ROOT/'rtl/brickboy/brick_integration.svh').read_text()
        for name, (offset, width) in p.FIELDS.items():
            if name in ('panel_enabled', 'speaker'):
                continue
            reference = f'brick_config[{offset}]' if width==1 else f'brick_config[{offset+width-1}:{offset}]'
            connection = re.search(r'\.set_'+name+r'\(([^\n]+)', wiring)
            self.assertIsNotNone(connection, name)
            self.assertIn(reference, connection.group(1), name)

    def test_menu_banks(self):
        source = (ROOT/'Gameboy.sv').read_text()
        self.assertIn('"P4,BrickBoy Mods;"', source)
        self.assertIn('"P4P5,Adjust Effects;"', source)
        self.assertIn('"P5P4,Back to BrickBoy Mods;"', source)
        self.assertIn('"P5O[82:80],Section,', source)
        rows = re.findall(r'"h([A-E])P5O\[(\d+)(?::(\d+))?\],([^;]+);"', source)
        self.assertEqual(len(rows), 42)
        coverage = 0
        for section, high, low, text in rows:
            high, low = int(high), int(low or high)
            self.assertTrue(56 <= low <= high <= 79)
            width = high-low+1
            offset = (ord(section)-ord('A'))*24 + low-56
            mask = ((1 << width)-1) << offset
            self.assertFalse(coverage & mask)
            coverage |= mask
            self.assertEqual(len(text.split(','))-1, 1 << width)
        self.assertEqual(coverage, p.MASK & ((1 << 120)-1))

if __name__ == '__main__':
    unittest.main()
