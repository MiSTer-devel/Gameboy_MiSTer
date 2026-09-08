# BrickBoy Mods

Optional DMG panel rendering and speaker simulation, derived from Kathoc's
BrickBoy work. Both are disabled by default. Attribution and licenses are in
[CREDITS.md](CREDITS.md) and [rtl/brickboy/LICENSE](rtl/brickboy/LICENSE).

## Controls and compatibility

Open **BrickBoy Mods** in the core menu. **Adjust Effects** provides 42 independent
controls across Panel, Colour, Optics, Motion/STN, and Ageing. Panel enable and
speaker selection are separate root controls. Reset restores effect/speaker
defaults while preserving panel enable; randomize preserves both enables.

The renderer is active only for DMG, excluding enabled SGB modes and MegaDuck.
GBC, SGB, and MegaDuck retain the native video path. Speaker processing is
independently selectable. Native fast-forward audio behavior is retained.
The stock scandoubler/HQ2x/scanline effects are bypassed while the panel renderer
is active. Vinegar is not instantiated in this integration.

The CPU, input and save-state implementation files are unchanged. The integration
does change top-level video/audio selection and HPS storage/status wiring;
hardware regression testing of the native paths is therefore still necessary.

## Presets

See [preset instructions](presets/README.md). Mount a supplied or generated
`.BBP` preset before editing. Mounting loads its settings; **Save Mounted Preset**
overwrites the mounted preset only after validation. Remount after reloading
the core to restore all sections. There is no automatic mount or save.

MiSTer's ordinary saved core configuration retains only the editor window, not
all banks. Previous experimental BrickBoy status layouts are incompatible:
mount Default.bbp or reset BrickBoy defaults when changing test versions.
Preset writes are not crash-atomic; retain backups.

## Integration design

- Native status bits 0..50 are preserved; 51/52 control panel/speaker.
- A 24-bit editor window uses 79..56; section uses 82..80. The section follows
  the window in the ascending 16-bit HPS transfer. Pending feedback must
  converge before editing resumes.
- Action bits: 124 reset, 125 randomize, 126 save, 127 reload.
- Five 24-bit banks occupy preset bits 0..119; panel/speaker use 126/127.
  Unused bits are masked and validated. The precise schema is `FIELDS` in
  [the preset tool](tools/brickboy_presets.py).
- `brick_status_notify` queues adjacent native/editor notification events.
- Virtual drive 0 remains cartridge saves; drive 1 is the preset. Slot 0 image
  size is latched separately, and buffer writes qualify on the matching ACK.
  Presets access only sector zero of a validated, explicitly mounted 512-byte file.
- No MiSTer Main or shared `sys/` protocol changes are required.
- Page links use `P4P5` and `P5P4`. Stock Back/Left returns to the core root;
  use **Back to BrickBoy Mods** for the explicit return link.

The imported video source retains its optional Vinegar implementation and
reference assets for provenance/regression comparisons. This integration sets
`ENABLE_VINEGAR=0`, preserving its three-cycle delay with a bypass. Those ROMs
are not instantiated. Persistence and crosstalk remain enabled.

Original trim, tint and reflector mappings are retained. Ink Green/Blue menu
index 2 selects the advertised ink level 1; the standalone helper duplicated
level 2 at that index. Shader arithmetic is otherwise unchanged by the menu work.

## Validation

[Build/resource comparison](BASELINE_COMPARISON.md) includes portable Quartus
summaries. [Tests](tests/README.md) describes a reproducible regression command.
The built test RBF passed the project's configured timing analysis, not a
broader multicorner qualification.

The test build has been deployed for user evaluation. Hardware results and
user approval have not yet been recorded; deployment alone is not validation.
In particular, verify HDMI/analog video, pacing, native modes, saves/RTC,
save-state slot selection, and preset round trips on the target system.
