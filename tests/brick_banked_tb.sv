module brick_banked_tb;
reg clk=0; always #5 clk=~clk;
reg [127:0] status=0, preset_data=0;
reg native_update=0, preset_loaded=0;
wire [127:0] config_data, result;
wire update, save, load, busy;
wire combined_update;
brick_status_notify notify(clk,native_update,update,combined_update);
brick_settings dut(clk,status,native_update,preset_loaded,preset_data,
 config_data,result,update,save,load,busy);
localparam [119:0] MASK={24'h0fffff,24'h00ffff,24'h000fff,24'h7fffff,24'h03ffff};
reg got_reply=0;
reg [127:0] reply;
integer replies=0, saves=0, loads=0;
always @(posedge clk) begin
 #1;
 if(combined_update) begin reply=result; got_reply=1; replies=replies+1; end
 if(save) saves=saves+1;
 if(load) loads=loads+1;
end
task tick; begin @(posedge clk); #2; end endtask
// Model hps_io: ascending 16-bit words, with gaps between transfers.
task send(input [127:0] value);
 integer j;
 reg [127:0] staged;
 begin
  for(j=0;j<8;j=j+1) begin
   @(negedge clk); staged=status; staged[j*16 +:16]=value[j*16 +:16]; status=staged;
   repeat(3) tick();
  end
 end
endtask
task flush;
 integer tries;
 reg [127:0] message;
 begin
  for(tries=0;tries<8;tries=tries+1) begin
   repeat(4) tick();
   if(got_reply) begin message=reply; got_reply=0; send(message); end
  end
  if(busy) $fatal(1,"Editor response did not converge");
 end
endtask
reg [119:0] expected=0;
reg [127:0] value, randomized;
reg [50:0] native;
integer bank, k, before_count;
initial begin
 status[50:0]=51'h5abcdef123456; status[51]=1; status[52]=1;
 native=status[50:0]; repeat(4) tick();
 for(k=0;k<40;k=k+1) begin
  bank=k%5;
  value=status; value[82:80]=3'(bank); send(value); flush();
  if(status[79:56] !== expected[bank*24 +:24]) $fatal(1,"Wrong bank hydration k=%0d bank=%0d actual_bank=%0d active=%0d replies=%0d got=%h expected=%h config=%h",k,bank,status[82:80],dut.active_bank,replies,status[79:56],expected[bank*24 +:24],config_data);
  value=status; value[79:56]=$urandom & MASK[bank*24 +:24];
  expected[bank*24 +:24]=value[79:56]; send(value); flush();
  if(config_data[119:0] !== expected) $fatal(1,"Cross-bank corruption");
  if(status[50:0] !== native) $fatal(1,"Native status changed");
 end
 // Native slot notifications adjacent to a section change must not swallow
 // the BrickBoy notification. Upstream changes remain live in status_out.
 native_update=1; value=status; value[82:80]=0; send(value);
 status[33:32]=2; native=status[50:0]; tick();
 if(result[50:0]!==native) $fatal(1,"Stale native reply");
 @(negedge clk); native_update=0; flush();
 // Snapshot save is a one-shot even if its trigger remains held.
 before_count=saves; value=status; value[126]=1; send(value);
 repeat(30) tick();
 if(saves!=before_count+1) $fatal(1,"Save repeats while held");
 value=status; value[126]=0; send(value);
 before_count=loads; value=status; value[127]=1; send(value); repeat(30) tick();
 if(loads!=before_count+1) $fatal(1,"Load repeats while held");
 value=status; value[127]=0; send(value);
 // All banks participate in randomize; reserved/native/enable bits survive.
 value=status; value[125]=1; send(value); flush();
 randomized=config_data;
 if((config_data[119:0]&~MASK)!=0 || config_data[119:0]==0 || config_data[127:126]!=3)
  $fatal(1,"Randomize mask or enable preservation");
 value=status; value[124]=1; send(value); flush();
 if(config_data[119:0]!=0 || status[52] || !status[51]) $fatal(1,"Reset defaults");
 // Presets restore every section, plus panel and speaker, atomically.
 @(negedge clk); preset_data=randomized; preset_loaded=1; tick();
 @(negedge clk); preset_loaded=0; flush();
 if(config_data!==randomized || status[50:0]!==native) $fatal(1,"Preset restore");
 // Redirect a second section selection while the first reply is outstanding.
 value=status; value[82:80]=1; send(value);
 value=status; value[82:80]=4; send(value); flush();
 if(config_data!==randomized) $fatal(1,"Rapid navigation corrupted settings");
 // Out-of-range saved section must recover to Panel.
 value=status; value[82:80]=7; send(value); flush();
 if(status[82:80]!=0 || config_data!==randomized) $fatal(1,"Invalid bank recovery");
 $display("PASS: serial bank switching, independent values, notifications, actions, preset restore");
 $finish;
end
endmodule
