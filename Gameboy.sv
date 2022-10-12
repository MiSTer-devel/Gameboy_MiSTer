//============================================================================
//  Gameboy
//  Copyright (c) 2015 Till Harbaum <till@harbaum.org>  
//
//  Port to MiSTer
//  Copyright (C) 2017,2018 Sorgelig
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

assign ADC_BUS  = 'Z;
assign VGA_F1 = 0;

assign {UART_RTS, UART_TXD, UART_DTR} = 0;

assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;

assign LED_USER  = ioctl_download | sav_pending;
assign LED_DISK  = 0;
assign LED_POWER = 0;
assign BUTTONS   = 0;
assign HDMI_FREEZE = 0;
assign VGA_SCALER= 0;
assign VGA_DISABLE = 0;

assign AUDIO_MIX = status[8:7];

// Status Bit Map: (0..31 => "O", 32..63 => "o")
// 0         1         2         3          4         5         6
// 01234567890123456789012345678901 23456789012345678901234567890123
// 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV
// XXXXXXXXXXX XXXXXXXXXXXXXXXXXXXX XXXXXXXXXX

`include "build_id.v" 
localparam CONF_STR = {
	"GAMEBOY;SS3E000000:40000;",
	"FS1,GBCGB BIN,Load ROM;",
	"OEF,System,Auto,Gameboy,Gameboy Color,MegaDuck;",
	"D7o79,Mapper,Auto,WisdomTree,Mani161,MBC1,MBC3;",
	"-;",
	"ONO,Super Game Boy,Off,Palette,On;",
	"d5FC2,SGB,Load SGB border;",
	"-;",
	"C,Cheats;",
	"h0OH,Cheats enabled,Yes,No;",
	"-;",
	"h2R9,Load Backup RAM;",
	"h2RA,Save Backup RAM;",
	"OD,Autosave,Off,On;",
	"-;",
	"OV,Savestates to SDCard,On,Off;",
	"o01,Savestate Slot,1,2,3,4;",
	"h3RS,Save state (Alt-F1);",
	"h3RT,Restore state (F1);",
	"-;",

	"P1,Audio & Video;",
	"P1-;",
	"P1OC,Inverted color,No,Yes;",
	"P1o4,Screen Shadow,No,Yes;",
	"h6P1o5,Use GBA Mode,No,Yes;",
	"P1O12,Custom Palette,Off,Auto,On;",
	"h1P1FC3,GBP,Load Palette;",
	"P1-;",
	"P1O34,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"P1OLM,Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
	"P1OIK,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"P1O5,Stabilize video(buffer),Off,On;",
	"P1OG,Frame blend,Off,On;",
	"d4P1OU,GBC Colors,Corrected,Raw;",
	"P1o2,Analog width,Narrow,Wide;",
	"P1-;",
	"P1O78,Stereo mix,none,25%,50%,100%;",

	"P2,Misc.;",
	"P2-;",
	"P2FC4,BIN,Load GBC Boot;",
	"P2FC5,BIN,Load DMG Boot;",
	"P2FC6,BIN,Load SGB Boot;",
	"P2-;",
	"P2O6,Link Port,Disabled,Enabled;",
	"P2o6,Rumble,On,Off;",
	"P2-;",
	"P2OP,FastForward Sound,On,Off;",
	"P2OQ,Pause when OSD is open,Off,On;",
	"P2OR,Rewind Capture,Off,On;",
	"P2-;",
	"P2o3,Super Game Boy + GBC,Off,On;",

	"-;",
	"R0,Reset;",
	"J1,A,B,Select,Start,FastForward,Savestates,Rewind;",
	"I,",
	"Slot=DPAD|Save/Load=Pause+DPAD,",
	"Active Slot 1,",
	"Active Slot 2,",
	"Active Slot 3,",
	"Active Slot 4,",
	"Save to state 1,",
	"Restore state 1,",
	"Save to state 2,",
	"Restore state 2,",
	"Save to state 3,",
	"Restore state 3,",
	"Save to state 4,",
	"Restore state 4,",
	"Rewinding...;",
	"V,v",`BUILD_DATE
};

////////////////////   CLOCKS   ///////////////////

wire clk_sys, clk_ram;
wire pll_locked;

assign CLK_VIDEO = clk_ram;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_ram),
	.outclk_1(clk_sys),
	.locked(pll_locked)
);

