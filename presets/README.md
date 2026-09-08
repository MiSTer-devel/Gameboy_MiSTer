# BrickBoy Mods presets (experimental)

Copy `Default.bbp` into the existing `games/GAMEBOY` directory. Keep a copy if
you want multiple presets: **Save Mounted Preset overwrites the mounted file**.

1. Open **BrickBoy Mods → Mount BrickBoy Preset**, then select the `.bbp` file.
2. A valid preset loads automatically. Default.bbp has all original/default
   settings, with the optional DMG panel and speaker disabled.
3. Enable DMG Panel, then open **Adjust Effects** and choose a Section.
4. Adjust any controls. Sections retain independent values while switching.
5. Return using **Back to BrickBoy Mods**, then **Save Mounted Preset**.
6. After reloading the core, remount the preset to restore all sections.

MiSTer's ordinary core configuration does NOT contain all the banks. Presets
require explicit mounting; this experiment does not modify Main to auto-mount.
Reset/randomize affect live settings only until explicitly saved. Reset keeps
the panel enable but resets the speaker; randomize keeps both enables.
The standard Back/Left action goes to the core's root menu, as in stock Main.

Files are exactly 512 bytes: `BBP1`, little-endian version 1 and payload length
16, a 128-bit payload, a 16-bit one's-complement sum of the first 12 words,
then zero padding. The full 256-word sum is 0xffff modulo 65536. Reserved
payload bits must be zero. This detects common corruption, not malicious edits.
The core refuses to write a file unless it has first validated successfully.
Only sector zero of virtual drive 1 is used. Cartridge saves remain in drive 0.
Read-only files can load but cannot save. A timeout or mid-transfer remount
fails closed; mount the file again to retry. Keep backups: writes are one-sector
writes, not crash-atomic transactions, and HPS acknowledgment is not a guarantee
against storage failure or power loss.

Create a fresh file with standard Python (refuses to overwrite an existing one):

```text
python tools/brickboy_presets.py create MyPanel.bbp
python tools/brickboy_presets.py inspect MyPanel.bbp
python tools/brickboy_presets.py create MyPanel.bbp --settings options.json
```

JSON values are menu indices, not physical units; omitted controls default to
zero. `FIELDS` in the script documents all controls and the file layout.

Hardware testing is still required. No upstream PR is authorized without the
user's own test and explicit approval.
