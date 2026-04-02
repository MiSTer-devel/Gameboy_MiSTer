module megaduck_laptop
(
	input         clk_sys,
	input         reset,
	input         ce_32k,

	input  [10:0] ps2_key,
	input  [64:0] rtc_bcd,

	input         serial_clk_in,
	input         serial_data_in,
	output reg    serial_clk_out,
	output reg    serial_data_out
);

localparam [7:0] CMD_GET_KEYS      = 8'h00;
localparam [7:0] CMD_DONE_OK       = 8'h01;
localparam [7:0] CMD_DONE_OK_ALT   = 8'h81;
localparam [7:0] CMD_ABORT_FAIL    = 8'h04;
localparam [7:0] CMD_PRINT_INIT    = 8'h09;
localparam [7:0] CMD_RTC_SET       = 8'h0B;
localparam [7:0] CMD_RTC_GET       = 8'h0C;

localparam [7:0] REPLY_BOOT_OK     = 8'h01;
localparam [7:0] REPLY_BOOT_FAIL   = 8'h00;
localparam [7:0] REPLY_BUFFER_OK   = 8'h03;
localparam [7:0] REPLY_BUFFER_FAIL = 8'h06;
localparam [7:0] REPLY_CHECKSUM_OK = 8'h01;
localparam [7:0] REPLY_CHECKSUM_BAD= 8'h00;
localparam [7:0] REPLY_PRINT_INIT  = 8'h01;

localparam [2:0] ST_INIT_RX_COUNT  = 3'd0;
localparam [2:0] ST_INIT_WAIT_REQ  = 3'd1;
localparam [2:0] ST_INIT_WAIT_ACK  = 3'd2;
localparam [2:0] ST_READY          = 3'd3;
localparam [2:0] ST_RX_LEN         = 3'd4;
localparam [2:0] ST_RX_PAYLOAD     = 3'd5;
localparam [2:0] ST_RX_CHECKSUM    = 3'd6;
localparam [2:0] ST_WAIT_BUF_ACK   = 3'd7;

localparam [1:0] SHIFT_KEEP        = 2'd0;
localparam [1:0] SHIFT_FORCE_OFF   = 2'd1;
localparam [1:0] SHIFT_FORCE_ON    = 2'd2;

localparam [7:0] KEY_NONE          = 8'h00;
localparam [7:0] KBD_REPLY_LEN     = 8'd4;
localparam [7:0] RTC_REPLY_LEN     = 8'd10;
localparam [7:0] RTC_SET_LEN       = 8'd8;

localparam [7:0] FLAG_REPEAT       = 8'h01;
localparam [7:0] FLAG_CAPSLOCK     = 8'h02;
localparam [7:0] FLAG_SHIFT        = 8'h04;

localparam [7:0] KEY_F1            = 8'h80;
localparam [7:0] KEY_F2            = 8'h84;
localparam [7:0] KEY_F3            = 8'h88;
localparam [7:0] KEY_F4            = 8'h8C;
localparam [7:0] KEY_F5            = 8'h90;
localparam [7:0] KEY_F6            = 8'h94;
localparam [7:0] KEY_F7            = 8'h98;
localparam [7:0] KEY_F8            = 8'h9C;
localparam [7:0] KEY_F9            = 8'hA0;
localparam [7:0] KEY_F10           = 8'hA4;
localparam [7:0] KEY_F11           = 8'hA8;
localparam [7:0] KEY_F12           = 8'hAC;

localparam [7:0] KEY_ESCAPE        = 8'h81;
localparam [7:0] KEY_1             = 8'h85;
localparam [7:0] KEY_2             = 8'h89;
localparam [7:0] KEY_3             = 8'h8D;
localparam [7:0] KEY_4             = 8'h91;
localparam [7:0] KEY_5             = 8'h95;
localparam [7:0] KEY_6             = 8'h99;
localparam [7:0] KEY_7             = 8'h9D;
localparam [7:0] KEY_8             = 8'hA1;
localparam [7:0] KEY_9             = 8'hA5;
localparam [7:0] KEY_0             = 8'hA9;
localparam [7:0] KEY_SINGLE_QUOTE  = 8'hAD;
localparam [7:0] KEY_BACKSPACE     = 8'hB5;

localparam [7:0] KEY_HELP          = 8'h82;
localparam [7:0] KEY_Q             = 8'h86;
localparam [7:0] KEY_W             = 8'h8A;
localparam [7:0] KEY_E             = 8'h8E;
localparam [7:0] KEY_R             = 8'h92;
localparam [7:0] KEY_T             = 8'h96;
localparam [7:0] KEY_Y             = 8'h9A;
localparam [7:0] KEY_U             = 8'h9E;
localparam [7:0] KEY_I             = 8'hA2;
localparam [7:0] KEY_O             = 8'hA6;
localparam [7:0] KEY_P             = 8'hAA;
localparam [7:0] KEY_BACKTICK      = 8'hAE;
localparam [7:0] KEY_RIGHT_BRACKET = 8'hB2;
localparam [7:0] KEY_ENTER         = 8'hB6;

