module hdma(
	input  reset,
   input  clk,    // 4 Mhz cpu clock
	
	// cpu register interface
	input        sel_reg,
	input  [3:0] addr,
	input        wr,
	output [7:0] dout,
	input  [7:0] din,
	
	input [1:0] lcd_mode, 
	
	// dma connection
	output hdma_rd,
	output [15:0] hdma_source_addr,
	output [15:0] hdma_target_addr

);

//ff51-ff55 HDMA1-5 (GBC)
reg [7:0] hdma_source_h;		// ff51
reg [3:0] hdma_source_l;		// ff52 only top 4 bits used
reg [4:0] hdma_target_h;	   // ff53 only lowest 5 bits used
reg [3:0] hdma_target_l;	   // ff54 only top 4 bits used
reg hdma_mode; 					// ff55 bit 7  - 1=General Purpose DMA 0=H-Blank DMA
reg hdma_enabled;					// ff55 !bit 7 when read
reg [6:0] hdma_length;			// ff55 bit 6:0 - dma transfer length (hdma_length+1)*16 bytes

assign dout = hdma_do;
assign hdma_rd = hdma_active;
assign hdma_source_addr = { hdma_source_h,hdma_source_l,4'd0} + hdma_cnt[12:1];
assign hdma_target_addr = { 3'd0,hdma_target_h,hdma_target_l,4'd0} + hdma_cnt[12:1];

reg hdma_active;

// it takes about 8us to transfer a block of 16 bytes. -> 500ns per byte -> 2Mhz
// 32 cycles in Normal Speed Mode, and 64 'fast' cycles in Double Speed Mode
reg [12:0] hdma_cnt; 
reg [4:0]  hdma_16byte_cnt; //16bytes*2

reg hdma_state;
parameter active=1'b0,wait_h=1'b1;


always @(posedge clk) begin
	if(reset) begin
		hdma_active <= 1'b0;
		hdma_state <= wait_h;
		hdma_enabled <= 1'b0;
	end else begin
		
		// writing the hdma register engages the dma engine
		if(wr && (addr == 4'h5)) begin
			if (hdma_mode == 1 && hdma_enabled && !din[7]) begin  //terminate an active H-Blank transfer by writing zero to Bit 7 of FF55
				hdma_state <= wait_h;
				hdma_active <= 1'b0;
				hdma_enabled <= 1'b0;
			end else begin															  //normal trigger
				hdma_enabled <= 1'b1;
				hdma_mode <= din[7];
				hdma_length <= din[6:0];  
				hdma_cnt <= 12'd0;
				hdma_16byte_cnt <= 5'h1f;
				if (din[7] == 1) hdma_state <= wait_h;
			end
		end
		
		if (hdma_enabled) begin
			if(hdma_mode==0) begin 				                    //mode 0 GDMA do the transfer in one go			
				if(hdma_cnt != (((hdma_length+1)*16)-1)*2) begin
					hdma_active <= 1'b1;
					hdma_cnt <= hdma_cnt + 1'd1;
					hdma_16byte_cnt <= hdma_16byte_cnt - 1'd1;
					if (!hdma_16byte_cnt)
							hdma_length <= hdma_length - 1'd1;
				end else begin
					hdma_active <= 1'b0;
					hdma_enabled <= 1'b0;
				end
			end else begin        			                       //mode 1 HDMA transfer 1 block (16bytes) in each H-Blank only
				case (hdma_state)
					
					wait_h:begin 
								if (lcd_mode == 2'b00 ) 	// Mode 00:  h-blank
									hdma_state <= active;
								hdma_16byte_cnt <= 5'h1f;
							 end
					
					active:begin
								if(hdma_cnt != (((hdma_length+1)*16)-1)*2) begin
									hdma_active <= 1'b1;
									hdma_cnt <= hdma_cnt + 1'd1;
									hdma_16byte_cnt <= hdma_16byte_cnt - 1'd1;
									if (!hdma_16byte_cnt) begin
											hdma_length <= hdma_length - 1'd1;
											hdma_state <= wait_h;
									end
								end else begin
									hdma_active <= 1'b0;
									hdma_enabled <= 1'b0;
								end
							 end
				endcase 	
			end
		end
	end
end

always @(posedge clk) begin
	if(reset) begin
		hdma_source_h <= 8'hFF;
		hdma_source_l <= 4'hF;
		hdma_target_h <= 5'h1F;
		hdma_target_l <= 4'hF;	
	end else if(sel_reg && wr) begin
		
		case (addr)
			4'd1: hdma_source_h <= din;
			4'd2: hdma_source_l <= din[7:4];
			4'd3: hdma_target_h <= din[4:0];
			4'd4: hdma_target_l <= din[7:4];
		endcase
	end
end


wire [7:0] hdma_do = sel_reg?
								(addr==4'd1)?hdma_source_h:
								(addr==4'd2)?{hdma_source_l,4'd0}:
								(addr==4'd3)?{3'd0,hdma_target_h}:
								(addr==4'd4)?{hdma_target_l,4'd0}:
								(addr==4'd5 && hdma_enabled)?{1'b0,hdma_length}:
								8'hFF:
							8'hFF;

endmodule