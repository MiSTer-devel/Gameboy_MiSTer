module mappers(
	input         reset,

	input         clk_sys,
	input         ce_cpu,
	input         ce_cpu2x,
	input         speed,

	input         mbc1,
	input         mbc1m,
	input         mbc2,
	input         mbc3,
	input         mbc30,
	input         mbc5,
	input         mbc6,
	input         mbc7,
	input         mmm01,
	input         huc1,
	input         huc3,
	input         gb_camera,
	input         tama,

	input  [15:0] joystick_analog_0,

	input  [32:0] RTC_time,
	output [31:0] RTC_timestampOut,
	output [47:0] RTC_savedtimeOut,
	output        RTC_inuse,

	input         bk_wr,
	input         bk_rtc_wr,
	input  [16:0] bk_addr,
	input  [15:0] bk_data,
	input  [63:0] img_size,

	input         savestate_load,
	input  [15:0] savestate_data,
	output [15:0] savestate_back,
	input  [63:0] savestate_data2,
	output [63:0] savestate_back2,

	input         has_ram,
	input   [3:0] ram_mask,
	input   [8:0] rom_mask,

	input  [15:0] cart_addr,
	input   [7:0] cart_mbc_type,

	input         cart_wr,
	input   [7:0] cart_di,

	input         cram_rd,
	input   [7:0] cram_di,    // input from Cart RAM q
	output  [7:0] cram_do,    // output to CPU
	output [16:0] cram_addr,

	output  [7:0] cram_wr_do, // For writing to Cart RAM directly without CPU (MBC7 EEPROM)
	output        cram_wr,

	output  [9:0] mbc_bank,
	output        ram_enabled,
	output        has_battery

);

tri1 [7:0] cram_do_b;
tri0 [9:0] mbc_bank_b;
tri0 [16:0] cram_addr_b;
tri0 ram_enabled_b, has_battery_b;
tri0 [15:0] savestate_back_b;
tri0 [63:0] savestate_back2_b;
tri0 [7:0] cram_wr_do_b;
tri0 cram_wr_b;
tri0 [31:0] RTC_timestampOut_b;
tri0 [47:0] RTC_savedtimeOut_b;
tri0 RTC_inuse_b;


wire ce = speed ? ce_cpu2x : ce_cpu;
wire no_mapper = ~(mbc1 | mbc2 | mbc3 | mbc5 | mbc6 | mbc7 | mmm01 | huc1 | huc3 | gb_camera | tama);

mbc1 map_mbc1 (
	.enable           ( mbc1 ),
	.mbc1m            ( mbc1m ),

	.clk_sys          ( clk_sys ),
	.ce_cpu           ( ce ),

	.savestate_load   ( savestate_load ),
	.savestate_data   ( savestate_data ),
	.savestate_back_b ( savestate_back_b ),

	.has_ram          ( has_ram  ),
	.ram_mask         ( ram_mask ),
	.rom_mask         ( rom_mask ),

	.cart_addr        ( cart_addr ),
	.cart_mbc_type    ( cart_mbc_type ),

	.cart_wr          ( cart_wr ),
	.cart_di          ( cart_di ),

	.cram_di          ( cram_di ),
	.cram_do_b        ( cram_do_b ),
	.cram_addr_b      ( cram_addr_b ),

	.mbc_bank_b       ( mbc_bank_b ),
	.ram_enabled_b    ( ram_enabled_b ),
	.has_battery_b    ( has_battery_b )
);

mbc2 map_mbc2 (
	.enable           ( mbc2 ),

	.clk_sys          ( clk_sys ),
	.ce_cpu           ( ce ),

	.savestate_load   ( savestate_load ),
	.savestate_data   ( savestate_data ),
	.savestate_back_b ( savestate_back_b ),

	.ram_mask         ( ram_mask ),
	.rom_mask         ( rom_mask ),

	.cart_addr        ( cart_addr ),
	.cart_mbc_type    ( cart_mbc_type ),

	.cart_wr          ( cart_wr ),
	.cart_di          ( cart_di ),

	.cram_di          ( cram_di ),
	.cram_do_b        ( cram_do_b ),
	.cram_addr_b      ( cram_addr_b ),

	.mbc_bank_b       ( mbc_bank_b ),
	.ram_enabled_b    ( ram_enabled_b ),
	.has_battery_b    ( has_battery_b )
);