localparam [7:0] KEY_A             = 8'h87;
localparam [7:0] KEY_S             = 8'h8B;
localparam [7:0] KEY_D             = 8'h8F;
localparam [7:0] KEY_F             = 8'h93;
localparam [7:0] KEY_G             = 8'h97;
localparam [7:0] KEY_H             = 8'h9B;
localparam [7:0] KEY_J             = 8'h9F;
localparam [7:0] KEY_K             = 8'hA3;
localparam [7:0] KEY_L             = 8'hA7;

localparam [7:0] KEY_Z             = 8'hB8;
localparam [7:0] KEY_X             = 8'hBC;
localparam [7:0] KEY_C             = 8'hC0;
localparam [7:0] KEY_V             = 8'hC4;
localparam [7:0] KEY_B             = 8'hC8;
localparam [7:0] KEY_N             = 8'hCC;
localparam [7:0] KEY_M             = 8'hD0;
localparam [7:0] KEY_COMMA         = 8'hD4;
localparam [7:0] KEY_PERIOD        = 8'hD8;
localparam [7:0] KEY_DASH          = 8'hDC;
localparam [7:0] KEY_DELETE        = 8'hE0;

localparam [7:0] KEY_SPACE         = 8'hB9;
localparam [7:0] KEY_LESS_THAN     = 8'hBD;
localparam [7:0] KEY_PAGE_UP       = 8'hC1;
localparam [7:0] KEY_PAGE_DOWN     = 8'hC5;
localparam [7:0] KEY_MULTIPLY      = 8'hD9;
localparam [7:0] KEY_ARROW_DOWN    = 8'hDD;
localparam [7:0] KEY_MINUS         = 8'hE1;
localparam [7:0] KEY_DIVIDE        = 8'hE4;
localparam [7:0] KEY_ARROW_LEFT    = 8'hE5;
localparam [7:0] KEY_ARROW_UP      = 8'hE8;
localparam [7:0] KEY_EQUALS        = 8'hE9;
localparam [7:0] KEY_ARROW_RIGHT   = 8'hED;
localparam [7:0] KEY_PLUS          = 8'hEC;
localparam [7:0] KEY_PRINTSCREEN   = 8'hDE;

localparam [7:0] KEY_PIANO_DO_SHARP   = 8'hBA;
localparam [7:0] KEY_PIANO_RE_SHARP   = 8'hBE;
localparam [7:0] KEY_PIANO_FA_SHARP   = 8'hC6;
localparam [7:0] KEY_PIANO_SOL_SHARP  = 8'hCA;
localparam [7:0] KEY_PIANO_LA_SHARP   = 8'hCE;
localparam [7:0] KEY_PIANO_DO2_SHARP  = 8'hD6;
localparam [7:0] KEY_PIANO_RE2_SHARP  = 8'hDA;
localparam [7:0] KEY_PIANO_FA2_SHARP  = 8'hE2;
localparam [7:0] KEY_PIANO_SOL2_SHARP = 8'hE6;
localparam [7:0] KEY_PIANO_LA2_SHARP  = 8'hEA;

localparam [7:0] KEY_PIANO_DO         = 8'hBB;
localparam [7:0] KEY_PIANO_RE         = 8'hBF;
localparam [7:0] KEY_PIANO_MI         = 8'hC3;
localparam [7:0] KEY_PIANO_FA         = 8'hC7;
localparam [7:0] KEY_PIANO_SOL        = 8'hCB;
localparam [7:0] KEY_PIANO_LA         = 8'hCF;
localparam [7:0] KEY_PIANO_SI         = 8'hD3;
localparam [7:0] KEY_PIANO_DO2        = 8'hD7;
localparam [7:0] KEY_PIANO_RE2        = 8'hDB;
localparam [7:0] KEY_PIANO_MI2        = 8'hDF;
localparam [7:0] KEY_PIANO_FA2        = 8'hE3;
localparam [7:0] KEY_PIANO_SOL2       = 8'hE7;
localparam [7:0] KEY_PIANO_LA2        = 8'hEB;
localparam [7:0] KEY_PIANO_SI2        = 8'hEF;

localparam [1:0] TX_HALF_PERIOD       = 2'd1;
localparam [6:0] TX_DELAY_SHORT       = 7'd16;
localparam [6:0] TX_DELAY_BUFFER      = 7'd82;
localparam [6:0] TX_DELAY_BUFFER_GAP  = 7'd66;
localparam integer TX_PACKET_MAX      = 10;

