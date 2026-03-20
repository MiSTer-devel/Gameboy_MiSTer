// insideGadgets USB Keyboard + Mouse adapter emulation
//
// The adapter is a accessory on the GB serial link port.  The Game Boy polls by
// initiating an 8-bit serial transfer (SC = 0x81, internal clock) and reads
// the byte returned by the adapter.
//
// KEYBOARD – single byte per key-press:
//   Letters a-z  (no shift) : ASCII 97-122  (USB HID keycode + 93)
//   Letters A-Z  (shift)    : ASCII 65-90
//   Numbers 1-0  (no shift) : 123-132       (USB HID keycode + 93)
//   Numbers 1-0  (shift)    : standard US symbols: !@#$%^&*() = 33,64,35-38,94,38,42,40,41
//   Space=137  Enter=133  Backspace=135  Escape=134  Tab=136
//   Minus=138  Equals=139  [=140  ]=141  \=142  ;=144  '=145  `=146
//   Comma=147  Period=148  Slash=149
//   Shifted symbols: _  +  {  }  |  :  "  ~  <  >  ?  (standard US ASCII)
//   Idle / no new key: 0x00 (ignored by keyboard ROM: value must be >=1 and <254;
//                             ignored by mouse ROM: only non-zero bytes are buffered)
//
// MOUSE – three bytes per event:
//   Byte 1 (button + direction signs):
//     bit 7 = 0 (always)
//     bit 6 = 1 (FORCE_NONZERO_BIT_BUTTONS, always set)
//     bit 5 = Y_DIR_POS (1 if accumulated Y delta is non-negative in screen coords)
//     bit 4 = X_DIR_POS (1 if accumulated X delta is non-negative)
//     bit 3 = 0
//     bit 2 = middle button
//     bit 1 = right button
//     bit 0 = left button
//   Byte 2 (X magnitude): bit 7 = 1 (FORCE_NONZERO_BIT_MOVE), bits 6:0 = |X| clamped 0-127
//   Byte 3 (Y magnitude): bit 7 = 1 (FORCE_NONZERO_BIT_MOVE), bits 6:0 = |Y| clamped 0-127
//
//   ps2_mouse from MiSTer hps_io is in PS/2 format:
//     ps2_mouse[7:0]   = PS/2 byte 1: {Y_ov, X_ov, Y_sign, X_sign, 1, mid, right, left}
//     ps2_mouse[15:8]  = PS/2 byte 2: X magnitude (unsigned)
//     ps2_mouse[23:16] = PS/2 byte 3: Y magnitude (unsigned)
//   X_sign (bit 4) = 1 means leftward (negative X).
//   Y_sign (bit 5) = 1 means downward in PS/2 convention (positive in screen coords);
//   Y is therefore negated when accumulating to convert PS/2 to screen coordinates.
//
//   Packets are sent only when there is actual movement or a button state change.
//   X/Y deltas from ps2_mouse are accumulated between sends.
//
// Both keyboard and mouse work simultaneously; keyboard bytes take priority.

module ig_kb
(
	input         clk_sys,
	input         reset,

	input  [10:0] ps2_key,
	input  [24:0] ps2_mouse,

	input         serial_clk_in,
	output reg    serial_data_out
);

localparam [7:0] IG_NONE = 8'h00;

// TX state machine — tracks position within a 3-byte mouse packet.
// Keyboard and idle bytes are output directly (TX_IDLE); mouse bytes use tx_shift.
localparam [1:0] TX_IDLE    = 2'd0; // outputting idle/keyboard byte
localparam [1:0] TX_MOUSE_X = 2'd1; // button byte was loaded into tx_shift; X byte is next
localparam [1:0] TX_MOUSE_Y = 2'd2; // X byte loaded; Y byte is next
localparam [1:0] TX_MOUSE_Z = 2'd3; // Y byte loaded; return to idle after

