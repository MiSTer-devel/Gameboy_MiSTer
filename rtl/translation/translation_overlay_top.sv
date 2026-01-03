//------------------------------------------------------------------------------
// translation_overlay_top.sv
//
// Top-level module for GB/GBA translation overlay system
// Intercepts VRAM writes, detects Japanese text tiles, and provides translation
// via two modes: Replace (in-place tile swap) or Caption (subtitle overlay)
//
// Target: Analogue Pocket (openFPGA, Cyclone V)
//------------------------------------------------------------------------------

module translation_overlay_top #(
    parameter MODE_REPLACE = 1'b0,
    parameter MODE_CAPTION = 1'b1
) (
    // Clock and reset
    input  logic        clk,            // System clock (GB: ~4.19MHz, GBA: ~16.78MHz)
    input  logic        clk_vid,        // Video clock (pixel clock)
    input  logic        rst_n,          // Active-low reset

    // VRAM snoop interface (from GB/GBA memory controller)
    input  logic        vram_we,        // VRAM write enable
    input  logic [12:0] vram_addr,      // VRAM address (GB: 13-bit for 8KB)
    input  logic [7:0]  vram_wdata,     // VRAM write data

    // VRAM replacement interface (to GB/GBA memory controller)
    output logic        vram_replace_en,    // Replace mode: intercept write
    output logic [7:0]  vram_replace_data,  // Replace mode: substituted data

    // Video input (from GB/GBA PPU)
    input  logic [14:0] vid_rgb_in,     // RGB555 pixel data
    input  logic        vid_de_in,      // Data enable (active pixel)
    input  logic        vid_vs_in,      // Vertical sync
    input  logic        vid_hs_in,      // Horizontal sync
    input  logic [7:0]  vid_x,          // X position (0-159 for GB)
    input  logic [7:0]  vid_y,          // Y position (0-143 for GB)

    // Video output (to display/scaler)
    output logic [14:0] vid_rgb_out,    // RGB555 with optional caption overlay
    output logic        vid_de_out,
    output logic        vid_vs_out,
    output logic        vid_hs_out,

    // External memory interface (for large dictionaries)
    output logic        ext_mem_rd,
    output logic [23:0] ext_mem_addr,
    input  logic [31:0] ext_mem_rdata,
    input  logic        ext_mem_rvalid,

    // Configuration interface
    input  logic        cfg_enable,         // Translation system enable
    input  logic        cfg_mode,           // 0=Replace, 1=Caption
    input  logic [14:0] cfg_caption_color,  // Caption text color (RGB555)
    input  logic [7:0]  cfg_caption_y,      // Caption Y position

    // Debug outputs
    output logic        dbg_tile_detected,
    output logic [15:0] dbg_tile_hash,
    output logic        dbg_match_found
);

    //--------------------------------------------------------------------------
    // Internal signals
    //--------------------------------------------------------------------------

    // From VRAM snooper
    logic        tile_capture_done;
    logic [15:0] tile_hash;
    logic [10:0] tile_index;
    logic        tile_is_text_region;

    // From hash lookup
    logic        hash_match_found;
    logic [7:0]  matched_char_code;
    logic [15:0] translation_ptr;

    // From translation engine
    logic        translation_ready;
    logic [255:0] english_string;  // Up to 32 ASCII chars
    logic [4:0]  english_length;

    // For caption renderer
    logic [14:0] caption_rgb;
    logic        caption_alpha;

    // For replace mode
    logic [7:0]  replacement_tile_data;
    logic        do_replace;

    //--------------------------------------------------------------------------
    // VRAM Snooper - monitors VRAM writes for Japanese text tiles
    //--------------------------------------------------------------------------
    vram_snooper u_vram_snooper (
        .clk                (clk),
        .rst_n              (rst_n),

        // VRAM write monitoring
        .vram_we            (vram_we),
        .vram_addr          (vram_addr),
        .vram_wdata         (vram_wdata),

        // Tile capture output
        .tile_capture_done  (tile_capture_done),
        .tile_index         (tile_index),
        .tile_is_text_region(tile_is_text_region),

        // To hash generator
        .hash_data_valid    (hash_data_valid),
        .hash_data          (hash_data),
        .hash_data_last     (hash_data_last),

        // Configuration
        .cfg_enable         (cfg_enable)
    );

    //--------------------------------------------------------------------------
    // Tile Hash Generator - computes CRC-16 of tile data
    //--------------------------------------------------------------------------
    tile_hash_generator u_tile_hasher (
        .clk            (clk),
        .rst_n          (rst_n),

        // Input from snooper
        .data_valid     (hash_data_valid),
        .data_in        (hash_data),
        .data_last      (hash_data_last),

        // Hash output
        .hash_valid     (tile_hash_valid),
        .hash_out       (tile_hash)
    );

    //--------------------------------------------------------------------------
    // Hash Lookup Table - Bloom filter + hash table for character matching
    //--------------------------------------------------------------------------
    hash_lookup_table u_hash_lookup (
        .clk                (clk),
        .rst_n              (rst_n),

        // Hash input
        .hash_valid         (tile_hash_valid),
        .hash_in            (tile_hash),

        // Match output
        .match_found        (hash_match_found),
        .char_code          (matched_char_code),
        .translation_ptr    (translation_ptr),

        // External memory for large dictionaries
        .ext_mem_rd         (ext_mem_rd),
        .ext_mem_addr       (ext_mem_addr),
        .ext_mem_rdata      (ext_mem_rdata),
        .ext_mem_rvalid     (ext_mem_rvalid)
    );

    //--------------------------------------------------------------------------
    // Caption Renderer - draws translated text as overlay
    //--------------------------------------------------------------------------
    caption_renderer u_caption_renderer (
        .clk            (clk_vid),
        .rst_n          (rst_n),

        // Video timing
        .pixel_x        (vid_x),
        .pixel_y        (vid_y),
        .pixel_de       (vid_de_in),

        // Text input (from translation engine)
        .text_valid     (translation_ready && cfg_mode == MODE_CAPTION),
        .text_string    (english_string),
        .text_length    (english_length),

        // Caption output
        .caption_rgb    (caption_rgb),
        .caption_alpha  (caption_alpha),

        // Configuration
        .cfg_text_color (cfg_caption_color),
        .cfg_y_position (cfg_caption_y),
        .cfg_enable     (cfg_enable && cfg_mode == MODE_CAPTION)
    );

    //--------------------------------------------------------------------------
    // Alpha Blender - composites caption overlay with video
    //--------------------------------------------------------------------------
    alpha_blender u_alpha_blender (
        .clk            (clk_vid),
        .rst_n          (rst_n),

        // Video input
        .vid_rgb_in     (vid_rgb_in),
        .vid_de_in      (vid_de_in),
        .vid_vs_in      (vid_vs_in),
        .vid_hs_in      (vid_hs_in),

        // Caption overlay
        .overlay_rgb    (caption_rgb),
        .overlay_alpha  (caption_alpha),

        // Blended output
        .vid_rgb_out    (vid_rgb_out),
        .vid_de_out     (vid_de_out),
        .vid_vs_out     (vid_vs_out),
        .vid_hs_out     (vid_hs_out)
    );

    //--------------------------------------------------------------------------
    // Replace Mode Control - direct VRAM tile substitution
    //--------------------------------------------------------------------------
    replace_mode_ctrl u_replace_ctrl (
        .clk                (clk),
        .rst_n              (rst_n),

        // From hash lookup
        .match_found        (hash_match_found),
        .char_code          (matched_char_code),

        // VRAM replacement
        .vram_replace_en    (do_replace),
        .vram_replace_data  (replacement_tile_data),

        // Configuration
        .cfg_enable         (cfg_enable && cfg_mode == MODE_REPLACE)
    );

    //--------------------------------------------------------------------------
    // Output assignments
    //--------------------------------------------------------------------------

    // Replace mode outputs
    assign vram_replace_en   = do_replace && cfg_mode == MODE_REPLACE;
    assign vram_replace_data = replacement_tile_data;

    // Debug outputs
    assign dbg_tile_detected = tile_capture_done;
    assign dbg_tile_hash     = tile_hash;
    assign dbg_match_found   = hash_match_found;

endmodule
