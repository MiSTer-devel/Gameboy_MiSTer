// Gameboy for the MiST
// (c) 2015 Till Harbaum

// The gameboy lcd runs from a shift register which is filled at 4194304 pixels/sec

module lcd (
	input   clk,
	input   clkena,
	input [1:0] data,
	input [1:0] mode,
	
	//palette
	input [23:0] pal1,
	input [23:0] pal2,
	input [23:0] pal3,
	input [23:0] pal4,

	input tint,
	input inv,

	// pixel clock
   input  pclk,
   input  pce,
	input  on,
	
   // VGA output
   output reg	hs,
   output reg 	vs,
   output reg 	blank,
   output [7:0] r,
   output [7:0] g,
   output [7:0] b
);

// Mode 00:  h-blank
// Mode 01:  v-blank
// Mode 10:  oam
// Mode 11:  oam and vram

// space for 2*160 pixel
reg [7:0] shift_reg_wptr;
reg p_toggle;
reg [1:0] shift_reg [511:0];
reg [1:0] last_mode_in;

// shift register input
always @(posedge clk) begin
	last_mode_in <= mode;

	// end of vsync
	if(clkena) begin
		shift_reg[{p_toggle, shift_reg_wptr}] <= data;
		shift_reg_wptr <= shift_reg_wptr + 8'd1;
	end
	
	// reset write pointer at end of hsync phase
	if((mode != 2'b00) && (last_mode_in == 2'b00)) begin
		shift_reg_wptr <= 8'd0;
		p_toggle <= !p_toggle;
	end
end
		
// 
parameter H   = 160;    // width of visible area
parameter HFP = 16;     // unused time before hsync
parameter HS  = 20;     // width of hsync
parameter HBP = 32;     // unused time after hsync
// total = 228

parameter V   = 576;    // height of visible area
parameter VFP = 2;      // unused time before vsync
parameter VS  = 2;      // width of vsync
parameter VBP = 36;     // unused time after vsync
// total = 616

reg[7:0] h_cnt;         // horizontal pixel counter
reg[9:0] v_cnt;         // vertical pixel counter

// horizontal pixel counter
reg [1:0] last_mode_h;
always@(posedge pclk) begin
	if(pce) begin
		last_mode_h <= mode;
		
		if(h_cnt==H+HFP+HS+HBP-1)   h_cnt <= 0;
		else                        h_cnt <= h_cnt + 1'd1;

		// generate positive hsync signal
		if(h_cnt == H+HFP)    hs <= 1'b1;
		if(h_cnt == H+HFP+HS) hs <= 1'b0;

		// synchronize to input mode
		// end of hblank
		if((mode == 2'b10) && (last_mode_h == 2'b00))
			h_cnt <= 0;
	end
end

// veritical pixel counter
reg [1:0] last_mode_v;
always@(posedge pclk) begin
	if(pce) begin
		// the vertical counter is processed at the begin of each hsync
		if(h_cnt == H+HFP+HS+HBP-1) begin
			if(v_cnt==VS+VFP+V+VBP-1)  v_cnt <= 0; 
			else							   v_cnt <= v_cnt + 1'd1;

			// generate positive vsync signal
			if(v_cnt == V+VFP)    vs <= 1'b1;
			if(v_cnt == V+VFP+VS) vs <= 1'b0;

			last_mode_v <= mode;

			// synchronize to input mode
			// end of mode 01 (vblank)
			// make and offset of - 4 for the 4 line delay of the scandoubler
			if((mode != 2'b01) && (last_mode_v == 2'b01))
				v_cnt <= 10'd616 - 10'd4;
		end
	end
end

// -------------------------------------------------------------------------------
// ------------------------------- pixel generator -------------------------------
// -------------------------------------------------------------------------------
reg [1:0] pixel_reg;
reg [7:0] shift_reg_rptr;

always@(posedge pclk) begin
	if(pce) begin
		// visible area?
		if((v_cnt < V) && (h_cnt < H)) begin
			blank <= 1'b0;
			pixel_reg <= shift_reg[{!p_toggle, shift_reg_rptr}];
			shift_reg_rptr <= shift_reg_rptr + 8'd1;
		end else begin
			blank <= 1'b1;
			shift_reg_rptr <= 8'd0;
		end
	end
end

wire [1:0] pixel = on? (pixel_reg ^ {inv,inv}) :2'b00;

// gameboy "color" palette
wire [7:0] pal_r = (pixel==0)?pal1[23:16]:(pixel==1)?pal2[23:16]:
	(pixel==2)?pal3[23:16]:pal4[23:16];
wire [7:0] pal_g = (pixel==0)?pal1[15:8] :(pixel==1)?pal2[15:8] :
	(pixel==2)?pal3[15:8] :pal4[15:8] ;
wire [7:0] pal_b = (pixel==0)?pal1[7:0]  :(pixel==1)?pal2[7:0]  :
	(pixel==2)?pal3[7:0]  :pal4[7:0]  ;

// greyscale
wire [7:0] grey = (pixel==0)?8'd252:(pixel==1)?8'd168:(pixel==2)?8'd96:8'd0;
assign r = blank?8'b00000000:tint?pal_r:grey;
assign g = blank?8'b00000000:tint?pal_g:grey;
assign b = blank?8'b00000000:tint?pal_b:grey;

endmodule