// ---------------------------------------------------------------------------
// PS/2 keyboard scancode → insideGadgets output byte (unshifted)
// ---------------------------------------------------------------------------
function automatic [7:0] map_ps2_unshifted;
	input [7:0] scancode;
	input       extended;
	begin
		map_ps2_unshifted = IG_NONE;
		if (!extended) begin
			case (scancode)
				// Letters — ASCII lowercase == USB HID + 93 for a-z
				8'h1C: map_ps2_unshifted = 8'd97;   // a
				8'h32: map_ps2_unshifted = 8'd98;   // b
				8'h21: map_ps2_unshifted = 8'd99;   // c
				8'h23: map_ps2_unshifted = 8'd100;  // d
				8'h24: map_ps2_unshifted = 8'd101;  // e
				8'h2B: map_ps2_unshifted = 8'd102;  // f
				8'h34: map_ps2_unshifted = 8'd103;  // g
				8'h33: map_ps2_unshifted = 8'd104;  // h
				8'h43: map_ps2_unshifted = 8'd105;  // i
				8'h3B: map_ps2_unshifted = 8'd106;  // j
				8'h42: map_ps2_unshifted = 8'd107;  // k
				8'h4B: map_ps2_unshifted = 8'd108;  // l
				8'h3A: map_ps2_unshifted = 8'd109;  // m
				8'h31: map_ps2_unshifted = 8'd110;  // n
				8'h44: map_ps2_unshifted = 8'd111;  // o
				8'h4D: map_ps2_unshifted = 8'd112;  // p
				8'h15: map_ps2_unshifted = 8'd113;  // q
				8'h2D: map_ps2_unshifted = 8'd114;  // r
				8'h1B: map_ps2_unshifted = 8'd115;  // s
				8'h2C: map_ps2_unshifted = 8'd116;  // t
				8'h3C: map_ps2_unshifted = 8'd117;  // u
				8'h2A: map_ps2_unshifted = 8'd118;  // v
				8'h1D: map_ps2_unshifted = 8'd119;  // w
				8'h22: map_ps2_unshifted = 8'd120;  // x
				8'h35: map_ps2_unshifted = 8'd121;  // y
				8'h1A: map_ps2_unshifted = 8'd122;  // z
				// Numbers — HID keycodes 30-39 for 1-0, output = HID + 93
				8'h16: map_ps2_unshifted = 8'd123;  // 1 (HID 30 + 93)
				8'h1E: map_ps2_unshifted = 8'd124;  // 2
				8'h26: map_ps2_unshifted = 8'd125;  // 3
				8'h25: map_ps2_unshifted = 8'd126;  // 4
				8'h2E: map_ps2_unshifted = 8'd127;  // 5
				8'h36: map_ps2_unshifted = 8'd128;  // 6
				8'h3D: map_ps2_unshifted = 8'd129;  // 7
				8'h3E: map_ps2_unshifted = 8'd130;  // 8
				8'h46: map_ps2_unshifted = 8'd131;  // 9
				8'h45: map_ps2_unshifted = 8'd132;  // 0 (HID 39 + 93)
				// Special keys — HID keycode + 93
				8'h76: map_ps2_unshifted = 8'd134;  // Escape     (41+93)
				8'h5A: map_ps2_unshifted = 8'd133;  // Enter      (40+93)
				8'h66: map_ps2_unshifted = 8'd135;  // Backspace  (42+93)
				8'h0D: map_ps2_unshifted = 8'd136;  // Tab        (43+93)
				8'h29: map_ps2_unshifted = 8'd137;  // Space      (44+93)
				8'h4E: map_ps2_unshifted = 8'd138;  // -          (45+93)
				8'h55: map_ps2_unshifted = 8'd139;  // =          (46+93)
				8'h54: map_ps2_unshifted = 8'd140;  // [          (47+93)
				8'h5B: map_ps2_unshifted = 8'd141;  // ]          (48+93)
				8'h5D: map_ps2_unshifted = 8'd142;  // \          (49+93)
				8'h4C: map_ps2_unshifted = 8'd144;  // ;          (51+93)
				8'h52: map_ps2_unshifted = 8'd145;  // '          (52+93)
				8'h0E: map_ps2_unshifted = 8'd146;  // `          (53+93)
				8'h41: map_ps2_unshifted = 8'd147;  // ,          (54+93)
				8'h49: map_ps2_unshifted = 8'd148;  // .          (55+93)
				8'h4A: map_ps2_unshifted = 8'd149;  // /          (56+93)
				default: ;
			endcase
		end
	end
endfunction

