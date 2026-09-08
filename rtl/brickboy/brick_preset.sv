// One explicitly mounted 512-byte BBP1 preset in virtual drive 1.
// No writes on mount. Only validated files may be explicitly overwritten.
module brick_preset #(parameter TIMEOUT_CYCLES = 335544320) (
 input wire clk, input wire mounted, input wire readonly,
 input wire [63:0] image_size,
 input wire save, input wire load, input wire [127:0] config_data,
 output reg loaded = 0, output reg [127:0] loaded_data = 0,
 output wire can_save, output wire busy, output reg error = 0,
 output reg sd_rd = 0, output reg sd_wr = 0,
 input wire sd_ack, input wire [7:0] buff_addr,
 input wire [15:0] buff_dout, input wire buff_wr,
 output reg [15:0] buff_din
);
localparam IDLE=0, READ=1, WRITE=2, DRAIN=3;
reg [1:0] state = IDLE;
reg available = 0, writable = 0, valid_file = 0;
reg old_mount = 0, old_ack = 0;
reg seen_ack = 0, malformed = 0;
reg [8:0] count = 0;
reg [15:0] sum = 0;
reg [127:0] rx = 0, tx = 0;
reg [31:0] watchdog = 0;
localparam [127:0] CONFIG_MASK = {2'b11,6'b0,24'h0fffff,24'h00ffff,24'h000fff,24'h7fffff,24'h03ffff};
assign busy = state != IDLE;
assign can_save = available && writable && valid_file && !busy;
integer i;
reg [15:0] tx_sum;
always @* begin
 tx_sum = 16'h4242 + 16'h3150 + 16'd1 + 16'd16;
 for(i=0;i<8;i=i+1) tx_sum = tx_sum + tx[i*16 +:16];
 case(buff_addr)
  0: buff_din = 16'h4242; // bytes "BBP1"
  1: buff_din = 16'h3150;
  2: buff_din = 16'd1;
  3: buff_din = 16'd16;
  12: buff_din = ~tx_sum;
  default: buff_din = (buff_addr>=4 && buff_addr<12) ? tx[(buff_addr-4)*16 +:16] : 16'd0;
 endcase
end
task start_read;
 begin
  state <= READ; sd_rd <= 1; sd_wr <= 0;
  count <= 0; sum <= 0; rx <= 0; malformed <= 0;
  seen_ack <= 0; watchdog <= 0; error <= 0;
 end
endtask
always @(posedge clk) begin
 loaded <= 0;
 old_mount <= mounted;
 old_ack <= sd_ack;
 if(mounted && !old_mount) begin
  available <= image_size == 512;
  writable <= !readonly;
  valid_file <= 0;
  sd_rd <= 0; sd_wr <= 0;
  // Abort remounts during an active transaction without applying partial data.
  if(state != IDLE || sd_ack) begin state <= DRAIN; error <= 1; end
  else if(image_size == 512) start_read();
  else begin state <= IDLE; error <= image_size != 0; end
 end else if(state == IDLE) begin
  if(load && available && !sd_ack) start_read();
  else if(save && can_save && !sd_ack) begin
   tx <= config_data & CONFIG_MASK;
   sd_wr <= 1; state <= WRITE;
   seen_ack <= 0; watchdog <= 0; error <= 0;
  end else if(save || load) error <= 1;
 end else if(state == DRAIN) begin
  // Fail closed. A fresh mount is required to recover after timeout/remount.
  if(!sd_ack) begin state <= IDLE; available <= 0; end
 end else begin
  watchdog <= watchdog + 1'b1;
  if(sd_ack) begin seen_ack <= 1; sd_rd <= 0; sd_wr <= 0; end
  if(state == READ && buff_wr && sd_ack) begin
   if(count >= 256 || buff_addr != count[7:0]) malformed <= 1;
   if(count < 256) count <= count + 1'b1;
   sum <= sum + buff_dout;
   case(buff_addr)
    0: if(buff_dout != 16'h4242) malformed <= 1;
    1: if(buff_dout != 16'h3150) malformed <= 1;
    2: if(buff_dout != 1) malformed <= 1;
    3: if(buff_dout != 16) malformed <= 1;
    default: begin
     if(buff_addr>=4 && buff_addr<12) rx[(buff_addr-4)*16 +:16] <= buff_dout;
     else if(buff_addr>12 && buff_dout!=0) malformed <= 1;
    end
   endcase
  end
  if(old_ack && !sd_ack && seen_ack) begin
   state <= IDLE;
   if(state == READ) begin
    if(count == 256 && !malformed && sum == 16'hffff && (rx & ~CONFIG_MASK) == 0) begin
     loaded_data <= rx; loaded <= 1; valid_file <= 1;
    end else begin error <= 1; valid_file <= 0; end
   end
  end else if(watchdog >= TIMEOUT_CYCLES-1) begin
   sd_rd <= 0; sd_wr <= 0; valid_file <= 0;
   state <= DRAIN; error <= 1;
  end
 end
end
endmodule
