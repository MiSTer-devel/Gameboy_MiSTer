//------------------------------------------------------------------------------
// alpha_blender.sv
//
// Composites the caption overlay with the GB/GBA video output.
// Uses simple alpha (1-bit: fully opaque or fully transparent).
//
// For caption pixels with alpha=1, outputs the overlay color.
// For caption pixels with alpha=0, passes through the original video.
//------------------------------------------------------------------------------

module alpha_blender (
    input  logic        clk,
    input  logic        rst_n,

    // Video input (from GB/GBA PPU)
    input  logic [14:0] vid_rgb_in,     // RGB555
    input  logic        vid_de_in,      // Data enable
    input  logic        vid_vs_in,      // Vertical sync
    input  logic        vid_hs_in,      // Horizontal sync

    // Caption overlay input
    input  logic [14:0] overlay_rgb,    // RGB555
    input  logic        overlay_alpha,  // 1 = show overlay

    // Blended video output
    output logic [14:0] vid_rgb_out,
    output logic        vid_de_out,
    output logic        vid_vs_out,
    output logic        vid_hs_out,

    // Configuration
    input  logic        cfg_enable,         // Enable blending
    input  logic [3:0]  cfg_blend_alpha     // Future: for semi-transparency (0-15)
);

    //--------------------------------------------------------------------------
    // Delay video signals to match caption pipeline latency
    //--------------------------------------------------------------------------

    // Caption renderer has 2-cycle latency, so delay video to match
    logic [14:0] vid_rgb_d1, vid_rgb_d2;
    logic        vid_de_d1, vid_de_d2;
    logic        vid_vs_d1, vid_vs_d2;
    logic        vid_hs_d1, vid_hs_d2;

    always_ff @(posedge clk) begin
        vid_rgb_d1 <= vid_rgb_in;
        vid_rgb_d2 <= vid_rgb_d1;
        vid_de_d1  <= vid_de_in;
        vid_de_d2  <= vid_de_d1;
        vid_vs_d1  <= vid_vs_in;
        vid_vs_d2  <= vid_vs_d1;
        vid_hs_d1  <= vid_hs_in;
        vid_hs_d2  <= vid_hs_d1;
    end

    //--------------------------------------------------------------------------
    // Alpha blending
    //--------------------------------------------------------------------------

    logic [14:0] blended_rgb;

    always_comb begin
        if (cfg_enable && overlay_alpha) begin
            // Simple 1-bit alpha: fully replace with overlay
            blended_rgb = overlay_rgb;
        end else begin
            // Pass through original video
            blended_rgb = vid_rgb_d2;
        end
    end

    //--------------------------------------------------------------------------
    // Future: Semi-transparent blending
    // Formula: out = (overlay * alpha + video * (16-alpha)) / 16
    //--------------------------------------------------------------------------

    // For semi-transparent blending (not used yet):
    // wire [4:0] vid_r = vid_rgb_d2[4:0];
    // wire [4:0] vid_g = vid_rgb_d2[9:5];
    // wire [4:0] vid_b = vid_rgb_d2[14:10];
    // wire [4:0] ovl_r = overlay_rgb[4:0];
    // wire [4:0] ovl_g = overlay_rgb[9:5];
    // wire [4:0] ovl_b = overlay_rgb[14:10];
    //
    // wire [8:0] blend_r = (ovl_r * cfg_blend_alpha + vid_r * (16 - cfg_blend_alpha));
    // wire [8:0] blend_g = (ovl_g * cfg_blend_alpha + vid_g * (16 - cfg_blend_alpha));
    // wire [8:0] blend_b = (ovl_b * cfg_blend_alpha + vid_b * (16 - cfg_blend_alpha));
    //
    // Semi-transparent output would be: {blend_b[8:4], blend_g[8:4], blend_r[8:4]}

    //--------------------------------------------------------------------------
    // Output registers
    //--------------------------------------------------------------------------

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vid_rgb_out <= 15'h0000;
            vid_de_out  <= 1'b0;
            vid_vs_out  <= 1'b0;
            vid_hs_out  <= 1'b0;
        end else begin
            vid_rgb_out <= blended_rgb;
            vid_de_out  <= vid_de_d2;
            vid_vs_out  <= vid_vs_d2;
            vid_hs_out  <= vid_hs_d2;
        end
    end

endmodule