// PS/2 keyboard scancode → insideGadgets output byte (shifted)
// Letters use -32 (a→A). Numbers and symbols use the standard US-layout shifted character.
function automatic [7:0] map_ps2_shifted;
	input [7:0] scancode;
	input       extended;
	reg [7:0]   u;
	begin
		u = map_ps2_unshifted(scancode, extended);
		if (u >= 8'd97 && u <= 8'd122) begin
			map_ps2_shifted = u - 8'd32;       // a-z → A-Z
		end else begin
			case (scancode)
				// Numbers → US symbols
				8'h16: map_ps2_shifted = 8'd33;  // ! (Shift+1)
				8'h1E: map_ps2_shifted = 8'd64;  // @ (Shift+2)
				8'h26: map_ps2_shifted = 8'd35;  // # (Shift+3)
				8'h25: map_ps2_shifted = 8'd36;  // $ (Shift+4)
				8'h2E: map_ps2_shifted = 8'd37;  // % (Shift+5)
				8'h36: map_ps2_shifted = 8'd94;  // ^ (Shift+6)
				8'h3D: map_ps2_shifted = 8'd38;  // & (Shift+7)
				8'h3E: map_ps2_shifted = 8'd42;  // * (Shift+8)
				8'h46: map_ps2_shifted = 8'd40;  // ( (Shift+9)
				8'h45: map_ps2_shifted = 8'd41;  // ) (Shift+0)
				// Symbol keys → shifted symbols
				8'h4E: map_ps2_shifted = 8'd95;  // _ (Shift+-)
				8'h55: map_ps2_shifted = 8'd43;  // + (Shift+=)
				8'h54: map_ps2_shifted = 8'd123; // { (Shift+[)
				8'h5B: map_ps2_shifted = 8'd125; // } (Shift+])
				8'h5D: map_ps2_shifted = 8'd124; // | (Shift+\)
				8'h4C: map_ps2_shifted = 8'd58;  // : (Shift+;)
				8'h52: map_ps2_shifted = 8'd34;  // " (Shift+')
				8'h0E: map_ps2_shifted = 8'd126; // ~ (Shift+`)
				8'h41: map_ps2_shifted = 8'd60;  // < (Shift+,)
				8'h49: map_ps2_shifted = 8'd62;  // > (Shift+.)
				8'h4A: map_ps2_shifted = 8'd63;  // ? (Shift+/)
				default: map_ps2_shifted = u;    // Space, Enter, etc. unchanged
			endcase
		end
	end
endfunction

// ---------------------------------------------------------------------------
// PS/2 keyboard state
// ---------------------------------------------------------------------------
wire        ps2_event    = (ps2_last != ps2_key[10]);
wire        ps2_pressed  = ps2_key[9];
wire        ps2_extended = ps2_key[8];
wire [7:0]  ps2_scancode = ps2_key[7:0];

reg         ps2_last;
reg         shift_held;
reg [7:0]   ig_key;        // pending keyboard byte (IG_NONE = none)
reg         key_sent;      // cleared on new press; set after first transfer
reg [7:0]   raw_key;

// ---------------------------------------------------------------------------
// Mouse accumulation state
// ---------------------------------------------------------------------------
wire        mouse_event  = (m_last != ps2_mouse[24]);

reg         m_last;
reg signed [15:0] m_x_acc;      // signed accumulator for X movement
reg signed [15:0] m_y_acc;      // signed accumulator for Y movement
reg [2:0]   m_btns;             // current button state {middle, right, left}
reg [2:0]   m_btns_last;        // button state at last packet send
reg         m_has_event;        // at least one mouse event since last send

// Pre-computed X/Y bytes stored when a mouse packet is started
reg [7:0]   m_b2;               // X magnitude byte (FORCE_NONZERO | |X|)
reg [7:0]   m_b3;               // Y magnitude byte (FORCE_NONZERO | |Y|)

// Combinatorial helpers for mouse byte construction (computed from current accumulators)
wire [15:0] m_abs_x = m_x_acc[15] ? (~m_x_acc + 16'd1) : {1'b0, m_x_acc[14:0]};
wire [15:0] m_abs_y = m_y_acc[15] ? (~m_y_acc + 16'd1) : {1'b0, m_y_acc[14:0]};
wire [6:0]  m_cx    = (|m_abs_x[15:7]) ? 7'd127 : m_abs_x[6:0];
wire [6:0]  m_cy    = (|m_abs_y[15:7]) ? 7'd127 : m_abs_y[6:0];

