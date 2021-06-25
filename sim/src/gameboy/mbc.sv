module mbc
(
   input         clk_sys,
   input         clkram,
   input         reset,
   input         ce_cpu2x,

   input  [15:0] cart_addr,
   input         cart_rd,
   input         cart_wr,
   output  [7:0] cart_do,
   input   [7:0] cart_di,

   output reg [7:0]  cart_ram_size,
   output        is_gbc,

   input         sleep_savestate,

   input [63:0]  SaveStateBus_Din,
   input [9:0]   SaveStateBus_Adr,
   input         SaveStateBus_wren,
   input         SaveStateBus_rst,
   output [63:0] SaveStateBus_Dout,
   input         savestate_load,

   input [19:0]  Savestate_CRAMAddr,
   input         Savestate_CRAMRWrEn,
   input [7:0]   Savestate_CRAMWriteData,
   output [7:0]  Savestate_CRAMReadData
);


///////////////////////////////////////////////////


// http://fms.komkon.org/GameBoy/Tech/Carts.html

// 32MB SDRAM memory map using word addresses
// 2 2 2 2 1 1 1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 0 0 D
// 3 2 1 0 9 8 7 6 5 4 3 2 1 0 9 8 7 6 5 4 3 2 1 0 S
// -------------------------------------------------
// 0 0 0 0 X X X X X X X X X X X X X X X X X X X X X up to 2MB used as ROM (MBC1-3), 8MB for MBC5
// 0 0 0 0 R R B B B B B C C C C C C C C C C C C C C MBC1 ROM (R=RAM bank in mode 0)

wire [6:0] mbc1_rom_bank_mode;
wire [8:0] rom_mask;
wire [3:0] ram_mask;

reg mbc_ram_enable;
reg mbc1_mode;
reg mbc3_mode;
reg [8:0] mbc_rom_bank_reg;
reg [3:0] mbc_ram_bank_reg; // 0-15

reg [7:0] cart_logo_check = 8'd0;
reg [2:0] cart_logo_idx = 3'd0;
wire mbc1m = &cart_logo_check;

