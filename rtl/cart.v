module cart_top (
    input         reset,

    input         clk_sys,
    input         ce_cpu,
    input         ce_cpu2x,
    input         speed,

    input  [15:0] cart_addr,
    input         cart_rd,
    input         cart_wr,
    output  [7:0] cart_do,
    input   [7:0] cart_di, // data from CPU to cart
    output  [9:0] mbc_bank,

    output reg    dn_write,
    output        cart_ready,

    output        cram_rd,
    output        cram_wr,

    input         cart_download,

    output  [7:0] ram_mask_file,
    output  [7:0] ram_size,
    output        has_save,

    output        isGBC_game,
    output        isSGB_game,

    input         ioctl_download,
    input         ioctl_wr,
    input  [24:0] ioctl_addr,
    input  [15:0] ioctl_dout,
    output        ioctl_wait,

    input         bk_wr,
    input         bk_rtc_wr,
    input  [16:0] bk_addr,
    input  [15:0] bk_data,
    output [15:0] bk_q,
    input  [63:0] img_size,

    input  [15:0] sdram_di,

    input  [15:0] joystick_analog_0,

    input  [32:0] RTC_time,
    output [31:0] RTC_timestampOut,
    output [47:0] RTC_savedtimeOut,
    output        RTC_inuse,

    input  [63:0] SaveStateExt_Din,
    input   [9:0] SaveStateExt_Adr,
    input         SaveStateExt_wren,
    input         SaveStateExt_rst,
    output [63:0] SaveStateExt_Dout,
    input         savestate_load,
    input         sleep_savestate,

    input  [19:0] Savestate_CRAMAddr,
    input         Savestate_CRAMRWrEn,
    input   [7:0] Savestate_CRAMWriteData,
    output  [7:0] Savestate_CRAMReadData
);
///////////////////////////////////////////////////


// http://fms.komkon.org/GameBoy/Tech/Carts.html

// 32MB SDRAM memory map using word addresses
// 2 2 2 2 1 1 1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 0 0 D
// 3 2 1 0 9 8 7 6 5 4 3 2 1 0 9 8 7 6 5 4 3 2 1 0 S
// -------------------------------------------------
// 0 0 0 0 X X X X X X X X X X X X X X X X X X X X X up to 2MB used as ROM (MBC1-3), 8MB for MBC5
// 0 0 0 0 R R B B B B B C C C C C C C C C C C C C C MBC1 ROM (R=RAM bank in mode 0)

wire [15:0] SS_Ext;
wire [15:0] SS_Ext_BACK;
wire [63:0] SS_Ext2;
wire [63:0] SS_Ext2_BACK;

wire [63:0] SaveStateBus_Dout_or[0:1];

eReg_SavestateV #(0, 32, 15, 0, 64'h0000000000000001) iREG_SAVESTATE_Ext  (clk_sys, SaveStateExt_Din, SaveStateExt_Adr, SaveStateExt_wren, SaveStateExt_rst, SaveStateBus_Dout_or[0], SS_Ext_BACK,  SS_Ext);
eReg_SavestateV #(0, 37, 63, 0, 64'h0000000000000000) iREG_SAVESTATE_Ext2 (clk_sys, SaveStateExt_Din, SaveStateExt_Adr, SaveStateExt_wren, SaveStateExt_rst, SaveStateBus_Dout_or[1], SS_Ext2_BACK, SS_Ext2);

assign SaveStateExt_Dout = SaveStateBus_Dout_or[0] | SaveStateBus_Dout_or[1];

wire [7:0] cram_do;
wire [16:0] mbc_cram_addr;
wire mbc_ram_enable, mbc_battery;
wire mbc_cram_wr;
wire [7:0] mbc_cram_wr_do;

