module hdma(
	input  reset,
	input  clk,
	input  ce, // 4 or 8 Mhz cpu clock
	input  speed,  // cpu speed mode use for amount of byte cycles
	
	// cpu register interface
	input        sel_reg,
	input  [3:0] addr,
	input        wr,
	output [7:0] dout,
	input  [7:0] din,

	input  cpu_phi_r_ce,
	input  cpu_phi_f_ce,
	input  hdma_phi_r_ce, // 2MHz PHI
	input  hdma_phi_f_ce,

	input [1:0] lcd_mode, 
	
	// dma connection
	output hdma_rd,
	output [15:0] hdma_source_addr,
	output [15:0] hdma_target_addr,

	// savestates              
	input  [63:0] SaveStateBus_Din, 
	input  [9:0]  SaveStateBus_Adr, 
	input         SaveStateBus_wren,
	input         SaveStateBus_rst, 
	output [63:0] SaveStateBus_Dout
);

// savestates
wire [47:0] SS_HDMA;
wire [47:0] SS_HDMA_BACK;

eReg_SavestateV #(0, 7, 47, 0, 64'h000000000FFFFFF0) iREG_SAVESTATE_HDMA (clk, SaveStateBus_Din, SaveStateBus_Adr, SaveStateBus_wren, SaveStateBus_rst, SaveStateBus_Dout, SS_HDMA_BACK, SS_HDMA);

// ff51-ff55 HDMA1-5 (GBC)
reg [15:4] hdma_source;  // ff51, ff52 only top 4 bits used
reg [15:4] hdma_target;  // ff53, ff54 only top 4 bits used

reg        hdma_mode;    // ff55 bit 7 - 0 = General Purpose DMA / 1 = H-Blank DMA
reg        hdma_enabled; // ff55 !bit 7 when read
reg [7:0]  hdma_length;  // ff55 bit 6:0 - dma transfer length (hdma_length+1)*16 bytes

reg        hdma_active;
reg        hdma_run;
reg        hdma_trigger;
reg        hdma_init;

// it takes about 8us to transfer a block of 16 bytes. -> 500ns per byte -> 2Mhz
reg [3:0] byte_cnt;  // 16bytes

assign hdma_rd = hdma_active;
assign hdma_source_addr = { hdma_source, byte_cnt };
assign hdma_target_addr = { hdma_target, byte_cnt };

reg [1:0] hdma_state;
parameter active=2'd0,blocksent=2'd1,wait_h=2'd2;

assign SS_HDMA_BACK[    0] = hdma_active ;
assign SS_HDMA_BACK[ 2: 1] = hdma_state  ;
assign SS_HDMA_BACK[    3] = hdma_enabled;
assign SS_HDMA_BACK[15: 4] = hdma_source ;
assign SS_HDMA_BACK[27:16] = hdma_target;
assign SS_HDMA_BACK[   28] = hdma_run;
assign SS_HDMA_BACK[   29] = 1'b0;
assign SS_HDMA_BACK[   30] = hdma_mode   ;
assign SS_HDMA_BACK[38:31] = hdma_length ;
assign SS_HDMA_BACK[42:39] = byte_cnt    ;
assign SS_HDMA_BACK[44:43] = 2'd0;
assign SS_HDMA_BACK[   45] = hdma_trigger;
assign SS_HDMA_BACK[   46] = hdma_init;
assign SS_HDMA_BACK[   47] = 1'b0;


