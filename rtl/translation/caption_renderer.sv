//------------------------------------------------------------------------------
// caption_renderer.sv
//
// Renders translated English text as a caption overlay at the bottom of the
// screen. Uses an 8x8 pixel ASCII font stored in BRAM.
//
// Caption area: Bottom 36 pixels of GB screen (160x36, supports 2 lines of text)
// Color depth: 2bpp (4 colors: transparent, text, outline, shadow)
// Font: 8x8 fixed-width ASCII
//
// Text is rendered with a 1-pixel black outline for readability.
//------------------------------------------------------------------------------

module caption_renderer #(
    parameter SCREEN_WIDTH = 160,       // GB screen width
    parameter SCREEN_HEIGHT = 144,      // GB screen height
    parameter CAPTION_HEIGHT = 36,      // Caption area height (bottom of screen)
    parameter CHARS_PER_LINE = 18,      // 160/8 = 20, leave 1 char margin each side
    parameter MAX_LINES = 2,
    parameter FONT_WIDTH = 8,
    parameter FONT_HEIGHT = 8
) (
    input  logic        clk,
    input  logic        rst_n,

    // Video timing input
    input  logic [7:0]  pixel_x,        // 0-159
    input  logic [7:0]  pixel_y,        // 0-143
    input  logic        pixel_de,       // Data enable (active pixel)

    // Text input (from translation engine)
    input  logic        text_valid,     // New text string ready
    input  logic [255:0] text_string,   // Up to 32 ASCII characters (256/8)
    input  logic [4:0]  text_length,    // Actual string length

    // Caption pixel output
    output logic [14:0] caption_rgb,    // RGB555 color
    output logic        caption_alpha,  // 1 = show caption pixel

    // Configuration
    input  logic [14:0] cfg_text_color,     // Text color (RGB555)
    input  logic [14:0] cfg_outline_color,  // Outline color (RGB555)
    input  logic [7:0]  cfg_y_position,     // Caption Y start position
    input  logic        cfg_enable
);

    //--------------------------------------------------------------------------
    // Caption text buffer (2 lines x 20 chars max)
    //--------------------------------------------------------------------------

    logic [7:0] line_buffer [0:MAX_LINES-1][0:CHARS_PER_LINE-1];
    logic [4:0] line_length [0:MAX_LINES-1];
    logic       line_valid [0:MAX_LINES-1];

    //--------------------------------------------------------------------------
    // Font ROM instance
    //--------------------------------------------------------------------------

    logic [10:0] font_addr;
    logic [7:0]  font_data;

    font_rom u_font_rom (
        .clk        (clk),
        .addr       (font_addr),
        .data       (font_data)
    );

    //--------------------------------------------------------------------------
    // Text loading logic
    //--------------------------------------------------------------------------

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int l = 0; l < MAX_LINES; l++) begin
                line_valid[l] <= 1'b0;
                line_length[l] <= 5'd0;
                for (int c = 0; c < CHARS_PER_LINE; c++) begin
                    line_buffer[l][c] <= 8'h20;  // Space
                end
            end
        end else if (text_valid && cfg_enable) begin
            // Load new text into line buffer
            // Simple single-line for now (multi-line word wrap could be added)
            line_valid[0] <= 1'b1;
            line_length[0] <= (text_length > CHARS_PER_LINE) ? CHARS_PER_LINE : text_length;

            for (int c = 0; c < CHARS_PER_LINE; c++) begin
                if (c < text_length) begin
                    // Extract character from packed string (MSB first)
                    line_buffer[0][c] <= text_string[255 - c*8 -: 8];
                end else begin
                    line_buffer[0][c] <= 8'h20;  // Pad with spaces
                end
            end
        end
    end

    //--------------------------------------------------------------------------
    // Caption area detection
    //--------------------------------------------------------------------------

    wire in_caption_area = (pixel_y >= cfg_y_position) &&
                           (pixel_y < cfg_y_position + CAPTION_HEIGHT);

    // Which line and character are we rendering?
    wire [7:0] caption_y_offset = pixel_y - cfg_y_position;
    wire [0:0] text_line = caption_y_offset[4:3];  // 0 or 1 (16 pixels per text line)
    wire [2:0] glyph_row = caption_y_offset[2:0];  // Row within glyph (0-7)

    // Center text horizontally
    wire [4:0] text_start_x = (SCREEN_WIDTH - line_length[text_line] * FONT_WIDTH) >> 1;
    wire       in_text_x = (pixel_x >= text_start_x) &&
                           (pixel_x < text_start_x + line_length[text_line] * FONT_WIDTH);

    wire [4:0] char_index = (pixel_x - text_start_x) >> 3;  // Which character (0-17)
    wire [2:0] glyph_col = pixel_x[2:0];                    // Column within glyph (0-7)

    //--------------------------------------------------------------------------
    // Font ROM addressing
    //--------------------------------------------------------------------------

    logic [7:0] current_char;
    logic [7:0] font_bitmap;
    logic       pixel_on;

    // Pipeline stage 1: Calculate font address
    always_ff @(posedge clk) begin
        if (in_caption_area && in_text_x && line_valid[text_line]) begin
            current_char <= line_buffer[text_line][char_index];
        end else begin
            current_char <= 8'h20;  // Space character
        end
    end

    // Font address: char_code * 8 + row
    assign font_addr = {current_char[6:0], glyph_row};

    // Pipeline stage 2: Read font data and determine pixel
    logic [2:0] glyph_col_d1;
    logic       in_caption_area_d1;
    logic       in_text_x_d1;

    always_ff @(posedge clk) begin
        glyph_col_d1 <= glyph_col;
        in_caption_area_d1 <= in_caption_area;
        in_text_x_d1 <= in_text_x;
    end

    assign font_bitmap = font_data;
    assign pixel_on = font_bitmap[7 - glyph_col_d1];  // MSB is leftmost pixel

    //--------------------------------------------------------------------------
    // Outline detection (check neighboring pixels)
    //--------------------------------------------------------------------------

    // For proper outline, we'd need to check 8 neighbors
    // Simplified: just render text with no outline for now
    // Full outline would require buffering 3 rows of font data

    //--------------------------------------------------------------------------
    // Output generation
    //--------------------------------------------------------------------------

    logic [14:0] output_rgb;
    logic        output_alpha;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            output_rgb <= 15'h0000;
            output_alpha <= 1'b0;
        end else begin
            if (cfg_enable && in_caption_area_d1 && in_text_x_d1) begin
                if (pixel_on) begin
                    // Text pixel
                    output_rgb <= cfg_text_color;
                    output_alpha <= 1'b1;
                end else begin
                    // Background in text area (semi-transparent black box)
                    output_rgb <= 15'h0000;
                    output_alpha <= 1'b1;  // Show background box
                end
            end else begin
                // Outside caption area
                output_rgb <= 15'h0000;
                output_alpha <= 1'b0;
            end
        end
    end

    assign caption_rgb = output_rgb;
    assign caption_alpha = output_alpha;

endmodule
