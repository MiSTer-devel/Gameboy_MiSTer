// Gameboy for the MiST
// (c) 2015 Till Harbaum

// The gameboy lcd runs from a shift register which is filled at 4194304 pixels/sec

module lcd
(
	input        clk_sys,
	input        ce,
	input        ce2,
   
	input        core1_lcd_clkena,
	input [14:0] core1_data,
	input  [1:0] core1_mode,
   input        core1_on,
   input        core1_lcd_vs,
   
   input        core2_lcd_clkena,
	input [14:0] core2_data,
	input  [1:0] core2_mode,
   input        core2_on,
   input        core2_lcd_vs,
   
	input        isGBC,
	input        double_buffer,
   input        seperatorLine,
   
   output       pauseVideoCore1,
   output       pauseVideoCore2,

	//palette
	input [23:0] pal1,
	input [23:0] pal2,
	input [23:0] pal3,
	input [23:0] pal4,

	input        tint,
	input        inv,
	input        originalcolors,

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
	output reg [7:0] b,
	output           h_end
);

reg lcd_off1;
reg [14:0] vbuffer_inptr1;
reg blank_de1, blank_output1;
reg [14:0] blank_data1;
wire pix_wr1 = ce & (core1_lcd_clkena | blank_de1);
reg [7:0] hpos1;
always @(posedge clk_sys) begin
	reg old_lcd_off, old_on, old_lcd_vs;
	reg [8:0] blank_hcnt,blank_vcnt;

	lcd_off1 <= !core1_on || (core1_mode == 2'd01);
	blank_de1 <= (!core1_on && blank_output1 && blank_hcnt < 160 && blank_vcnt < 144);

   if (pix_wr1) begin 
      vbuffer_inptr1 <= vbuffer_inptr1 + 1'd1;
      if (hpos1 < 159) begin
         hpos1 <= hpos1 + 1'd1;
      end else begin
         hpos1 <= 0;
      end
   end

	old_lcd_off <= lcd_off1;
	if(old_lcd_off ^ lcd_off1) begin
		vbuffer_inptr1 <= 0;
      hpos1          <= 0;
	end

	old_on <= core1_on;
	if (old_on & ~core1_on & ~blank_output1) begin // LCD disabled, start blank output
		blank_output1 <= 1'b1;
		{blank_hcnt,blank_vcnt} <= 0;
	end

	// Regenerate LCD timings for filling with blank color when LCD is off
	if (ce & ~core1_on & blank_output1) begin
		blank_data1 <= core1_data;
		blank_hcnt <= blank_hcnt + 1'b1;
      hpos1      <= hpos1 + 1'd1;
		if (blank_hcnt == 9'd455) begin
			blank_hcnt <= 0;
         hpos1      <= 0;
			blank_vcnt <= blank_vcnt + 1'b1;
			if (blank_vcnt == 9'd153) begin
				blank_vcnt <= 0;
				vbuffer_inptr1 <= 0;
			end
		end
	end

	// Output 1 blank frame until VSync after LCD is enabled
	old_lcd_vs <= core1_lcd_vs;
	if (~old_lcd_vs & core1_lcd_vs & blank_output1)
		blank_output1 <= 0;
end
reg [14:0] vbuffer1[160*144];
always @(posedge clk_sys) if(pix_wr1) vbuffer1[vbuffer_inptr1] <= (hpos1 == 8'd159 && seperatorLine) ? 15'd0 : (core1_on & blank_output1) ? blank_data1 : core1_data;



reg lcd_off2;
reg [14:0] vbuffer_inptr2;
reg blank_de2, blank_output2;
reg [14:0] blank_data2;
wire pix_wr2 = ce2 & (core2_lcd_clkena | blank_de2);
reg [7:0] hpos2;
always @(posedge clk_sys) begin
	reg old_lcd_off, old_on, old_lcd_vs;
	reg [8:0] blank_hcnt,blank_vcnt;

	lcd_off2 <= !core2_on || (core2_mode == 2'd01);
	blank_de2 <= (!core2_on && blank_output2 && blank_hcnt < 160 && blank_vcnt < 144);

	if (pix_wr2) begin 
      vbuffer_inptr2 <= vbuffer_inptr2 + 1'd1;
      if (hpos2 < 159) begin
         hpos2 <= hpos2 + 1'd1;
      end else begin
         hpos2 <= 0;
      end
   end

	old_lcd_off <= lcd_off2;
	if(old_lcd_off ^ lcd_off2) begin
		vbuffer_inptr2 <= 0;
      hpos2          <= 0;
	end

	old_on <= core2_on;
	if (old_on & ~core2_on & ~blank_output2) begin // LCD disabled, start blank output
		blank_output2 <= 1'b1;
		{blank_hcnt,blank_vcnt} <= 0;
	end

	// Regenerate LCD timings for filling with blank color when LCD is off
	if (ce2 & ~core2_on & blank_output2) begin
		blank_data2 <= core2_data;
		blank_hcnt <= blank_hcnt + 1'b1;
      hpos2      <= hpos2 + 1'd1;
		if (blank_hcnt == 9'd455) begin
			blank_hcnt <= 0;
         hpos2      <= 0;
			blank_vcnt <= blank_vcnt + 1'b1;
			if (blank_vcnt == 9'd153) begin
				blank_vcnt <= 0;
				vbuffer_inptr2 <= 0;
			end
		end
	end

	// Output 1 blank frame until VSync after LCD is enabled
	old_lcd_vs <= core2_lcd_vs;
	if (~old_lcd_vs & core2_lcd_vs & blank_output2)
		blank_output2 <= 0;
end
reg [14:0] vbuffer2[160*144];
always @(posedge clk_sys) if(pix_wr2) vbuffer2[vbuffer_inptr2] <= (hpos2 == 8'd0 && seperatorLine) ? 15'd0 : (core2_on & blank_output2) ? blank_data2 : core2_data;


// Mode 00:  h-blank
// Mode 01:  v-blank
// Mode 10:  oam
// Mode 11:  oam and vram	

// Narrow
parameter H      = 9'd320;   // width of visible area
parameter HFP    = 9'd23;    // unused time before hsync
parameter HS     = 9'd32;    // width of hsync
parameter HBP    = 9'd50;    // unused time after hsync
parameter HTOTAL = H+HFP+HS+HBP;
// total = 425

parameter V_BORDER = 9'd40;
parameter H_START  = 9'd9;

parameter V        = 144; // height of visible area
parameter VS_START = 37;  // start of vsync
parameter VSTART   = 105; // start of active video
parameter VTOTAL   = 264;

wire [8:0] h_total  = HTOTAL;
wire [8:0] hs_start = (H_START+H+HFP);
wire [8:0] hs_end   = (H_START+H+HFP+HS);
assign     h_end    = (h_cnt == h_total-1);

// (67108864 / 32 / 228 / 154) == (67108864 / 10 /  425.6 / 264) == 59.7275Hz
// We need 4256 cycles per line so 1 pixel clock cycle needs to be 6 cycles longer.
// Narrow: 424x10 + 1x16 cycles
// Wide:   352x12 + 2x16 cycles
reg [3:0] pix_div_cnt;
reg ce_pix_n;
always @(posedge clk_vid) begin
	pix_div_cnt <= pix_div_cnt + 1'd1;
	// Longer cycle at the last pixel(s)
	if (~h_end && pix_div_cnt == 4'd9)
		pix_div_cnt <= 0;

	ce_pix <= !pix_div_cnt;
	ce_pix_n <= (pix_div_cnt == 4'd5);
end

reg [14:0] vbuffer_outptr1;
reg [14:0] vbuffer_outptr2;
reg bufferselect;

reg [7:0] pauseCnt1;
reg [7:0] pauseCnt2;

reg vb, gb_hb, gb_vb, wait_vbl;
always @(posedge clk_vid) begin
	reg old_lcd_off;
	reg old_on;

	if (ce_pix_n) begin
		// generate positive hsync signal
		if(h_cnt == hs_end)
			hs <= 0;
		if(h_cnt == hs_start) begin
			hs <= 1;

			// generate positive vsync signal
			if(v_cnt == VS_START)   vs <= 1;
			if(v_cnt == VS_START+3) vs <= 0;
		end

		// Hblank
		if(h_cnt == H_START)        gb_hb <= 0;
		if(h_cnt == H_START+H)      gb_hb <= 1;

		// Vblank
		if(v_cnt == VSTART)    gb_vb <= 0;
		if(v_cnt == VSTART+V)  gb_vb <= 1;

		if(v_cnt == VSTART-V_BORDER)            vb <= 0;
		if(v_cnt == VSTART+V_BORDER+V-VTOTAL)   vb <= 1;
	end

	if(ce_pix) begin

		h_cnt <= h_cnt + 1'd1;
		if(h_end) begin
			h_cnt <= 0;
			if(~(vb & wait_vbl) | double_buffer) v_cnt <= v_cnt + 1'd1;
			if(v_cnt >= VTOTAL-1) v_cnt <= 0;

			if(v_cnt == VSTART-1) begin
				vbuffer_outptr1 	<= 0;
				vbuffer_outptr2 	<= 0;
			end
		end
      
      if(h_cnt == 0            ) bufferselect <= 1'b0;
      if(h_cnt == H_START + 159) bufferselect <= 1'b1;

		// visible area?
		if(~gb_hb & ~gb_vb) begin
         if (h_cnt < H_START + 160)
            vbuffer_outptr1 <= vbuffer_outptr1 + 1'd1;
         else
            vbuffer_outptr2 <= vbuffer_outptr2 + 1'd1;
		end
	end

	old_lcd_off <= lcd_off1;
	old_on <= core1_on;
	if (~double_buffer) begin
		// Lcd turned on. Wait in vblank for output reset.
		if (~old_on & core1_on & ~vb) wait_vbl <= 1'b1; // lcd enabled

		if (old_lcd_off & ~lcd_off1 & vb) begin // lcd enabled or out of vblank
			wait_vbl <= 0;
			h_cnt <= 0;
			v_cnt <= 0;
			hs    <= 0;
			vs    <= 0;
		end
	end
   
   // 11521 -> line 72, 4801 -> line 30
   if ((vbuffer_outptr1 == 11521) && (vbuffer_inptr1 > 4801)) begin
      pauseCnt1 <= 8'd255;
   end else if(pauseCnt1 > 0) begin
      pauseCnt1 <= pauseCnt1 - 1'd1;
   end
   
   if ((vbuffer_outptr2 == 11521) && (vbuffer_inptr2 > 4801)) begin
      pauseCnt2 <= 8'd255;
   end else if(pauseCnt2 > 0) begin
      pauseCnt2 <= pauseCnt2 - 1'd1;
   end
   
end

assign pauseVideoCore1 = (pauseCnt1 > 0) ? 1'b1 : 1'b0;
assign pauseVideoCore2 = (pauseCnt2 > 0) ? 1'b1 : 1'b0;

// -------------------------------------------------------------------------------
// ------------------------------- pixel generator -------------------------------
// -------------------------------------------------------------------------------
reg [14:0] pixel_reg1;
reg [14:0] pixel_reg2;
always @(posedge clk_vid) begin
   pixel_reg1 <= vbuffer1[vbuffer_outptr1];
   pixel_reg2 <= vbuffer2[vbuffer_outptr2];
end

// Current pixel_reg latched at ce_pix_n so it is ready at ce_pix
reg [14:0] pixel_out;
always@(posedge clk_vid) begin
	if (ce_pix_n) pixel_out <= (bufferselect) ? pixel_reg2 : pixel_reg1;
end

wire [1:0] pixel = (pixel_out[1:0] ^ {inv,inv}); //invert gb only

wire  [4:0] r5 = pixel_out[4:0];
wire  [4:0] g5 = pixel_out[9:5];
wire  [4:0] b5 = pixel_out[14:10];

wire [31:0] r10 = (r5 * 13) + (g5 * 2) +b5;
wire [31:0] g10 = (g5 * 3) + b5;
wire [31:0] b10 = (r5 * 3) + (g5 * 2) + (b5 * 11);

// greyscale
wire [7:0] grey = (pixel==0) ? 8'd252 : (pixel==1) ? 8'd168 : (pixel==2) ? 8'd96 : 8'd0;

function [7:0] blend;
	input [7:0] a,b;
	reg [8:0] sum;
	begin
		sum = a + b;
		blend = sum[8:1];
	end
endfunction

reg [7:0] r_tmp, g_tmp, b_tmp;
always@(*) begin
	if (isGBC & !originalcolors) begin
		r_tmp = r10[8:1];
		g_tmp = {g10[6:0],1'b0};
		b_tmp = b10[8:1];
	end else if (isGBC & originalcolors) begin
		r_tmp = {r5,r5[4:2]};
		g_tmp = {g5,g5[4:2]};
		b_tmp = {b5,b5[4:2]};
	end else if (tint) begin
		{r_tmp,g_tmp,b_tmp} = (pixel==0) ? pal1 : (pixel==1) ? pal2 : (pixel==2) ? pal3 : pal4;
	end else begin
		{r_tmp,g_tmp,b_tmp} = {3{grey}};
	end
end

reg [7:0] r_cur, g_cur, b_cur;
reg hbl_l, vbl_l;
reg border_en;
always@(posedge clk_vid) begin

	if (ce_pix)
		{r_cur, g_cur, b_cur} <= {r_tmp, g_tmp, b_tmp};

	if (ce_pix) begin
		// visible area?
		hbl_l <= gb_hb;
		vbl_l <= gb_vb;
		hbl <= hbl_l;
		vbl <= vbl_l;

		{r,g,b} <= {r_cur, g_cur, b_cur};
	end

end

endmodule
