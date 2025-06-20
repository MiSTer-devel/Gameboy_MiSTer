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

// Bootrom checksums
`define MISTER_CGB0_CHECKSUM 18'h2CE10
`define ORIGINAL_CGB_CHECKSUM 18'h2F3EA

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
	output        HDMI_BLACKOUT,
	output        HDMI_BOB_DEINT,

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

assign DDRAM_CLK      = 0;
assign DDRAM_BURSTCNT = 0;
assign DDRAM_ADDR     = 0;
assign DDRAM_RD       = 0;
assign DDRAM_DIN      = 0;
assign DDRAM_BE       = 0;
assign DDRAM_WE       = 0;

// Status Bit Map: (0..31 => "O", 32..63 => "o")
// 0         1         2         3          4         5         6
// 01234567890123456789012345678901 23456789012345678901234567890123
// 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV
// XXXXXXXXXXXXXXXXXXXXXXXX      X       XXXXXXX

`include "build_id.v" 
localparam CONF_STR = {
	"GAMEBOY2P;SS3E000000:40000;",
	"FS1,GBCGB BIN,Load ROM;",
	"O[6],Rom for second GB,Off,On;",
	"OEF,System,Auto,Gameboy,Gameboy Color,MegaDuck;",
	"D7o79,Mapper,Auto,WisdomTree,Mani161,MBC1,MBC3;",
	"-;",
	"O[11],Dupe Save to GB 2,Off,On;",
	"h2R9,Reload Backup RAM;",
	"h2RA,Save Backup RAM;",
	"OD,Autosave,Off,On;",
	"-;",

	"P1,Audio & Video;",
	"P1-;",
	"P1ON,Seperator Line,Off,On;",
	"P1OC,Inverted color,No,Yes;",
	"P1O12,Custom Palette,Off,Auto,On;",
	"h1P1FC3,GBP,Load Palette;",
	"P1-;",
	"P1O34,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"P1OLM,Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
	"P1OIK,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"d4P1OU,GBC Colors,Corrected,Raw;",
	"P1O5,Sync Video,Off,On;",
	"P1-;",
	"P1O78,Stereo mix,none,25%,50%,100%;",
	"P1O[43],Audio mode,Accurate,No Pops;",
	"P1OGH,Audioselect,GB 1,GB 2,Mixed,Split 1=L 2=R;",

	"P2,Misc.;",
	"P2-;",
	"P2FC4,BIN,Load GBC Boot;",
	"P2FC5,BIN,Load DMG Boot;",
	"P2FC6,BIN,Load SGB Boot;",
	"P2-;",
	"d6P2O[37],GBC/GBA mode,GBC,GBA;",
	"d8P2O[42],Fast boot,Off,On;",
	"P2o6,Rumble,On,Off;",

	"-;",
	"R0,Reset;",
	"J1,A,B,Select,Start;",
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
reg         ioctl_wait;

wire [15:0] joystick_0, joystick_1, joystick_2, joystick_3;
wire [15:0] joystick_analog_0, joystick_analog_1;
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
wire [15:0] joy0_rumble, joy1_rumble;

wire [32:0] RTC_time;

wire        sys_auto     = (status[15:14] == 0);
wire        sys_gbc      = (status[15:14] == 2);
wire        sys_megaduck = (status[15:14] == 3);

wire        dupe_save_gb2 = status[11];
wire        rom_load_gb2  = status[6];

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
	.status_menumask({7'h0, 
		fastboot_available,
		sys_megaduck, boot_gba_available,1'b0,isGBC,
		1'b0,sav_supported,|tint,1'b0}),
	.status_in(status),
	.status_set(1'b0),
	.direct_video(direct_video),
	.gamma_bus(gamma_bus),
	.forced_scandoubler(forced_scandoubler),

	.joystick_0(joystick_0),
	.joystick_1(joystick_1),
	.joystick_2(joystick_2),
	.joystick_3(joystick_3),
	.joystick_l_analog_0(joystick_analog_0),
	.joystick_l_analog_1(joystick_analog_1),

	.joystick_0_rumble(joy0_rumble),
	.joystick_1_rumble(joy1_rumble),
	
	.ps2_key(ps2_key),
	
	.info_req(1'b0),
	.info(0),
	
	.TIMESTAMP(RTC_time)
);

///////////////////////////////////////////////////

wire [14:0] cart1_addr;
wire        cart1_a15;
wire        cart1_rd;
wire        cart1_wr;
wire        cart1_oe;
wire  [7:0] cart1_di;
wire  [7:0] cart1_do;
wire [22:0] mbc1_addr;
wire        gb1_nCS; // WRAM or Cart RAM CS

wire [14:0] cart2_addr;
wire        cart2_a15;
wire        cart2_rd;
wire        cart2_wr;
wire        cart2_oe;
wire  [7:0] cart2_di;
wire  [7:0] cart2_do;
wire [22:0] mbc2_addr;
wire        gb2_nCS;


wire cart_download = ioctl_download && (filetype[5:0] == 6'h01 || filetype == 8'h80);
wire md_download = ioctl_download && (filetype == 8'h81);
wire palette_download = ioctl_download && (filetype == 3 /*|| !filetype*/);
wire cgb_boot_download = ioctl_download && (filetype == 4);
wire dmg_boot_download = ioctl_download && (filetype == 5);
wire sgb_boot_download = ioctl_download && (filetype == 6);
wire boot_download = cgb_boot_download | dmg_boot_download | sgb_boot_download;

///////////////////////////// Bootrom added features ///////////////////////////

// Fastboot is available for MiSTer-built bootroms (except SGB)
wire fastboot_available = !((isGBC && using_custom_cgb_bootrom &&  checksum_cgb != `MISTER_CGB0_CHECKSUM) || (!isGBC && using_custom_dmg_bootrom));
// GBA mode is available for MiSTer-built CGB bootroms and the original CGB bootrom.
// We verify that a loaded bootrom enables GBA mode by calculating a simple checksum.
wire boot_gba_available = (!using_custom_cgb_bootrom || using_real_cgb_bios || checksum_cgb == `MISTER_CGB0_CHECKSUM);
wire using_real_cgb_bios = (checksum_cgb == `ORIGINAL_CGB_CHECKSUM);

