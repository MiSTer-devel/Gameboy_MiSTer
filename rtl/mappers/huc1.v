module huc1 (
	input         enable,

	input         clk_sys,
	input         ce_cpu,

	input         savestate_load,
	input [15:0]  savestate_data,
	inout [15:0]  savestate_back_b,

	input         has_ram,
	input  [3:0]  ram_mask,
	input  [8:0]  rom_mask,

	input [15:0]  cart_addr,
	input  [7:0]  cart_mbc_type,

	input         cart_wr,
	input  [7:0]  cart_di,

	input  [7:0]  cram_di,
	inout  [7:0]  cram_do_b,
	inout [16:0]  cram_addr_b,

	inout  [9:0]  mbc_bank_b,
	inout         ram_enabled_b,
	inout         has_battery_b
);

wire [9:0] mbc_bank;
wire ram_enabled;
wire [7:0] cram_do;
wire [16:0] cram_addr;
wire has_battery;
wire [15:0] savestate_back;

assign mbc_bank_b       = enable ? mbc_bank       : 10'hZ;
assign cram_do_b        = enable ? cram_do        :  8'hZ;
assign cram_addr_b      = enable ? cram_addr      : 17'hZ;
assign ram_enabled_b    = enable ? ram_enabled    :  1'hZ;
assign has_battery_b    = enable ? has_battery    :  1'hZ;
assign savestate_back_b = enable ? savestate_back : 16'hZ;

// --------------------- CPU register interface ------------------

reg ir_en;  //0: RAM, 1: IR
reg [5:0] rom_bank_reg;
reg [1:0] ram_bank_reg;

assign savestate_back[ 5: 0] = rom_bank_reg;
assign savestate_back[ 8: 6] = 0;
assign savestate_back[10: 9] = ram_bank_reg;
assign savestate_back[12:11] = 0;
assign savestate_back[   13] = ir_en;
assign savestate_back[   14] = 0;
assign savestate_back[   15] = 0;

always @(posedge clk_sys) begin
	if(savestate_load & enable) begin
		rom_bank_reg <= savestate_data[ 5: 0]; //6'd1;
		ram_bank_reg <= savestate_data[10: 9]; //2'd0;
		ir_en        <= savestate_data[   13]; //1'b0;
	end else if(~enable) begin
		rom_bank_reg <= 6'd1;
		ram_bank_reg <= 2'd0;
		ir_en        <= 1'b0;
	end else if(ce_cpu) begin
		if (cart_wr & ~cart_addr[15]) begin
			case(cart_addr[14:13])
				2'b00: ir_en <= (cart_di[3:0] == 4'hE); //IR enable/disable
				2'b01: rom_bank_reg <= (cart_di[5:0] == 0) ? 6'd1 : cart_di[5:0]; //write to ROM bank register
				2'b10: ram_bank_reg <= cart_di[1:0]; //write to RAM bank register
			endcase
		end
	end
end

wire [1:0] ram_bank = ram_bank_reg & ram_mask[1:0];

// 0x0000-0x3FFF = Bank 0
wire [5:0] rom_bank = (cart_addr[15:14] == 2'b00) ? 6'd0 : rom_bank_reg;

// mask address lines to enable proper mirroring
wire [5:0] rom_bank_m = rom_bank & rom_mask[5:0];	 //64

assign mbc_bank = { 3'b000, rom_bank_m, cart_addr[13] };	// 16k ROM Bank 0-63
assign ram_enabled = ~ir_en & has_ram;

// 0xC0 is no light detected
assign cram_do = ir_en ? 8'hC0 : ram_enabled ? cram_di : 8'hFF;
assign cram_addr = { 2'b00, ram_bank, cart_addr[12:0] };
assign has_battery = 1;


endmodule