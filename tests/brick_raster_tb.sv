module brick_raster_tb;
reg clk=0;
always #5 clk=~clk;
reg [1:0] effect=0;
wire hs,vs,hblank,vblank,de;
wire [23:0] rgb;
brick_video #(.ENABLE_PERSISTENCE(1), .ENABLE_VINEGAR(0)) dut(.clk_sys(clk),.ce(1'b1),.lcd_clkena(1'b0),
 .lcd_data(2'd0),.lcd_mode(2'd1),.lcd_on(1'b0),.lcd_vsync(1'b0),
 .set_bright({effect,effect[0]}),
 .set_warm({effect,effect[0]}),
 .set_ink_r({effect,effect[0]}),
 .set_ink_g({effect,effect[0]}),
 .set_ink_b({effect,effect[0]}),
 .set_offtint(effect),
 .set_refsat(effect),
 .set_deadline({1'b0,effect}),
 .set_grain({effect,effect[0]}),
 .set_real(effect[0]),
 .set_vinegar(effect),
 .set_rot_blob('0),
 .set_rot_seed('0),
 .set_flicker(effect),
 .set_grid(effect),
 .set_shadow(effect),
 .set_ghost(effect),
 .set_gradient(effect),
 .set_vignette(effect),
 .set_matte(effect),
 .set_fill(effect),
 .set_gap(effect),
 .set_gate(effect),
 .set_dimming(effect),
 .set_frontlight(effect),
 .set_backlight(effect),
 .set_contrast_fade(effect),
 .set_dust(effect),
 .set_brightness(effect),
 .set_contrast(effect),
 .set_saturation(effect),
 .set_gamma(effect),
 .set_blacklift(effect),
 .set_density(effect),
 .set_bleed(effect),
 .set_xtalk(effect),
 .set_xtnoise(effect),
 .set_xtedge(effect),
 .set_cold(effect),
 .set_depth(effect),
 .set_blur(effect),
 .set_ghost_gamma(effect),
 .set_dead_edge(effect),
 .set_dead_lit(effect),
 .set_dead_rows(effect),
 .hs(hs),.vs(vs),.hblank(hblank),.vblank(vblank),.de(de),.rgb(rgb));
integer cycle=0, last_h=-1, last_v=-1, frames=0, active=0;
reg old_h=0, old_v=0;
reg [23:0] rot_delay[0:2];
always @(posedge clk) begin
 rot_delay[0] <= dut.aging_rgb;
 rot_delay[1] <= rot_delay[0];
 rot_delay[2] <= rot_delay[1];
 #1;
 if(cycle>4 && dut.vinegar_rgb !== rot_delay[2])
  $fatal(1,"Vinegar bypass changed RGB or three-cycle latency");
end
initial begin
 repeat(896*627*4) begin
  @(posedge clk); #1;
  cycle=cycle+1;
  if(hs && !old_h) begin
   if(last_h>=0 && cycle-last_h!=896) $fatal(1,"Line pacing changed");
   last_h=cycle;
  end
  if(vs && !old_v) begin
   if(last_v>=0) begin
    if(cycle-last_v!=561792) $fatal(1,"Frame pacing changed");
    if(active!=640*576) $fatal(1,"Active geometry changed: %0d",active);
    frames=frames+1;
   end
   last_v=cycle; active=0;
  end
  if(!hblank && !vblank) active=active+1;
  old_h=hs; old_v=vs;
  if(cycle==700000) effect=3;
 end
 if(frames<3) $fatal(1,"Missing frame output");
 $display("PASS: 896x627 raster, 640x576 active, fixed frame period with effects changed");
 $finish;
end
endmodule