reg using_custom_dmg_bootrom = 0;
reg using_custom_cgb_bootrom = 0;
always @(posedge clk_sys) begin
	if (cgb_boot_download)
		using_custom_cgb_bootrom <= 1;
	if (dmg_boot_download)
		using_custom_dmg_bootrom <= 1;
end

reg boot_download_r;
always @(posedge clk_sys)
    boot_download_r <= boot_download;

// Calculate checksum for incoming cgb bootrom downloads
reg [17:0] checksum_cgb;
always @(posedge clk_sys) begin
    // Reset checksum on new boot download
    if (cgb_boot_download && !boot_download_r)
        checksum_cgb <= 0;
    else if (cgb_boot_download && ioctl_wr)
        checksum_cgb <= checksum_cgb + ioctl_dout[15:8] + ioctl_dout[7:0];
end

////////////////////////////////////////////////////////////////////////////////
reg rom_bank_gb2;
always @(posedge clk_sys) begin
	if (~old_downloading & downloading) begin
		rom_bank_gb2 <= rom_load_gb2;
	end
end

reg dn_write;
always @(posedge clk_sys) begin
	if(ioctl_wr) ioctl_wait <= 1;

	if(ce1_cpu2x) begin
		dn_write <= ioctl_wait;
		if(dn_write) {ioctl_wait, dn_write} <= 0;
	end
end

wire  [1:0] sdram_ds = cart_download ? 2'b11 : {mbc1_addr[0], ~mbc1_addr[0]};
wire [15:0] sdram_do;
wire [15:0] sdram_di = cart_download ? ioctl_dout : 16'd0;
wire [23:0] sdram_addr = cart_download? { 1'b0, rom_bank_gb2, ioctl_addr[22:1] } : {2'b00, mbc1_addr[22:1]};
wire sdram_oe = ~cart_download & cart1_rd & ~cram1_rd;
wire sdram_ack;
wire sdram_we = cart_download & dn_write;