// 0x0000-0x3FFF = Bank 0
wire [8:0] mbc_rom_bank = (cart_addr[15:14] == 2'b00) ? 9'd0 : mbc_rom_bank_reg;

// mask address lines to enable proper mirroring
wire [6:0] mbc1_rom_bank = mbc1_rom_bank_mode & rom_mask[6:0]; // 128
wire [6:0] mbc2_rom_bank = mbc_rom_bank[6:0]  & rom_mask[6:0]; // 16
wire [6:0] mbc3_rom_bank = mbc_rom_bank[6:0]  & rom_mask[6:0]; // 128
wire [8:0] mbc5_rom_bank = mbc_rom_bank       & rom_mask;      // 480
wire [8:0] mbc6_rom_bank = mbc_rom_bank       & rom_mask;      // 128

// extract header fields extracted from cartridge
// during download
wire [7:0] cart_mbc_type;
reg  [7:0] cart_rom_size;
reg  [7:0] cart_cgb_flag;
reg  [7:0] cart_sgb_flag;
reg  [7:0] cart_old_licensee;
reg [15:0] cart_logo_data[0:7];

// RAM size
assign ram_mask =                         // 0 - no ram
       (cart_ram_size == 'h01) ? 4'b0000: // 1 -   2k -  1 bank
       (cart_ram_size == 'h02) ? 4'b0000: // 2 -   8k -  1 bank
       (cart_ram_size == 'h03) ? 4'b0011: // 3 -  32k -  4 banks
       (cart_ram_size == 'h05) ? 4'b0111: // 5 -  64k -  8 banks
                                 4'b1111; // 4 - 128k - 16 banks

// ROM size
assign rom_mask =
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

wire gb_camera =
    (cart_mbc_type == 'hFC);   // POCKET CAMERA

/*
wire tama5 =
    (cart_mbc_type == 'hFD);   // BANDAI TAMA5

wire HuC3 =
    (cart_mbc_type == 'hFE);   // HuC3
*/

wire HuC1 =
  (cart_mbc_type == 'hFF);     // HuC1+RAM+BATTERY


// ---------------------------------------------------------------
// ----------------------------- MBC -----------------------------
// ---------------------------------------------------------------

wire [9:0] mbc1_addr = {2'b00, mbc1_rom_bank, cart_addr[13]}; // 16k ROM Bank 0-127 or MBC1M Bank 0-63

wire [9:0] mbc2_addr = {2'b00, mbc2_rom_bank, cart_addr[13]}; // 16k ROM Bank 0-15

wire [9:0] mbc3_addr = {2'b00, mbc3_rom_bank, cart_addr[13]}; // 16k ROM Bank 0-127

wire [9:0] mbc5_addr = {       mbc5_rom_bank, cart_addr[13]}; // 16k ROM Bank 0-480 (0h-1E0h)

wire [9:0] mbc6_addr = {       mbc6_rom_bank, cart_addr[13]}; // 16k ROM Bank 0-127

// https://forums.nesdev.com/viewtopic.php?p=168940#p168940
// https://gekkio.fi/files/gb-docs/gbctr.pdf
// MBC1 $6000 Mode register:
// 0: Bank2 ANDed with CPU A14. Bank2 affects ROM 0x4000-0x7FFF only
// 1: Passthrough. Bank2 affects ROM 0x0000-0x3FFF, 0x4000-0x7FFF, RAM 0xA000-0xBFFF
wire [1:0] mbc1_bank2 = mbc_ram_bank_reg[1:0] & {2{cart_addr[14] | mbc1_mode}};

// -------------------------- RAM banking ------------------------

wire [1:0] mbc1_ram_bank = mbc1_bank2 & ram_mask[1:0];
wire [1:0] mbc3_ram_bank = mbc_ram_bank_reg[1:0] & ram_mask[1:0];
wire [3:0] mbc5_ram_bank = mbc_ram_bank_reg & ram_mask;

// -------------------------- ROM banking ------------------------

// MBC1:  4x32 16KByte banks
// MBC1M: 4x16 16KByte banks
assign mbc1_rom_bank_mode = mbc1m ? { 1'b0, mbc1_bank2, mbc_rom_bank[3:0] } :
                                    {       mbc1_bank2, mbc_rom_bank[4:0] };

// in mode 0 map memory at A000-BFFF
// in mode 1 map rtc register at A000-BFFF
// wire [6:0] mbc3_ram_bank_addr = { mbc3_mode?2'b00:mbc3_ram_bank_reg, mbc3_rom_bank_reg};

wire mbc_battery =
    (cart_mbc_type == 8'h03) || // MBC1+RAM+BATTERY
    (cart_mbc_type == 8'h06) || // MBC2+BATTERY
    (cart_mbc_type == 8'h09) || // ROM+RAM+BATTERY
    (cart_mbc_type == 8'h0D) || // MMM01+RAM+BATTERY
    (cart_mbc_type == 8'h0F) || // MBC3+TIMER+BATTERY
    (cart_mbc_type == 8'h10) || // MBC3+TIMER+RAM+BATTER
    (cart_mbc_type == 8'h13) || // MBC3+RAM+BATTERY
    (cart_mbc_type == 8'h1B) || // MBC5+RAM+BATTERY
    (cart_mbc_type == 8'h1E) || // MBC5+RUMBLE+RAM+BATTERY
    (cart_mbc_type == 8'h22) || // MBC7+SENSOR+RUMBLE+RAM+BATTERY
    (cart_mbc_type == 8'hFF);   // HuC1+RAM+BATTERY


// --------------------- CPU register interface ------------------

wire [15:0] SS_Ext;
wire [15:0] SS_Ext_BACK;

assign SS_Ext_BACK[ 8: 0] = mbc_rom_bank_reg;
assign SS_Ext_BACK[12: 9] = mbc_ram_bank_reg;
assign SS_Ext_BACK[   13] = mbc1_mode;
assign SS_Ext_BACK[   14] = mbc3_mode;
assign SS_Ext_BACK[   15] = mbc_ram_enable;

always @(posedge clk_sys) begin
    if (savestate_load) begin
        mbc_rom_bank_reg <= SS_Ext[ 8: 0]; // 5'd1;
        mbc_ram_bank_reg <= SS_Ext[12: 9]; // 4'd0;
        mbc1_mode        <= SS_Ext[   13]; // 1'b0;
        mbc3_mode        <= SS_Ext[   14]; // 1'b0;
        mbc_ram_enable   <= SS_Ext[   15]; // 1'b0;
    end else if (reset) begin
        mbc_rom_bank_reg <= 5'd1;
        mbc_ram_bank_reg <= 4'd0;
        mbc1_mode        <= 1'b0;
        mbc3_mode        <= 1'b0;
        mbc_ram_enable   <= 1'b0;
    end else if (ce_cpu2x) begin

        // write to ROM bank register
        if (cart_wr && (cart_addr[15:13] == 3'b001)) begin
            if (~mbc5 && (cart_di[6:0]==0 || (mbc1 && cart_di[4:0]==0) || (mbc2 && cart_di[3:0]==0))) // special case mbc1-3 rombank 0=1
                mbc_rom_bank_reg <= 5'd1;
            else if (mbc5) begin
                if (cart_addr[13:12] == 2'b11) // 3000-3FFF High bit
                    mbc_rom_bank_reg[8] <= cart_di[0];
                else // 2000-2FFF low 8 bits
                    mbc_rom_bank_reg[7:0] <= cart_di[7:0];
            end else
                mbc_rom_bank_reg <= {2'b00,cart_di[6:0]}; // mbc1-3
        end

        // write to RAM bank register
        if (cart_wr && (cart_addr[15:13] == 3'b010)) begin
            if (mbc3) begin
                if (cart_di[3]==1)
                    mbc3_mode <= 1'b1; // enable RTC
                else begin
                    mbc3_mode <= 1'b0; // enable RAM
                    mbc_ram_bank_reg <= {2'b00,cart_di[1:0]};
                end
            end else
                if (mbc5)// can probably be simplified
                    mbc_ram_bank_reg <= cart_di[3:0];
                else
                    mbc_ram_bank_reg <= {2'b00,cart_di[1:0]};
        end

        // MBC1 ROM/RAM Mode Select
        if (mbc1 && cart_wr && (cart_addr[15:13] == 3'b011))
                mbc1_mode <= cart_di[0];

        // RAM enable/disable
        if (ce_cpu2x && cart_wr && (cart_addr[15:13] == 3'b000))
            mbc_ram_enable <= (cart_di[3:0] == 4'ha);
    end
end

wire [9:0] mbc_bank =
    mbc1  ? mbc1_addr:  // MBC1, 16k bank 0, 16k bank 1-127 + RAM
    mbc2  ? mbc2_addr:  // MBC2, 16k bank 0, 16k bank  1-15 + RAM
    mbc3  ? mbc3_addr:
    mbc5  ? mbc5_addr:
    mbc6  ? mbc6_addr:
/*
    tama5 ? tama5_addr:
    HuC1  ? HuC1_addr:
    HuC3  ? HuC3_addr:
*/
    {8'd0, cart_addr[14:13]}; // no MBC, 32k linear address

wire isGBC_game = (cart_cgb_flag == 8'h80 || cart_cgb_flag == 8'hC0);
wire isSGB_game = (cart_sgb_flag == 8'h03 && cart_old_licensee == 8'h33);

assign is_gbc = isGBC_game;

reg [127:0] palette = 128'h828214517356305A5F1A3B4900000000;

// MBC1M detect
// always @(posedge clk_sys) begin
//    if (~old_downloading & downloading) begin
//        cart_logo_idx <= 3'd0;
//        cart_logo_check <= 8'd0;
//    end
//
//    if (cart_download & ioctl_wr) begin
//        case(ioctl_addr)
//            'h142: cart_cgb_flag <= ioctl_dout[15:8];
//            'h146: {cart_mbc_type, cart_sgb_flag} <= ioctl_dout;
//            'h148: { cart_ram_size, cart_rom_size } <= ioctl_dout;
//            'h14a: { cart_old_licensee } <= ioctl_dout[15:8];
//        endcase
//
//        // Store cart logo data
//        if (ioctl_addr >= 'h104 && ioctl_addr <= 'h112) begin
//            cart_logo_data[cart_logo_idx] <= ioctl_dout;
//            cart_logo_idx <= cart_logo_idx + 1'b1;
//        end
//
//        // MBC1 Multicart detect: Compare 8 words of logo data at second 256KByte bank
//        if (ioctl_addr >= 'h40104 && ioctl_addr <= 'h40112) begin
//            cart_logo_check[cart_logo_idx] <= (ioctl_dout == cart_logo_data[cart_logo_idx]);
//            cart_logo_idx <= cart_logo_idx + 1'b1;
//        end
//
//    end
//
//    if (palette_download & ioctl_wr) begin
//            palette[127:0] <= {palette[111:0], ioctl_dout[7:0], ioctl_dout[15:8]};
//    end
// end

wire [7:0] sdram_do;

wire [23:0] sdram_addr = {1'b0, mbc_bank, cart_addr[12:0]};

sdram_model sdram_model
(
   clkram,
   sdram_addr,
   cart_rd,
   sdram_do,
   cart_cgb_flag,
   cart_sgb_flag,
   cart_mbc_type,
   cart_rom_size,
   cart_ram_size,
   cart_old_licensee
);


// TODO: e.g. output and read timer register values from mbc3 when selected
reg cart_ready = 1;

wire cram_rd;
wire [7:0] cram_do;

assign cart_do = ~cart_ready ? 8'h00 :
	             cram_rd ? cram_do : sdram_do;
//            cart_addr[0] ?
//                sdram_do[15:8]:
//                sdram_do[7:0];


reg isGBC = 0;
// always @(posedge clk_sys) if (reset) begin
//    if (status[15:14]) isGBC <= status[15];
//    else if (cart_download) isGBC <= !filetype[7:4];
// end


// /////////////////////////// savestates /////////////////////////////////

eReg_SavestateV #(0, 32, 15, 0, 64'h0000000000000001) iREG_SAVESTATE_Ext (clk_sys, SaveStateBus_Din, SaveStateBus_Adr, SaveStateBus_wren, SaveStateBus_rst, SaveStateBus_Dout, SS_Ext_BACK, SS_Ext);

// ///////////////////////  BRAM SAVE/LOAD  /////////////////////////////

// wire [16:0] bk_addr = {sd_lba[7:0],sd_buff_addr};
// wire bk_wr = sd_buff_wr & sd_ack;
// wire [15:0] bk_data = sd_buff_dout;
// wire [15:0] bk_q;
// assign sd_buff_din = bk_q;

wire [16:0] cram_addr =
    sleep_savestate ? Savestate_CRAMAddr[16:0]:
               mbc1 ? {2'b00, mbc1_ram_bank, cart_addr[12:0]}:
               mbc3 ? {2'b00, mbc3_ram_bank, cart_addr[12:0]}:
               mbc5 ? {mbc5_ram_bank, cart_addr[12:0]}:
                      {4'd0, cart_addr[12:0]};

wire [7:0] cram_q_h;
wire [7:0] cram_q_l;
wire [7:0] cram_q = cram_addr[0] ? cram_q_h : cram_q_l;

assign cram_do =
    mbc_ram_enable ?
        ((cart_addr[15:9] == 7'b1010000) && mbc2) ?
            {4'hF,cram_q[3:0]} : // 4 bit MBC2 Ram needs top half masked.
            mbc3_mode ?
                8'h0:            // RTC mode
                cram_q :         // Return normal value
        8'hFF;                   // Ram not enabled


reg read_low = 0;
always @(posedge clk_sys) begin
   read_low <= cram_addr[0];
end

assign Savestate_CRAMReadData = read_low ? cram_q_h : cram_q_l;

wire is_cram_addr = (cart_addr[15:13] == 3'b101);
assign cram_rd = cart_rd & is_cram_addr;
wire cram_wr = sleep_savestate ? Savestate_CRAMRWrEn : cart_wr & is_cram_addr & mbc_ram_enable;

wire [7:0] cram_di = sleep_savestate ? Savestate_CRAMWriteData : cart_di;

// Up to 8kb * 16banks of Cart Ram (128kb)

dpram #(16) cram_l (
    .clock_a (clk_sys),
    .address_a (cram_addr[16:1]),
    .wren_a (cram_wr & ~cram_addr[0]),
    .data_a (cram_di),
    .q_a (cram_q_l),

    .clock_b (clk_sys),
    .address_b (16'd0),
    .wren_b (1'b0),
    .data_b (8'b0)

    // .clock_b (clk_sys),
    // .address_b (bk_addr[15:0]),
    // .wren_b (bk_wr),
    // .data_b (bk_data[7:0]),
    // .q_b (bk_q[7:0])
);

dpram #(16) cram_h (
    .clock_a (clk_sys),
    .address_a (cram_addr[16:1]),
    .wren_a (cram_wr & cram_addr[0]),
    .data_a (cram_di),
    .q_a (cram_q_h),

    .clock_b (clk_sys),
    .address_b (16'd0),
    .wren_b (1'b0),
    .data_b (8'b0)

    // .clock_b (clk_sys),
    // .address_b (bk_addr[15:0]),
    // .wren_b (bk_wr),
    // .data_b (bk_data[15:8]),
    // .q_b (bk_q[15:8])
);

// wire downloading = cart_download;

// reg  bk_ena          = 0;
// reg  new_load        = 0;
// reg  old_downloading = 0;
// reg  sav_pending     = 0;
// wire sav_supported   = (mbc_battery && (cart_ram_size > 0 || mbc2) && bk_ena);
//
// always @(posedge clk_sys) begin
//    old_downloading <= downloading;
//    if (~old_downloading & downloading) bk_ena <= 0;
//
//    // Save file always mounted in the end of downloading state.
//    if (downloading && img_mounted && !img_readonly) bk_ena <= 1;
//
//    if (old_downloading & ~downloading & sav_supported)
//        new_load <= 1'b1;
//    else if (bk_state)
//        new_load <= 1'b0;
//
//    if (cram_wr & ~OSD_STATUS & sav_supported)
//        sav_pending <= 1'b1;
//    else if (bk_state)
//        sav_pending <= 1'b0;
// end
//
// wire bk_load    = status[9] | new_load;
// wire bk_save    = status[10] | (sav_pending & OSD_STATUS & status[13]);
// reg  bk_loading = 0;
// reg  bk_state   = 0;

// RAM size
wire [7:0] ram_mask_file =        // 0 - no ram
          (mbc2 || mbc7) ? 8'h01: // MBC2 512x4bits, MBC7 256 bytes EEPROM
    (cart_ram_size == 1) ? 8'h03: // 1 -   2k -  1 bank   sd_lba[1:0]
    (cart_ram_size == 2) ? 8'h0F: // 2 -   8k -  1 bank   sd_lba[3:0]
    (cart_ram_size == 3) ? 8'h3F: // 3 -  32k -  4 banks  sd_lba[5:0]
    (cart_ram_size == 5) ? 8'h7F: // 5 -  64k -  8 banks  sd_lba[6:0]
                           8'hFF; // 4 - 128k - 16 banks  sd_lba[7:0] 1111

// always @(posedge clk_sys) begin
//    reg old_load = 0, old_save = 0, old_ack;
//
//    old_load <= bk_load;
//    old_save <= bk_save;
//    old_ack  <= sd_ack;
//
//    if (~old_ack & sd_ack) {sd_rd, sd_wr} <= 0;
//
//    if (!bk_state) begin
//        if (bk_ena & ((~old_load & bk_load) | (~old_save & bk_save))) begin
//            bk_state <= 1;
//            bk_loading <= bk_load;
//            sd_lba <= 32'd0;
//            sd_rd <=  bk_load;
//            sd_wr <= ~bk_load;
//        end
//        if (old_downloading & ~downloading & |img_size & bk_ena) begin
//            bk_state <= 1;
//            bk_loading <= 1;
//            sd_lba <= 0;
//            sd_rd <= 1;
//            sd_wr <= 0;
//        end
//    end else begin
//        if (old_ack & ~sd_ack) begin
//
//            if (sd_lba[7:0]>=ram_mask_file) begin
//                bk_loading <= 0;
//                bk_state <= 0;
//            end else begin
//                sd_lba <= sd_lba + 1'd1;
//                sd_rd  <=  bk_loading;
//                sd_wr  <= ~bk_loading;
//            end
//        end
//    end
// end

endmodule