mbc3 map_mbc3 (
	.enable            ( mbc3 ),
	.reset             ( reset ),
	.mbc30             ( mbc30 ),

	.clk_sys           ( clk_sys ),
	.ce_cpu            ( ce ),

	.savestate_load    ( savestate_load ),
	.savestate_data    ( savestate_data ),
	.savestate_back_b  ( savestate_back_b ),

	.RTC_time          ( RTC_time         ),
	.RTC_timestampOut_b( RTC_timestampOut_b ),
	.RTC_savedtimeOut_b( RTC_savedtimeOut_b ),
	.RTC_inuse_b       ( RTC_inuse_b      ),

	.bk_wr             ( bk_wr     ),
	.bk_rtc_wr         ( bk_rtc_wr ),
	.bk_addr           ( bk_addr   ),
	.bk_data           ( bk_data   ),
	.img_size          ( img_size  ),

	.has_ram           ( has_ram  ),
	.ram_mask          ( ram_mask ),
	.rom_mask          ( rom_mask ),

	.cart_addr         ( cart_addr     ),
	.cart_mbc_type     ( cart_mbc_type ),

	.cart_wr           ( cart_wr ),
	.cart_di           ( cart_di ),

	.cram_di           ( cram_di     ),
	.cram_do_b         ( cram_do_b   ),
	.cram_addr_b       ( cram_addr_b ),

	.mbc_bank_b        ( mbc_bank_b    ),
	.ram_enabled_b     ( ram_enabled_b ),
	.has_battery_b     ( has_battery_b )
);

mbc5 map_mbc5 (
	.enable           ( mbc5 ),

	.clk_sys          ( clk_sys ),
	.ce_cpu           ( ce ),

	.savestate_load   ( savestate_load ),
	.savestate_data   ( savestate_data ),
	.savestate_back_b ( savestate_back_b ),

	.has_ram          ( has_ram  ),
	.ram_mask         ( ram_mask ),
	.rom_mask         ( rom_mask ),

	.cart_addr        ( cart_addr ),
	.cart_mbc_type    ( cart_mbc_type ),

	.cart_wr          ( cart_wr ),
	.cart_di          ( cart_di ),

	.cram_di          ( cram_di ),
	.cram_do_b        ( cram_do_b ),
	.cram_addr_b      ( cram_addr_b ),

	.mbc_bank_b       ( mbc_bank_b ),
	.ram_enabled_b    ( ram_enabled_b ),
	.has_battery_b    ( has_battery_b )
);

mbc6 map_mbc6 (
	.enable           ( mbc6 ),

	.clk_sys          ( clk_sys ),
	.ce_cpu           ( ce ),

	.savestate_load   ( savestate_load ),
	.savestate_data   ( savestate_data2 ),
	.savestate_back_b ( savestate_back2_b ),

	.has_ram          ( has_ram  ),
	.ram_mask         ( ram_mask ),
	.rom_mask         ( rom_mask ),

	.cart_addr        ( cart_addr ),
	.cart_mbc_type    ( cart_mbc_type ),

	.cart_wr          ( cart_wr ),
	.cart_di          ( cart_di ),

	.cram_di          ( cram_di ),
	.cram_do_b        ( cram_do_b ),
	.cram_addr_b      ( cram_addr_b ),

	.mbc_bank_b       ( mbc_bank_b ),
	.ram_enabled_b    ( ram_enabled_b ),
	.has_battery_b    ( has_battery_b )
);

mbc7 map_mbc7 (
	.enable           ( mbc7 ),

	.clk_sys          ( clk_sys ),
	.ce_cpu           ( ce ),
	.ce_1x            ( ce_cpu ),

	.savestate_load   ( savestate_load ),
	.savestate_data   ( savestate_data ),
	.savestate_back_b ( savestate_back_b ),
	.savestate_data2  ( savestate_data2 ),
	.savestate_back2_b( savestate_back2_b ),

	.joystick_analog_x  ( joystick_analog_0[7:0] ),
	.joystick_analog_y  ( joystick_analog_0[15:8] ),

	.has_ram          ( has_ram  ),
	.ram_mask         ( ram_mask ),
	.rom_mask         ( rom_mask ),

	.cart_addr        ( cart_addr ),
	.cart_mbc_type    ( cart_mbc_type ),

	.cart_wr          ( cart_wr ),
	.cart_di          ( cart_di ),

	.cram_di          ( cram_di ),
	.cram_do_b        ( cram_do_b ),
	.cram_addr_b      ( cram_addr_b ),

	.cram_wr_do_b     ( cram_wr_do_b ),
	.cram_wr_b        ( cram_wr_b ),

	.mbc_bank_b       ( mbc_bank_b ),
	.ram_enabled_b    ( ram_enabled_b ),
	.has_battery_b    ( has_battery_b )
);

mmm01 map_mmm01 (
	.enable           ( mmm01 ),

	.clk_sys          ( clk_sys ),
	.ce_cpu           ( ce ),

	.savestate_load   ( savestate_load ),
	.savestate_data   ( savestate_data2 ),
	.savestate_back_b ( savestate_back2_b ),

	.has_ram          ( has_ram  ),
	.ram_mask         ( ram_mask ),
	.rom_mask         ( rom_mask ),

	.cart_addr        ( cart_addr ),
	.cart_mbc_type    ( cart_mbc_type ),

	.cart_wr          ( cart_wr ),
	.cart_di          ( cart_di ),

	.cram_di          ( cram_di ),
	.cram_do_b        ( cram_do_b ),
	.cram_addr_b      ( cram_addr_b ),

	.mbc_bank_b       ( mbc_bank_b ),
	.ram_enabled_b    ( ram_enabled_b ),
	.has_battery_b    ( has_battery_b )
);

