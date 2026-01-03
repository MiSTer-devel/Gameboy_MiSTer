`timescale 1ns / 1ps
//------------------------------------------------------------------------------
// vram_snooper.sv
//
// Monitors VRAM writes to detect and capture tile data for Japanese text
// detection. Buffers complete 8x8 tiles (16 bytes for GB 2bpp format) and
// streams them to the hash generator.
//
// GB VRAM Layout (8KB):
//   0x8000-0x97FF: Tile Data (384 tiles, 6KB) - where we snoop
//   0x9800-0x9BFF: BG Map 1 (1KB)
//   0x9C00-0x9FFF: BG Map 2 (1KB)
//
// GB Tile Format (2bpp, 16 bytes per 8x8 tile):
//   Each row is 2 bytes: low bits in byte 0, high bits in byte 1
//   8 rows = 16 bytes total
//------------------------------------------------------------------------------

module vram_snooper #(
    parameter TILE_SIZE_BYTES = 16,     // GB: 16 bytes (2bpp), GBA: 32 bytes (4bpp)
    parameter VRAM_TILE_START = 13'h0000,   // Start of tile data region
    parameter VRAM_TILE_END   = 13'h17FF    // End of tile data region (6KB)
) (
    input  logic        clk,
    input  logic        rst_n,

    // VRAM write monitoring (directly from memory bus)
    input  logic        vram_we,        // VRAM write enable
    input  logic [12:0] vram_addr,      // VRAM address (13-bit for 8KB)
    input  logic [7:0]  vram_wdata,     // VRAM write data

    // Tile capture status
    output logic        tile_capture_done,  // Complete tile captured
    output logic [8:0]  tile_index,         // Which tile (0-383 for GB)
    output logic        tile_is_text_region,// Hint: address in typical text tile area

    // Stream to hash generator
    output logic        hash_data_valid,    // Byte ready for hashing
    output logic [7:0]  hash_data,          // Byte to hash
    output logic        hash_data_last,     // Last byte of tile

    // Configuration
    input  logic        cfg_enable,         // Snooping enabled
    input  logic [8:0]  cfg_text_tile_start,// First tile index of text font
    input  logic [8:0]  cfg_text_tile_end   // Last tile index of text font
);

    //--------------------------------------------------------------------------
    // Internal state
    //--------------------------------------------------------------------------

    // Tile buffer - stores complete tile before hashing
    logic [7:0] tile_buffer [0:TILE_SIZE_BYTES-1];

    // Current tile tracking
    logic [8:0]  capturing_tile;        // Tile we're capturing
    logic [3:0]  bytes_captured;        // Bytes received for current tile
    logic [15:0] tile_write_mask;       // Which bytes have been written
    logic        capture_in_progress;

    // State machine
    typedef enum logic [2:0] {
        IDLE,
        CAPTURING,
        STREAMING,
        DONE
    } state_t;

    state_t state, next_state;

    // Streaming counter
    logic [3:0] stream_index;

    //--------------------------------------------------------------------------
    // Address decoding
    //--------------------------------------------------------------------------

    // Check if address is in tile data region
    // verilator lint_off UNSIGNED
    wire in_tile_region = (vram_addr >= VRAM_TILE_START[12:0]) &&
                          (vram_addr <= VRAM_TILE_END[12:0]);
    // verilator lint_on UNSIGNED

    // Calculate tile index from address (16 bytes per tile)
    wire [8:0] addr_tile_index = vram_addr[12:4];  // Divide by 16

    // Calculate byte offset within tile
    wire [3:0] addr_byte_offset = vram_addr[3:0];

    // Check if this tile is in the configured text font range
    wire in_text_range = (addr_tile_index >= cfg_text_tile_start) &&
                         (addr_tile_index <= cfg_text_tile_end);

    //--------------------------------------------------------------------------
    // Tile buffer capture logic
    //--------------------------------------------------------------------------

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < TILE_SIZE_BYTES; i++) begin
                tile_buffer[i] <= 8'h00;
            end
            tile_write_mask <= 16'h0000;
            capturing_tile <= 9'd0;
            capture_in_progress <= 1'b0;
        end else if (cfg_enable && vram_we && in_tile_region) begin
            // VRAM write detected in tile region

            if (!capture_in_progress || (addr_tile_index != capturing_tile)) begin
                // Start capturing new tile
                capturing_tile <= addr_tile_index;
                capture_in_progress <= 1'b1;

                // Reset buffer for new tile
                tile_write_mask <= 16'h0000;
                for (int i = 0; i < TILE_SIZE_BYTES; i++) begin
                    tile_buffer[i] <= 8'h00;
                end
            end

            // Store byte in buffer
            tile_buffer[addr_byte_offset] <= vram_wdata;
            tile_write_mask[addr_byte_offset] <= 1'b1;
        end
    end

    // Count captured bytes
    always_comb begin
        bytes_captured = 4'd0;
        for (int i = 0; i < TILE_SIZE_BYTES; i++) begin
            bytes_captured = bytes_captured + {3'b0, tile_write_mask[i]};
        end
    end

    // Tile complete when all 16 bytes captured
    wire tile_complete = (tile_write_mask == 16'hFFFF);

    //--------------------------------------------------------------------------
    // State machine
    //--------------------------------------------------------------------------

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    always_comb begin
        next_state = state;

        case (state)
            IDLE: begin
                if (capture_in_progress && tile_complete) begin
                    next_state = STREAMING;
                end
            end

            STREAMING: begin
                if (stream_index == 4'(TILE_SIZE_BYTES - 1)) begin
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
    // Streaming to hash generator
    //--------------------------------------------------------------------------

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stream_index <= 4'd0;
        end else if (state == IDLE) begin
            stream_index <= 4'd0;
        end else if (state == STREAMING) begin
            stream_index <= stream_index + 1;
        end
    end

    //--------------------------------------------------------------------------
    // Output assignments
    //--------------------------------------------------------------------------

    // Hash data streaming
    assign hash_data_valid = (state == STREAMING);
    assign hash_data = tile_buffer[stream_index];
    assign hash_data_last = (state == STREAMING) && (stream_index == 4'(TILE_SIZE_BYTES - 1));

    // Capture status
    assign tile_capture_done = (state == DONE);
    assign tile_index = capturing_tile;
    assign tile_is_text_region = in_text_range;

    //--------------------------------------------------------------------------
    // Clear capture state after streaming complete
    //--------------------------------------------------------------------------

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled above
        end else if (state == DONE) begin
            capture_in_progress <= 1'b0;
            tile_write_mask <= 16'h0000;
        end
    end

endmodule
