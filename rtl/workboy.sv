// Workboy
// Based on all published information, this is probably incomplete.


module workboy
(
	input         clk_sys,
	input         reset,

	input  [10:0] ps2_key,
	input  [64:0] rtc_bcd,

	input         serial_clk_in,
	input         serial_data_in,
	output reg    serial_data_out
);

localparam [7:0] CMD_R = 8'h52;  // 'R'
localparam [7:0] CMD_W = 8'h57;  // 'W'
localparam [7:0] CMD_O = 8'h4F;  // 'O'
localparam [7:0] RESP_D = 8'h44; // 'D'

localparam [7:0] KEY_NONE    = 8'hFF;
localparam [7:0] KEY_REQUIRE = 8'h40;
localparam [7:0] KEY_FORBID  = 8'h80;
localparam [7:0] KEY_SHIFT_DOWN = 8'd39; // WorkBoy NUM mode key
localparam [7:0] KEY_SHIFT_UP   = 8'd50; // WorkBoy CAPS mode key

function automatic [8:0] map_ps2_to_workboy;
	input [7:0] scancode;
	input       extended;
	input       shift_held;
	begin
		map_ps2_to_workboy = 9'h000;

		if (extended) begin
			case (scancode)
				8'h6B: map_ps2_to_workboy = {1'b1, 8'd13}; // Left
				8'h70: map_ps2_to_workboy = {1'b1, 8'd12}; // Insert/Unknown
				8'h71: map_ps2_to_workboy = {1'b1, 8'd11}; // Delete/Backspace
				8'h72: map_ps2_to_workboy = {1'b1, 8'd55}; // Down
				8'h74: map_ps2_to_workboy = {1'b1, 8'd56}; // Right
				8'h75: map_ps2_to_workboy = {1'b1, 8'd54}; // Up
				default: ;
			endcase
		end else begin
			case (scancode)
				8'h01: map_ps2_to_workboy = {1'b1, 8'd9};  // F9
				8'h03: map_ps2_to_workboy = {1'b1, 8'd5};  // F5
				8'h04: map_ps2_to_workboy = {1'b1, 8'd3};  // F3
				8'h05: map_ps2_to_workboy = {1'b1, 8'd1};  // F1
				8'h06: map_ps2_to_workboy = {1'b1, 8'd2};  // F2
				8'h09: map_ps2_to_workboy = {1'b1, 8'd12}; // F10
				8'h0A: map_ps2_to_workboy = {1'b1, 8'd8};  // F8
				8'h0B: map_ps2_to_workboy = {1'b1, 8'd6};  // F6
				8'h0C: map_ps2_to_workboy = {1'b1, 8'd4};  // F4
				8'h0D: map_ps2_to_workboy = {1'b1, KEY_SHIFT_DOWN}; // Tab -> NUM mode
				8'h0E: map_ps2_to_workboy = {1'b1, shift_held ? (8'd25 | KEY_REQUIRE) : 8'd51}; // ` or ~
				8'h15: map_ps2_to_workboy = {1'b1, 8'd17}; // Q
				8'h16: map_ps2_to_workboy = {1'b1, shift_held ? (8'd24 | KEY_REQUIRE) : (8'd17 | KEY_REQUIRE)}; // 1 or !
				8'h1A: map_ps2_to_workboy = {1'b1, 8'd40}; // Z
				8'h1B: map_ps2_to_workboy = {1'b1, 8'd29}; // S
				8'h1C: map_ps2_to_workboy = {1'b1, 8'd28}; // A
				8'h1D: map_ps2_to_workboy = {1'b1, 8'd18}; // W
				8'h1E: map_ps2_to_workboy = {1'b1, shift_held ? (8'd53 | KEY_REQUIRE) : (8'd18 | KEY_REQUIRE)}; // 2 or @
				8'h21: map_ps2_to_workboy = {1'b1, 8'd42}; // C
				8'h22: map_ps2_to_workboy = {1'b1, 8'd41}; // X
				8'h23: map_ps2_to_workboy = {1'b1, 8'd30}; // D
				8'h24: map_ps2_to_workboy = {1'b1, 8'd19}; // E
				8'h25: map_ps2_to_workboy = {1'b1, shift_held ? (8'd27 | KEY_FORBID) : (8'd28 | KEY_REQUIRE)}; // 4 or $
				8'h26: map_ps2_to_workboy = {1'b1, shift_held ? (8'd27 | KEY_REQUIRE) : (8'd19 | KEY_REQUIRE)}; // 3 or #
				8'h29: map_ps2_to_workboy = {1'b1, 8'd52}; // Space
				8'h2A: map_ps2_to_workboy = {1'b1, shift_held ? (8'd43 | KEY_REQUIRE) : 8'd43}; // V or .
				8'h2B: map_ps2_to_workboy = {1'b1, 8'd31}; // F
				8'h2C: map_ps2_to_workboy = {1'b1, shift_held ? (8'd21 | KEY_REQUIRE) : 8'd21}; // T or M-
				8'h2D: map_ps2_to_workboy = {1'b1, shift_held ? (8'd20 | KEY_REQUIRE) : 8'd20}; // R or M+
				8'h2E: map_ps2_to_workboy = {1'b1, shift_held ? (8'd44 | KEY_REQUIRE) : (8'd29 | KEY_REQUIRE)}; // 5 or %
				8'h31: map_ps2_to_workboy = {1'b1, 8'd45}; // N
				8'h32: map_ps2_to_workboy = {1'b1, 8'd44}; // B
				8'h33: map_ps2_to_workboy = {1'b1, shift_held ? (8'd33 | KEY_REQUIRE) : 8'd33}; // H or x
				8'h34: map_ps2_to_workboy = {1'b1, 8'd32}; // G
				8'h35: map_ps2_to_workboy = {1'b1, shift_held ? (8'd22 | KEY_REQUIRE) : 8'd22}; // Y or MR
				8'h36: map_ps2_to_workboy = {1'b1, (8'd30 | KEY_REQUIRE)}; // 6
				8'h3A: map_ps2_to_workboy = {1'b1, shift_held ? (8'd46 | KEY_REQUIRE) : 8'd46}; // M or C
				8'h3B: map_ps2_to_workboy = {1'b1, shift_held ? (8'd34 | KEY_REQUIRE) : 8'd34}; // J or divide
				8'h3C: map_ps2_to_workboy = {1'b1, shift_held ? (8'd23 | KEY_REQUIRE) : 8'd23}; // U or MC
				8'h3D: map_ps2_to_workboy = {1'b1, (8'd40 | KEY_REQUIRE)}; // 7 (Shift+7 '&' has no direct WorkBoy symbol)
				8'h3E: map_ps2_to_workboy = {1'b1, shift_held ? (8'd26 | KEY_REQUIRE) : (8'd41 | KEY_REQUIRE)}; // 8 or *
				8'h41: map_ps2_to_workboy = {1'b1, shift_held ? (8'd47 | KEY_REQUIRE) : (8'd47 | KEY_FORBID)}; // , or <
				8'h42: map_ps2_to_workboy = {1'b1, 8'd35}; // K
				8'h43: map_ps2_to_workboy = {1'b1, 8'd24}; // I
				8'h44: map_ps2_to_workboy = {1'b1, shift_held ? (8'd25 | KEY_REQUIRE) : 8'd25}; // O or pound
				8'h45: map_ps2_to_workboy = {1'b1, shift_held ? (8'd36 | KEY_REQUIRE) : (8'd51 | KEY_REQUIRE)}; // 0 or )
				8'h46: map_ps2_to_workboy = {1'b1, shift_held ? (8'd35 | KEY_REQUIRE) : (8'd42 | KEY_REQUIRE)}; // 9 or (
				8'h49: map_ps2_to_workboy = {1'b1, shift_held ? (8'd48 | KEY_REQUIRE) : (8'd48 | KEY_FORBID)}; // . or >
				8'h4A: map_ps2_to_workboy = {1'b1, shift_held ? (8'd49 | KEY_REQUIRE) : (8'd49 | KEY_FORBID)}; // / or ?
				8'h4B: map_ps2_to_workboy = {1'b1, 8'd36}; // L
				8'h4C: map_ps2_to_workboy = {1'b1, shift_held ? 8'd37 : (8'd37 | KEY_FORBID)}; // ; or :
				8'h4D: map_ps2_to_workboy = {1'b1, 8'd26}; // P
				8'h4E: map_ps2_to_workboy = {1'b1, (8'd32 | KEY_REQUIRE)}; // -
				8'h52: map_ps2_to_workboy = {1'b1, shift_held ? (8'd53 | KEY_REQUIRE) : (8'd53 | KEY_FORBID)}; // ' or @
				8'h54: map_ps2_to_workboy = {1'b1, (8'd35 | KEY_REQUIRE)}; // [ -> (
				8'h55: map_ps2_to_workboy = {1'b1, shift_held ? (8'd31 | KEY_REQUIRE) : (8'd45 | KEY_REQUIRE)}; // = or +
				8'h58: map_ps2_to_workboy = {1'b1, KEY_SHIFT_UP}; // Caps Lock -> CAPS mode
				8'h5A: map_ps2_to_workboy = {1'b1, 8'd38}; // Enter
				8'h5B: map_ps2_to_workboy = {1'b1, (8'd36 | KEY_REQUIRE)}; // ] -> )
				8'h5D: map_ps2_to_workboy = {1'b1, shift_held ? (8'd27 | KEY_REQUIRE) : (8'd27 | KEY_FORBID)}; // \ or |
				8'h61: map_ps2_to_workboy = {1'b1, shift_held ? (8'd27 | KEY_REQUIRE) : (8'd27 | KEY_FORBID)}; // Non-US \ or |
				8'h66: map_ps2_to_workboy = {1'b1, 8'd11}; // Backspace
				8'h76: map_ps2_to_workboy = {1'b1, 8'd10}; // Escape
				8'h77: map_ps2_to_workboy = {1'b1, KEY_SHIFT_DOWN}; // Num Lock -> NUM mode
				8'h83: map_ps2_to_workboy = {1'b1, 8'd7};  // F7
				default: ;
			endcase
		end
	end
