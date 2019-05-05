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
	inout  [44:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        VGA_CLK,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        VGA_CE,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)

	//Base video clock. Usually equals to CLK_SYS.
	output        HDMI_CLK,

	//Multiple resolutions are supported using different HDMI_CE rates.
	//Must be based on CLK_VIDEO
	output        HDMI_CE,

	output  [7:0] HDMI_R,
	output  [7:0] HDMI_G,
	output  [7:0] HDMI_B,
	output        HDMI_HS,
	output        HDMI_VS,
	output        HDMI_DE,   // = ~(VBlank | HBlank)
	output  [1:0] HDMI_SL,   // scanlines fx

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output  [7:0] HDMI_ARX,
	output  [7:0] HDMI_ARY,

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)
	input         TAPE_IN,

	// SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface

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

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..5 - USR1..USR4
	// Set USER_OUT to 1 to read from USER_IN.
	input   [5:0] USER_IN,
	output  [5:0] USER_OUT,

	input         OSD_STATUS
);

assign USER_OUT = '1;
assign VGA_F1 = 0;

assign {UART_RTS, UART_TXD, UART_DTR} = 0;

assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;

assign LED_USER  = ioctl_download | sav_pending;
assign LED_DISK  = 0;
assign LED_POWER = 0;


assign HDMI_ARX  = status[4:3] == 2'b10 ? 8'd16:
						 status[4:3] == 2'b01 ? 8'd10:
						 8'd4;
						 
assign HDMI_ARY  = status[4:3] == 2'b10 ? 8'd9:
						 status[4:3] == 2'b01 ? 8'd9:
						 8'd3;

assign AUDIO_MIX = status[8:7];

`include "build_id.v" 
localparam CONF_STR1 = {
	"GAMEBOY;;",
	"-;",
	"FS,GBCGB ,Load ROM;",
	"OEF,System,Auto,Gameboy,Gameboy Color;",
	"-;",
	"OC,Inverted color,No,Yes;",
	"FC,GG,Game Genie Code;",
	"OH,Game Genie,ON,OFF;",
	"O1,Palette,Grayscale,Custom;"
};

localparam CONF_STR2 = {
	",GBP,Load Palette;",
	"-;",
	"OD,OSD triggered autosaves,No,Yes;",
};

localparam CONF_STR3 = {
	"9,Load Backup RAM;"
};

localparam CONF_STR4 = {
	"A,Save Backup RAM;",
	"-;",
	"O34,Aspect ratio,4:3,10:9,16:9;",
	"O78,Stereo mix,none,25%,50%,100%;",
	"-;",
	"R0,Reset;",
	"J1,A,B,Select,Start;",
	"V,v",`BUILD_DATE
};

////////////////////   CLOCKS   ///////////////////

wire clk_sys;
wire clk_vga;
wire pll_locked;
		
pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys),
	.outclk_1(SDRAM_CLK),
	.outclk_2(clk_vga),
	.locked(pll_locked)
);

///////////////////////////////////////////////////

wire [31:0] status;
wire  [1:0] buttons;

wire        ioctl_download;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire [15:0] ioctl_dout;
reg         ioctl_wait;

wire [15:0] joystick_0, joystick_1;
wire [15:0] joystick = joystick_0 | joystick_1;
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

wire [7:0] sav_char = sav_supported ? "R" : "+";

hps_io #(.STRLEN(($size(CONF_STR1)>>3) + ($size(CONF_STR2)>>3) + ($size(CONF_STR3)>>3) + ($size(CONF_STR4)>>3) + 3), .WIDE(1)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.conf_str({CONF_STR1,status[1]?"F":"+",CONF_STR2, sav_char, CONF_STR3, sav_char, CONF_STR4}),

	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_wait(ioctl_wait),
	.ioctl_index(filetype),
	
	.sd_lba(sd_lba),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din(sd_buff_din),
	.sd_buff_wr(sd_buff_wr),
	.img_mounted(img_mounted),
	.img_readonly(img_readonly),
	.img_size(img_size),

	.buttons(buttons),
	.status(status),

	.joystick_0(joystick_0),
	.joystick_1(joystick_1)
);

