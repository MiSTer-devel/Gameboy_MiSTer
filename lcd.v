// Gameboy for the MiST
// (c) 2015 Till Harbaum

// The gameboy lcd runs from a shift register which is filled at 4194304 pixels/sec

module lcd (
	input   clk_sys, // 67.108864 MHz
	input   ce_cpu, // 4.194304 Mhz
	input   clkena,
	input [14:0] data,
	input [1:0] mode,
	input isGBC,
	input  double_buffer,
	
	//palette
	input [23:0] pal1,
	input [23:0] pal2,
	input [23:0] pal3,
	input [23:0] pal4,

	input tint,
	input inv,

	input  on,

	output reg ce_pix,

   // VGA output
   output reg	hs,
   output reg 	vs,
   output reg 	hbl,
   output reg 	vbl,
   output reg [7:0] r,
   output reg [7:0] g,
   output reg [7:0] b
);


reg [14:0] vbuffer_inptr;
reg [14:0] vbuffer_outptr;
reg vbuffer_in_bank, vbuffer_out_bank;

//image buffer 160x144x15bits for cgb
dpram #(16,15) vbuffer (
	.clock_a (clk_sys & ce_cpu),
	.address_a (vbuffer_in_bank ? (vbuffer_inptr+16'd23040) : vbuffer_inptr),
	.wren_a (clkena),
	.data_a (data),
	.q_a (),
	
	.clock_b (clk_sys & ce_pix),
	.address_b (vbuffer_out_bank ? (vbuffer_outptr+16'd23040) : vbuffer_outptr),
	.wren_b (1'b0), //only reads
	.data_b (),
	.q_b (pixel_reg)
);

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

parameter V        = 144; // height of visible area
parameter VS_START = 35;  // start of vsync
parameter VSTART   = 105; // start of active video
parameter VTOTAL   = 264;

reg[8:0] h_cnt;         // horizontal pixel counter
reg[8:0] v_cnt;         // vertical pixel counter


// (67108864 / 32 / 228 / 154) == (67108864 / 10 /  425.6 / 264) == 59.7275Hz
// We need 4256 cycles per line so 1 pixel clock cycle needs to be 6 cycles longer.
// 424x10 + 1x16 cycles
reg [3:0] pix_div_cnt;
always @(posedge clk_sys) begin
	pix_div_cnt <= pix_div_cnt + 1'd1;
	if (h_cnt != HTOTAL-1 && pix_div_cnt == 4'd9) // Longer cycle at the last pixel
		pix_div_cnt <= 0;

	ce_pix <= !pix_div_cnt;
end

wire lcd_off = !on || (mode == 2'd01);
reg old_lcd_off;
reg hb, vb;
always @(posedge clk_sys) begin

	if (ce_cpu) begin
		if(clkena) begin
			if (~lcd_off) begin
				vbuffer_inptr <= vbuffer_inptr + 1'd1;
			end
		end
	end

	if (!pix_div_cnt) begin
		// generate positive hsync signal
		if(h_cnt == H+HFP+HS) hs <= 0;
		if(h_cnt == H+HFP)    begin
			hs <= 1;

			// generate positive vsync signal
			if(v_cnt == VS_START)   vs <= 1;
			if(v_cnt == VS_START+3) vs <= 0;
		end

		// Hblank
		if(h_cnt == 0)        hb <= 0;
		if(h_cnt >= H)        hb <= 1;

		// Vblank
		if(v_cnt == VSTART)    vb <= 0;
		if(v_cnt >= VSTART+V)  vb <= 1;

	end

	if(ce_pix) begin

		h_cnt <= h_cnt + 1'd1;
		if(h_cnt == HTOTAL-1) begin
			h_cnt <= 0;
			if(~&v_cnt) v_cnt <= v_cnt + 1'd1;
			if( (double_buffer || lcd_off) && v_cnt >= VTOTAL-1) v_cnt <= 0;

			if(v_cnt == VSTART-1) begin
				vbuffer_outptr 	<= 0;
				// Read from write buffer if it is far enough ahead
				vbuffer_out_bank <= (vbuffer_inptr >= (160*60) || ~double_buffer) ? vbuffer_in_bank : ~vbuffer_in_bank;
			end
		end

		// visible area?
		if(~hb & ~vb) begin
			vbuffer_outptr <= vbuffer_outptr + 1'd1;
		end
	end

	old_lcd_off <= lcd_off;
	if(~old_lcd_off & lcd_off) begin  //lcd disabled or vsync restart pointer
		vbuffer_inptr <= 0;
		vbuffer_in_bank <= ~vbuffer_in_bank;
	end

	if (old_lcd_off & ~lcd_off & ~double_buffer & vb) begin // lcd enabled
		h_cnt <= 0;
		v_cnt <= 0;
		hs    <= 0;
		vs    <= 0;
	end
end

// -------------------------------------------------------------------------------
// ------------------------------- pixel generator -------------------------------
// -------------------------------------------------------------------------------
reg [14:0] pixel_reg;

always@(posedge clk_sys) begin
	reg hbl_r, vbl_r;
	if(ce_pix) begin
		// visible area?
		hbl_r <= hb;
		vbl_r <= vb;
		hbl <= hbl_r;
		vbl <= vbl_r;
		r <= (tint||isGBC) ? pal_r : grey;
		g <= (tint||isGBC) ? pal_g : grey;
		b <= (tint||isGBC) ? pal_b : grey;
	end
end

wire [14:0] pixel = on?isGBC?pixel_reg:
							  {13'd0,(pixel_reg[1:0] ^ {inv,inv})}: //invert gb only
							  15'd0;

							  
wire [4:0] r5 = pixel_reg[4:0];
wire [4:0] g5 = pixel_reg[9:5];
wire [4:0] b5 = pixel_reg[14:10];

wire [31:0] r10 = (r5 * 13) + (g5 * 2) +b5;
wire [31:0] g10 = (g5 * 3) + b5;
wire [31:0] b10 = (r5 * 3) + (g5 * 2) + (b5 * 11);

// gameboy "color" palette
wire [7:0] pal_r = //isGBC?{pixel_reg[4:0],3'd0}:
                   isGBC?r10[8:1]:
                   (pixel==0)?pal1[23:16]:
						 (pixel==1)?pal2[23:16]:
						 (pixel==2)?pal3[23:16]:
						 pal4[23:16];

wire [7:0] pal_g = //isGBC?{pixel_reg[9:5],3'd0}:
                   isGBC?{g10[6:0],1'b0}:
                   (pixel==0)?pal1[15:8]:
                   (pixel==1)?pal2[15:8]:
						 (pixel==2)?pal3[15:8]:
						 pal4[15:8];
						 
wire [7:0] pal_b = //isGBC?{pixel_reg[14:10],3'd0}:
                    isGBC?b10[8:1]:
						 (pixel==0)?pal1[7:0]:
                   (pixel==1)?pal2[7:0]:
						 (pixel==2)?pal3[7:0]:
						 pal4[7:0];

// greyscale
wire [7:0] grey = (pixel==0)?8'd252:(pixel==1)?8'd168:(pixel==2)?8'd96:8'd0;

endmodule
