module brick_preset_tb;
reg clk=0; always #5 clk=~clk;
reg mounted=0, readonly=0, save=0, load=0, ack=0, wr=0;
reg [63:0] size=512;
reg [127:0] config_data=0;
reg [7:0] addr=0;
reg [15:0] dout=0;
wire loaded, can_save, busy, error, rd, sdwr;
wire [127:0] restored;
wire [15:0] din;
brick_preset #(.TIMEOUT_CYCLES(2048)) dut(clk,mounted,readonly,size,
 save,load,config_data,loaded,restored,can_save,busy,error,rd,sdwr,ack,addr,dout,wr,din);
localparam [127:0] MASK={2'b11,6'b0,24'h0fffff,24'h00ffff,24'h000fff,24'h7fffff,24'h03ffff};
reg [15:0] disk[0:255];
integer loads=0;
always @(posedge clk) begin #1; if(loaded) loads=loads+1; end
task tick; begin @(posedge clk); #2; end endtask
task make_disk(input [127:0] cfg);
 integer j; reg [15:0] checksum;
 begin
  for(j=0;j<256;j=j+1) disk[j]=0;
  disk[0]=16'h4242; disk[1]=16'h3150; disk[2]=1; disk[3]=16;
  for(j=0;j<8;j=j+1) disk[4+j]=cfg[j*16 +:16];
  checksum=0; for(j=0;j<12;j=j+1) checksum=checksum+disk[j];
  disk[12]=~checksum;
 end
endtask
task mount_file;
 begin @(negedge clk); mounted=1; tick(); @(negedge clk); mounted=0; tick(); end
endtask
task read_sector(input integer words);
 integer j;
 begin
  if(!rd || sdwr) $fatal(1,"Missing read or unintended write");
  @(negedge clk); ack=1; tick();
  for(j=0;j<words;j=j+1) begin
   @(negedge clk); addr=8'(j); dout=disk[j]; wr=1; tick();
  end
  @(negedge clk); wr=0; tick(); @(negedge clk); ack=0; tick(); tick();
 end
endtask
task pulse_save;
 begin @(negedge clk); save=1; tick(); @(negedge clk); save=0; tick(); end
endtask
reg [127:0] expected;
integer j, before_load;
initial begin
 expected={32'hc0000000,32'habcdef12,32'h23456789,32'h87654321} & MASK;
 make_disk(expected); mount_file();
 // Shared buffer traffic for another slot must be ignored without our ACK.
 @(negedge clk); wr=1; dout=16'hdead; addr=8'd99;
 repeat(20) tick(); @(negedge clk); wr=0;
 read_sector(256);
 if(!can_save || restored!==expected || loads!=1) $fatal(1,"Valid preset rejected");
 // Explicit write uses a stable snapshot even if controls change mid-transfer.
 config_data=~expected & MASK; expected=config_data; pulse_save();
 if(!sdwr || rd) $fatal(1,"Explicit save not issued");
 @(negedge clk); ack=1; tick();
 for(j=0;j<256;j=j+1) begin
  @(negedge clk); addr=8'(j); config_data=0; tick(); disk[j]=din;
 end
 @(negedge clk); ack=0; tick(); tick();
 mount_file(); read_sector(256);
 if(restored!==expected || loads!=2) $fatal(1,"Write/read round trip failed");
 // A checksum error cannot mutate configuration or authorize overwrites.
 before_load=loads; disk[4]=disk[4]^1; mount_file(); read_sector(256);
 if(!error || can_save || loads!=before_load) $fatal(1,"Corrupt preset accepted");
 pulse_save(); if(sdwr) $fatal(1,"Overwrote invalid file");
 make_disk(expected); mount_file(); read_sector(32);
 if(!error || can_save || loads!=before_load) $fatal(1,"Partial preset accepted");
 // Correct checksum but illegal reserved configuration bits must be rejected.
 make_disk(expected | (128'd1<<120)); mount_file(); read_sector(256);
 if(!error || can_save || loads!=before_load) $fatal(1,"Unknown config accepted");
 make_disk(expected); readonly=1; mount_file(); read_sector(256);
 if(can_save || restored!==expected) $fatal(1,"Read-only behavior");
 pulse_save(); if(sdwr) $fatal(1,"Read-only write");
 readonly=0; size=1024; mount_file();
 if(rd || sdwr || can_save) $fatal(1,"Wrong-sized file accessed");
 size=512; make_disk(expected); mount_file();
 repeat(2055) tick();
 if(busy || rd || sdwr || !error || can_save) $fatal(1,"Timeout recovery");
 mount_file(); read_sector(256);
 if(!can_save) $fatal(1,"Remount recovery");
 before_load=loads;
 mount_file(); @(negedge clk); ack=1; tick();
 mount_file(); // changing the mounted file during a read must fail closed
 repeat(4) tick();
 @(negedge clk); ack=0; tick(); tick();
 if(can_save || rd || sdwr || loads!=before_load) $fatal(1,"Mid-read remount accepted");
 mount_file(); read_sector(256);
 if(!can_save) $fatal(1,"Recovery after aborted remount");
 $display("PASS: preset save/load, stable snapshots, corruption/size/read-only/timeout guards");
 $finish;
end
endmodule
