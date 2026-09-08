// Bank selector (82:80) is transferred AFTER the whole window (79:56).
// Keep this ordering: it prevents an old window being written to a new bank.
module brick_settings(
 input wire clk, input wire [127:0] status, input wire native_update,
 input wire preset_loaded, input wire [127:0] preset_data,
 output wire [127:0] config_data, output wire [127:0] status_out,
 output reg status_set = 0, output reg save_preset = 0,
 output reg load_preset = 0, output wire editor_busy
);
reg [119:0] banks = 0;
reg [2:0] active_bank = 0;
reg [3:0] previous_actions = 0;
wire [3:0] press = status[127:124] & ~previous_actions;
wire [2:0] bank = status[82:80] < 5 ? status[82:80] : 3'd0;
reg [127:0] rng = 128'h627269636b626f795f6d69737465725f;
wire feedback = rng[127] ^ rng[125] ^ rng[100] ^ rng[98];
localparam [119:0] MASK = {24'h0fffff,24'h00ffff,24'h000fff,24'h7fffff,24'h03ffff};
reg [127:51] reply = 0;
reg pending = 0, notify = 0, old_native = 0;
assign editor_busy = pending | notify | status_set;
assign config_data = {status[52:51],6'b0,banks};
// Never replay stale native settings during a pending editor response.
assign status_out = {(pending || notify || status_set) ? reply : status[127:51],status[50:0]};
task request_window(input [119:0] values, input [2:0] selected,
                    input panel, input speaker);
 begin
  reply <= 0;
  reply[51] <= panel; reply[52] <= speaker;
  reply[79:56] <= values[selected*24 +:24];
  reply[82:80] <= selected;
  pending <= 1; notify <= 1;
 end
endtask
always @(posedge clk) begin
 rng <= {rng[126:0],feedback};
 previous_actions <= status[127:124];
 old_native <= native_update;
 status_set <= 0; save_preset <= 0; load_preset <= 0;
 // Give hps_io a low cycle between native and BrickBoy notifications.
 if(notify && !native_update && !old_native && !status_set) begin
  status_set <= 1; notify <= 0;
 end
 if(preset_loaded) begin
  banks <= preset_data[119:0] & MASK;
  active_bank <= bank;
  request_window(preset_data[119:0] & MASK,bank,preset_data[126],preset_data[127]);
 end else if(pending) begin
  if(bank != active_bank) begin
   active_bank <= bank;
   request_window(banks,bank,status[51],status[52]);
  end else if(!notify && !status_set &&
              status[82:80] == reply[82:80] &&
              status[79:56] == reply[79:56] &&
              status[52:51] == reply[52:51]) pending <= 0;
 end else if(press[0]) begin
  banks <= 0;
  request_window(120'd0,bank,status[51],1'b0);
 end else if(press[1]) begin
  banks <= rng[119:0] & MASK;
  request_window(rng[119:0] & MASK,bank,status[51],status[52]);
 end else if(bank != active_bank || status[82:80] > 4) begin
  active_bank <= bank;
  request_window(banks,bank,status[51],status[52]);
 end else begin
  banks[active_bank*24 +:24] <= status[79:56] & MASK[active_bank*24 +:24];
  // Preset engine snapshots next cycle, after this window commit.
  save_preset <= press[2]; load_preset <= press[3];
 end
end
endmodule

// hps_io detects rising edges, so ORing adjacent native/editor notifications
// can swallow one. Coalesce simultaneous events and queue adjacent ones.
module brick_status_notify(input wire clk, input wire native_event,
 input wire editor_event, output reg pulse = 0);
reg queued = 0;
always @(posedge clk) begin
 pulse <= 0;
 if(pulse) queued <= queued | native_event | editor_event;
 else if(queued | native_event | editor_event) begin
  pulse <= 1;
  queued <= 0;
 end
end
endmodule