///////////////////////////////////////////////////

wire [63:0] status;
wire  [1:0] buttons;
wire        forced_scandoubler;
wire        direct_video;
wire [21:0] gamma_bus;

wire        ioctl_download;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire [15:0] ioctl_dout;
wire        ioctl_wait;

wire [15:0] joystick_0, joy0_unmod, joystick_1, joystick_2, joystick_3;
wire [15:0] joystick_analog_0;
wire [10:0] ps2_key;

wire [7:0]  filetype;

reg  [31:0] sd_lba;
reg         sd_rd = 0;
reg         sd_wr = 0;
wire        sd_ack;
wire  [7:0] sd_buff_addr;
wire [15:0] sd_buff_dout;
wire [15:0] sd_buff_din;
wire        sd_buff_wr;
wire        img_mounted;
wire        img_readonly;
wire [63:0] img_size;
wire [15:0] joy0_rumble;

wire [32:0] RTC_time;

wire        sys_auto     = (status[15:14] == 0);
wire        sys_gbc      = (status[15:14] == 2);
wire        sys_megaduck = (status[15:14] == 3);

hps_io #(.CONF_STR(CONF_STR), .WIDE(1)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(),

	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_wait(ioctl_wait),
	.ioctl_index(filetype),
	
	.sd_lba('{sd_lba}),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din('{sd_buff_din}),
	.sd_buff_wr(sd_buff_wr),
	.img_mounted(img_mounted),
	.img_readonly(img_readonly),
	.img_size(img_size),

	.buttons(buttons),
	.status(status),
	.status_menumask({sys_megaduck,using_real_cgb_bios,sgb_border_en,isGBC,cart_ready,sav_supported,|tint,gg_available}),
	.status_in({status[63:34],ss_slot,status[31:0]}),
	.status_set(statusUpdate),
	.direct_video(direct_video),
	.gamma_bus(gamma_bus),
	.forced_scandoubler(forced_scandoubler),

	.joystick_0(joy0_unmod),
	.joystick_1(joystick_1),
	.joystick_2(joystick_2),
	.joystick_3(joystick_3),
	.joystick_l_analog_0(joystick_analog_0),

	.joystick_0_rumble(joy0_rumble),
	
	.ps2_key(ps2_key),
	
	.info_req(ss_info_req),
	.info(ss_info),
	
	.TIMESTAMP(RTC_time)
);

assign joystick_0 = joy0_unmod[9] ? 16'b0 : joy0_unmod;

///////////////////////////////////////////////////

wire [14:0] cart_addr;
wire [22:0] mbc_addr;
wire cart_a15;
wire cart_rd;
wire cart_wr;
wire cart_oe;
wire [7:0] cart_di, cart_do;
wire nCS; // WRAM or Cart RAM CS