function automatic [7:0] bcd_to_bin;
	input [7:0] value;
	reg [7:0] tens;
	begin
		tens = {4'd0, value[7:4]};
		bcd_to_bin = (tens << 3) + (tens << 1) + {4'd0, value[3:0]};
	end
endfunction

function automatic [7:0] bin_to_bcd_99;
	input [7:0] value;
	begin
		if (value >= 8'd90)      bin_to_bcd_99 = 8'h90 + (value - 8'd90);
		else if (value >= 8'd80) bin_to_bcd_99 = 8'h80 + (value - 8'd80);
		else if (value >= 8'd70) bin_to_bcd_99 = 8'h70 + (value - 8'd70);
		else if (value >= 8'd60) bin_to_bcd_99 = 8'h60 + (value - 8'd60);
		else if (value >= 8'd50) bin_to_bcd_99 = 8'h50 + (value - 8'd50);
		else if (value >= 8'd40) bin_to_bcd_99 = 8'h40 + (value - 8'd40);
		else if (value >= 8'd30) bin_to_bcd_99 = 8'h30 + (value - 8'd30);
		else if (value >= 8'd20) bin_to_bcd_99 = 8'h20 + (value - 8'd20);
		else if (value >= 8'd10) bin_to_bcd_99 = 8'h10 + (value - 8'd10);
		else                     bin_to_bcd_99 = value[7:0];
	end
endfunction

function automatic [7:0] hour24_to_hour12_bcd;
	input [7:0] hour24;
	begin
		hour24_to_hour12_bcd = bin_to_bcd_99((hour24 >= 8'd12) ? (hour24 - 8'd12) : hour24);
	end
endfunction

function automatic [7:0] days_in_month;
	input [7:0] year_code;
	input [7:0] month;
	reg leap_year;
	begin
		leap_year = ~|year_code[1:0];
		case (month)
			8'd1, 8'd3, 8'd5, 8'd7, 8'd8, 8'd10, 8'd12: days_in_month = 8'd31;
			8'd4, 8'd6, 8'd9, 8'd11:                    days_in_month = 8'd30;
			8'd2:                                       days_in_month = leap_year ? 8'd29 : 8'd28;
			default:                                    days_in_month = 8'd31;
		endcase
	end
endfunction

function automatic rtc_set_is_boot_default;
	input [7:0] year_code;
	input [7:0] month;
	input [7:0] day;
	input [7:0] weekday;
	input [7:0] ampm;
	input [7:0] hour;
	input [7:0] minute;
	input [7:0] second;
	begin
		// Ignore the ROM's known placeholder RTC writes once at startup so
		// MiSTer's host clock remains the initial source, like Workboy does.
		rtc_set_is_boot_default =
			((year_code == 8'h94) && (month == 8'h01) && (day == 8'h01) && (weekday == 8'h06) &&
			 (ampm == 8'h00) && (hour == 8'h00) && (minute == 8'h00) && (second == 8'h00)) ||
			((year_code == 8'h93) && (month == 8'h06) && (day == 8'h01) && (weekday == 8'h02) &&
			 (ampm == 8'h00) && (hour == 8'h00) && (minute == 8'h00) && (second == 8'h00));
	end
endfunction

task automatic tick_rtc_one_second;
	begin
		if (rtc_second == 8'd59) begin
			rtc_second <= 8'd0;
			if (rtc_minute == 8'd59) begin
				rtc_minute <= 8'd0;
				if (rtc_hour24 == 8'd23) begin
					rtc_hour24  <= 8'd0;
					rtc_weekday <= (rtc_weekday == 8'd6) ? 8'd0 : (rtc_weekday + 8'd1);
					if (rtc_day == days_in_month(rtc_year, rtc_month)) begin
						rtc_day <= 8'd1;
						if (rtc_month == 8'd12) begin
							rtc_month <= 8'd1;
							rtc_year  <= (rtc_year == 8'd99) ? 8'd0 : (rtc_year + 8'd1);
						end else begin
							rtc_month <= rtc_month + 8'd1;
						end
					end else begin
						rtc_day <= rtc_day + 8'd1;
					end
				end else begin
					rtc_hour24 <= rtc_hour24 + 8'd1;
				end
			end else begin
				rtc_minute <= rtc_minute + 8'd1;
			end
		end else begin
			rtc_second <= rtc_second + 8'd1;
		end
	end
endtask

function automatic [10:0] ps2_to_duck;
	input [7:0] scancode;
	input       extended;
	input       shift_held;
	input       ctrl_held;
	begin
		ps2_to_duck = 11'd0;

		if (ctrl_held && !extended) begin
			case (scancode)
				8'h05: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_PIANO_DO_SHARP};
				8'h06: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_PIANO_RE_SHARP};
				8'h04: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_PIANO_FA_SHARP};
				8'h0C: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_PIANO_SOL_SHARP};
				8'h03: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_PIANO_LA_SHARP};
				8'h0B: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_PIANO_DO2_SHARP};
				8'h83: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_PIANO_RE2_SHARP};
				8'h0A: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_PIANO_FA2_SHARP};
				8'h01: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_PIANO_SOL2_SHARP};
				8'h09: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_PIANO_LA2_SHARP};

				8'h0E: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_PIANO_DO};
				8'h16: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_PIANO_RE};
				8'h1E: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_PIANO_MI};
				8'h26: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_PIANO_FA};
				8'h25: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_PIANO_SOL};
				8'h2E: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_PIANO_LA};
				8'h36: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_PIANO_SI};
				8'h3D: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_PIANO_DO2};
				8'h3E: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_PIANO_RE2};
				8'h46: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_PIANO_MI2};
				8'h45: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_PIANO_FA2};
				8'h4E: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_PIANO_SOL2};
				8'h55: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_PIANO_LA2};
				8'h66: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_PIANO_SI2};
				default: ;
			endcase
		end
		else if (extended) begin
			case (scancode)
				8'h75: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_ARROW_UP};
				8'h72: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_ARROW_DOWN};
				8'h6B: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_ARROW_LEFT};
				8'h74: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_ARROW_RIGHT};
				8'h7D: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_PAGE_UP};
				8'h7A: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_PAGE_DOWN};
				8'h71: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_DELETE};
				8'h4A: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_DIVIDE};
				8'h5A: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_ENTER};
				8'h7C: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_PRINTSCREEN};
				default: ;
			endcase
		end
		else begin
			case (scancode)
				8'h0D: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_HELP};
				8'h76: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_ESCAPE};
				8'h66: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_BACKSPACE};
				8'h5A: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_ENTER};
				8'h05: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_F1};
				8'h06: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_F2};
				8'h04: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_F3};
				8'h0C: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_F4};
				8'h03: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_F5};
				8'h0B: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_F6};
				8'h83: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_F7};
				8'h0A: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_F8};
				8'h01: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_F9};
				8'h09: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_F10};
				8'h78: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_F11};
				8'h07: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_F12};
				8'h7C: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_MULTIPLY};
				8'h7B: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_MINUS};
				8'h79: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_PLUS};
				8'h7E: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_PRINTSCREEN};

				8'h1C: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_A};
				8'h32: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_B};
				8'h21: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_C};
				8'h23: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_D};
				8'h24: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_E};
				8'h2B: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_F};
				8'h34: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_G};
				8'h33: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_H};
				8'h43: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_I};
				8'h3B: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_J};
				8'h42: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_K};
				8'h4B: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_L};
				8'h3A: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_M};
				8'h31: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_N};
				8'h44: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_O};
				8'h4D: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_P};
				8'h15: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_Q};
				8'h2D: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_R};
				8'h1B: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_S};
				8'h2C: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_T};
				8'h3C: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_U};
				8'h2A: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_V};
				8'h1D: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_W};
				8'h22: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_X};
				8'h35: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_Y};
				8'h1A: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_Z};

				8'h16: ps2_to_duck = shift_held ? {1'b1, SHIFT_FORCE_ON,  KEY_1}            : {1'b1, SHIFT_FORCE_OFF, KEY_1};
				8'h1E: if (!shift_held) ps2_to_duck = {1'b1, SHIFT_FORCE_OFF, KEY_2};
				8'h26: if (!shift_held) ps2_to_duck = {1'b1, SHIFT_FORCE_OFF, KEY_3};
				8'h25: ps2_to_duck = shift_held ? {1'b1, SHIFT_FORCE_ON,  KEY_4}            : {1'b1, SHIFT_FORCE_OFF, KEY_4};
				8'h2E: ps2_to_duck = shift_held ? {1'b1, SHIFT_FORCE_ON,  KEY_5}            : {1'b1, SHIFT_FORCE_OFF, KEY_5};
				8'h36: if (!shift_held) ps2_to_duck = {1'b1, SHIFT_FORCE_OFF, KEY_6};
				8'h3D: ps2_to_duck = shift_held ? {1'b1, SHIFT_FORCE_ON,  KEY_6}            : {1'b1, SHIFT_FORCE_OFF, KEY_7};
				8'h3E: ps2_to_duck = shift_held ? {1'b1, SHIFT_FORCE_ON,  KEY_RIGHT_BRACKET}: {1'b1, SHIFT_FORCE_OFF, KEY_8};
				8'h46: ps2_to_duck = shift_held ? {1'b1, SHIFT_FORCE_ON,  KEY_8}            : {1'b1, SHIFT_FORCE_OFF, KEY_9};
				8'h45: ps2_to_duck = shift_held ? {1'b1, SHIFT_FORCE_ON,  KEY_9}            : {1'b1, SHIFT_FORCE_OFF, KEY_0};

				8'h0E: if (!shift_held) ps2_to_duck = {1'b1, SHIFT_FORCE_OFF, KEY_BACKTICK};
				8'h4E: ps2_to_duck = shift_held ? {1'b1, SHIFT_FORCE_ON,  KEY_DASH}         : {1'b1, SHIFT_FORCE_OFF, KEY_DASH};
				8'h55: ps2_to_duck = shift_held ? {1'b1, SHIFT_FORCE_OFF, KEY_PLUS}         : {1'b1, SHIFT_FORCE_OFF, KEY_EQUALS};
				8'h54: if (!shift_held) ps2_to_duck = {1'b1, SHIFT_FORCE_ON,  KEY_BACKTICK};
				8'h5B: if (!shift_held) ps2_to_duck = {1'b1, SHIFT_FORCE_OFF, KEY_RIGHT_BRACKET};
				8'h5D: if (!shift_held) ps2_to_duck = {1'b1, SHIFT_FORCE_ON,  KEY_0};
				8'h61: ps2_to_duck = shift_held ? {1'b1, SHIFT_FORCE_ON,  KEY_LESS_THAN}    : {1'b1, SHIFT_FORCE_OFF, KEY_LESS_THAN};
				8'h4C: ps2_to_duck = shift_held ? {1'b1, SHIFT_FORCE_ON,  KEY_PERIOD}       : {1'b1, SHIFT_FORCE_ON,  KEY_COMMA};
				8'h52: ps2_to_duck = shift_held ? {1'b1, SHIFT_FORCE_ON,  KEY_2}            : {1'b1, SHIFT_FORCE_OFF, KEY_SINGLE_QUOTE};
				8'h41: ps2_to_duck = shift_held ? {1'b1, SHIFT_FORCE_OFF, KEY_LESS_THAN}    : {1'b1, SHIFT_FORCE_OFF, KEY_COMMA};
				8'h49: ps2_to_duck = shift_held ? {1'b1, SHIFT_FORCE_ON,  KEY_LESS_THAN}    : {1'b1, SHIFT_FORCE_OFF, KEY_PERIOD};
				8'h4A: ps2_to_duck = shift_held ? {1'b1, SHIFT_FORCE_ON,  KEY_SINGLE_QUOTE} : {1'b1, SHIFT_FORCE_ON,  KEY_7};
				8'h29: ps2_to_duck = {1'b1, SHIFT_KEEP, KEY_SPACE};
				default: ;
			endcase
		end
	end
endfunction

task automatic start_packet_tx;
	input [3:0] count;
	input [6:0] start_delay;
	input [6:0] gap_delay;
	begin
		if (count != 0) begin
			tx_active         <= 1'b1;
			tx_stream_mode    <= 1'b0;
			tx_remaining      <= {5'd0, count};
			tx_packet_index   <= 4'd0;
			tx_bit_index      <= 3'd0;
			tx_half_counter   <= TX_HALF_PERIOD;
			tx_delay_counter  <= start_delay;
			tx_gap_delay      <= gap_delay;
			tx_shift          <= tx_packet[0];
			serial_clk_out  <= 1'b1;
			serial_data_out <= tx_packet[0][7];
		end
	end
endtask

task automatic start_stream_tx;
	input [7:0] first_value;
	input [8:0] count;
	input [6:0] start_delay;
	input [6:0] gap_delay;
	begin
		if (count != 0) begin
			tx_active         <= 1'b1;
			tx_stream_mode    <= 1'b1;
			tx_remaining      <= count;
			tx_packet_index   <= 4'd0;
			tx_stream_value   <= first_value;
			tx_bit_index      <= 3'd0;
			tx_half_counter   <= TX_HALF_PERIOD;
			tx_delay_counter  <= start_delay;
			tx_gap_delay      <= gap_delay;
			tx_shift          <= first_value;
			serial_clk_out  <= 1'b1;
			serial_data_out <= first_value[7];
		end
	end
endtask

task automatic queue_single_byte;
	input [7:0] value;
	input [6:0] start_delay;
	begin
		tx_packet[0] = value;
		start_packet_tx(4'd1, start_delay, 7'd0);
	end
endtask

task automatic queue_keyboard_reply;
	reg [7:0] send_key;
	reg [7:0] send_flags;
	reg [7:0] sum;
	begin
		send_flags = 8'h00;
		if (key_pending) begin
			send_key = pending_key;
			if (pending_capslock_down) send_flags = send_flags | FLAG_CAPSLOCK;
			if (pending_shift_down)    send_flags = send_flags | FLAG_SHIFT;

			case (pending_shift_mode)
				SHIFT_FORCE_OFF: send_flags = send_flags & ~FLAG_SHIFT;
				SHIFT_FORCE_ON:  send_flags = send_flags | FLAG_SHIFT;
				default: ;
			endcase

			key_pending   <= 1'b0;
			last_key_sent <= pending_key;
		end else begin
			send_key = current_key;
			if (capslock_down) send_flags = send_flags | FLAG_CAPSLOCK;
			if (shift_down)    send_flags = send_flags | FLAG_SHIFT;

			case (current_shift_mode)
				SHIFT_FORCE_OFF: send_flags = send_flags & ~FLAG_SHIFT;
				SHIFT_FORCE_ON:  send_flags = send_flags | FLAG_SHIFT;
				default: ;
			endcase

			if ((current_key != KEY_NONE) && (current_key == last_key_sent)) begin
				send_key = KEY_NONE;
				send_flags = send_flags | FLAG_REPEAT;
			end

			last_key_sent <= current_key;
		end

		tx_packet[0] = KBD_REPLY_LEN;
		tx_packet[1] = send_flags;
		tx_packet[2] = send_key;
		sum = tx_packet[0] + tx_packet[1] + tx_packet[2];
		tx_packet[3] = (~sum[7:0]) + 8'd1;
		start_packet_tx(4'd4, TX_DELAY_BUFFER, TX_DELAY_BUFFER_GAP);
	end
endtask

task automatic queue_rtc_reply;
	reg [7:0] year_out;
	reg [7:0] month_out;
	reg [7:0] day_out;
	reg [7:0] wday_out;
	reg [7:0] hour24_out;
	reg [7:0] minute_out;
	reg [7:0] second_out;
	reg [7:0] sum;
	begin
		year_out   = bin_to_bcd_99(rtc_year);
		month_out  = bin_to_bcd_99(rtc_month);
		day_out    = bin_to_bcd_99(rtc_day);
		wday_out   = bin_to_bcd_99(rtc_weekday);
		hour24_out = rtc_hour24;
		minute_out = bin_to_bcd_99(rtc_minute);
		second_out = bin_to_bcd_99(rtc_second);

		tx_packet[0] = RTC_REPLY_LEN;
		tx_packet[1] = year_out;
		tx_packet[2] = month_out;
		tx_packet[3] = day_out;
		tx_packet[4] = wday_out;
		tx_packet[5] = (hour24_out >= 8'd12) ? 8'h01 : 8'h00;
		tx_packet[6] = hour24_to_hour12_bcd(hour24_out);
		tx_packet[7] = minute_out;
		tx_packet[8] = second_out;

		sum = 8'd0;
		sum = sum + tx_packet[0] + tx_packet[1] + tx_packet[2] + tx_packet[3] + tx_packet[4];
		sum = sum + tx_packet[5] + tx_packet[6] + tx_packet[7] + tx_packet[8];
		tx_packet[9] = (~sum[7:0]) + 8'd1;
		start_packet_tx(4'd10, TX_DELAY_BUFFER, TX_DELAY_BUFFER_GAP);
	end
endtask

task automatic load_host_rtc_defaults;
	begin
		rtc_custom     <= 1'b0;
		rtc_year       <= bcd_to_bin(rtc_bcd[47:40]);
		rtc_month      <= bcd_to_bin(rtc_bcd[39:32]);
		rtc_day        <= bcd_to_bin(rtc_bcd[31:24]);
		rtc_weekday    <= bcd_to_bin(rtc_bcd[55:48]);
		rtc_hour24     <= bcd_to_bin(rtc_bcd[23:16]);
		rtc_minute     <= bcd_to_bin(rtc_bcd[15:8]);
		rtc_second     <= bcd_to_bin(rtc_bcd[7:0]);
		rtc_subseconds <= 15'd0;
		rtc_bcd_toggle_last <= rtc_bcd[64];
	end
endtask

reg        gb_clk_last;
reg        gb_clk_rise_armed;
reg [2:0]  gb_bit_count;
reg [7:0]  gb_rx_shift;

reg [2:0]  state;
reg [7:0]  init_counter;

reg        tx_active;
reg        tx_stream_mode;
reg [8:0]  tx_remaining;
reg [3:0]  tx_packet_index;
reg [2:0]  tx_bit_index;
reg [1:0]  tx_half_counter;
reg [6:0]  tx_delay_counter;
reg [6:0]  tx_gap_delay;
reg [7:0]  tx_shift;
reg [7:0]  tx_stream_value;
reg [7:0]  tx_packet[0:TX_PACKET_MAX-1];

reg        shift_down;
reg        ctrl_down;
reg        capslock_down;
reg        ps2_last;
reg [7:0]  current_key;
reg [1:0]  current_shift_mode;
reg        key_pending;
reg [7:0]  pending_key;
reg [1:0]  pending_shift_mode;
reg        pending_shift_down;
reg        pending_capslock_down;
reg [7:0]  last_key_sent;

reg        rtc_custom;
reg [7:0]  rtc_year;
reg [7:0]  rtc_month;
reg [7:0]  rtc_day;
reg [7:0]  rtc_weekday;
reg [7:0]  rtc_hour24;
reg [7:0]  rtc_minute;
reg [7:0]  rtc_second;
reg [14:0] rtc_subseconds;
reg        rtc_bcd_toggle_last;
reg        rtc_filter_boot_set;

reg [2:0]  rx_payload_count;
reg [7:0]  rx_checksum;
reg [7:0]  rx_buffer[0:7];

reg [10:0] mapped_key;
reg [7:0]  received_byte;
reg [7:0]  tx_next_byte;

wire        ps2_event    = (ps2_last != ps2_key[10]);
wire        ps2_pressed  = ps2_key[9];
wire        ps2_extended = ps2_key[8];
wire [7:0]  ps2_scancode = ps2_key[7:0];

wire        gb_clk_falling =  gb_clk_last & ~serial_clk_in;
wire        gb_clk_rising  = ~gb_clk_last &  serial_clk_in;

always @(posedge clk_sys) begin
	ps2_last    <= ps2_key[10];
	gb_clk_last <= serial_clk_in;

	if (reset) begin
		serial_clk_out  <= 1'b1;
		serial_data_out <= 1'b1;
		gb_clk_last       <= serial_clk_in;
		gb_clk_rise_armed <= 1'b0;
		gb_bit_count      <= 3'd0;
		gb_rx_shift       <= 8'h00;
		state             <= ST_INIT_RX_COUNT;
		init_counter      <= 8'h00;
		tx_active         <= 1'b0;
		tx_stream_mode    <= 1'b0;
		tx_remaining      <= 9'd0;
		tx_packet_index   <= 4'd0;
		tx_bit_index      <= 3'd0;
		tx_half_counter   <= TX_HALF_PERIOD;
		tx_delay_counter  <= 7'd0;
		tx_gap_delay      <= 7'd0;
		tx_shift          <= 8'h00;
		tx_stream_value   <= 8'h00;
		shift_down        <= 1'b0;
		ctrl_down         <= 1'b0;
		capslock_down     <= 1'b0;
		ps2_last          <= 1'b0;
		current_key       <= KEY_NONE;
		current_shift_mode<= SHIFT_KEEP;
		key_pending       <= 1'b0;
		pending_key       <= KEY_NONE;
		pending_shift_mode<= SHIFT_KEEP;
		pending_shift_down<= 1'b0;
		pending_capslock_down <= 1'b0;
		last_key_sent     <= KEY_NONE;
		rx_payload_count  <= 3'd0;
		rx_checksum       <= 8'd0;
		rtc_filter_boot_set <= 1'b1;
		load_host_rtc_defaults();
	end else begin
		if (rtc_bcd[64] != rtc_bcd_toggle_last) begin
			if (!rtc_custom) begin
				load_host_rtc_defaults();
			end else begin
				rtc_bcd_toggle_last <= rtc_bcd[64];
			end
		end

		if (ce_32k) begin
			if (rtc_subseconds == 15'd32767) begin
				rtc_subseconds <= 15'd0;
				tick_rtc_one_second();
			end else begin
				rtc_subseconds <= rtc_subseconds + 15'd1;
			end
		end

		if (ps2_event) begin
			mapped_key = 11'd0;

			if (!ps2_extended && (ps2_scancode == 8'h12 || ps2_scancode == 8'h59)) begin
				shift_down <= ps2_pressed;
			end else if (ps2_scancode == 8'h14) begin
				ctrl_down <= ps2_pressed;
				if (!ps2_pressed)
					current_key <= KEY_NONE;
			end else if (!ps2_extended && ps2_scancode == 8'h58 && ps2_pressed) begin
				capslock_down <= ~capslock_down;
			end else if (ps2_pressed) begin
				mapped_key = ps2_to_duck(ps2_scancode, ps2_extended, shift_down, ctrl_down);

				if (mapped_key[10]) begin
					current_key        <= mapped_key[7:0];
					current_shift_mode <= mapped_key[9:8];
					pending_key        <= mapped_key[7:0];
					pending_shift_mode <= mapped_key[9:8];
					pending_shift_down <= shift_down;
					pending_capslock_down <= capslock_down;
					key_pending        <= 1'b1;
				end
			end else if (ps2_scancode != 8'hF0) begin
				current_key        <= KEY_NONE;
				current_shift_mode <= SHIFT_KEEP;
			end
		end

		if (ce_32k && tx_active) begin
			if (tx_delay_counter != 0) begin
				tx_delay_counter <= tx_delay_counter - 7'd1;
			end else if (tx_half_counter != 0) begin
				tx_half_counter <= tx_half_counter - 2'd1;
			end else begin
				tx_half_counter <= TX_HALF_PERIOD;

				if (serial_clk_out) begin
					serial_clk_out <= 1'b0;
				end else begin
					serial_clk_out <= 1'b1;

					if (tx_bit_index == 3'd7) begin
						tx_bit_index <= 3'd0;

						if (tx_remaining > 9'd1) begin
							tx_remaining    <= tx_remaining - 9'd1;
							tx_delay_counter <= tx_gap_delay;

							if (tx_stream_mode) begin
								tx_next_byte    = tx_stream_value - 8'd1;
								tx_stream_value <= tx_next_byte;
							end else begin
								tx_packet_index <= tx_packet_index + 4'd1;
								tx_next_byte    = tx_packet[tx_packet_index + 4'd1];
							end

							tx_shift          <= tx_next_byte;
							serial_data_out <= tx_next_byte[7];
						end else begin
							tx_active         <= 1'b0;
							tx_stream_mode    <= 1'b0;
							tx_remaining      <= 9'd0;
							serial_data_out <= 1'b1;
							tx_shift          <= 8'h00;
						end
					end else begin
						tx_bit_index      <= tx_bit_index + 3'd1;
						tx_shift          <= {tx_shift[6:0], 1'b0};
						serial_data_out <= tx_shift[6];
					end
				end
			end
		end

		if (!tx_active && gb_clk_falling) begin
			gb_clk_rise_armed <= 1'b1;
		end

		if (!tx_active && gb_clk_rising && gb_clk_rise_armed) begin
			gb_clk_rise_armed <= 1'b0;
			gb_rx_shift <= {gb_rx_shift[6:0], serial_data_in};

			if (gb_bit_count == 3'd7) begin
				gb_bit_count  <= 3'd0;
				received_byte = {gb_rx_shift[6:0], serial_data_in};

				case (state)
					ST_INIT_RX_COUNT: begin
						if (received_byte == init_counter) begin
							if (init_counter == 8'hFF) begin
								state <= ST_INIT_WAIT_REQ;
								queue_single_byte(REPLY_BOOT_OK, TX_DELAY_SHORT);
							end else begin
								init_counter <= init_counter + 8'd1;
							end
						end else if (received_byte == 8'hFF) begin
							init_counter <= 8'h00;
							queue_single_byte(REPLY_BOOT_FAIL, TX_DELAY_SHORT);
						end
					end

					ST_INIT_WAIT_REQ: begin
						if (received_byte == CMD_GET_KEYS) begin
							state <= ST_INIT_WAIT_ACK;
							start_stream_tx(8'hFF, 9'd256, TX_DELAY_SHORT, TX_DELAY_SHORT);
						end
					end

					ST_INIT_WAIT_ACK: begin
						if (received_byte == CMD_DONE_OK) begin
							state <= ST_READY;
						end else if (received_byte == CMD_ABORT_FAIL) begin
							state <= ST_INIT_RX_COUNT;
							init_counter <= 8'h00;
						end
					end

					ST_READY: begin
						case (received_byte)
							CMD_GET_KEYS: begin
								state <= ST_WAIT_BUF_ACK;
								queue_keyboard_reply();
							end

							CMD_PRINT_INIT: begin
								queue_single_byte(REPLY_PRINT_INIT, TX_DELAY_SHORT);
							end

							CMD_RTC_GET: begin
								state <= ST_WAIT_BUF_ACK;
								queue_rtc_reply();
							end

							CMD_RTC_SET: begin
								state      <= ST_RX_LEN;
								queue_single_byte(REPLY_BUFFER_OK, TX_DELAY_BUFFER);
							end

							default: ;
						endcase
					end

					ST_RX_LEN: begin
						if (received_byte == (RTC_SET_LEN + 8'd2)) begin
							rx_payload_count <= 3'd0;
							rx_checksum      <= received_byte;
							state            <= ST_RX_PAYLOAD;
							queue_single_byte(REPLY_BUFFER_OK, TX_DELAY_SHORT);
						end else begin
							state <= ST_READY;
							queue_single_byte(REPLY_BUFFER_FAIL, TX_DELAY_SHORT);
						end
					end

					ST_RX_PAYLOAD: begin
						rx_buffer[rx_payload_count] <= received_byte;
						rx_checksum <= rx_checksum + received_byte;

						if (rx_payload_count == 3'd7)
							state <= ST_RX_CHECKSUM;
						else
							rx_payload_count <= rx_payload_count + 3'd1;
						queue_single_byte(REPLY_BUFFER_OK, TX_DELAY_SHORT);
					end

					ST_RX_CHECKSUM: begin
						if ((rx_checksum + received_byte) == 8'h00) begin
							if (rtc_filter_boot_set &&
								rtc_set_is_boot_default(rx_buffer[0], rx_buffer[1], rx_buffer[2], rx_buffer[3],
													  rx_buffer[4], rx_buffer[5], rx_buffer[6], rx_buffer[7])) begin
								rtc_filter_boot_set <= 1'b0;
							end else begin
								rtc_filter_boot_set <= 1'b0;
								rtc_custom     <= 1'b1;
								rtc_year       <= bcd_to_bin(rx_buffer[0]);
								rtc_month      <= bcd_to_bin(rx_buffer[1]);
								rtc_day        <= bcd_to_bin(rx_buffer[2]);
								rtc_weekday    <= bcd_to_bin(rx_buffer[3]);
								rtc_hour24     <= bcd_to_bin(rx_buffer[5]) + (rx_buffer[4][0] ? 8'd12 : 8'd0);
								rtc_minute     <= bcd_to_bin(rx_buffer[6]);
								rtc_second     <= bcd_to_bin(rx_buffer[7]);
								rtc_subseconds <= 15'd0;
							end
							state <= ST_READY;
							queue_single_byte(REPLY_CHECKSUM_OK, TX_DELAY_SHORT);
						end else begin
							state <= ST_READY;
							queue_single_byte(REPLY_CHECKSUM_BAD, TX_DELAY_SHORT);
						end
					end

					ST_WAIT_BUF_ACK: begin
						if ((received_byte == CMD_DONE_OK) || (received_byte == CMD_DONE_OK_ALT) || (received_byte == CMD_ABORT_FAIL)) begin
							state <= ST_READY;
						end
					end

					default: state <= ST_READY;
				endcase
			end else begin
				gb_bit_count <= gb_bit_count + 3'd1;
			end
		end else if (!tx_active && gb_clk_rising) begin
			gb_clk_rise_armed <= 1'b0;
			gb_bit_count      <= 3'd0;
		end
	end
end

endmodule