mappers mappers (
    .reset ( reset ),
    .clk_sys   ( clk_sys ),
    .ce_cpu    ( ce_cpu ),
    .ce_cpu2x  ( ce_cpu2x ),
    .speed ( speed ),

    .mbc1 ( mbc1 ),
    .mbc1m ( mbc1m ),
    .mbc2 ( mbc2 ),
    .mbc3 ( mbc3 ),
    .mbc30( mbc30 ),
    .mbc5 ( mbc5 ),
    .mbc6 ( mbc6 ),
    .mbc7 ( mbc7 ),
    .mmm01 ( mmm01 ),
    .huc1 ( HuC1 ),
    .huc3 ( HuC3 ),
    .gb_camera ( gb_camera ),
    .tama ( tama ),

    .joystick_analog_0 ( joystick_analog_0 ),

    .RTC_time          ( RTC_time         ),
    .RTC_timestampOut  ( RTC_timestampOut ),
    .RTC_savedtimeOut  ( RTC_savedtimeOut ),
    .RTC_inuse         ( RTC_inuse        ),

    .bk_wr          ( bk_wr          ),
    .bk_rtc_wr      ( bk_rtc_wr      ),
    .bk_addr        ( bk_addr        ),
    .bk_data        ( bk_data        ),
    .img_size       ( img_size       ),

    .savestate_load   ( savestate_load ),
    .savestate_data   ( SS_Ext         ),
    .savestate_back   ( SS_Ext_BACK    ),
    .savestate_data2  ( SS_Ext2        ),
    .savestate_back2  ( SS_Ext2_BACK   ),

    .has_ram  ( |cart_ram_size ),
    .ram_mask ( ram_mask ),
    .rom_mask ( rom_mask ),

    .cart_addr ( cart_addr ),
    .cart_mbc_type ( cart_mbc_type ),

    .cart_wr   ( cart_wr ),
    .cart_di   ( cart_di ),

    .cram_rd   ( cram_rd  ),
    .cram_di   ( cram_q  ),
    .cram_do   ( cram_do  ),
    .cram_addr ( mbc_cram_addr ),

    .cram_wr_do ( mbc_cram_wr_do ),
    .cram_wr    ( mbc_cram_wr ),

    .mbc_bank    ( mbc_bank ),
    .ram_enabled ( mbc_ram_enable ),
    .has_battery ( mbc_battery )

);

// extract header fields extracted from cartridge
// during download
reg  [7:0] cart_mbc_type;
reg  [7:0] cart_rom_size;
reg  [7:0] cart_ram_size;
reg  [7:0] cart_cgb_flag;
reg  [7:0] cart_sgb_flag;
reg  [7:0] cart_old_licensee;
reg [15:0] cart_logo_data[0:7];