///////////////////////////////////////////////////

wire cart_download = ioctl_download && (filetype == 8'h01 || filetype == 8'h41 || filetype == 8'h80);
wire palette_download = ioctl_download && (filetype == 8'h07 || filetype == 8'h00);
wire bios_download = ioctl_download && (filetype == 8'h40);

wire type_gg = filetype == 8'h04;

wire  [1:0] sdram_ds = cart_download ? 2'b11 : {cart_addr[0], ~cart_addr[0]};
wire [15:0] sdram_do;
wire [15:0] sdram_di = cart_download ? ioctl_dout : 16'd0;
wire [23:0] sdram_addr = cart_download? ioctl_addr[24:1]: {2'b00, mbc_bank, cart_addr[12:1]};
wire sdram_oe = ~cart_download & cart_rd & ~cram_rd;
wire sdram_we = cart_download & dn_write;

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

    // system interface
   .clk            ( clk_sys                   ),
   .sync           ( ce_cpu2x                  ),
   .init           ( ~pll_locked               ),

   // cpu interface
   .din            ( sdram_di                  ),
   .addr           ( sdram_addr                ),
   .ds             ( sdram_ds                  ),
   .we             ( sdram_we                  ),
   .oe             ( sdram_oe                  ),
   .dout           ( sdram_do                  )
);

reg cart_ready = 0;
reg dn_write;
always @(posedge clk_sys) begin
	if(ioctl_wr) ioctl_wait <= 1;

	if(speed?ce_cpu2x:ce_cpu) begin
		dn_write <= ioctl_wait;
		if(dn_write) {ioctl_wait, dn_write} <= 0;
		if(dn_write) cart_ready <= 1;
	end
end

///////////////////////////////////////////////////


// http://fms.komkon.org/GameBoy/Tech/Carts.html

// 32MB SDRAM memory map using word addresses
// 2 2 2 2 1 1 1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 0 0 D
// 3 2 1 0 9 8 7 6 5 4 3 2 1 0 9 8 7 6 5 4 3 2 1 0 S
// -------------------------------------------------
// 0 0 0 0 X X X X X X X X X X X X X X X X X X X X X up to 2MB used as ROM (MBC1-3), 8MB for MBC5 
// 0 0 0 0 R R B B B B B C C C C C C C C C C C C C C MBC1 ROM (R=RAM bank in mode 0)

// ---------------------------------------------------------------
// ----------------------------- MBC1 ----------------------------
// ---------------------------------------------------------------

wire [9:0] mbc1_addr = 
	(cart_addr[15:14] == 2'b00)?{9'd0, cart_addr[13]}:        				// 16k ROM Bank 0
	(cart_addr[15:14] == 2'b01)?{2'b00, mbc1_rom_bank, cart_addr[13]}: 	// 16k ROM Bank 1-127
	9'd0;
	
wire [9:0] mbc2_addr = 
	(cart_addr[15:14] == 2'b00)?{9'd0, cart_addr[13]}:        				// 16k ROM Bank 0
	(cart_addr[15:14] == 2'b01)?{2'b00, mbc2_rom_bank, cart_addr[13]}:	// 16k ROM Bank 1-15
	9'd0;
	
wire [9:0] mbc3_addr = 
	(cart_addr[15:14] == 2'b00)?{9'd0, cart_addr[13]}:        				// 16k ROM Bank 0
	(cart_addr[15:14] == 2'b01)?{2'b00,mbc3_rom_bank, cart_addr[13]}:  	// 16k ROM Bank 1-127
	9'd0;

wire [9:0] mbc5_addr = 
	(cart_addr[15:14] == 2'b00)?{9'd0, cart_addr[13]}:        				// 16k ROM Bank 0
	(cart_addr[15:14] == 2'b01)?{mbc5_rom_bank, cart_addr[13]}:       	// 16k ROM Bank 0-480 (0h-1E0h)
	9'd0;
	
// -------------------------- RAM banking ------------------------

// in mode 0 (16/8 mode) the ram is not banked 
// in mode 1 (4/32 mode) four ram banks are used
wire [1:0] mbc1_ram_bank = (mbc1_mode?mbc_ram_bank_reg[1:0]:2'b00) & ram_mask[1:0];
wire [1:0] mbc3_ram_bank = mbc_ram_bank_reg[1:0] & ram_mask[1:0];
wire [3:0] mbc5_ram_bank = mbc_ram_bank_reg & ram_mask;

// -------------------------- ROM banking ------------------------
   
// in mode 0 (16/8 mode) the ram bank select signals are the upper rom address lines 
// in mode 1 (4/32 mode) the upper two rom address lines are 2'b00
wire [6:0] mbc1_rom_bank_mode = { mbc1_mode?2'b00:mbc_ram_bank_reg[1:0], mbc_rom_bank_reg[4:0]};

// in mode 0 map memory at A000-BFFF
// in mode 1 map rtc register at A000-BFFF
//wire [6:0] mbc3_ram_bank_addr = { mbc3_mode?2'b00:mbc3_ram_bank_reg, mbc3_rom_bank_reg};

// mask address lines to enable proper mirroring
wire [6:0] mbc1_rom_bank = mbc1_rom_bank_mode & rom_mask[6:0];		 //128
wire [6:0] mbc2_rom_bank = mbc_rom_bank_reg[6:0] & rom_mask[6:0];  //16
wire [6:0] mbc3_rom_bank = mbc_rom_bank_reg[6:0] & rom_mask[6:0];  //128
wire [8:0] mbc5_rom_bank = mbc_rom_bank_reg & rom_mask;  //480

wire mbc_battery = (cart_mbc_type == 8'h03) || (cart_mbc_type == 8'h06) || (cart_mbc_type == 8'h09) || (cart_mbc_type == 8'h0D) ||
	(cart_mbc_type == 8'h10) || (cart_mbc_type == 8'h13) || (cart_mbc_type == 8'h1B) || (cart_mbc_type == 8'h1E) ||
	(cart_mbc_type == 8'h22) || (cart_mbc_type == 8'hFF);

// --------------------- CPU register interface ------------------
reg mbc_ram_enable;
reg mbc1_mode;
reg mbc3_mode;
reg [8:0] mbc_rom_bank_reg;
reg [3:0] mbc_ram_bank_reg; //0-15


always @(posedge clk_sys) begin
	if(reset) begin
		mbc_rom_bank_reg <= 5'd1;
		mbc_ram_bank_reg <= 4'd0;
		mbc1_mode <= 1'b0;
		mbc3_mode <= 1'b0;
		mbc_ram_enable <= 1'b0;
	end else if(ce_cpu2x) begin
		
		//write to ROM bank register
		if(cart_wr && (cart_addr[15:13] == 3'b001)) begin
			if(~mbc5 && cart_di[6:0]==0) //special case mbc1-3 rombank 0=1
				mbc_rom_bank_reg <= 5'd1;
			else if (mbc5) begin
				if (cart_addr[13:12] == 2'b11) //3000-3FFF High bit
					mbc_rom_bank_reg[8] <= cart_di[0];
				else //2000-2FFF low 8 bits
					mbc_rom_bank_reg[7:0] <= cart_di[7:0];
			end else
				mbc_rom_bank_reg <= {2'b00,cart_di[6:0]}; //mbc1-3
		end	
		
		//write to RAM bank register
		if(cart_wr && (cart_addr[15:13] == 3'b010)) begin
			if (mbc3) begin
				if (cart_di[3]==1)
					mbc3_mode <= 1'b1; //enable RTC
				else begin
					mbc3_mode <= 1'b0; //enable RAM
					mbc_ram_bank_reg <= {2'b00,cart_di[1:0]};
				end
			end else
				if (mbc5)//can probably be simplified
					mbc_ram_bank_reg <= cart_di[3:0];
				else
					mbc_ram_bank_reg <= {2'b00,cart_di[1:0]};
		end

		// MBC1 ROM/RAM Mode Select
		if(mbc1 && cart_wr && (cart_addr[15:13] == 3'b011))
				mbc1_mode <= cart_di[0];
		
		//RAM enable/disable
		if(ce_cpu2x && cart_wr && (cart_addr[15:13] == 3'b000))
			mbc_ram_enable <= (cart_di[3:0] == 4'ha);
	end
end


// extract header fields extracted from cartridge
// during download
reg [7:0] cart_mbc_type;
reg [7:0] cart_rom_size;
reg [7:0] cart_ram_size;
reg [7:0] cart_cgb_flag;

// RAM size
wire [3:0] ram_mask =               	// 0 - no ram
	   (cart_ram_size == 1)?4'b0000:   	// 1 - 2k, 1 bank
	   (cart_ram_size == 2)?4'b0000:   	// 2 - 8k, 1 bank
	   (cart_ram_size == 3)?4'b0011:		// 3 - 32k, 4 banks
		4'b1111;   						   	// 4 - 128k 16 banks
		
// ROM size
wire [8:0] rom_mask =                    	 // 0 - 2 banks, 32k direct mapped
	   (cart_rom_size == 1)? 9'b000000011:  // 1 - 4 banks = 64k
	   (cart_rom_size == 2)? 9'b000000111:  // 2 - 8 banks = 128k
	   (cart_rom_size == 3)? 9'b000001111:  // 3 - 16 banks = 256k
	   (cart_rom_size == 4)? 9'b000011111:  // 4 - 32 banks = 512k
	   (cart_rom_size == 5)? 9'b000111111:  // 5 - 64 banks = 1M
	   (cart_rom_size == 6)? 9'b001111111:  // 6 - 128 banks = 2M		
		(cart_rom_size == 7)? 9'b011111111:  // 7 - 256 banks = 4M
		(cart_rom_size == 8)? 9'b111111111:  // 8 - 512 banks = 8M
		(cart_rom_size == 82)?9'b001111111:  //$52 - 72 banks = 1.1M
		(cart_rom_size == 83)?9'b001111111:  //$53 - 80 banks = 1.2M
		(cart_rom_size == 84)?9'b001111111:
                            9'b001111111;  //$54 - 96 banks = 1.5M

wire mbc1 = (cart_mbc_type == 1) || (cart_mbc_type == 2) || (cart_mbc_type == 3);
wire mbc2 = (cart_mbc_type == 5) || (cart_mbc_type == 6);
//wire mmm01 = (cart_mbc_type == 11) || (cart_mbc_type == 12) || (cart_mbc_type == 13) || (cart_mbc_type == 14);
wire mbc3 = (cart_mbc_type == 15) || (cart_mbc_type == 16) || (cart_mbc_type == 17) || (cart_mbc_type == 18) || (cart_mbc_type == 19);
//wire mbc4 = (cart_mbc_type == 21) || (cart_mbc_type == 22) || (cart_mbc_type == 23);
wire mbc5 = (cart_mbc_type == 25) || (cart_mbc_type == 26) || (cart_mbc_type == 27) || (cart_mbc_type == 28) || (cart_mbc_type == 29) || (cart_mbc_type == 30);
//wire tama5 = (cart_mbc_type == 253);
//wire tama6 = (cart_mbc_type == ???);
//wire HuC1 = (cart_mbc_type == 254);
//wire HuC3 = (cart_mbc_type == 255);

wire [9:0] mbc_bank =
	mbc1?mbc1_addr:                  // MBC1, 16k bank 0, 16k bank 1-127 + ram
	mbc2?mbc2_addr:                  // MBC2, 16k bank 0, 16k bank 1-15 + ram
	mbc3?mbc3_addr:
	mbc5?mbc5_addr:
//	tama5?tama5_addr:
//	HuC1?HuC1_addr:
//	HuC3?HuC3_addr:              
	{8'd0, cart_addr[14:13]};  // no MBC, 32k linear address
	
wire isGBC_game = (cart_cgb_flag == 8'h80 || cart_cgb_flag == 8'hC0);

reg [127:0] palette = 128'h828214517356305A5F1A3B4900000000;

always @(posedge clk_sys) begin
	if(!pll_locked) begin
		cart_mbc_type <= 8'h00;
		cart_rom_size <= 8'h00;
		cart_ram_size <= 8'h00;
	end else begin
		if(cart_download & ioctl_wr) begin
			case(ioctl_addr)
			   'h142: cart_cgb_flag <= ioctl_dout[15:8];
				'h146: cart_mbc_type <= ioctl_dout[15:8];
				'h148: { cart_ram_size, cart_rom_size } <= ioctl_dout;
			endcase
		end 
	end
	if (palette_download & ioctl_wr) begin
			palette[127:0] <= {palette[111:0], ioctl_dout[7:0], ioctl_dout[15:8]};
	end
end

//TODO: e.g. output and read timer register values from mbc3 when selected 
wire [7:0] cart_di;    // data from cpu to cart
wire [7:0] cart_do =
	~cart_ready ?
		8'h00 :
		cram_rd ? 
			cram_do :
			cart_addr[0] ?
				sdram_do[15:8]:
				sdram_do[7:0];


wire [15:0] cart_addr;
wire cart_rd;
wire cart_wr;

wire lcd_clkena;
wire [14:0] lcd_data;
wire [1:0] lcd_mode;
wire lcd_on;

assign AUDIO_S = 0;

wire reset = (RESET | status[0] | buttons[1] | cart_download | bk_loading);
wire speed;

reg isGBC = 0;
always @(posedge clk_sys) if(reset) isGBC <= status[15:14] ? status[15] : !filetype[7:4];

// the gameboy itself
gb gb (
	.reset	    ( reset      ),
	.clk         ( clk_cpu    ),   // the whole gameboy runs on 4mhnz
	.clk2x       ( clk_cpu2x  ),   // ~8MHz in dualspeed mode (GBC)
	.new_game_load  ( cart_download),

	.fast_boot   ( 0          ),
	.joystick    ( joystick   ),
	.isGBC       ( isGBC      ),
	.isGBC_game  ( isGBC_game ),

	// interface to the "external" game cartridge
	.cart_addr   ( cart_addr  ),
	.cart_rd     ( cart_rd    ),
	.cart_wr     ( cart_wr    ),
	.cart_do     ( cart_do    ),
	.cart_di     ( cart_di    ),
	
	//gbc bios interface
	.gbc_bios_addr   ( bios_addr  ),
	.gbc_bios_do     ( bios_do    ),

	// audio
	.audio_l 	 ( AUDIO_L	  ),
	.audio_r 	 ( AUDIO_R	  ),
	
	// interface to the lcd
	.lcd_clkena  ( lcd_clkena ),
	.lcd_data    ( lcd_data   ),
	.lcd_mode    ( lcd_mode   ),
	.lcd_on      ( lcd_on     ),
	.speed       ( speed      ),
	
	.gg              (status[17]),
	.gg_code         (gg_code)
);

wire vga_bl;

// VGA output
lcd #(80, 80, 48, 48) lcd_vga (
	 .pclk   ( clk_vga    ),
	 .pce    ( ce_vga     ),
	 .clk    ( clk_cpu    ),
	 .isGBC  ( isGBC      ),

	 .tint   ( status[1]  ),
	 .inv    ( status[12]  ),

	 // Palettes
	 .pal1   (palette[127:104]),
	 .pal2   (palette[103:80]),
	 .pal3   (palette[79:56]),
	 .pal4   (palette[55:32]),

	 // serial interface
	 .clkena ( lcd_clkena ),
	 .data   ( lcd_data   ),
	 .mode   ( lcd_mode   ),  // used to detect begin of new lines and frames
	 .on     ( lcd_on     ),
	 
  	 .hs     ( VGA_HS  ),
	 .vs     ( VGA_VS  ),
	 .blank  ( vga_bl  ),
	 .r      ( VGA_R   ),
	 .g      ( VGA_G   ),
	 .b      ( VGA_B   )
);

assign VGA_CLK = clk_vga;
assign VGA_CE = ce_vga;
assign VGA_DE = ~vga_bl;

wire hdmi_bl;

// HDMI output
lcd lcd_hdmi (
	 .pclk   ( clk_sys_old),
	 .pce    ( ce_pix     ),
	 .clk    ( clk_cpu    ),
	 .isGBC  ( isGBC      ),

	 .tint   ( status[1]  ),
	 .inv    ( status[12]  ),

	 // Palettes
	 .pal1   (palette[127:104]),
	 .pal2   (palette[103:80]),
	 .pal3   (palette[79:56]),
	 .pal4   (palette[55:32]),

	 // serial interface
	 .clkena ( lcd_clkena ),
	 .data   ( lcd_data   ),
	 .mode   ( lcd_mode   ),  // used to detect begin of new lines and frames
	 .on     ( lcd_on     ),
	 
  	 .hs     ( HDMI_HS  ),
	 .vs     ( HDMI_VS  ),
	 .blank  ( hdmi_bl ),
	 .r      ( HDMI_R   ),
	 .g      ( HDMI_G   ),
	 .b      ( HDMI_B   )
);

assign HDMI_CLK = clk_sys;
assign HDMI_CE = ce_pix;
assign HDMI_DE = ~hdmi_bl;
assign HDMI_SL = 0;

wire clk_sys_old =  clk_sys & ce_sys;
wire ce_cpu2x = ce_pix;
wire clk_cpu = clk_sys & ce_cpu;
wire clk_cpu2x = clk_sys & ce_pix;

reg ce_pix, ce_cpu,ce_sys;
always @(negedge clk_sys) begin
	reg [3:0] div = 0;

	div <= div + 1'd1;
	ce_sys   <= !div[0];
	ce_pix   <= !div[2:0];
	ce_cpu   <= !div[3:0];
end

reg ce_vga;
always @(negedge clk_vga) begin
	reg [3:0] div = 0;

	div <= div + 1'd1;
	ce_vga   <= !div[1:0];   // clk_vga div 4   = 6.029 MHz
end


///////////////////////////// GBC BIOS /////////////////////////////////

wire [7:0] bios_do;
wire [11:0] bios_addr;

dpram_dif #(12,8,11,16) boot_rom_gbc (
	.clock (clk_sys),
	
	.address_a (bios_addr),
	.wren_a (),
	.data_a (),
	.q_a (bios_do),
	
	.address_b (ioctl_addr[11:1]),
	.wren_b (ioctl_wr && bios_download),
	.data_b (ioctl_dout),
	.q_b ()
);

/////////////////////////  GAME GENIE //////////////////////////////////

reg [34:0] gg_code;

// Code layout:
// {clock bit, enable, compare enable, 15'b address, 8'b compare, 8'b replace}
//  34         33      32              31:16         15:8         7:0
reg [3:0] old_ioctl_addr;
always_ff @(posedge clk_sys) begin
	gg_code[34] <= 1'b0;
	old_ioctl_addr <= ioctl_addr[3:0];
	gg_code[34] <= 1'b0;

	if (ioctl_download && type_gg) begin
		case (ioctl_addr[3:0])
			0:  gg_code[32]    <= ioctl_dout[0];   // Compare Enable
			4:  gg_code[31:16] <= ioctl_dout;      // Address
			8:  gg_code[15:8]  <= ioctl_dout[7:0]; // compare byte
			12: gg_code[7:0]   <= ioctl_dout[7:0]; // replace byte
			14: gg_code[34]    <=  1'b1;           // Clock it in
		endcase
	end
end

/////////////////////////  BRAM SAVE/LOAD  /////////////////////////////

wire [16:0] bk_addr = {sd_lba[7:0],sd_buff_addr};
wire bk_wr = sd_buff_wr & sd_ack;
wire [15:0] bk_data = sd_buff_dout;
wire [15:0] bk_q;
assign sd_buff_din = bk_q;

wire [7:0] cram_do =
	mbc_ram_enable ? 
		((cart_addr[15:9] == 7'b1010000) && mbc2) ? 
			{4'hF,cram_q[3:0]} : // 4 bit MBC2 Ram needs top half masked.
			mbc3_mode ?
				8'h0:            // RTC mode 
				cram_q :         // Return normal value
		8'hFF;                   // Ram not enabled

wire [7:0] cram_q = cram_addr[0] ? cram_q_h : cram_q_l;
wire [7:0] cram_q_h;
wire [7:0] cram_q_l;

wire is_cram_addr = (cart_addr[15:13] == 3'b101);
wire cram_rd = cart_rd & is_cram_addr;
wire cram_wr = cart_wr & is_cram_addr;
wire [16:0] cram_addr = mbc1? {2'b00,mbc1_ram_bank, cart_addr[12:0]}:
								mbc3? {2'b00,mbc3_ram_bank, cart_addr[12:0]}:
								mbc5?	{mbc5_ram_bank, cart_addr[12:0]}:
								{4'd0, cart_addr[12:0]};

// Up to 8kb * 16banks of Cart Ram (128kb)

dpram #(16) cram_l (
	.clock_a (clk_cpu2x),
	.address_a (cram_addr[16:1]),
	.wren_a (cram_wr & ~cram_addr[0]),
	.data_a (cart_di),
	.q_a (cram_q_l),
	
	.clock_b (clk_sys),
	.address_b (bk_addr[15:0]),
	.wren_b (bk_wr),
	.data_b (bk_data[7:0]),
	.q_b (bk_q[7:0])
);

dpram #(16) cram_h (
	.clock_a (clk_cpu2x),
	.address_a (cram_addr[16:1]),
	.wren_a (cram_wr & cram_addr[0]),
	.data_a (cart_di),
	.q_a (cram_q_h),
	
	.clock_b (clk_sys),
	.address_b (bk_addr[15:0]),
	.wren_b (bk_wr),
	.data_b (bk_data[15:8]),
	.q_b (bk_q[15:8])
);

wire downloading = cart_download;

reg  bk_ena          = 0;
reg  new_load        = 0;
reg  old_downloading = 0;
reg  sav_pending     = 0;
wire sav_supported   = (mbc_battery && (cart_ram_size > 0 || mbc2) && bk_ena);

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

// RAM size
wire [7:0] ram_mask_file =  											// 0 - no ram
		(mbc2)?8'h01:														// mbc2 512x4bits
	   (cart_ram_size == 1)?8'h03:   								// 1 - 2k, 1 bank		 sd_lba[1:0]
	   (cart_ram_size == 2)?8'h0F:   								// 2 - 8k, 1 bank		 sd_lba[3:0]
	   (cart_ram_size == 3)?8'h3F:									// 3 - 32k, 4 banks	 sd_lba[5:0]
		8'hFF;   						   								// 4 - 128k 16 banks  sd_lba[7:0] 1111

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
			
			if(sd_lba[7:0]>=ram_mask_file) begin
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