wire [15:0] sdram_do2;
wire [23:0] sdram_addr2 = {1'b0, rom_bank_gb2, mbc2_addr[22:1]};
wire        sdram_oe2   = ~cart_download & cart2_rd & ~cram2_rd;
wire        sdram_ack2;

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
   .sync           ( ce_ram2x                  ),
   .init           ( ~pll_locked               ),

   // cpu interface
   .dout           ( sdram_do                  ),
   .din            ( sdram_di                  ),
   .addr           ( sdram_addr                ),
   .ds             ( sdram_ds                  ),
   .we             ( sdram_we                  ),
   .oe             ( sdram_oe                  ),
   .ack            ( sdram_ack                 ),
   
   .dout2          ( sdram_do2                 ),
   .addr2          ( sdram_addr2               ),
   .oe2            ( sdram_oe2                 ),
   .ack2           ( sdram_ack2                )
);

wire cram1_rd, cram1_wr;
wire cram2_rd, cram2_wr;
wire [7:0] rom1_do = (mbc1_addr[0]) ? sdram_do[15:8]  : sdram_do[7:0];
wire [7:0] rom2_do = (mbc2_addr[0]) ? sdram_do2[15:8] : sdram_do2[7:0];
wire isGBC_game1, isGBC_game2;
wire cart1_has_save, cart2_has_save;
wire [31:0] RTC_timestampOut;
wire [47:0] RTC_savedtimeOut;
wire RTC_inuse;
wire rumbling1, rumbling2;
wire [2:0] mapper_sel = status[41:39];

reg [127:0] palette = 128'h828214517356305A5F1A3B4900000000;

always @(posedge clk_sys) begin
	if (palette_download & ioctl_wr) begin
			palette[127:0] <= {palette[111:0], ioctl_dout[7:0], ioctl_dout[15:8]};
	end
end

assign AUDIO_S = 1;

wire reset = (RESET | status[0] | buttons[1] | cart_download | boot_download | bk_loading);

reg megaduck = 0;
reg isGBC = 0;
always @(posedge clk_sys) if(reset) begin
	if (cart_download)
		megaduck <= sys_megaduck;
	if (md_download)
		megaduck <= sys_auto || sys_megaduck;

	if(~sys_auto) isGBC <= sys_gbc;
	else if(cart_download) begin
		if (!filetype[5:0]) isGBC <= (isGBC_game1 | isGBC_game2);
		else isGBC <= !filetype[7:6];
	end
end

// core 1
wire speed1;
wire SaveStateBus_rst1;

