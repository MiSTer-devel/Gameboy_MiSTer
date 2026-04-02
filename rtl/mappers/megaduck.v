module megaduck (
	input         enable,
	input         duck_md0_mode,

	input         clk_sys,
	input         ce_cpu,

	input         savestate_load,
	input [15:0]  savestate_data,
	inout [15:0]  savestate_back_b,

	input         has_ram,
	input  [1:0]  ram_mask,
	input  [6:0]  rom_mask,

	input [14:0]  cart_addr,
	input         cart_a15,

	input  [7:0]  cart_mbc_type,

	input         cart_wr,
	input  [7:0]  cart_di,

	input  [7:0]  cram_di,
	inout  [7:0]  cram_do_b,
	inout [16:0]  cram_addr_b,

	inout [22:0]  mbc_addr_b,
	inout         ram_enabled_b,
	inout         has_battery_b
);

wire [22:0] mbc_addr;
wire ram_enabled;
wire [7:0] cram_do;
wire [16:0] cram_addr;
wire has_battery;
wire [15:0] savestate_back;

assign mbc_addr_b       = enable ? mbc_addr       : 23'hZ;
assign cram_do_b        = enable ? cram_do        :  8'hZ;
assign cram_addr_b      = enable ? cram_addr      : 17'hZ;
assign ram_enabled_b    = enable ? ram_enabled    :  1'hZ;
assign has_battery_b    = enable ? has_battery    :  1'hZ;
assign savestate_back_b = enable ? savestate_back : 16'hZ;


// Megaduck banks are pretty simple. They are broken up into chunks of 0x4000. So bank 0
// is 0-0x3fff, bank 1 is 0x4000-0x7fff and so on. On most carts, only the top 0x4000 of the rom
// can be bank switched and the bottom is fixed at bank 0. In this case, the bank number is
// written to address 0x0001. Note that the bank can never be less than 1 for the upper bank.
// On some roms, a ram address is written instead which changes the entire visible rom space
// instead of just the upper slot.

reg [7:0] bank_top, bank_bottom;
reg [1:0] ram_bank;
wire [7:0] rom_bank = cart_addr[14] ? bank_top : bank_bottom;
wire [1:0] duck_ram_bank = ram_bank & ram_mask[1:0];
wire       duck_ram_enabled = duck_md0_mode & has_ram;
wire [16:0] duck_cram_addr = { 2'b00, duck_ram_bank, cart_addr[12:0] };
wire       duck_bank_write = cart_wr & ~cart_a15 & (cart_addr == 15'h0001);
wire       duck_pair_write = cart_wr &  cart_a15 & ~cart_addr[14];
wire       duck_md0_bank_write = cart_wr & ~cart_a15 & (cart_addr == 15'h1000);
wire [7:0] savestate_bank_bottom = duck_md0_mode ? {bank_bottom[7:1], ram_bank[0]} : bank_bottom;
wire [7:0] savestate_bank_top    = duck_md0_mode ? {bank_top[7:1],    ram_bank[1]} : bank_top;

// --------------------- CPU register interface ------------------

assign savestate_back[ 7: 0] = savestate_bank_bottom;
assign savestate_back[15: 8] = savestate_bank_top;

always @(posedge clk_sys) begin
	if(savestate_load & enable) begin
		if (duck_md0_mode) begin
			bank_bottom <= {savestate_data[7:1], 1'b0};
			bank_top    <= {savestate_data[15:9], 1'b1};
			ram_bank    <= {savestate_data[8], savestate_data[0]};
		end else begin
			bank_bottom <= savestate_data[7:0];
			bank_top    <= savestate_data[15:8];
			ram_bank    <= 2'd0;
		end
	end else if(~enable) begin
		bank_bottom <= 8'd0;
		bank_top    <= 8'd1;
		ram_bank    <= 2'd0;
	end else if(ce_cpu) begin
		if (duck_md0_mode) begin
			// SameDuck's MD0 laptop mapper: 0x1000 selects the 32KB ROM bank pair
			// in the lower nibble and the 8KB SRAM bank in the upper nibble.
			if (duck_md0_bank_write) begin
				bank_top    <= {3'd0, cart_di[3:0], 1'b1};
				bank_bottom <= {3'd0, cart_di[3:0], 1'b0};
				ram_bank    <= cart_di[5:4];
			end
		end else begin
			if (duck_bank_write) begin
				bank_top <= (cart_di[7:0] == 0) ? 8'd1 : cart_di;
			end else if (duck_pair_write) begin
				bank_top    <= {cart_di[6:0], 1'b1};
				bank_bottom <= {cart_di[6:0], 1'b0};
			end
		end
	end
end

assign mbc_addr = { 1'b0, rom_bank, cart_addr[13:0] };
assign ram_enabled = duck_ram_enabled;

assign cram_do = ram_enabled ? cram_di : 8'hFF;
assign cram_addr = ram_enabled ? duck_cram_addr : 17'd0;
assign has_battery = duck_ram_enabled;


endmodule