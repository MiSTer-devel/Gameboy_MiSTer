// Gameboy for the MiST
// (c) 2015 Till Harbaum

// The gameboy lcd runs from a shift register which is filled at 4194304 pixels/sec

module lcd
(
	input        clk_sys,
	input        pix_wr,
	input [14:0] data,

	input  [1:0] mode,
	input        isGBC,
	input        double_buffer,

	//palette
	input [23:0] pal1,
	input [23:0] pal2,
	input [23:0] pal3,
	input [23:0] pal4,

	input [15:0] sgb_border_pix,
	input        sgb_pal_en,
	input        sgb_en,

	input        tint,
	input        inv,

	input        on,

	// VGA output
	input            clk_vid, // 67.108864 MHz
	output reg       ce_pix,
	output reg	     hs,
	output reg 	     vs,
	output reg 	     hbl,
	output reg 	     vbl,
	output reg [8:0] h_cnt,
	output reg [8:0] v_cnt,
	output reg [7:0] r,
	output reg [7:0] g,
	output reg [7:0] b
);

reg [14:0] vbuffer_inptr;
reg vbuffer_in_bank;
reg lcd_off;
always @(posedge clk_sys) begin
	reg old_lcd_off;

	lcd_off <= !on || (mode == 2'd01);

	if (pix_wr & ~lcd_off) vbuffer_inptr <= vbuffer_inptr + 1'd1;

	old_lcd_off <= lcd_off;
	if(~old_lcd_off & lcd_off) begin  //lcd disabled or vsync restart pointer
		vbuffer_inptr <= 0;
		vbuffer_in_bank <= ~vbuffer_in_bank;
	end
end

reg [14:0] vbuffer[65536];
always @(posedge clk_sys) if(pix_wr) vbuffer[{vbuffer_in_bank, vbuffer_inptr}] <= data;


// Mode 00:  h-blank
// Mode 01:  v-blank
// Mode 10:  oam
// Mode 11:  oam and vram	

parameter H      = 160;   // width of visible area
parameter HFP    = 103;   // unused time before hsync
parameter HS     = 32;    // width of hsync
parameter HBP    = 130;   // unused time after hsync
parameter HTOTAL = H+HFP+HS+HBP;
// total = 425

parameter H_BORDER = 48;
parameter V_BORDER = 40;
parameter H_START   = 4+H_BORDER;

parameter V        = 144; // height of visible area
parameter VS_START = 37;  // start of vsync
parameter VSTART   = 105; // start of active video
parameter VTOTAL   = 264;

// (67108864 / 32 / 228 / 154) == (67108864 / 10 /  425.6 / 264) == 59.7275Hz
// We need 4256 cycles per line so 1 pixel clock cycle needs to be 6 cycles longer.
// 424x10 + 1x16 cycles
reg [3:0] pix_div_cnt;
always @(posedge clk_vid) begin
	pix_div_cnt <= pix_div_cnt + 1'd1;
	if (h_cnt != HTOTAL-1 && pix_div_cnt == 4'd9) // Longer cycle at the last pixel
		pix_div_cnt <= 0;

	ce_pix <= !pix_div_cnt;
end

reg [14:0] vbuffer_outptr;
reg vbuffer_out_bank;

reg hb, vb, gb_hb, gb_vb, wait_vbl;
always @(posedge clk_vid) begin
	reg [14:0] inptr,inptr1,inptr2;
	reg old_lcd_off;
	reg old_on;

	inptr2 <= vbuffer_inptr;
	inptr1 <= inptr2;
	if(inptr1 == inptr2) inptr <= inptr1;

	if (!pix_div_cnt) begin
		// generate positive hsync signal
		if(h_cnt == H_START+H+HFP+HS) hs <= 0;
		if(h_cnt == H_START+H+HFP)    begin
			hs <= 1;

			// generate positive vsync signal
			if(v_cnt == VS_START)   vs <= 1;
			if(v_cnt == VS_START+3) vs <= 0;
		end

		// Hblank
		if(h_cnt == H_START)        gb_hb <= 0;
		if(h_cnt == H_START+H)      gb_hb <= 1;

		if(h_cnt == H_START-H_BORDER)      hb <= 0;
		if(h_cnt == H_START+H_BORDER+H)    hb <= 1;

		// Vblank
		if(v_cnt == VSTART)    gb_vb <= 0;
		if(v_cnt == VSTART+V)  gb_vb <= 1;

		if(v_cnt == VSTART-V_BORDER)            vb <= 0;
		if(v_cnt == VSTART+V_BORDER+V-VTOTAL)   vb <= 1;
	end

	if(ce_pix) begin

		h_cnt <= h_cnt + 1'd1;
		if(h_cnt == HTOTAL-1) begin
			h_cnt <= 0;
			if(~(vb & wait_vbl) | double_buffer) v_cnt <= v_cnt + 1'd1;
			if(v_cnt >= VTOTAL-1) v_cnt <= 0;

			if(v_cnt == VSTART-1) begin
				vbuffer_outptr 	<= 0;
				// Read from write buffer if it is far enough ahead
				vbuffer_out_bank <= (inptr >= (160*60) || ~double_buffer) ? vbuffer_in_bank : ~vbuffer_in_bank;
			end
		end

		// visible area?
		if(~gb_hb & ~gb_vb) begin
			vbuffer_outptr <= vbuffer_outptr + 1'd1;
		end
	end

	old_lcd_off <= lcd_off;
	old_on <= on;
	if (~double_buffer) begin
		// Lcd turned on. Wait in vblank for output reset.
		if (~old_on & on & ~vb) wait_vbl <= 1'b1; // lcd enabled

		if (old_lcd_off & ~lcd_off & vb) begin // lcd enabled or out of vblank
			wait_vbl <= 0;
			h_cnt <= 0;
			v_cnt <= 0;
			hs    <= 0;
			vs    <= 0;
		end
	end
end

// -------------------------------------------------------------------------------
// ------------------------------- pixel generator -------------------------------
// -------------------------------------------------------------------------------
reg [14:0] pixel_reg;
always @(posedge clk_vid) pixel_reg <= vbuffer[{vbuffer_out_bank, vbuffer_outptr}];

wire [1:0] pixel = (pixel_reg[1:0] ^ {inv,inv}); //invert gb only

wire  [4:0] r5 = pixel_reg[4:0];
wire  [4:0] g5 = pixel_reg[9:5];
wire  [4:0] b5 = pixel_reg[14:10];

wire [31:0] r10 = (r5 * 13) + (g5 * 2) +b5;
wire [31:0] g10 = (g5 * 3) + b5;
wire [31:0] b10 = (r5 * 3) + (g5 * 2) + (b5 * 11);

// greyscale
wire [7:0] grey = (pixel==0) ? 8'd252 : (pixel==1) ? 8'd168 : (pixel==2) ? 8'd96 : 8'd0;

// sgb_border_pix contains backdrop color when sgb_border_pix[15] is low.
wire sgb_border = sgb_border_pix[15] & sgb_en;

always@(posedge clk_vid) begin
	if(ce_pix) begin
		// visible area?
		hbl <= sgb_en ? hb : gb_hb;
		vbl <= sgb_en ? vb : gb_vb;

		// Allow backdrop color in border area and the border to overlap game area.
		if (((gb_hb|gb_vb) & sgb_en) | sgb_border) begin
			r <= {sgb_border_pix[4:0],sgb_border_pix[4:2]};
			g <= {sgb_border_pix[9:5],sgb_border_pix[9:7]};
			b <= {sgb_border_pix[14:10],sgb_border_pix[14:12]};
		end else if (isGBC) begin
			r <= r10[8:1];
			g <= {g10[6:0],1'b0};
			b <= b10[8:1];
		end else if (sgb_pal_en) begin
			r <= {r5,r5[4:2]};
			g <= {g5,g5[4:2]};
			b <= {b5,b5[4:2]};
		end else if (tint) begin
			{r,g,b} <= (pixel==0) ? pal1 : (pixel==1) ? pal2 : (pixel==2) ? pal3 : pal4;
		end else begin
			{r,g,b} <= {3{grey}};
		end

	end
end




endmodule