// Byte 1: {0, FORCE_NONZERO, y_pos, x_pos, 0, mid, right, left}
// "positive" = sign bit is 0 (non-negative), including zero — direction irrelevant when |mag|=0
wire [7:0]  m_b1_w  = {1'b0, 1'b1, ~m_y_acc[15], ~m_x_acc[15], 1'b0, m_btns};
wire [7:0]  m_b2_w  = {1'b1, m_cx};
wire [7:0]  m_b3_w  = {1'b1, m_cy};

// Send a packet when an event has occurred AND there is something non-trivial to report
wire m_sendable = m_has_event && ((m_btns != m_btns_last) || (|m_x_acc) || (|m_y_acc));

// ---------------------------------------------------------------------------
// Serial clock edge detection
// ---------------------------------------------------------------------------
reg         clk_last;
wire        clk_falling = clk_last & ~serial_clk_in;
wire        clk_rising  = ~clk_last & serial_clk_in;

reg         clk_rise_armed;
reg [2:0]   bit_count;

// ---------------------------------------------------------------------------
// TX state and shift register
// ---------------------------------------------------------------------------
reg [1:0]   tx_state;
reg [7:0]   tx_shift;   // byte being shifted out in TX_MOUSE_* modes


// ---------------------------------------------------------------------------
// Main sequential logic
// ---------------------------------------------------------------------------
always @(posedge clk_sys) begin
	ps2_last  <= ps2_key[10];
	clk_last  <= serial_clk_in;
	m_last    <= ps2_mouse[24];

	if (reset) begin
		serial_data_out <= 1'b1;
		ps2_last        <= 1'b0;
		shift_held      <= 1'b0;
		ig_key          <= IG_NONE;
		key_sent        <= 1'b0;
		clk_last        <= serial_clk_in;
		clk_rise_armed  <= 1'b0;
		bit_count       <= 3'd0;
		tx_shift        <= IG_NONE;
		tx_state        <= TX_IDLE;
		m_last          <= ps2_mouse[24];
		m_x_acc         <= 16'sd0;
		m_y_acc         <= 16'sd0;
		m_btns          <= 3'b000;
		m_btns_last     <= 3'b000;
		m_has_event     <= 1'b0;
	end else begin

		// ---- PS/2 keyboard events ----
		if (ps2_event) begin
			if (!ps2_extended && (ps2_scancode == 8'h12 || ps2_scancode == 8'h59)) begin
				// Left / right shift
				shift_held <= ps2_pressed;
			end else if (ps2_pressed) begin
				raw_key = map_ps2_unshifted(ps2_scancode, ps2_extended);
				if (raw_key != IG_NONE) begin
					ig_key   <= shift_held ? map_ps2_shifted(ps2_scancode, ps2_extended) : raw_key;
					key_sent      <= 1'b0;
				end
			end else if (ps2_scancode != 8'hF0) begin
				// Key release — return line to idle so the same key can be re-pressed
				ig_key   <= IG_NONE;
				key_sent <= 1'b0;
			end
		end

		// ---- Mouse events ----
		// Accumulate X/Y and track current button state on every HPS mouse report.
		// ps2_mouse is in PS/2 format: byte1=status, byte2=X mag, byte3=Y mag.
		// X: 9-bit signed = {X_sign(bit4), X_mag[15:8]}; sign-extend to 16-bit.
		// Y: same but negate — PS/2 Y_sign=1 means down, screen Y+ = down, so
		//    subtracting the PS/2 delta converts to screen coordinates.
		if (mouse_event) begin
			m_x_acc     <= m_x_acc + {{7{ps2_mouse[4]}}, ps2_mouse[4], ps2_mouse[15:8]};
			m_y_acc     <= m_y_acc - {{7{ps2_mouse[5]}}, ps2_mouse[5], ps2_mouse[23:16]};
			m_btns      <= ps2_mouse[2:0];  // {middle, right, left} from PS/2 status byte
			m_has_event <= 1'b1;
		end

		// ---- Serial output ----
		if (clk_falling) begin
			clk_rise_armed  <= 1'b1;
			serial_data_out <= tx_shift[7];
		end

		if (clk_rising && clk_rise_armed) begin
			clk_rise_armed <= 1'b0;

			if (bit_count == 3'd7) begin
				// End of byte — decide what the next byte is
				bit_count <= 3'd0;

				case (tx_state)
					TX_IDLE: begin
						if (ig_key != IG_NONE && !key_sent) begin
							// Latch key into shift reg; transmitted next byte period.
							tx_shift <= ig_key;
							key_sent <= 1'b1;
						end else if (m_sendable) begin
							// Start a 3-byte mouse packet.
							// m_b1_w/m_b2_w/m_b3_w use the current (pre-clear) accumulators.
							tx_shift    <= m_b1_w;
							m_b2        <= m_b2_w;
							m_b3        <= m_b3_w;
							tx_state    <= TX_MOUSE_X;
							m_has_event <= 1'b0;
							m_x_acc     <= 16'sd0;
							m_y_acc     <= 16'sd0;
							m_btns_last <= m_btns;
						end else begin
							tx_shift <= IG_NONE;
						end
					end

					TX_MOUSE_X: begin
						// Button byte just finished; load the X magnitude byte
						tx_shift <= m_b2;
						tx_state <= TX_MOUSE_Y;
					end

					TX_MOUSE_Y: begin
						// X byte just finished; load the Y magnitude byte
						tx_shift <= m_b3;
						tx_state <= TX_MOUSE_Z;
					end

					TX_MOUSE_Z: begin
						// Y byte just finished; preload idle and return
						tx_shift <= IG_NONE;
						tx_state <= TX_IDLE;
					end
				endcase

			end else begin
				bit_count <= bit_count + 1'd1;
				tx_shift <= {tx_shift[6:0], 1'b0};
			end

		end else if (clk_rising) begin
			// Rising edge without a prior falling edge — re-sync
			clk_rise_armed <= 1'b0;
			bit_count      <= 3'd0;
		end

	end
end

endmodule