// RAM size
wire [3:0] ram_mask =                 // 0 - no ram
   (cart_ram_size == 'h01) ? 4'b0000: // 1 -   2k -  1 bank
   (cart_ram_size == 'h02) ? 4'b0000: // 2 -   8k -  1 bank
   (cart_ram_size == 'h03) ? 4'b0011: // 3 -  32k -  4 banks
   (cart_ram_size == 'h05) ? 4'b0111: // 5 -  64k -  8 banks
                             4'b1111; // 4 - 128k - 16 banks

// ROM size
wire [8:0] rom_mask =
   (cart_rom_size == 'h00) ? 9'b000000001:  // $00 -   2 banks = 32k (direct mapped)
   (cart_rom_size == 'h01) ? 9'b000000011:  // $01 -   4 banks = 64k
   (cart_rom_size == 'h02) ? 9'b000000111:  // $02 -   8 banks = 128k
   (cart_rom_size == 'h03) ? 9'b000001111:  // $03 -  16 banks = 256k
   (cart_rom_size == 'h04) ? 9'b000011111:  // $04 -  32 banks = 512k
   (cart_rom_size == 'h05) ? 9'b000111111:  // $05 -  64 banks = 1M
   (cart_rom_size == 'h06) ? 9'b001111111:  // $06 - 128 banks = 2M
   (cart_rom_size == 'h07) ? 9'b011111111:  // $07 - 256 banks = 4M
   (cart_rom_size == 'h08) ? 9'b111111111:  // $08 - 512 banks = 8M
   (cart_rom_size == 'h52) ? 9'b001111111:  // $52 -  72 banks = 1.1M
   (cart_rom_size == 'h53) ? 9'b001111111:  // $53 -  80 banks = 1.2M
   (cart_rom_size == 'h54) ? 9'b001111111:  // $54 -  96 banks = 1.5M
                             9'b001111111;

wire mbc1 =
    (cart_mbc_type == 'h01) || // MBC1
    (cart_mbc_type == 'h02) || // MBC1+RAM
    (cart_mbc_type == 'h03);   // MBC1+RAM+BATTERY

wire mbc2 =
    (cart_mbc_type == 'h05) || // MBC2
    (cart_mbc_type == 'h06);   // MBC2+BATTERY

/*
wire mmm01 =
    (cart_mbc_type == 'h0b) || // MMM01
    (cart_mbc_type == 'h0c) || // MMM01+RAM
    (cart_mbc_type == 'h0d);   // MMM01+RAM+BATTERY
*/

wire mbc3 =
    (cart_mbc_type == 'h0F) || // MBC3+TIMER+BATTERY
    (cart_mbc_type == 'h10) || // MBC3+TIMER+RAM+BATTERY
    (cart_mbc_type == 'h11) || // MBC3
    (cart_mbc_type == 'h12) || // MBC3+RAM
    (cart_mbc_type == 'h13);   // MBC3+RAM+BATTERY

wire mbc30 =                   // MBC3 with RAM size 64 KByte refers to MBC30
    mbc3 &&
    ((cart_rom_size == 'h07) || (cart_ram_size == 'h05));

// MBC4 doesn't exist !

wire mbc5 =
    (cart_mbc_type == 'h19) || // MBC5
    (cart_mbc_type == 'h20) || // MBC5+RAM
    (cart_mbc_type == 'h21) || // MBC5+RAM+BATTERY
    (cart_mbc_type == 'h22) || // MBC5+RUMBLE
    (cart_mbc_type == 'h23) || // MBC5+RUMBLE+RAM
    (cart_mbc_type == 'h24);   // MBC5+RUMBLE+RAM+BATTERY

wire mbc6 =
    (cart_mbc_type == 'h20)    // MBC6

wire mbc7 =
    (cart_mbc_type == 'h22);   // MBC7+SENSOR+RUMBLE+RAM+BATTERY

wire gb_camera =
    (cart_mbc_type == 'hFC);   // POCKET CAMERA

wire tama =
    (cart_mbc_type == 'hFD);   // BANDAI TAMA5

wire HuC3 =
    (cart_mbc_type == 'hFE);   // HuC3

wire HuC1 =
  (cart_mbc_type == 'hFF);     // HuC1+RAM+BATTERY

assign isGBC_game = (cart_cgb_flag == 8'h80 || cart_cgb_flag == 8'hC0);
assign isSGB_game = (cart_sgb_flag == 8'h03 && cart_old_licensee == 8'h33);


// MBC1M detect
reg [7:0] cart_logo_check;
reg [2:0] cart_logo_idx;
wire mbc1m = &cart_logo_check;

reg old_cart_download;
always @(posedge clk_sys) begin

    old_cart_download <= cart_download;
    if(~old_cart_download & cart_download) begin
        cart_logo_idx <= 3'd0;
        cart_logo_check <= 8'd0;
        cart_mbc_type <= 8'd0;
        mbc1m <= 0;
        mmm01 <= 0;
    end

    if(cart_download & ioctl_wr) begin
        case(ioctl_addr[11:0])
            'h142: cart_cgb_flag <= ioctl_dout[15:8];
            'h146: begin
                {cart_mbc_type, cart_sgb_flag} <= ioctl_dout;
                // "Mani 4 in 1" have incorrectly set MBC3 in the header
                if ( mmm01 && ioctl_dout[15:8] == 8'h11) cart_mbc_type <= 8'h0B;
            end
            'h148: { cart_ram_size, cart_rom_size } <= ioctl_dout;
            'h14a: { cart_old_licensee } <= ioctl_dout[15:8];
        endcase

        //Store cart logo data
        if (ioctl_addr >= 'h104 && ioctl_addr <= 'h112) begin
            cart_logo_data[cart_logo_idx] <= ioctl_dout;
            cart_logo_idx <= cart_logo_idx + 1'b1;
        end

        // MBC1 Multicart detect: Compare 8 words of logo data at second 256KByte bank
        // MMM01 detect: Compare the last bank every 512KByte ($78000+)
        if ( mbc1m_bank | mmm01_bank ) begin
            if (ioctl_addr[11:0] >= 12'h104 && ioctl_addr[11:0] <= 12'h112) begin
                cart_logo_check[cart_logo_idx] <= (ioctl_dout == cart_logo_data[cart_logo_idx]);
                cart_logo_idx <= cart_logo_idx + 1'b1;
                if (&cart_logo_idx) begin
                    if (mbc1m_bank) mbc1m_check_end <= 1;
                    if (mmm01_bank) mmm01_check_end <= 1;
                end
            end
        end
    end

    if (mbc1m_check_end) begin
        mbc1m_check_end <= 0;
        mbc1m <= cart_logo_match;
    end

    if (mmm01_check_end) begin
        mmm01_check_end <= 0;
        mmm01 <= cart_logo_match;
        if (cart_logo_match) mbc1m <= 0;
    end
end

assign ram_size = cart_ram_size;

reg cart_ready_r = 0;
reg ioctl_wait_r;
always @(posedge clk_sys) begin
    if(ioctl_wr) ioctl_wait_r <= 1;

    if(speed?ce_cpu2x:ce_cpu) begin
        dn_write <= ioctl_wait_r;
        if(dn_write) {ioctl_wait_r, dn_write} <= 0;
        if(dn_write) cart_ready_r <= 1;
    end
end

assign cart_ready = cart_ready_r;
assign ioctl_wait = ioctl_wait_r;

reg [7:0] cart_do_r;
always @* begin
    if (~cart_ready)
        cart_do_r = 8'h00;
    else if (cram_rd)
        cart_do_r = cram_do;
    else
        cart_do_r = (cart_addr[0]) ? sdram_di[15:8] : sdram_di[7:0];
end

assign cart_do = cart_do_r;

reg read_low = 0;
always @(posedge clk_sys) begin
    read_low <= cram_addr[0];
end

assign Savestate_CRAMReadData = read_low ? cram_q_h : cram_q_l;

wire [7:0] cram_q = cram_addr[0] ? cram_q_h : cram_q_l;
wire [7:0] cram_q_h;
wire [7:0] cram_q_l;

wire is_cram_addr = (cart_addr[15:13] == 3'b101);
assign cram_rd = cart_rd & is_cram_addr;
assign cram_wr = sleep_savestate ? Savestate_CRAMRWrEn : mbc_cram_wr || (cart_wr & is_cram_addr & mbc_ram_enable);

wire [16:0] cram_addr = sleep_savestate ? Savestate_CRAMAddr[16:0] : mbc_cram_addr;
wire [7:0] cram_di = sleep_savestate ? Savestate_CRAMWriteData : mbc_cram_wr ? mbc_cram_wr_do : cart_di;

// RAM size
assign ram_mask_file =               // 0 - no ram
     (mbc2 || mbc7 || tama) ? 8'h01: // MBC2 512x4bits, MBC7 256 bytes EEPROM
    (cart_ram_size == 'h01) ? 8'h03: // 1 -   2k -  1 bank   sd_lba[1:0]
    (cart_ram_size == 'h02) ? 8'h0F: // 2 -   8k -  1 bank   sd_lba[3:0]
    (cart_ram_size == 'h03) ? 8'h3F: // 3 -  32k -  4 banks  sd_lba[5:0]
    (cart_ram_size == 'h05) ? 8'h7F: // 5 -  64k -  8 banks  sd_lba[6:0]
                              8'hFF; // 4 - 128k - 16 banks  sd_lba[7:0] 1111

assign has_save = mbc_battery && (cart_ram_size > 0 || mbc2 || mbc7 || tama);

// Up to 8kb * 16banks of Cart Ram (128kb)

dpram #(16) cram_l (
    .clock_a (clk_sys),
    .address_a (cram_addr[16:1]),
    .wren_a (cram_wr & ~cram_addr[0]),
    .data_a (cram_di),
    .q_a (cram_q_l),

    .clock_b (clk_sys),
    .address_b (bk_addr[15:0]),
    .wren_b (bk_wr),
    .data_b (bk_data[7:0]),
    .q_b (bk_q[7:0])
);

dpram #(16) cram_h (
    .clock_a (clk_sys),
    .address_a (cram_addr[16:1]),
    .wren_a (cram_wr & cram_addr[0]),
    .data_a (cram_di),
    .q_a (cram_q_h),

    .clock_b (clk_sys),
    .address_b (bk_addr[15:0]),
    .wren_b (bk_wr),
    .data_b (bk_data[15:8]),
    .q_b (bk_q[15:8])
);

endmodule
