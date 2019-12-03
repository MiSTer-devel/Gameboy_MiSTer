module link #(
  parameter CLK_DIV = 511
)(
  // system signals
  input clk,
  input rst,

  input sel_sc,
  input sel_sb,
  input cpu_wr_n,
  input sc_start_in,
  input sc_int_clock_in,

  input [7:0] sb_in,

  input serial_clk_in,
  input serial_data_in,

  output serial_clk_out,
  output serial_data_out,
  output [7:0] sb,
  output serial_irq,
  output reg sc_start,
  output reg sc_int_clock
);

assign sb = sb_r;

reg [3:0] serial_counter;

reg [7:0] sb_r = 0;

reg serial_out_r = 0;
assign serial_data_out = serial_out_r;

reg serial_clk_out_r = 1;
assign serial_clk_out = serial_clk_out_r;

assign serial_irq = serial_irq_r;
reg serial_irq_r;

reg [8:0] serial_clk_div; //8192Hz

reg [1:0]  serial_clk_in_last;

// serial master
always @(posedge clk) begin
	serial_irq_r <= 1'b0;
   if(rst) begin
		  sc_start <= 1'b0;
		  sc_int_clock <= 1'b0;
        sb_r <= sb_in;
        //serial_clk_in_last <= serial_clk_in;
		  serial_clk_in_last <= {1'b0,serial_clk_in};
	end else if (sel_sc && !cpu_wr_n) begin     //cpu write
		sc_start <= sc_start_in;
		sc_int_clock <= sc_int_clock_in;
		if (sc_start_in) begin                   //enable transfer
			serial_clk_div <= CLK_DIV[8:0];
			serial_counter <= 4'd8;
			serial_clk_out_r <= 1'b1;
         //serial_clk_in_last <= serial_clk_in;
			serial_clk_in_last <= {1'b0,serial_clk_in};
		end
	end else if (sel_sb && !cpu_wr_n) begin
		sb_r <= sb_in;
	end else if (sc_start) begin // serial transfer
      if (sc_int_clock) begin   // internal clock
         serial_clk_div <= serial_clk_div - 9'd1;

         if (serial_counter != 0) begin
            if (serial_clk_div == {1'b0,CLK_DIV[8:1]+1'd1}) begin
               serial_clk_out_r <= ~serial_clk_out_r;
               serial_out_r <= sb[7];
            end else if (!serial_clk_div) begin
               sb_r <= {sb[6:0], serial_data_in};
					serial_clk_out_r <= ~serial_clk_out;
               serial_counter <= serial_counter - 1'd1;
               serial_clk_div <= CLK_DIV[8:0];
            end
         end else begin
            serial_irq_r <= 1'b1;
            sc_start <= 1'b0;
            serial_clk_div <= CLK_DIV[8:0];
            serial_counter <= 4'd8;
         end
      end else begin  // external clock
            serial_clk_in_last[0] <= serial_clk_in;
            serial_clk_in_last[1] <=  serial_clk_in_last[0] ;
            if (serial_clk_in_last[1] != serial_clk_in_last[0]) begin
					if (serial_clk_in_last[1] == 0) begin
						serial_out_r <= sb[7];                 // send out bit to linked gb
						serial_counter <= serial_counter - 1'd1;
					end else begin                               // posedge external clock
					sb_r <= {sb[6:0], serial_data_in};        // capture bit into sb
					if (serial_counter == 0) begin            // read in 8 bits?
						serial_irq_r <= 1'b1;                  // set interrupt, reset counter/sc_start for next read
						sc_start <= 1'b0;
						serial_counter <= 4'd8;
					end
				end
         end
      end
   end
end

endmodule
// vim:sw=3:ts=3:et:
