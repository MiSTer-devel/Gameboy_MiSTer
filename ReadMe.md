# Gameboy for MiSTer

This is port of [Gameboy for MiST](https://github.com/mist-devel/mist-board/tree/master/cores/gameboy)

* Place RBF file into root of SD card.
* Place *.gb files into Gameboy folder.

## Open Source Bootstrap roms
This now includes the open source boot ROMs from [https://github.com/LIJI32/SameBoy/](https://github.com/LIJI32/SameBoy/) (for maximum GBC compatibility/authenticity you can still place the Gameboy color bios/bootrom into the Gameboy folder and rename it to boot1.rom)

## Palettes
Core supports custom palettes (*.gbp) which should be places into Gameboy folder. Some examples are available in palettes folder.

## Autoload
To autoload custom palette at startup rename it to boot0.rom
To autoload favorite game at startup rename it to boot2.rom

## Analog output 
Due to using a weird video resolution and frequencies (from a TV signal perspective) the core needs help from the scaler to output a 15KHz Signal.

For now you can append this to your MiSTer.ini configuration file (credit goes to ghogan42/soltan_g42) that enables the vga_scaler to be active when using this core

**be aware that you will lose HDMI output for this core** :

```ini
[Gameboy]
video_mode=320,8,32,24,240,4,3,16,6048
vga_scaler=1
vsync_adjust=2
vscale_mode=1
```


