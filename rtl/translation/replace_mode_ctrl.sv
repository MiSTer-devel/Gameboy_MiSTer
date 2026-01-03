//------------------------------------------------------------------------------
// replace_mode_ctrl.sv
//
// Controls VRAM tile replacement for Replace Mode translation.
// When a Japanese character tile is detected, substitutes the VRAM write
// with the corresponding English character tile(s).
//
// Challenges handled:
// - English is often longer than Japanese
// - Uses compressed 5x8 font (2 chars per 8x8 tile)
// - Manages a pool of spare tiles for overflow
//------------------------------------------------------------------------------

module replace_mode_ctrl #(
    parameter TILE_POOL_SIZE = 64,          // Number of spare tiles
    parameter TILE_POOL_BASE = 9'd320       // Base tile index for spare tiles
) (
    input  logic        clk,
    input  logic        rst_n,

    // From hash lookup
    input  logic        match_found,
    input  logic        lookup_done,
    input  logic [7:0]  char_code,          // Japanese character code
    input  logic [15:0] translation_ptr,    // Pointer to English translation

    // From VRAM snooper
    input  logic [8:0]  tile_index,         // Tile being written
    input  logic [3:0]  byte_offset,        // Byte within tile

    // VRAM replacement output
    output logic        vram_replace_en,
    output logic [7:0]  vram_replace_data,

    // Configuration
    input  logic        cfg_enable
);

    //--------------------------------------------------------------------------
    // English tile ROM interface
    //--------------------------------------------------------------------------

    logic [10:0] eng_tile_addr;
    logic [7:0]  eng_tile_data;

    // English tile ROM (contains pre-rendered 5x8 font packed into 8x8 tiles)
    english_tile_rom u_eng_tile_rom (
        .clk    (clk),
        .addr   (eng_tile_addr),
        .data   (eng_tile_data)
    );

    //--------------------------------------------------------------------------
    // State machine
    //--------------------------------------------------------------------------

    typedef enum logic [2:0] {
        IDLE,
        WAIT_LOOKUP,
        FETCH_TRANSLATION,
        REPLACE_TILE,
        DONE
    } state_t;

    state_t state, next_state;

    //--------------------------------------------------------------------------
    // Replacement logic
    //--------------------------------------------------------------------------

    logic [8:0]  target_tile;
    logic [7:0]  replacement_char;
    logic [3:0]  replace_byte_idx;
    logic        replacing;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            replacing <= 1'b0;
            target_tile <= 9'd0;
            replacement_char <= 8'h0;
            replace_byte_idx <= 4'd0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    replacing <= 1'b0;
                    if (lookup_done && match_found && cfg_enable) begin
                        target_tile <= tile_index;
                        // For now, use direct ASCII mapping
                        // translation_ptr would point to actual translation string
                        replacement_char <= translation_ptr[7:0];
                        replace_byte_idx <= 4'd0;
                    end
                end

                REPLACE_TILE: begin
                    replacing <= 1'b1;
                    replace_byte_idx <= replace_byte_idx + 1;
                end

                DONE: begin
                    replacing <= 1'b0;
                end
            endcase
        end
    end

    always_comb begin
        next_state = state;

        case (state)
            IDLE: begin
                if (lookup_done && match_found && cfg_enable) begin
                    next_state = FETCH_TRANSLATION;
                end
            end

            FETCH_TRANSLATION: begin
                // Single cycle to set up
                next_state = REPLACE_TILE;
            end

            REPLACE_TILE: begin
                if (replace_byte_idx == 4'd15) begin
                    next_state = DONE;
                end
            end

            DONE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    //--------------------------------------------------------------------------
    // English tile ROM addressing
    //--------------------------------------------------------------------------

    // Address = char_code * 16 + byte_index
    assign eng_tile_addr = {replacement_char[6:0], replace_byte_idx};

    //--------------------------------------------------------------------------
    // Output generation
    //--------------------------------------------------------------------------

    assign vram_replace_en = replacing && cfg_enable;
    assign vram_replace_data = eng_tile_data;

endmodule


//------------------------------------------------------------------------------
// english_tile_rom.sv
//
// Pre-rendered English character tiles for Replace Mode.
// Contains 96 printable ASCII characters (0x20-0x7F) in GB 2bpp format.
// Each character is 8x8 pixels = 16 bytes.
//------------------------------------------------------------------------------

module english_tile_rom (
    input  logic        clk,
    input  logic [10:0] addr,    // 7-bit char + 4-bit byte offset
    output logic [7:0]  data
);

    // 96 characters * 16 bytes = 1536 bytes
    logic [7:0] rom [0:1535];

    // Initialize with font data (placeholder - actual font loaded from .hex file)
    initial begin
        $readmemh("data/fonts/ascii_8x8_2bpp.hex", rom);
    end

    always_ff @(posedge clk) begin
        data <= rom[addr];
    end

endmodule