wire cart_download = ioctl_download && (filetype[5:0] == 6'h01 || filetype == 8'h80);
wire md_download = ioctl_download && (filetype == 8'h81);
wire palette_download = ioctl_download && (filetype == 3 /*|| !filetype*/);
wire sgb_border_download = ioctl_download && (filetype == 2);
wire cgb_boot_download = ioctl_download && (filetype == 4);
wire dmg_boot_download = ioctl_download && (filetype == 5);
wire sgb_boot_download = ioctl_download && (filetype == 6);
wire boot_download = cgb_boot_download | dmg_boot_download | sgb_boot_download;


wire  [1:0] sdram_ds = cart_download ? 2'b11 : {mbc_addr[0], ~mbc_addr[0]};
wire [15:0] sdram_do;
wire [15:0] sdram_di = cart_download ? ioctl_dout : 16'd0;
wire [23:0] sdram_addr = cart_download? ioctl_addr[24:1]: {2'b00, mbc_addr[22:1]};
wire sdram_oe = ~cart_download & cart_rd & ~cram_rd;
wire sdram_we = cart_download & dn_write;
wire sdram_refresh_force;
wire sdram_autorefresh = !ff_on;

assign SDRAM_CKE = 1;

sdram sdram (
   // interface to the MT48LC16M16 chip
   .sd_data        ( SDRAM_DQ                  ),
   .sd_addr        ( SDRAM_A                   ),
   .sd_dqm         ( {SDRAM_DQMH, SDRAM_DQML}  ),
   .sd_cs          ( SDRAM_nCS                 ),
   .sd_ba          ( SDRAM_BA                  ),
   .sd_we          ( SDRAM_nWE                 ),
   .sd_ras         ( SDRAM_nRAS                ),
   .sd_cas         ( SDRAM_nCAS                ),
   .sd_clk         ( SDRAM_CLK                 ),

    // system interface
   .clk            ( clk_ram                   ),
   .sync           ( ce_cpu2x                  ),
   .init           ( ~pll_locked               ),

   // cpu interface
   .din            ( sdram_di                  ),
   .addr           ( sdram_addr                ),
   .ds             ( sdram_ds                  ),
   .we             ( sdram_we                  ),
   .oe             ( sdram_oe                  ),
   .autorefresh    ( sdram_autorefresh         ),
   .refresh        ( sdram_refresh_force       ),
   .dout           ( sdram_do                  )
);

wire dn_write;
wire cart_ready;
wire cram_rd, cram_wr;
wire [7:0] rom_do = (mbc_addr[0]) ? sdram_do[15:8] : sdram_do[7:0];
wire [7:0] ram_mask_file, cart_ram_size;
wire isGBC_game, isSGB_game;
wire cart_has_save;
wire [31:0] RTC_timestampOut;
wire [47:0] RTC_savedtimeOut;
wire RTC_inuse;
wire rumbling;
wire [2:0] mapper_sel = status[41:39];

assign joy0_rumble = {8'd0, ((rumbling & ~status[38]) ? 8'd128 : 8'd0)};

reg ce_32k; // 32768Hz clock for RTC
reg [9:0] ce_32k_div;
always @(posedge clk_sys) begin
	ce_32k_div <= ce_32k_div + 1'b1;
	ce_32k <= !ce_32k_div;
end

cart_top cart (
	.reset	     ( reset      ),

	.clk_sys     ( clk_sys    ),
	.ce_cpu      ( ce_cpu     ),
	.ce_cpu2x    ( ce_cpu2x   ),
	.speed       ( speed      ),
	.megaduck    ( megaduck   ),
	.mapper_sel  ( mapper_sel ),

	.cart_addr   ( cart_addr  ),
	.cart_a15    ( cart_a15   ),
	.cart_rd     ( cart_rd    ),
	.cart_wr     ( cart_wr    ),
	.cart_do     ( cart_do    ),
	.cart_di     ( cart_di    ),
	.cart_oe     ( cart_oe    ),

	.nCS         ( nCS        ),

	.mbc_addr    ( mbc_addr   ),

	.dn_write    ( dn_write    ),
	.cart_ready  ( cart_ready  ),

	.cram_rd     ( cram_rd     ),
	.cram_wr     ( cram_wr     ),

	.cart_download ( cart_download ),

	.ram_mask_file ( ram_mask_file ),
	.ram_size      ( cart_ram_size ),
	.has_save      ( cart_has_save ),

	.isGBC_game    ( isGBC_game    ),
	.isSGB_game    ( isSGB_game    ),

	.ioctl_download ( ioctl_download ),
	.ioctl_wr       ( ioctl_wr       ),
	.ioctl_addr     ( ioctl_addr     ),
	.ioctl_dout     ( ioctl_dout     ),
	.ioctl_wait     ( ioctl_wait     ),

	.bk_wr          ( bk_wr          ),
	.bk_rtc_wr      ( bk_rtc_wr      ),
	.bk_addr        ( bk_addr        ),
	.bk_data        ( bk_data        ),
	.bk_q           ( bk_q           ),
	.img_size       ( img_size       ),

	.rom_di         ( rom_do       ),

	.joystick_analog_0 ( joystick_analog_0 ),

	.ce_32k           ( ce_32k           ),
	.RTC_time         ( RTC_time         ),
	.RTC_timestampOut ( RTC_timestampOut ),
	.RTC_savedtimeOut ( RTC_savedtimeOut ),
	.RTC_inuse        ( RTC_inuse        ),

	.SaveStateExt_Din ( SaveStateBus_Din  ),
	.SaveStateExt_Adr ( SaveStateBus_Adr  ),
	.SaveStateExt_wren( SaveStateBus_wren ),
	.SaveStateExt_rst ( SaveStateBus_rst  ),
	.SaveStateExt_Dout( SaveStateBus_Dout ),
	.savestate_load   ( savestate_load    ),
	.sleep_savestate  ( sleep_savestate   ),

	.Savestate_CRAMAddr     ( Savestate_CRAMAddr      ),
	.Savestate_CRAMRWrEn    ( Savestate_CRAMRWrEn     ),
	.Savestate_CRAMWriteData( Savestate_CRAMWriteData ),
	.Savestate_CRAMReadData ( Savestate_CRAMReadData  ),
	
	.rumbling (rumbling)
);

reg [127:0] palette = 128'h828214517356305A5F1A3B4900000000;
reg using_real_cgb_bios = 0;

always @(posedge clk_sys) begin
	if (cgb_boot_download)
		using_real_cgb_bios <= 1;
	if (palette_download & ioctl_wr) begin
			palette[127:0] <= {palette[111:0], ioctl_dout[7:0], ioctl_dout[15:8]};
	end
end

wire lcd_clkena;
wire [14:0] lcd_data;
wire [1:0] lcd_mode;
wire [1:0] lcd_data_gb;
wire lcd_on;
wire lcd_vsync;

wire DMA_on;

assign AUDIO_S = 0;

wire reset = (RESET | status[0] | buttons[1] | cart_download | boot_download | bk_loading);
wire speed;
reg megaduck = 0;

reg isGBC = 0;
always @(posedge clk_sys) if(reset) begin
	if (cart_download)
		megaduck <= sys_megaduck;
	if (md_download)
		megaduck <= sys_auto || sys_megaduck;

	if(~sys_auto) isGBC <= sys_gbc;
	else if(cart_download) begin
		if (!filetype[5:0]) isGBC <= isGBC_game;
		else isGBC <= !filetype[7:6];
	end
end

wire [15:0] GB_AUDIO_L;
wire [15:0] GB_AUDIO_R;

// the gameboy itself
gb gb (
	.reset	    ( reset      ),
	
	.clk_sys     ( clk_sys    ),
	.ce          ( ce_cpu     ),   // the whole gameboy runs on 4mhnz
	.ce_2x       ( ce_cpu2x   ),   // ~8MHz in dualspeed mode (GBC)
	
	.isGBC       ( isGBC      ),
	.isGBC_game  ( isGBC_game ),
	.isSGB       ( |sgb_en & ~isGBC ),
	.megaduck    ( megaduck   ),

	.joy_p54     ( joy_p54     ),
	.joy_din     ( joy_do_sgb  ),

	// interface to the "external" game cartridge
	.ext_bus_addr( cart_addr  ),
	.ext_bus_a15 ( cart_a15   ),
	.cart_rd     ( cart_rd    ),
	.cart_wr     ( cart_wr    ),
	.cart_do     ( cart_do    ),
	.cart_di     ( cart_di    ),
	.cart_oe     ( cart_oe    ),

	.nCS         ( nCS        ),

	.boot_gba_en    ( status[37] && using_real_cgb_bios ),

	.cgb_boot_download ( cgb_boot_download ),
	.dmg_boot_download ( dmg_boot_download ),
	.sgb_boot_download ( sgb_boot_download ),
	.ioctl_wr       ( ioctl_wr       ),
	.ioctl_addr     ( ioctl_addr     ),
	.ioctl_dout     ( ioctl_dout     ),

	// audio
	.audio_l 	 ( GB_AUDIO_L ),
	.audio_r 	 ( GB_AUDIO_R ),
	
	// interface to the lcd
	.lcd_clkena  ( lcd_clkena ),
	.lcd_data    ( lcd_data   ),
	.lcd_data_gb ( lcd_data_gb ),
	.lcd_mode    ( lcd_mode   ),
	.lcd_on      ( lcd_on     ),
	.lcd_vsync   ( lcd_vsync  ),
	
	.speed       ( speed      ),
	.DMA_on      ( DMA_on    ),
	
	// serial port
	.sc_int_clock2(sc_int_clock_out),
	.serial_clk_in(ser_clk_in),
	.serial_data_in(ser_data_in),
	.serial_clk_out(ser_clk_out),
	.serial_data_out(ser_data_out),
	
	// Palette download will disable cheats option (HPS doesn't distinguish downloads),
	// so clear the cheats and disable second option (chheats enable/disable)
	.gg_reset((code_download && ioctl_wr && !ioctl_addr) | cart_download | palette_download),
	.gg_en(~status[17]),
	.gg_code(gg_code),
	.gg_available(gg_available),
	
	// savestates
	.increaseSSHeaderCount (!status[31]),
	.cart_ram_size   (cart_ram_size),
	.save_state      (ss_save),
	.load_state      (ss_load),
	.savestate_number(ss_slot),
	.sleep_savestate (sleep_savestate),
	
	.SaveStateExt_Din (SaveStateBus_Din),
	.SaveStateExt_Adr (SaveStateBus_Adr),
	.SaveStateExt_wren(SaveStateBus_wren),
	.SaveStateExt_rst (SaveStateBus_rst),
	.SaveStateExt_Dout(SaveStateBus_Dout),
	.SaveStateExt_load(savestate_load),
	
	.Savestate_CRAMAddr     (Savestate_CRAMAddr),
	.Savestate_CRAMRWrEn    (Savestate_CRAMRWrEn),
	.Savestate_CRAMWriteData(Savestate_CRAMWriteData),
	.Savestate_CRAMReadData (Savestate_CRAMReadData),
	
	.SAVE_out_Din(ss_din),            // data read from savestate
	.SAVE_out_Dout(ss_dout),          // data written to savestate
	.SAVE_out_Adr(ss_addr),           // all addresses are DWORD addresses!
	.SAVE_out_rnw(ss_rnw),            // read = 1, write = 0
	.SAVE_out_ena(ss_req),            // one cycle high for each action
	.SAVE_out_be(ss_be),            
	.SAVE_out_done(ss_ack),            // should be one cycle high when write is done or read value is valid
	
	.rewind_on(status[27]),
	.rewind_active(status[27] & joystick_0[10])
);

assign AUDIO_L = (fast_forward && status[25]) ? 16'd0 : GB_AUDIO_L;
assign AUDIO_R = (fast_forward && status[25]) ? 16'd0 : GB_AUDIO_R;

// the lcd to vga converter
wire [7:0] R,G,B;
wire video_hs, video_vs;
wire HBlank, VBlank;
wire ce_pix;
wire [8:0] h_cnt, v_cnt;
wire [1:0] tint = status[2:1];
wire h_end;

lcd lcd
(
	// serial interface
	.clk_sys( clk_sys    ),
	.ce     ( ce_cpu         ),

	.lcd_clkena ( sgb_lcd_clkena ),
	.data   ( sgb_lcd_data   ),
	.mode   ( sgb_lcd_mode   ),  // used to detect begin of new lines and frames
	.on     ( sgb_lcd_on     ),
	.lcd_vs ( sgb_lcd_vsync  ),
	.shadow ( status[36]     ),

	.isGBC  ( isGBC      ),

	.tint   ( |tint       ),
	.inv    ( status[12]  ),
	.double_buffer( status[5]),
	.frame_blend( status[16] ),
	.originalcolors( status[30] ),
	.analog_wide ( status[34] ),

	// Palettes
	.pal1   (palette[127:104]),
	.pal2   (palette[103:80]),
	.pal3   (palette[79:56]),
	.pal4   (palette[55:32]),

	.sgb_border_pix ( sgb_border_pix),
	.sgb_pal_en     ( sgb_pal_en ),
	.sgb_en         ( sgb_border_en ),

	.clk_vid( CLK_VIDEO  ),
	.hs     ( video_hs   ),
	.vs     ( video_vs   ),
	.hbl    ( HBlank     ),
	.vbl    ( VBlank     ),
	.r      ( R          ),
	.g      ( G          ),
	.b      ( B          ),
	.ce_pix ( ce_pix     ),
	.h_cnt  ( h_cnt      ),
	.v_cnt  ( v_cnt      ),
	.h_end  ( h_end      )
);

wire [1:0] joy_p54;
wire [3:0] joy_do_sgb;
wire [14:0] sgb_lcd_data;
wire [15:0] sgb_border_pix;
wire sgb_lcd_clkena, sgb_lcd_on, sgb_lcd_vsync;
wire [1:0] sgb_lcd_mode;
wire sgb_pal_en;
wire [1:0] sgb_en = status[24:23];
wire sgb_border_en = sgb_en[1];

sgb sgb (
	.reset       ( reset       ),
	.clk_sys     ( clk_sys     ),
	.ce          ( ce_cpu      ),

	.clk_vid     ( CLK_VIDEO   ),
	.ce_pix      ( ce_pix      ),

	.joystick_0  ( joystick_0  ),
	.joystick_1  ( joystick_1  ),
	.joystick_2  ( joystick_2  ),
	.joystick_3  ( joystick_3  ),
	.joy_p54     ( joy_p54     ),
	.joy_do      ( joy_do_sgb  ),

	.sgb_en      ( |sgb_en & isSGB_game & (~isGBC | status[35]) ),
	.tint        ( tint[1]     ),
	.isGBC_game  ( isGBC & isGBC_game ),

	.lcd_on      ( lcd_on      ),
	.lcd_clkena  ( lcd_clkena  ),
	.lcd_data    ( lcd_data    ),
	.lcd_data_gb ( lcd_data_gb ),
	.lcd_mode    ( lcd_mode    ),
	.lcd_vsync   ( lcd_vsync   ),

	.h_cnt       ( h_cnt      ),
	.v_cnt       ( v_cnt      ),
	.h_end       ( h_end      ),

	.border_download (sgb_border_download),
	.ioctl_wr        (ioctl_wr),
	.ioctl_addr      (ioctl_addr),
	.ioctl_dout      (ioctl_dout),

	.sgb_border_pix  ( sgb_border_pix  ),
	.sgb_pal_en      ( sgb_pal_en      ),
	.sgb_lcd_data    ( sgb_lcd_data    ),
	.sgb_lcd_on      ( sgb_lcd_on      ),
	.sgb_lcd_clkena  ( sgb_lcd_clkena  ),
	.sgb_lcd_mode    ( sgb_lcd_mode    ),
	.sgb_lcd_vsync   ( sgb_lcd_vsync   )
);

reg HSync, VSync;
always @(posedge CLK_VIDEO) begin
	if(ce_pix) begin
		HSync <= video_hs;
		if(~HSync & video_hs) VSync <= video_vs;
	end
end

assign VGA_F1 = 0;
assign VGA_SL = sl[1:0];

wire [2:0] scale = status[20:18];
wire [2:0] sl = scale ? scale - 1'd1 : 3'd0;
wire       scandoubler = (scale || forced_scandoubler);

video_mixer #(.LINE_LENGTH(200), .GAMMA(1)) video_mixer
(
	.*,
	.freeze_sync(),
	.hq2x(scale==1)
);

wire [1:0] ar = status[4:3];
video_freak video_freak
(
	.*,
	.VGA_DE_IN(VGA_DE),
	.VGA_DE(),

	.ARX((!ar) ? (sgb_border_en ? 12'd16 : 12'd10) : (ar - 1'd1)),
	.ARY((!ar) ? (sgb_border_en ? 12'd14 : 12'd9 ) : 12'd0),
	.CROP_SIZE(0),
	.CROP_OFF(0),
	.SCALE(status[22:21])
);

//////////////////////////////// CE ////////////////////////////////////


wire ce_cpu, ce_cpu2x;
wire cart_act = cart_wr | cart_rd;

wire fastforward = joystick_0[8] && !ioctl_download && !OSD_STATUS;
wire ff_on;

wire sleep_savestate;

reg paused;
always_ff @(posedge clk_sys) begin
   paused <= sleep_savestate | (status[26] && OSD_STATUS && !ioctl_download && !reset && ~status[27]); // no pause when downloading rom, resetting or rewind capture is on
end

speedcontrol speedcontrol
(
	.clk_sys     (clk_sys),
	.pause       (paused),
	.speedup     (fast_forward),
	.cart_act    (cart_act),
	.DMA_on      (DMA_on),
	.ce          (ce_cpu),
	.ce_2x       (ce_cpu2x),
	.refresh     (sdram_refresh_force),
	.ff_on       (ff_on)
);

///////////////////////////// Fast Forward Latch /////////////////////////////////

reg fast_forward;
reg ff_latch;

always @(posedge clk_sys) begin : ffwd
	reg last_ffw;
	reg ff_was_held;
	longint ff_count;

	last_ffw <= fastforward;

	if (fastforward)
		ff_count <= ff_count + 1;

	if (~last_ffw & fastforward) begin
		ff_latch <= 0;
		ff_count <= 0;
	end

	if ((last_ffw & ~fastforward)) begin // 32mhz clock, 0.2 seconds
		ff_was_held <= 0;

		if (ff_count < 3200000 && ~ff_was_held) begin
			ff_was_held <= 1;
			ff_latch <= 1;
		end
	end

	fast_forward <= (fastforward | ff_latch);
end

///////////////////////////// savestates /////////////////////////////////

wire [63:0] SaveStateBus_Din; 
wire [9:0]  SaveStateBus_Adr; 
wire        SaveStateBus_wren;
wire        SaveStateBus_rst; 
wire [63:0] SaveStateBus_Dout;
wire        savestate_load;

wire [19:0] Savestate_CRAMAddr;     
wire        Savestate_CRAMRWrEn;    
wire [7:0]  Savestate_CRAMWriteData;
wire [7:0]  Savestate_CRAMReadData;
	
wire [63:0] ss_dout, ss_din;
wire [27:2] ss_addr;
wire  [7:0] ss_be;
wire        ss_rnw, ss_req, ss_ack;

assign DDRAM_CLK = clk_sys;
ddram ddram
(
	.*,

	.ch1_addr({ss_addr, 1'b0}),
	.ch1_din(ss_din),
	.ch1_dout(ss_dout),
	.ch1_req(ss_req),
	.ch1_rnw(ss_rnw),
	.ch1_be(ss_be),
	.ch1_ready(ss_ack)
);

// saving with keyboard/OSD/gamepad
wire [1:0] ss_slot;
wire [7:0] ss_info;
wire ss_save, ss_load, ss_info_req;
wire statusUpdate;

savestate_ui savestate_ui
(
	.clk            (clk_sys       ),
	.ps2_key        (ps2_key[10:0] ),
	.allow_ss       (cart_ready    ),
	.joySS          (joy0_unmod[9] ),
	.joyRight       (joy0_unmod[0] ),
	.joyLeft        (joy0_unmod[1] ),
	.joyDown        (joy0_unmod[2] ),
	.joyUp          (joy0_unmod[3] ),
	.joyStart       (joy0_unmod[7] ),
	.joyRewind      (joy0_unmod[10]),
	.rewindEnable   (status[27]    ), 
	.status_slot    (status[33:32] ),
	.OSD_saveload   (status[29:28] ),
	.ss_save        (ss_save       ),
	.ss_load        (ss_load       ),
	.ss_info_req    (ss_info_req   ),
	.ss_info        (ss_info       ),
	.statusUpdate   (statusUpdate  ),
	.selected_slot  (ss_slot       )
);
defparam savestate_ui.INFO_TIMEOUT_BITS = 27;

///////////////////////////// CHEATS //////////////////////////////////
// Code loading for WIDE IO (16 bit)
reg [128:0] gg_code;
wire        gg_available;
wire        code_download = &filetype;

// Code layout:
// {clock bit, code flags,     32'b address, 32'b compare, 32'b replace}
//  128        127:96          95:64         63:32         31:0
// Integer values are in BIG endian byte order, so it up to the loader
// or generator of the code to re-arrange them correctly.

always_ff @(posedge clk_sys) begin
	gg_code[128] <= 1'b0;

	if (code_download & ioctl_wr) begin
		case (ioctl_addr[3:0])
			0:  gg_code[111:96]  <= ioctl_dout; // Flags Bottom Word
			2:  gg_code[127:112] <= ioctl_dout; // Flags Top Word
			4:  gg_code[79:64]   <= ioctl_dout; // Address Bottom Word
			6:  gg_code[95:80]   <= ioctl_dout; // Address Top Word
			8:  gg_code[47:32]   <= ioctl_dout; // Compare Bottom Word
			10: gg_code[63:48]   <= ioctl_dout; // Compare top Word
			12: gg_code[15:0]    <= ioctl_dout; // Replace Bottom Word
			14: begin
				gg_code[31:16]    <= ioctl_dout; // Replace Top Word
				gg_code[128]      <= 1'b1;       // Clock it in
			end
		endcase
	end
end

/////////////////////////////  Serial link  ///////////////////////////////

assign USER_OUT[2] = 1'b1;
assign USER_OUT[3] = 1'b1;
assign USER_OUT[4] = 1'b1;
assign USER_OUT[5] = 1'b1;
assign USER_OUT[6] = 1'b1;

wire sc_int_clock_out;
wire ser_data_in;
wire ser_data_out;
wire ser_clk_in;
wire ser_clk_out;
wire serial_ena = status[6];

assign ser_data_in = serial_ena ? USER_IN[2] : 1'b1;
assign USER_OUT[1] = serial_ena ? ser_data_out : 1'b1;

assign ser_clk_in = serial_ena ? USER_IN[0] : 1'b1;
assign USER_OUT[0] = (serial_ena & sc_int_clock_out) ? ser_clk_out : 1'b1;



/////////////////////////  BRAM SAVE/LOAD  /////////////////////////////

wire [16:0] bk_addr = {sd_lba[7:0],sd_buff_addr};
wire bk_wr = (sd_lba[7:0] > ram_mask_file) ? 1'b0 : sd_buff_wr & sd_ack; // only restore data amount of saveram, don't save on RTC data
wire bk_rtc_wr = (sd_lba[7:0] > ram_mask_file) & sd_buff_wr & sd_ack;
wire [15:0] bk_data = sd_buff_dout;
wire [15:0] bk_q;
assign sd_buff_din = (sd_lba[7:0] <= ram_mask_file) ? bk_q :  // normal saveram data or RTC data
					 (sd_buff_addr == 8'd0) ? RTC_timestampOut[15:0]  :
					 (sd_buff_addr == 8'd1) ? RTC_timestampOut[31:16] :
					 (sd_buff_addr == 8'd2) ? RTC_savedtimeOut[15:0]  :
					 (sd_buff_addr == 8'd3) ? RTC_savedtimeOut[31:16] :
					 (sd_buff_addr == 8'd4) ? RTC_savedtimeOut[47:32] :
					 16'hFFFF;



wire downloading = cart_download;

reg  bk_ena          = 0;
reg  new_load        = 0;
reg  old_downloading = 0;
reg  sav_pending     = 0;
wire sav_supported   = cart_has_save && bk_ena;

always @(posedge clk_sys) begin
	old_downloading <= downloading;
	if(~old_downloading & downloading) bk_ena <= 0;

	//Save file always mounted in the end of downloading state.
	if(downloading && img_mounted && !img_readonly) bk_ena <= 1;

	if (old_downloading & ~downloading & sav_supported)
		new_load <= 1'b1;
	else if (bk_state)
		new_load <= 1'b0;

	if (cram_wr & ~OSD_STATUS & sav_supported)
		sav_pending <= 1'b1;
	else if (bk_state)
		sav_pending <= 1'b0;
end

wire bk_load    = status[9] | new_load;
wire bk_save    = status[10] | (sav_pending & OSD_STATUS & status[13]);
reg  bk_loading = 0;
reg  bk_state   = 0;


always @(posedge clk_sys) begin
	reg old_load = 0, old_save = 0, old_ack;

	old_load <= bk_load;
	old_save <= bk_save;
	old_ack  <= sd_ack;
	
	if(~old_ack & sd_ack) {sd_rd, sd_wr} <= 0;
	
	if(!bk_state) begin
		if(bk_ena & ((~old_load & bk_load) | (~old_save & bk_save))) begin
			bk_state <= 1;
			bk_loading <= bk_load;
			sd_lba <= 32'd0;
			sd_rd <=  bk_load;
			sd_wr <= ~bk_load;
		end
		if(old_downloading & ~downloading & |img_size & bk_ena) begin
			bk_state <= 1;
			bk_loading <= 1;
			sd_lba <= 0;
			sd_rd <= 1;
			sd_wr <= 0;
		end
	end else begin
		if(old_ack & ~sd_ack) begin
			
			if (RTC_inuse && sd_lba[7:0]>ram_mask_file) begin // save/load one block more when game/savefile uses RTC, only first 8 bytes used
				bk_loading <= 0;
				bk_state <= 0;
			end else if(!RTC_inuse && sd_lba[7:0]>=ram_mask_file) begin
				bk_loading <= 0;
				bk_state <= 0;
			end else begin
				sd_lba <= sd_lba + 1'd1;
				sd_rd  <=  bk_loading;
				sd_wr  <= ~bk_loading;
			end
		end
	end
end



endmodule
