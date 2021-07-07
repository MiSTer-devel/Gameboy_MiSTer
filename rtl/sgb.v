module sgb (
	input        reset,
	input        clk_sys,
	input        ce,

	input        clk_vid,
	input        ce_pix,

	input        sgb_en,
	input        tint,
	input        isGBC_game,

	input        lcd_clkena,
	input [14:0] lcd_data,
	input [1:0]  lcd_mode,
	input        lcd_on,
	input        lcd_vsync,

	input [8:0]  h_cnt,
	input [8:0]  v_cnt,
	input        h_end,

	input [7:0]  joystick,

	input [1:0]  joy_p54,
	output [3:0] joy_do,

	input        border_download,
	input        ioctl_wr,
	input [13:0] ioctl_addr,
	input [15:0] ioctl_dout,

	output reg [15:0] sgb_border_pix,

	output reg [14:0] sgb_lcd_data,
	output reg        sgb_lcd_clkena,
	output reg [1:0]  sgb_lcd_mode,
	output reg        sgb_lcd_on,
	output reg        sgb_lcd_vsync
);

wire p14 = joy_p54[0];
wire p15 = joy_p54[1];

assign joy_do = joy_data;

wire [3:0] joy_dir     = ~{ joystick[2], joystick[3], joystick[1], joystick[0] } | {4{p14}};
wire [3:0] joy_buttons = ~{ joystick[7], joystick[6], joystick[5], joystick[4] } | {4{p15}};
wire [3:0] joy_data = joy_dir & joy_buttons;

reg [14:0] lcd_data_r;
reg lcd_clkena_r, lcd_on_r, lcd_vsync_r;
reg [1:0] lcd_mode_r;

// Lcd pixel output
always @(posedge clk_sys) begin
	if (ce) begin

		lcd_data_r <= lcd_data;
		lcd_clkena_r <= lcd_clkena;
		lcd_mode_r <= lcd_mode;
		lcd_on_r <= lcd_on;
		lcd_vsync_r <= lcd_vsync;

		sgb_lcd_data <= lcd_data_r;

		sgb_lcd_clkena <= lcd_clkena_r;
		sgb_lcd_mode <= lcd_mode_r;
		sgb_lcd_on <= lcd_on_r;
		sgb_lcd_vsync <= lcd_vsync_r;
	end

end

endmodule