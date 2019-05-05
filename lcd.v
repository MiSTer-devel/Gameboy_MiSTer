// Gameboy for the MiST
// (c) 2015 Till Harbaum

// The gameboy lcd runs from a shift register which is filled at 4194304 pixels/sec

module lcd #(
   parameter HPRE=0,
   parameter HPOST=0,
   parameter VPRE=0,
   parameter VPOST=0
)
(
	// pixel clock
   input        pclk,
   input        pce,

	input        clk,
	input        clkena,
	input [14:0] data,
	input [1:0]  mode,
	input        on,

	//palette
	input [23:0] pal1,
	input [23:0] pal2,
	input [23:0] pal3,
	input [23:0] pal4,

	input tint,
	input inv,
	input isGBC,

   // video output
   output reg	hs,
   output reg	vs,
   output reg	blank,
   output [7:0] r,
   output [7:0] g,
   output [7:0] b
);

reg [14:0] vbuffer_inptr;

reg [14:0] vbuffer_outptr;
reg [14:0] vbuffer_lineptr;

dpram #(15,15) vbuffer (
	.clock_a (clk),
	.address_a (vbuffer_inptr),
	.wren_a (clkena),
	.data_a (data),
	.q_a (),
	
	.clock_b (pclk),
	.address_b (vbuffer_outptr),
	.wren_b (1'b0), //only reads
	.data_b (),
	.q_b (pixel_reg)
);

always @(posedge clk) begin
	if(!on || (mode==2'd01)) begin  //lcd disabled or vsync restart pointer
	   vbuffer_inptr <= 15'h0;
	end else begin
		if(clkena) vbuffer_inptr <= vbuffer_inptr + 15'd1; // end of vsync
	end
end

parameter H     = 160;    // width of visible area
parameter HFP   = 8;     // unused time before hsync
parameter HS    = 32;     // width of hsync
parameter HBP   = 24;     // unused time after hsync

parameter V     = 144;    // height of visible area
parameter VFP   = 4;      // unused time before vsync
parameter VS    = 3;      // width of vsync
parameter VBP   = 16;     // unused time after vsync

reg[8:0] h_cnt;         // horizontal pixel counter
reg[8:0] v_cnt;         // vertical pixel counter

// horizontal pixel counter
always@(posedge pclk) begin
	if(pce) begin
		if(h_cnt==HPRE+H+HPOST+HFP+HS+HBP-1)   h_cnt <= 0;
		else                                   h_cnt <= h_cnt + 1'd1;
		// generate positive hsync signal
		if(h_cnt == HPRE+H+HPOST+HFP)    hs <= 1'b1;
		if(h_cnt == HPRE+H+HPOST+HFP+HS) hs <= 1'b0;
	end
end

// vertical pixel counter
always@(posedge pclk) begin
	if(pce) begin
		// the vertical counter is processed at the begin of each hsync
		if(h_cnt == HPRE+H+HPOST+HFP+HS+HBP-1) begin
			if(v_cnt==VPRE+V+VPOST+VFP+VS+VBP-1)	v_cnt <= 0;
			else												v_cnt <= v_cnt + 1'd1;
			// generate positive vsync signal
			if(v_cnt == VPRE+V+VPOST+VFP)    vs <= 1'b1;
			if(v_cnt == VPRE+V+VPOST+VFP+VS) vs <= 1'b0;
		end
	end
end

// -------------------------------------------------------------------------------
// ------------------------------- pixel generator -------------------------------
// -------------------------------------------------------------------------------
reg [14:0] pixel_reg;

always@(posedge pclk) begin
	if(pce) begin
		// visible area?
		if((v_cnt < VPRE+V+VPOST) && (h_cnt < HPRE+H+HPOST)) begin
			blank <= 1'b0;
		end else begin
			blank <= 1'b1;
		end
	end
end

reg [8:0] currentpixel;
always@(posedge pclk) begin
	if(pce) begin
      // visible area?
      if((v_cnt >= VPRE) && (v_cnt < (VPRE + V))) begin
         // visible pixel?
         if ((h_cnt >= HPRE) && (h_cnt < (HPRE + H))) begin
            currentpixel   <= currentpixel + 9'd1;
         end else begin
            // move to the next line after visible area
            if(h_cnt == HPRE+H+HPOST+HFP) begin
               vbuffer_lineptr <= vbuffer_lineptr + H;
               currentpixel    <= 9'd0;
            end
         end
         vbuffer_outptr <= vbuffer_lineptr + currentpixel;
      // not visible area, reset pointers
      end else begin
         vbuffer_outptr 	<= 15'd0;
         vbuffer_lineptr	<= 15'd0;
         currentpixel <=	9'd0;
      end
	end
end

wire [14:0] pixel = on?isGBC?pixel_reg:
							  {13'd0,(pixel_reg[1:0] ^ {inv,inv})}: //invert gb only
							  15'd0;

wire [4:0] r5 = pixel_reg[4:0];
wire [4:0] g5 = pixel_reg[9:5];
wire [4:0] b5 = pixel_reg[14:10];

wire [31:0] r10 = (r5 * 13) + (g5 * 2) + b5;
wire [31:0] g10 = (g5 *  3) + b5;
wire [31:0] b10 = (r5 *  3) + (g5 * 2) + (b5 * 11);

wire prepost = (v_cnt < VPRE) || (v_cnt >= VPRE+V) || (h_cnt < HPRE) || (h_cnt >= HPRE+H);

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

assign r = blank||prepost?8'd0:tint||isGBC?pal_r:grey;
assign g = blank||prepost?8'd0:tint||isGBC?pal_g:grey;
assign b = blank||prepost?8'd0:tint||isGBC?pal_b:grey;

endmodule
