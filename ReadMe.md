# [Gameboy](https://en.wikipedia.org/wiki/Game_Boy)  / [Gameboy Color](https://en.wikipedia.org/wiki/Game_Boy_Color) for MiSTer Platform

This is port of [Gameboy for MiST](https://github.com/mist-devel/mist-board/tree/master/cores/gameboy)

* Place RBF file into root of SD card.
* Place *.gb files into Gameboy folder.

## Features
* Original Gameboy & Gameboy Color Support
* Super Gameboy Support - Borders, Palettes and Multiplayer
* SaveStates
* Fastforward 
* Rewind - Allows you to rewind up to 40 seconds of gameplay
* Frameblending - Prevents flicker in some games (e.g. "Chikyuu Kaihou Gun Zas") 
* Custom Palette Loading
* Real-Time Clock Support
* Gameboy Link Port Support - Requires USERIO adapter
* Cheats

## Open Source Bootstrap roms
This now includes the open source boot ROMs from [https://github.com/LIJI32/SameBoy/](https://github.com/LIJI32/SameBoy/) (for maximum GBC compatibility/authenticity you can still place the Gameboy color bios/bootrom into the Gameboy folder and rename it to boot1.rom)

## Palettes
Core supports custom palettes (*.gbp) which should be placed into Gameboy folder. Some examples are available in palettes folder.

## Autoload
To autoload favorite game at startup rename it to boot2.rom

## Video output
The Gameboy can disable video output at any time which causes problems with vsync_adjust=2 or analog video during screen transitions. Enable the Stabilize video option to fix this at the cost of some latency.

# Savestates
Core provides 4 slots to save and restore the state. 
Those can be saved to SDCard or reside only in memory for temporary use(OSD Option). 
Usage with either Keyboard, Gamepad mappable button or OSD.

Keyboard Hotkeys for save states:
- Alt-F1..F4 - save the state
- F1...F4 - restore

Gamepad:
- Savestatebutton+Left or Right switches the savestate slot
- Savestatebutton+Start+Down saves to the selected slot
- Savestatebutton+Start+Up loads from the selected slot