endfunction

function automatic [7:0] bcd_to_bin;
	input [7:0] bcd;
	begin
		bcd_to_bin = (bcd[7:4] * 8'd10) + bcd[3:0];
	end
endfunction

function automatic [7:0] nibble_to_ascii_hex;
	input [3:0] nibble;
	begin
		nibble_to_ascii_hex = (nibble < 4'd10) ? (8'h30 + nibble) : (8'h41 + nibble - 4'd10);
	end
endfunction

reg        ps2_last;
reg        phys_shift_down;
reg        shift_down;
reg        user_shift_down;
wire       ps2_event = (ps2_last != ps2_key[10]);
wire       ps2_pressed = ps2_key[9];
wire       ps2_extended = ps2_key[8];
wire [7:0] ps2_scancode = ps2_key[7:0];

reg [7:0]  wb_key;
reg [7:0]  mode;
reg [7:0]  buffer[0:20];
reg [5:0]  buffer_index;

reg        clk_last;
reg        clk_rise_armed;
wire       clk_falling = clk_last & ~serial_clk_in;
wire       clk_rising  = ~clk_last & serial_clk_in;

reg [2:0] bit_count;
reg [7:0] rx_shift;
wire [7:0] rx_byte = {rx_shift[6:0], serial_data_in};
reg [7:0] tx_shift;

reg [8:0] mapped_key;
reg [7:0] key_next;
reg [7:0] next_byte;
reg [7:0] year_tm;
integer i;

always @(posedge clk_sys) begin
	ps2_last <= ps2_key[10];
	clk_last <= serial_clk_in;

	if (reset) begin
		serial_data_out  <= 1'b1;
		ps2_last         <= 1'b0;
		phys_shift_down  <= 1'b0;
		shift_down       <= 1'b0;
		user_shift_down  <= 1'b0;
		wb_key           <= 8'h00;
		mode             <= 8'h00;
		buffer_index     <= 6'd0;
		clk_last         <= serial_clk_in;
		clk_rise_armed   <= 1'b0;
		bit_count        <= 3'd0;
		rx_shift         <= 8'h00;
		tx_shift         <= 8'h00;
		for (i = 0; i < 21; i = i + 1)
			buffer[i] <= 8'h00;
	end else begin
		if (ps2_event) begin
			mapped_key = 9'h000;

			if (!ps2_extended && (ps2_scancode == 8'h12 || ps2_scancode == 8'h59)) begin
				phys_shift_down <= ps2_pressed;
				mapped_key = {1'b1, ps2_pressed ? KEY_SHIFT_DOWN : KEY_SHIFT_UP};
			end else if (ps2_pressed) begin
				mapped_key = map_ps2_to_workboy(ps2_scancode, ps2_extended, phys_shift_down);
			end else if (ps2_scancode != 8'hF0) begin
				wb_key <= KEY_NONE;
			end

			if (mapped_key[8]) begin
				key_next = mapped_key[7:0];

				if (((key_next & (KEY_REQUIRE | KEY_FORBID)) == 8'h00) && (user_shift_down != shift_down)) begin
					if (user_shift_down) key_next = key_next | KEY_REQUIRE;
					else                 key_next = key_next | KEY_FORBID;
				end

				wb_key <= key_next;
			end
		end

		if (clk_falling) begin
			clk_rise_armed <= 1'b1;
			serial_data_out <= tx_shift[7];
		end

		if (clk_rising && clk_rise_armed) begin
			clk_rise_armed <= 1'b0;
			rx_shift <= rx_byte;

			if (bit_count == 3'd7) begin
				bit_count <= 3'd0;
				next_byte = 8'h00;

				if ((mode != CMD_W) && (rx_byte == CMD_R)) begin
					next_byte = RESP_D;
					wb_key    <= KEY_NONE;
					mode          <= CMD_R;
					buffer_index  <= 6'd1;
					year_tm       = 8'd100 + bcd_to_bin(rtc_bcd[47:40]);

					for (i = 0; i < 21; i = i + 1)
						buffer[i] <= 8'h00;
					buffer[0]  <= 8'h04;
					buffer[2]  <= rtc_bcd[7:0];
					buffer[3]  <= rtc_bcd[15:8];
					buffer[4]  <= rtc_bcd[23:16];
					buffer[5]  <= rtc_bcd[31:24];
					buffer[6]  <= rtc_bcd[39:32];
					buffer[15] <= year_tm;
				end else if ((mode != CMD_W) && (rx_byte == CMD_W)) begin
					next_byte    = RESP_D;
					mode         <= CMD_W;
					wb_key       <= KEY_NONE;
					buffer_index <= 6'd0;
				end else if ((mode != CMD_W) && ((rx_byte == CMD_O) || (mode == CMD_O))) begin
					mode      <= CMD_O;
					next_byte = wb_key;

					if (wb_key != KEY_NONE) begin
						if (wb_key & KEY_REQUIRE) begin
							key_next = wb_key & ~KEY_REQUIRE;
							wb_key   <= key_next;
							if (shift_down) begin
								next_byte = key_next;
								wb_key    <= KEY_NONE;
							end else begin
								next_byte  = KEY_SHIFT_DOWN;
								shift_down <= 1'b1;
							end
						end else if (wb_key & KEY_FORBID) begin
							key_next = wb_key & ~KEY_FORBID;
							wb_key   <= key_next;
							if (!shift_down) begin
								next_byte = key_next;
								wb_key    <= KEY_NONE;
							end else begin
								next_byte  = KEY_SHIFT_UP;
								shift_down <= 1'b0;
							end
						end else begin
							if (wb_key == KEY_SHIFT_DOWN) begin
								shift_down      <= 1'b1;
								user_shift_down <= 1'b1;
							end else if (wb_key == KEY_SHIFT_UP) begin
								shift_down      <= 1'b0;
								user_shift_down <= 1'b0;
							end
							next_byte = wb_key;
							wb_key    <= KEY_NONE;
						end
					end
				end else if (mode == CMD_R) begin
					if (buffer_index >= 6'd42) begin
						next_byte = 8'h00;
					end else begin
						if (buffer_index[0]) next_byte = nibble_to_ascii_hex(buffer[buffer_index[5:1]][3:0]);
						else                 next_byte = nibble_to_ascii_hex(buffer[buffer_index[5:1]][7:4]);
						buffer_index <= buffer_index + 1'd1;
					end
				end else if (mode == CMD_W) begin
					next_byte = RESP_D;
					if (buffer_index < 6'd2) begin
						buffer_index <= buffer_index + 1'd1;
					end else if ((buffer_index - 6'd2) < 6'd21) begin
						buffer[buffer_index - 6'd2] <= rx_byte;
						buffer_index <= buffer_index + 1'd1;
						if ((buffer_index + 6'd1 - 6'd2) == 6'd21)
							mode <= CMD_O;
					end
				end

				tx_shift <= next_byte;
			end else begin
				bit_count <= bit_count + 1'd1;
				tx_shift <= {tx_shift[6:0], 1'b0};
			end
		end else if (clk_rising) begin
			clk_rise_armed <= 1'b0;
			bit_count      <= 3'd0;
		end
	end
end

endmodule
