module brick_vinegar_tb;
reg clk=0;
always #5 clk=~clk;
reg [9:0] gx=0,gy=0;
reg [1:0] depth=0;
reg blob_mode=0;
reg [2:0] seed_sel=0;
reg [23:0] in_rgb=24'h8caf62;
wire [23:0] packed_rgb,reference_rgb;
brick_vinegar dut(clk,gx,gy,depth,blob_mode,seed_sel,in_rgb,packed_rgb);
brick_vinegar_reference reference_dut(clk,gx,gy,depth,blob_mode,seed_sel,in_rgb,reference_rgb);
integer mode,seed,level,x,y,cycles=0;
task check;
 begin
  @(posedge clk); #1;
  cycles=cycles+1;
  if(cycles>3 && packed_rgb!==reference_rgb)
   $fatal(1,"Vinegar packing changed output at cycle %0d",cycles);
 end
endtask
initial begin
 for(mode=0;mode<2;mode=mode+1)
  for(seed=0;seed<3;seed=seed+1)
   for(level=0;level<4;level=level+1)
    for(y=0;y<576;y=y+1)
     for(x=0;x<640;x=x+1) begin
      @(negedge clk);
      gx=10'(x); gy=10'(y); depth=2'(level);
      blob_mode=1'(mode); seed_sel=3'(seed);
      in_rgb=in_rgb+24'h013705;
      check();
     end
 repeat(4) check();
 $display("PASS: packed Vinegar matches wide-ROM pipeline for every pixel, mode, strength and retained seed");
 $finish;
end
endmodule