always @(posedge clk) begin
	if(reset) begin
		hdma_active  <= SS_HDMA[    0]; // 1'b0;
		hdma_state   <= SS_HDMA[ 2: 1]; // wait_h;
		hdma_enabled <= SS_HDMA[    3]; // 1'b0;
		hdma_source  <= SS_HDMA[15: 4]; // 12'hFFF;
		hdma_target  <= SS_HDMA[27:16]; // 12'hFFF;
		hdma_run     <= SS_HDMA[   28]; // 1'b0;
		hdma_mode    <= SS_HDMA[   30]; // 1'b0;
		hdma_length  <= SS_HDMA[38:31]; // 8'd0;
		byte_cnt     <= SS_HDMA[42:39]; // 4'd0;
		hdma_trigger <= SS_HDMA[   45]; // 1'b0;
		hdma_init    <= SS_HDMA[   46]; // 1'b0;
	end
	else begin

		if(ce & sel_reg & wr) begin
			case (addr)
				4'd1: hdma_source[15:8] <= din;
				4'd2: hdma_source[7:4]  <= din[7:4];
				4'd3: hdma_target[15:8] <= din;
				4'd4: hdma_target[7:4]  <= din[7:4];
			 
				// writing the hdma register engages the dma engine
				4'h5: begin
							hdma_length <= {1'b0,din[6:0]};
							if (hdma_mode == 1 && hdma_enabled && !din[7]) begin  //terminate a pending H-Blank transfer by writing zero to Bit 7 of FF55
								hdma_enabled <= 1'b0;
								hdma_trigger <= 1'b0;
							end else begin  //normal trigger
								hdma_enabled <= 1'b1;
								hdma_mode <= din[7];
								if (din[7] == 1) begin
									hdma_state <= wait_h;
								end else begin
									hdma_trigger <= 1'b1;
								end
							end
						end
			endcase
		end

		if (cpu_phi_r_ce) begin
			hdma_init <= hdma_trigger;
			hdma_active <= hdma_run;
		end

		if (cpu_phi_f_ce) begin
			if (hdma_init) begin
				hdma_trigger <= 1'b0;
				hdma_run <= 1'b1;
				byte_cnt <= 4'd0;
			end
		end

		if (hdma_phi_r_ce) begin
			if (hdma_active) begin
				byte_cnt <= byte_cnt + 1'b1;
				if (&byte_cnt) begin
					hdma_source <= hdma_source + 1'b1;
					hdma_target <= hdma_target + 1'b1;
					hdma_length <= hdma_length - 1'd1;
				end
			end
		end

		if (hdma_phi_f_ce) begin
			if (hdma_active) begin
				if (&byte_cnt) begin
					if (hdma_length == 0 || &hdma_target) begin
						hdma_run <= 1'b0;
						hdma_enabled <= 1'b0;
					end
					if (hdma_mode) begin
						hdma_state <= blocksent;
						hdma_run <= 1'b0;
					end
				end
			end
		end

		if (ce) begin
			if (hdma_mode) begin
				case (hdma_state)

					wait_h: begin
									if (lcd_mode == 2'b00 && hdma_enabled) begin // Mode 00:  h-blank
										hdma_state <= active;
										hdma_trigger <= 1'b1;
									end
							end

					blocksent: begin
									if (lcd_mode != 2'b00) // wait for end of Mode 0 
										hdma_state <= wait_h;
								end
				endcase
			end
		end

	end
end

assign dout = (sel_reg && addr==4'd5) ? {~hdma_enabled, hdma_length[6:0]} : 8'hFF;

endmodule

/*
`timescale 1 ns/100 ps  // time-unit = 1 ns, precision = 100 ps

module hdma_tb;

   // duration for each bit = 125 * timescale = 125 * 1 ns  = 125ns // 8MHz
   localparam period = 125;  

	reg  reset = 1'd1;
	reg  clk = 1'd0;
	reg speed = 1'b0;
	
	// cpu register interface
	reg        sel_reg = 1'd0;
	reg  [3:0] addr    = 4'd0;
	reg        wr      = 1'd0;
	wire [7:0] dout;
	reg  [7:0] din     = 8'd0;
	
	reg [1:0] lcd_mode = 2'd0; 
	
	// dma connection
	wire hdma_rd;
	wire hdma_active;
	wire [15:0] hdma_source_addr;
	wire [15:0] hdma_target_addr;
	
	
	
	hdma hdma(
		.reset	          ( reset         ),
		.clk		          ( clk           ),
		.speed				 ( speed         ),
 		 
		// cpu register interface
		.sel_reg 	       ( sel_reg       ),
		.addr			       ( addr          ),
		.wr			       ( wr	           ),
		.dout			       ( dout       ),
		.din               ( din           ),
		
		.lcd_mode          ( lcd_mode      ),
		
		// dma connection
		.hdma_rd           ( hdma_rd          ),
		.hdma_active       ( hdma_active      ),
		.hdma_source_addr  ( hdma_source_addr ),
		.hdma_target_addr  ( hdma_target_addr ) 
		
	);
	
	always #62 clk <= !clk;
	initial begin
		reset <= 1'b0;
		sel_reg <= 1'b1;
		addr <= 4'd4;
		
		#1000 
		
		sel_reg <= 1'b1;
		addr <= 4'd1; // source h
		din <= 8'h20;
		wr <= 1'd1;
		
		#period  
		 wr <= 1'd0;	
		
		#period
	
		sel_reg <= 1'b1;
		addr <= 4'd2; // source l
		din <= 8'h40;
		wr <= 1'd1;
		
		#period
		wr <= 1'd0;	
		
		#period
	
		sel_reg <= 1'b1;
		addr <= 4'd3; // target h
		din <= 8'h82;
		wr <= 1'd1;
		#period
		wr <= 1'd0;	
		
		#period 
	
		sel_reg <= 1'b1;
		addr <= 4'd4; // target l
		din <= 8'h00;
		wr <= 1'd1;
		
		#period
		wr <= 1'd0;	
		
		#period
		$display("GDMA");
		sel_reg <= 1'b1;
		addr <= 4'd5; // trigger GDMA with length 
		din <= 8'h01;  // 20h bytes
		wr <= 1'd1;
		#period
		wr <= 1'd0;	
		
		#8000	
		
		lcd_mode <= 2'd1; 
		#2000
		
		lcd_mode <= 2'd0; 
		#8000
		
		$display("HDMA");
		sel_reg <= 1'b1;
		addr <= 4'd5; // trigger HDMA with length 
		din <= 8'h82;  // 30h bytes
		wr <= 1'd1;
		
		#period
		wr <= 1'd0;	
		
		#16000	
		
		lcd_mode <= 2'd2; 
		#2000
		
		lcd_mode <= 2'd3; 
		#2000
		
		lcd_mode <= 2'd0; 
		#16000

		lcd_mode <= 2'd2; 
		#2000
		
		lcd_mode <= 2'd3; 
		#2000
		
		lcd_mode <= 2'd0; 
		#16000
		
		sel_reg <= 1'b1;
		addr <= 4'd5;
		$display("Check FF55");
				
		#1000 

		$display("HDMA with cancel");
		sel_reg <= 1'b1;
		addr <= 4'd5; // trigger HDMA with length 
		din <= 8'h82;  // 30h bytes
		wr <= 1'd1;
		
		#period
		wr <= 1'd0;
		
		#16000	
		
		lcd_mode <= 2'd2; 
		#2000
		
		lcd_mode <= 2'd3; 
		#2000
		
      $display("canceling");
		sel_reg <= 1'b1;
		addr <= 4'd5; // trigger HDMA with length 
		din <= 8'h00;  // stop
		wr <= 1'd1;
		
		#period
		wr <= 1'd0;	
		
		#16000	
		
		sel_reg <= 1'b1;
		addr <= 4'd5;
		$display("Check FF55");
		
		lcd_mode <= 2'd2; 
		#2000
		
		lcd_mode <= 2'd3; 
		#2000
		$display("Test Complete");
	end  
  
endmodule
*/