huc1 map_huc1 (
	.enable           ( huc1 ),

	.clk_sys          ( clk_sys ),
	.ce_cpu           ( ce ),

	.savestate_load   ( savestate_load ),
	.savestate_data   ( savestate_data ),
	.savestate_back_b ( savestate_back_b ),

	.has_ram          ( has_ram  ),
	.ram_mask         ( ram_mask ),
	.rom_mask         ( rom_mask ),

	.cart_addr        ( cart_addr ),
	.cart_mbc_type    ( cart_mbc_type ),

	.cart_wr          ( cart_wr ),
	.cart_di          ( cart_di ),

	.cram_di          ( cram_di ),
	.cram_do_b        ( cram_do_b ),
	.cram_addr_b      ( cram_addr_b ),

	.mbc_bank_b       ( mbc_bank_b ),
	.ram_enabled_b    ( ram_enabled_b ),
	.has_battery_b    ( has_battery_b )
);

huc3 map_huc3 (
	.enable            ( huc3 ),

	.clk_sys           ( clk_sys ),
	.ce_cpu            ( ce ),

	.savestate_load    ( savestate_load ),
	.savestate_data    ( savestate_data2 ),
	.savestate_back_b  ( savestate_back2_b ),

	.RTC_time          ( RTC_time         ),
	.RTC_timestampOut_b( RTC_timestampOut_b ),
	.RTC_savedtimeOut_b( RTC_savedtimeOut_b ),
	.RTC_inuse_b       ( RTC_inuse_b      ),

	.bk_rtc_wr         ( bk_rtc_wr ),
	.bk_addr           ( bk_addr   ),
	.bk_data           ( bk_data   ),

	.has_ram           ( has_ram  ),
	.ram_mask          ( ram_mask ),
	.rom_mask          ( rom_mask ),

	.cart_addr         ( cart_addr ),
	.cart_mbc_type     ( cart_mbc_type ),

	.cart_wr           ( cart_wr ),
	.cart_di           ( cart_di ),

	.cram_di           ( cram_di ),
	.cram_do_b         ( cram_do_b ),
	.cram_addr_b       ( cram_addr_b ),

	.mbc_bank_b        ( mbc_bank_b ),
	.ram_enabled_b     ( ram_enabled_b ),
	.has_battery_b     ( has_battery_b )
);


gb_camera map_gb_camera (
	.enable           ( gb_camera ),

	.clk_sys          ( clk_sys ),
	.ce_cpu           ( ce ),

	.savestate_load   ( savestate_load ),
	.savestate_data   ( savestate_data ),
	.savestate_back_b ( savestate_back_b ),

	.ram_mask         ( ram_mask ),
	.rom_mask         ( rom_mask ),

	.cart_addr        ( cart_addr ),
	.cart_mbc_type    ( cart_mbc_type ),

	.cart_wr          ( cart_wr ),
	.cart_di          ( cart_di ),

	.cram_di          ( cram_di ),
	.cram_do_b        ( cram_do_b ),
	.cram_addr_b      ( cram_addr_b ),

	.mbc_bank_b       ( mbc_bank_b ),
	.ram_enabled_b    ( ram_enabled_b ),
	.has_battery_b    ( has_battery_b )
);

// TODO: TAMA RTC
tama map_tama (
	.enable           ( tama ),

	.clk_sys          ( clk_sys ),
	.ce_cpu           ( ce ),
	.ce_1x            ( ce_cpu ),

	.savestate_load   ( savestate_load ),
	.savestate_data   ( savestate_data2 ),
	.savestate_back_b ( savestate_back2_b ),

	.has_ram          ( has_ram  ),
	.ram_mask         ( ram_mask ),
	.rom_mask         ( rom_mask ),

	.cart_addr        ( cart_addr ),
	.cart_mbc_type    ( cart_mbc_type ),

	.cart_wr          ( cart_wr ),
	.cart_di          ( cart_di ),

	.cram_rd          ( cram_rd ),
	.cram_di          ( cram_di ),
	.cram_do_b        ( cram_do_b ),
	.cram_addr_b      ( cram_addr_b ),

	.cram_wr_do_b     ( cram_wr_do_b ),
	.cram_wr_b        ( cram_wr_b ),

	.mbc_bank_b       ( mbc_bank_b ),
	.ram_enabled_b    ( ram_enabled_b ),
	.has_battery_b    ( has_battery_b )
);

assign { cram_do, ram_enabled } = { cram_do_b, ram_enabled_b };
assign { savestate_back, savestate_back2 } = { savestate_back_b, savestate_back2_b };
assign { RTC_timestampOut, RTC_savedtimeOut, RTC_inuse } = { RTC_timestampOut_b, RTC_savedtimeOut_b, RTC_inuse_b };
assign { cram_wr_do, cram_wr } = { cram_wr_do_b, cram_wr_b };

assign mbc_bank = no_mapper ? {8'd0, cart_addr[14:13]} : mbc_bank_b;
assign cram_addr = no_mapper ? {4'd0, cart_addr[12:0]} : cram_addr_b;
assign has_battery = no_mapper ? (cart_mbc_type == 8'h09) : has_battery_b;

endmodule