assign joy0_rumble = {8'd0, ((rumbling1 & ~status[38]) ? 8'd128 : 8'd0)};

reg ce_32k; // 32768Hz clock for RTC
reg [9:0] ce_32k_div;
always @(posedge clk_sys) begin
	ce_32k_div <= ce_32k_div + 1'b1;
	ce_32k <= !ce_32k_div;
end

cart_top cart1 (
	.reset	     ( reset      ),

	.clk_sys     ( clk_sys    ),
	.ce_cpu      ( ce1_cpu    ),
	.ce_cpu2x    ( ce1_cpu2x  ),
	.speed       ( speed1     ),
	.megaduck    ( megaduck   ),
	.mapper_sel  ( mapper_sel ),

	.cart_addr   ( cart1_addr  ),
	.cart_a15    ( cart1_a15   ),
	.cart_rd     ( cart1_rd    ),
	.cart_wr     ( cart1_wr    ),
	.cart_do     ( cart1_do    ),
	.cart_di     ( cart1_di    ),
	.cart_oe     ( cart1_oe    ),

	.nCS         ( gb1_nCS        ),

	.mbc_addr    ( mbc1_addr   ),

	.dn_write    (             ),
	.cart_ready  (             ),

	.cram_rd     ( cram1_rd     ),
	.cram_wr     ( cram1_wr     ),

	.cart_download ( cart_download & ~rom_load_gb2),

	.ram_mask_file (  ),
	.ram_size      (  ),
	.has_save      ( cart1_has_save ),

	.isGBC_game    ( isGBC_game1   ),
	.isSGB_game    (               ),

	.ioctl_download ( 1'b0           ),
	.ioctl_wr       ( ioctl_wr & ~rom_load_gb2),
	.ioctl_addr     ( ioctl_addr     ),
	.ioctl_dout     ( ioctl_dout     ),
	.ioctl_wait     (                ),

	.bk_wr          ( bk_wr1         ),
	.bk_rtc_wr      ( 1'b0           ),
	.bk_addr        ( bk_addr        ),
	.bk_data        ( bk_data        ),
	.bk_q           ( bk_q1          ),
	.img_size       ( img_size       ),

	.rom_di         ( rom1_do       ),

	.joystick_analog_0 ( joystick_analog_0 ),

	.ce_32k           ( ce_32k           ),
	.RTC_time         ( RTC_time         ),
	.RTC_timestampOut ( RTC_timestampOut ),
	.RTC_savedtimeOut ( RTC_savedtimeOut ),
	.RTC_inuse        ( RTC_inuse        ),

	.SaveStateExt_Din ( 0  ),
	.SaveStateExt_Adr ( 0  ),
	.SaveStateExt_wren( 0 ),
	.SaveStateExt_rst ( SaveStateBus_rst1  ),
	.SaveStateExt_Dout(  ),
	.savestate_load   ( 0   ),
	.sleep_savestate  ( 0   ),

	.Savestate_CRAMAddr     ( 0  ),
	.Savestate_CRAMRWrEn    ( 0  ),
	.Savestate_CRAMWriteData( 0  ),
	.Savestate_CRAMReadData (    ),

	.rumbling (rumbling1)
);

wire [15:0] AUDIO_L1;
wire [15:0] AUDIO_R1;

// the gameboy itself
gb gb1 (
	.reset	    ( reset      ),
	
	.clk_sys     ( clk_sys    ),
	.ce          ( ce1_cpu    ),   // the whole gameboy runs on 4mhnz
	.ce_2x       ( ce1_cpu2x  ),   // ~8MHz in dualspeed mode (GBC)
	
	.isGBC       ( isGBC      ),
	.real_cgb_boot ( using_real_cgb_bios ),
	.isSGB       ( 1'b0 ),
	.megaduck    ( megaduck   ),

	.joy_p54     ( joy1_p54     ),
	.joy_din     ( joy1_do      ),

	// interface to the "external" game cartridge
	.ext_bus_addr( cart1_addr  ),
	.ext_bus_a15 ( cart1_a15   ),
	.cart_rd     ( cart1_rd    ),
	.cart_wr     ( cart1_wr    ),
	.cart_do     ( cart1_do    ),
	.cart_di     ( cart1_di    ),
	.cart_oe     ( cart1_oe    ),

	.nCS         ( gb1_nCS     ),

	.boot_gba_en    ( boot_gba_available && status[37] ),
	.fast_boot_en   ( fastboot_available && status[42] ),

	.cgb_boot_download ( cgb_boot_download ),
	.dmg_boot_download ( dmg_boot_download ),
	.sgb_boot_download ( sgb_boot_download ),
	.ioctl_wr       ( ioctl_wr       ),
	.ioctl_addr     ( ioctl_addr     ),
	.ioctl_dout     ( ioctl_dout     ),

	// audio
	.audio_l 	 ( AUDIO_L1 ),
	.audio_r 	 ( AUDIO_R1 ),
	.audio_no_pops (status[43]),
	
	// interface to the lcd
	.lcd_clkena  ( lcd1_clkena ),
	.lcd_data    ( lcd1_data   ),
	.lcd_data_gb (            ),
	.lcd_mode    ( lcd1_mode   ),
	.lcd_on      ( lcd1_on     ),
	.lcd_vsync   ( lcd1_vsync  ),
	
	.speed       ( speed1    ),
	.DMA_on      (     ),
	
	// serial port
	.sc_int_clock2  (sc1_int_clock_out),
	.serial_clk_in  (ser1_clk_in),
	.serial_data_in (ser1_data_in),
	.serial_clk_out (ser1_clk_out),
	.serial_data_out(ser1_data_out),
	
	// Palette download will disable cheats option (HPS doesn't distinguish downloads),
	// so clear the cheats and disable second option (chheats enable/disable)
	.gg_reset(1'b0),
	.gg_en(1'b0),
	.gg_code(0),
	.gg_available(),
	
	// savestates
	.increaseSSHeaderCount (1'b0),
	.cart_ram_size   (8'd0),
	.save_state      (1'b0),
	.load_state      (1'b0),
	.savestate_number(2'b00),
	.sleep_savestate (),
	
	.SaveStateExt_Din (),
	.SaveStateExt_Adr (),
	.SaveStateExt_wren(),
	.SaveStateExt_rst (SaveStateBus_rst1),
	.SaveStateExt_Dout(0),
	.SaveStateExt_load(),
	
	.Savestate_CRAMAddr     (),
	.Savestate_CRAMRWrEn    (),
	.Savestate_CRAMWriteData(),
	.Savestate_CRAMReadData (0),
	
	.SAVE_out_Din(),            // data read from savestate
	.SAVE_out_Dout(0),          // data written to savestate
	.SAVE_out_Adr(),           // all addresses are DWORD addresses!
	.SAVE_out_rnw(),            // read = 1, write = 0
	.SAVE_out_ena(),            // one cycle high for each action
	.SAVE_out_be(),            
	.SAVE_out_done(1'b1),            // should be one cycle high when write is done or read value is valid
	
	.rewind_on(1'b0),
	.rewind_active(1'b0)
);

wire [1:0] joy1_p54;
wire [3:0] joy1_dir     = ~{ joystick_0[2], joystick_0[3], joystick_0[1], joystick_0[0] } | {4{joy1_p54[0]}};
wire [3:0] joy1_buttons = ~{ joystick_0[7], joystick_0[6], joystick_0[5], joystick_0[4] } | {4{joy1_p54[1]}};
wire [3:0] joy1_do      = joy1_dir & joy1_buttons;

// core 2
wire speed2;
wire SaveStateBus_rst2;

assign joy1_rumble = {8'd0, ((rumbling2 & ~status[38]) ? 8'd128 : 8'd0)};

cart_top cart2 (
	.reset	     ( reset      ),

	.clk_sys     ( clk_sys    ),
	.ce_cpu      ( ce2_cpu    ),
	.ce_cpu2x    ( ce2_cpu2x  ),
	.speed       ( speed2     ),
	.megaduck    ( megaduck   ),
	.mapper_sel  ( mapper_sel ),

	.cart_addr   ( cart2_addr  ),
	.cart_a15    ( cart2_a15   ),
	.cart_rd     ( cart2_rd    ),
	.cart_wr     ( cart2_wr    ),
	.cart_do     ( cart2_do    ),
	.cart_di     ( cart2_di    ),
	.cart_oe     ( cart2_oe    ),

	.nCS         ( gb2_nCS        ),

	.mbc_addr    ( mbc2_addr   ),

	.dn_write    (      ),
	.cart_ready  (      ),

	.cram_rd     ( cram2_rd     ),
	.cram_wr     ( cram2_wr     ),

	.cart_download ( cart_download ),

	.ram_mask_file (  ),
	.ram_size      (  ),
	.has_save      ( cart2_has_save ),

	.isGBC_game    ( isGBC_game2 ),
	.isSGB_game    (             ),

	.ioctl_download ( 1'b0           ),
	.ioctl_wr       ( ioctl_wr       ),
	.ioctl_addr     ( ioctl_addr     ),
	.ioctl_dout     ( ioctl_dout     ),
	.ioctl_wait     (  ),

	.bk_wr          ( bk_wr2         ),
	.bk_rtc_wr      ( 1'b0           ),
	.bk_addr        ( bk_addr        ),
	.bk_data        ( bk_data        ),
	.bk_q           ( bk_q2          ),
	.img_size       ( img_size       ),

	.rom_di         ( rom2_do      ),

	.joystick_analog_0 ( joystick_analog_1 ),

	.ce_32k           ( ce_32k           ),
	.RTC_time         ( RTC_time         ),
	.RTC_timestampOut (  ),
	.RTC_savedtimeOut (  ),
	.RTC_inuse        (  ),

	.SaveStateExt_Din ( 0  ),
	.SaveStateExt_Adr ( 0  ),
	.SaveStateExt_wren( 0 ),
	.SaveStateExt_rst ( SaveStateBus_rst2  ),
	.SaveStateExt_Dout(  ),
	.savestate_load   ( 0   ),
	.sleep_savestate  ( 0   ),

	.Savestate_CRAMAddr     ( 0  ),
	.Savestate_CRAMRWrEn    ( 0  ),
	.Savestate_CRAMWriteData( 0  ),
	.Savestate_CRAMReadData (    ),

	.rumbling (rumbling2)
);

wire [15:0] AUDIO_L2;
wire [15:0] AUDIO_R2;

// the gameboy itself
gb gb2 (
	.reset	    ( reset      ),
	
	.clk_sys     ( clk_sys    ),
	.ce          ( ce2_cpu    ),   // the whole gameboy runs on 4mhnz
	.ce_2x       ( ce2_cpu2x  ),   // ~8MHz in dualspeed mode (GBC)
	

	.isGBC       ( isGBC      ),
	.real_cgb_boot ( using_real_cgb_bios ),
	.isSGB       ( 1'b0 ),
	.megaduck    ( megaduck   ),

	.joy_p54     ( joy2_p54     ),
	.joy_din     ( joy2_do      ),

	// interface to the "external" game cartridge
	.ext_bus_addr( cart2_addr  ),
	.ext_bus_a15 ( cart2_a15   ),
	.cart_rd     ( cart2_rd    ),
	.cart_wr     ( cart2_wr    ),
	.cart_do     ( cart2_do    ),
	.cart_di     ( cart2_di    ),
	.cart_oe     ( cart2_oe    ),

	.nCS         ( gb2_nCS     ),

	.boot_gba_en    ( boot_gba_available && status[37] ),
	.fast_boot_en   ( fastboot_available && status[42] ),

	.cgb_boot_download ( cgb_boot_download ),
	.dmg_boot_download ( dmg_boot_download ),
	.sgb_boot_download ( sgb_boot_download ),
	.ioctl_wr       ( ioctl_wr       ),
	.ioctl_addr     ( ioctl_addr     ),
	.ioctl_dout     ( ioctl_dout     ),

	// audio
	.audio_l 	 ( AUDIO_L2 ),
	.audio_r 	 ( AUDIO_R2 ),
	.audio_no_pops (status[43]),
	
	// interface to the lcd
	.lcd_clkena  ( lcd2_clkena ),
	.lcd_data    ( lcd2_data   ),
	.lcd_data_gb (            ),
	.lcd_mode    ( lcd2_mode   ),
	.lcd_on      ( lcd2_on     ),
	.lcd_vsync   ( lcd2_vsync  ),
	
	.speed       ( speed2     ),
	.DMA_on      (      ),
	
	// serial port
	.sc_int_clock2  (sc2_int_clock_out),
	.serial_clk_in  (ser2_clk_in),
	.serial_data_in (ser2_data_in),
	.serial_clk_out (ser2_clk_out),
	.serial_data_out(ser2_data_out),
	
	// Palette download will disable cheats option (HPS doesn't distinguish downloads),
	// so clear the cheats and disable second option (chheats enable/disable)
	.gg_reset(1'b0),
	.gg_en(1'b0),
	.gg_code(0),
	.gg_available(),
	
	// savestates
	.increaseSSHeaderCount (1'b0),
	.cart_ram_size   (8'd0),
	.save_state      (1'b0),
	.load_state      (1'b0),
	.savestate_number(2'b00),
	.sleep_savestate (),
	
	.SaveStateExt_Din (),
	.SaveStateExt_Adr (),
	.SaveStateExt_wren(),
	.SaveStateExt_rst (SaveStateBus_rst2),
	.SaveStateExt_Dout(0),
	.SaveStateExt_load(),
	
	.Savestate_CRAMAddr     (),
	.Savestate_CRAMRWrEn    (),
	.Savestate_CRAMWriteData(),
	.Savestate_CRAMReadData (0),
	
	.SAVE_out_Din(),            // data read from savestate
	.SAVE_out_Dout(0),          // data written to savestate
	.SAVE_out_Adr(),           // all addresses are DWORD addresses!
	.SAVE_out_rnw(),            // read = 1, write = 0
	.SAVE_out_ena(),            // one cycle high for each action
	.SAVE_out_be(),            
	.SAVE_out_done(1'b1),            // should be one cycle high when write is done or read value is valid
	
	.rewind_on(1'b0),
	.rewind_active(1'b0)
);

wire [1:0] joy2_p54;
wire [3:0] joy2_dir     = ~{ joystick_1[2], joystick_1[3], joystick_1[1], joystick_1[0] } | {4{joy2_p54[0]}};
wire [3:0] joy2_buttons = ~{ joystick_1[7], joystick_1[6], joystick_1[5], joystick_1[4] } | {4{joy2_p54[1]}};
wire [3:0] joy2_do      = joy2_dir & joy2_buttons;

assign AUDIO_L = (status[17:16] == 3'd0) ? AUDIO_L1 : 
                 (status[17:16] == 3'd1) ? AUDIO_L2 : 
                 (status[17:16] == 3'd2) ? ($signed(AUDIO_L1[15:1]) + $signed(AUDIO_L2[15:1])) :
                                           ($signed(AUDIO_L1[15:1]) + $signed(AUDIO_R1[15:1]));

assign AUDIO_R = (status[17:16] == 3'd0) ? AUDIO_R1 : 
                 (status[17:16] == 3'd1) ? AUDIO_R2 : 
                 (status[17:16] == 3'd2) ? ($signed(AUDIO_R1[15:1]) + $signed(AUDIO_R2[15:1])) :
                                           ($signed(AUDIO_L2[15:1]) + $signed(AUDIO_R2[15:1]));


// the lcd to vga converter
wire [7:0] R,G,B;
wire video_hs, video_vs;
wire HBlank, VBlank;
wire ce_pix;
wire [8:0] h_cnt, v_cnt;
wire [1:0] tint = status[2:1];
wire h_end;

wire        lcd1_clkena;
wire [14:0] lcd1_data;
wire  [1:0] lcd1_mode;
wire        lcd1_on;
wire        lcd1_vsync;

wire        lcd2_clkena;
wire [14:0] lcd2_data;
wire  [1:0] lcd2_mode;
wire        lcd2_on;
wire        lcd2_vsync;

wire pauseVideoCore1;
wire pauseVideoCore2;

lcd lcd
(
	// serial interface
	.clk_sys( clk_sys    ),
	.ce     ( ce1_cpu    ),
	.ce2    ( ce2_cpu    ),

	.core1_lcd_clkena ( lcd1_clkena ),
	.core1_data       ( lcd1_data   ),
	.core1_mode       ( lcd1_mode   ),  // used to detect begin of new lines and frames
	.core1_on         ( lcd1_on     ),
	.core1_lcd_vs     ( lcd1_vsync  ),
   
   .core2_lcd_clkena ( lcd2_clkena ),
	.core2_data       ( lcd2_data   ),
	.core2_mode       ( lcd2_mode   ),  // used to detect begin of new lines and frames
	.core2_on         ( lcd2_on     ),
	.core2_lcd_vs     ( lcd2_vsync  ),

	.isGBC  ( isGBC      ),
   
	.seperatorLine  ( status[23] ),

	.tint   ( |tint       ),
	.inv    ( status[12]  ),
	.double_buffer( 1'b1),
	.originalcolors( status[30] ),
   
   .pauseVideoCore1 (pauseVideoCore1),
   .pauseVideoCore2 (pauseVideoCore2),
   
	// Palettes
	.pal1   (palette[127:104]),
	.pal2   (palette[103:80]),
	.pal3   (palette[79:56]),
	.pal4   (palette[55:32]),

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

video_mixer #(.LINE_LENGTH(320), .GAMMA(1)) video_mixer
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

	.ARX((!ar) ? (12'd20) : (ar - 1'd1)),
	.ARY((!ar) ? (12'd9 ) : 12'd0),
	.CROP_SIZE(0),
	.CROP_OFF(0),
	.SCALE(status[22:21])
);

//////////////////////////////// CE ////////////////////////////////////


wire ce1_cpu, ce1_cpu2x;
wire ce2_cpu, ce2_cpu2x;
wire ce_ram2x;

speedcontrol speedcontrol1
(
	.clk_sys     (clk_sys),
	.reset       (reset),
	.romread     (sdram_oe),
	.romack      (sdram_ack),
	.pausevideo  (pauseVideoCore1 & status[5]),
	.ce          (ce1_cpu),
	.ce_2x       (ce1_cpu2x)
);

speedcontrol speedcontrol2
(
	.clk_sys     (clk_sys),
	.reset       (reset),
	.romread     (sdram_oe2),
	.romack      (sdram_ack2),
	.pausevideo  (pauseVideoCore2 & status[5]),
	.ce          (ce2_cpu),
	.ce_2x       (ce2_cpu2x)
);

speedcontrol speedcontrolSDRAM
(
	.clk_sys     (clk_sys),
	.reset       (reset),
	.romread     (1'b0),
	.romack      (1'b1),
	.pausevideo  (1'b0),
	.ce          (),
	.ce_2x       (ce_ram2x)
);

/////////////////////////////  Serial link  ///////////////////////////////

assign USER_OUT[0] = 1'b1;
assign USER_OUT[1] = 1'b1;
assign USER_OUT[2] = 1'b1;
assign USER_OUT[3] = 1'b1;
assign USER_OUT[4] = 1'b1;
assign USER_OUT[5] = 1'b1;
assign USER_OUT[6] = 1'b1;

wire sc1_int_clock_out;
wire ser1_data_in;
wire ser1_data_out;
wire ser1_clk_in;
wire ser1_clk_out;

wire sc2_int_clock_out;
wire ser2_data_in;
wire ser2_data_out;
wire ser2_clk_in;
wire ser2_clk_out;

assign ser1_data_in = ser2_data_out;
assign ser1_clk_in  = ser2_clk_out;

assign ser2_data_in = ser1_data_out;
assign ser2_clk_in  = ser1_clk_out;

/////////////////////////  BRAM SAVE/LOAD  /////////////////////////////

wire [16:0] bk_addr = {sd_lba[7:0],sd_buff_addr};
wire bk_wr1 = ~sd_lba[8] & ~(rom_load_gb2 & dupe_save_gb2) & sd_buff_wr & sd_ack;
wire bk_wr2 = (sd_lba[8] | dupe_save_gb2) & sd_buff_wr & sd_ack;
wire [15:0] bk_data = sd_buff_dout;
wire [15:0] bk_q1;
wire [15:0] bk_q2;
assign sd_buff_din = (sd_lba[8]) ? bk_q2 : bk_q1;



wire downloading = cart_download;

reg  bk_ena          = 0;
reg  new_load        = 0;
reg  old_downloading = 0;
reg  sav_pending     = 0;
wire sav_supported   = (cart1_has_save | cart2_has_save) && bk_ena;

always @(posedge clk_sys) begin
	old_downloading <= downloading;
	if(~old_downloading & downloading) bk_ena <= 0;

	//Save file always mounted in the end of downloading state.
	if(downloading && img_mounted && !img_readonly) bk_ena <= 1;

	if (old_downloading & ~downloading & sav_supported)
		new_load <= 1'b1;
	else if (bk_state)
		new_load <= 1'b0;

	if ((cram1_wr | cram2_wr) & ~OSD_STATUS & sav_supported)
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
			
			// read max possible size or read half size for dupe mode
			if(sd_lba[8:0] == 9'h1FF || (sd_lba[8:0] == 9'h0FF && dupe_save_gb2)) begin
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
