// Optional DMG renderer. Standard GBC, SGB and MegaDuck use upstream video.
wire brick_active = status[51] && !isGBC && !sys_megaduck && !(|sgb_en);
wire brick_hs, brick_vs, brick_de, brick_hblank, brick_vblank;
wire [23:0] brick_rgb;
reg brick_ce_pix = 0;
always @(posedge CLK_VIDEO) brick_ce_pix <= ~brick_ce_pix;
wire [15:0] brick_audio_l, brick_audio_r;
brick_audio brick_speaker(.clk(clk_sys), .reset(reset), .enable(status[52]),
 .in_l(GB_AUDIO_L), .in_r(GB_AUDIO_R), .out_l(brick_audio_l), .out_r(brick_audio_r));

wire brick_status_set;
wire brick_combined_status_set;
brick_status_notify brick_notifications(.clk(clk_sys),
 .native_event(statusUpdate), .editor_event(brick_status_set),
 .pulse(brick_combined_status_set));
wire [127:0] brick_requested_status;
wire [127:0] brick_status_in = {brick_requested_status[127:34],ss_slot,brick_requested_status[31:0]};
wire [127:0] brick_config, brick_loaded_data;
wire brick_save_preset, brick_load_preset, brick_preset_loaded;
reg brick_info_req = 0, brick_old_busy = 0, brick_old_error = 0;
reg [7:0] brick_info = 0;
always @(posedge clk_sys) begin
 brick_info_req <= 0;
 brick_old_busy <= brick_preset_busy;
 brick_old_error <= brick_preset_error;
 if(brick_preset_loaded) begin brick_info_req <= 1; brick_info <= 15; end
 else if(brick_preset_error && !brick_old_error) begin brick_info_req <= 1; brick_info <= 17; end
 else if(brick_old_busy && !brick_preset_busy && !brick_preset_error) begin
  brick_info_req <= 1; brick_info <= 16;
 end
end
brick_settings brick_settings(.clk(clk_sys), .status(status), .native_update(statusUpdate),
 .preset_loaded(brick_preset_loaded), .preset_data(brick_loaded_data),
 .config_data(brick_config), .status_out(brick_requested_status), .status_set(brick_status_set),
 .save_preset(brick_save_preset), .load_preset(brick_load_preset), .editor_busy(brick_editor_busy));
brick_preset brick_preset(.clk(clk_sys), .mounted(mounted_slots[1]),
 .readonly(mounted_readonly), .image_size(mounted_size),
 .save(brick_save_preset), .load(brick_load_preset), .config_data(brick_config),
 .loaded(brick_preset_loaded), .loaded_data(brick_loaded_data),
 .can_save(brick_can_save), .busy(brick_preset_busy), .error(brick_preset_error),
 .sd_rd(brick_sd_rd), .sd_wr(brick_sd_wr), .sd_ack(ack_slots[1]),
 .buff_addr(sd_buff_addr), .buff_dout(sd_buff_dout), .buff_wr(sd_buff_wr),
 .buff_din(brick_sd_din));

function automatic [2:0] brick_trim(input [2:0] s);
 brick_trim = s == 0 ? 3'd3 : (s <= 3 ? s - 1'b1 : s);
endfunction
function automatic [2:0] brick_grain_level(input [2:0] s);
 brick_grain_level = s == 0 ? 3'd2 : (s <= 2 ? s - 1'b1 : s);
endfunction

function automatic [2:0] brick_ink(input [2:0] s, input [2:0] normal);
 brick_ink = s == 0 ? normal : s == 1 ? 3'd0 : (normal == 2 && s == 2) ? 3'd1 : s;
endfunction
function automatic [2:0] brick_offtint(input [1:0] s);
 case(s)
  0: brick_offtint=2; 1: brick_offtint=0;
  2: brick_offtint=4; 3: brick_offtint=6;
 endcase
endfunction
function automatic [2:0] brick_refsat(input [1:0] s);
 case(s)
  0: brick_refsat=1; 1: brick_refsat=0;
  2: brick_refsat=2; 3: brick_refsat=3;
 endcase
endfunction

brick_video #(.ENABLE_PERSISTENCE(1), .ENABLE_VINEGAR(0)) brick_panel(
 .clk_sys(clk_sys), .ce(ce_cpu), .lcd_clkena(lcd_clkena),
 .lcd_data(lcd_data_gb), .lcd_mode(lcd_mode), .lcd_on(lcd_on), .lcd_vsync(lcd_vsync),
 .set_bright(brick_trim(brick_config[2:0])),
 .set_warm(brick_trim(brick_config[5:3])),
 .set_grain(brick_grain_level(brick_config[8:6])),
 .set_real(brick_config[9]),
 .set_grid(brick_config[11:10]),
 .set_fill(brick_config[13:12]),
 .set_gap(brick_config[15:14]),
 .set_density(brick_config[17:16]),
 .set_ink_r(brick_ink(brick_config[26:24],3'd1)),
 .set_ink_g(brick_ink(brick_config[29:27],3'd2)),
 .set_ink_b(brick_ink(brick_config[32:30],3'd2)),
 .set_offtint(brick_offtint(brick_config[34:33])),
 .set_refsat(brick_refsat(brick_config[36:35])),
 .set_brightness(brick_config[38:37]),
 .set_contrast(brick_config[40:39]),
 .set_saturation(brick_config[42:41]),
 .set_gamma(brick_config[44:43]),
 .set_blacklift(brick_config[46:45]),
 .set_shadow(brick_config[49:48]),
 .set_gradient(brick_config[51:50]),
 .set_vignette(brick_config[53:52]),
 .set_matte(brick_config[55:54]),
 .set_depth(brick_config[57:56]),
 .set_blur(brick_config[59:58]),
 .set_ghost(brick_config[73:72]),
 .set_gate(brick_config[75:74]),
 .set_ghost_gamma(brick_config[77:76]),
 .set_bleed(brick_config[79:78]),
 .set_xtalk(brick_config[81:80]),
 .set_xtnoise(brick_config[83:82]),
 .set_xtedge(brick_config[85:84]),
 .set_cold(brick_config[87:86]),
 .set_dimming(brick_config[97:96]),
 .set_frontlight(brick_config[99:98]),
 .set_backlight(brick_config[101:100]),
 .set_contrast_fade(brick_config[103:102]),
 .set_dust(brick_config[105:104]),
 .set_deadline({1'b0,brick_config[107:106]}),
 .set_flicker(brick_config[109:108]),
 .set_dead_edge(brick_config[111:110]),
 .set_dead_lit(brick_config[113:112]),
 .set_dead_rows(brick_config[115:114]),
 .set_vinegar(2'd0), .set_rot_blob(1'b0), .set_rot_seed(3'd0),
 .hs(brick_hs), .vs(brick_vs), .de(brick_de),
 .hblank(brick_hblank), .vblank(brick_vblank), .rgb(brick_rgb)
);
