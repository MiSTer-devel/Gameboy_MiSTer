`timescale 1ns / 1ps
//------------------------------------------------------------------------------
// tile_hash_generator.sv
//
// Computes CRC-16 hash of tile data for efficient dictionary lookup.
// Uses CRC-16-CCITT polynomial (0x1021) for good distribution.
//
// Pipeline: Accepts one byte per clock, outputs hash when data_last asserted.
// Latency: 1 cycle after data_last
//
// CRC-16-CCITT:
//   Polynomial: x^16 + x^12 + x^5 + 1 (0x1021)
//   Initial value: 0xFFFF
//   Input reflection: No
//   Output reflection: No
//   Final XOR: 0x0000
//------------------------------------------------------------------------------

module tile_hash_generator (
    input  logic        clk,
    input  logic        rst_n,

    // Streaming byte input
    input  logic        data_valid,     // Input byte ready
    input  logic [7:0]  data_in,        // Input byte
    input  logic        data_last,      // Last byte of sequence

    // Hash output
    output logic        hash_valid,     // Hash computation complete
    output logic [15:0] hash_out        // Computed CRC-16 hash
);

    //--------------------------------------------------------------------------
    // CRC-16 lookup table (for single-byte computation per cycle)
    // Pre-computed for polynomial 0x1021
    //--------------------------------------------------------------------------

    logic [15:0] crc_table [0:255];

    // Initialize lookup table
    initial begin
        for (int i = 0; i < 256; i++) begin
            logic [15:0] crc;
            crc = {i[7:0], 8'h00};
            for (int j = 0; j < 8; j++) begin
                if (crc[15])
                    crc = (crc << 1) ^ 16'h1021;
                else
                    crc = crc << 1;
            end
            crc_table[i] = crc;
        end
    end

    //--------------------------------------------------------------------------
    // CRC state register
    //--------------------------------------------------------------------------

    logic [15:0] crc_reg;
    logic        computing;

    //--------------------------------------------------------------------------
    // CRC computation - one byte per cycle using table lookup
    //--------------------------------------------------------------------------

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            crc_reg <= 16'hFFFF;
            computing <= 1'b0;
            hash_valid <= 1'b0;
            hash_out <= 16'h0000;
        end else begin
            hash_valid <= 1'b0;

            if (data_valid) begin
                // Process one byte
                logic [7:0] table_index;
                logic [15:0] table_value;

                table_index = crc_reg[15:8] ^ data_in;
                table_value = crc_table[table_index];

                crc_reg <= {crc_reg[7:0], 8'h00} ^ table_value;
                computing <= 1'b1;

                if (data_last) begin
                    // Output hash on next cycle
                    hash_out <= {crc_reg[7:0], 8'h00} ^ table_value;
                    hash_valid <= 1'b1;
                    crc_reg <= 16'hFFFF;  // Reset for next tile
                    computing <= 1'b0;
                end
            end else if (!computing) begin
                // Idle - keep CRC at initial value
                crc_reg <= 16'hFFFF;
            end
        end
    end

endmodule


//------------------------------------------------------------------------------
// Alternative: Combinational CRC-16 for faster computation
// (Computes CRC of 8 bytes in a single cycle - useful for parallel processing)
//------------------------------------------------------------------------------

/* verilator lint_off DECLFILENAME */
module tile_hash_generator_fast (
    input  logic        clk,
    input  logic        rst_n,

    // Parallel input (process entire tile at once)
    input  logic        tile_valid,         // Tile data ready
    input  logic [127:0] tile_data,         // 16 bytes of tile data (GB format)

    // Hash output (available next cycle)
    output logic        hash_valid,
    output logic [15:0] hash_out
);

    //--------------------------------------------------------------------------
    // CRC-16 computation function (combinational)
    //--------------------------------------------------------------------------

    function automatic [15:0] crc16_byte(input [15:0] crc_in, input [7:0] data_in);
        logic [15:0] crc;
        crc = crc_in;
        for (int i = 0; i < 8; i++) begin
            if ((crc[15] ^ data_in[7-i]))
                crc = (crc << 1) ^ 16'h1021;
            else
                crc = crc << 1;
        end
        return crc;
    endfunction

    //--------------------------------------------------------------------------
    // Compute full CRC in two cycles (8 bytes per cycle)
    //--------------------------------------------------------------------------

    logic [15:0] crc_partial;
    logic [15:0] crc_final;
    logic        stage;
    logic [127:0] tile_data_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            crc_partial <= 16'hFFFF;
            crc_final <= 16'h0000;
            hash_valid <= 1'b0;
            hash_out <= 16'h0000;
            stage <= 1'b0;
            tile_data_reg <= 128'h0;
        end else begin
            hash_valid <= 1'b0;

            if (tile_valid && !stage) begin
                // Stage 1: Process bytes 0-7
                logic [15:0] crc;
                crc = 16'hFFFF;
                crc = crc16_byte(crc, tile_data[127:120]);  // Byte 0
                crc = crc16_byte(crc, tile_data[119:112]);  // Byte 1
                crc = crc16_byte(crc, tile_data[111:104]);  // Byte 2
                crc = crc16_byte(crc, tile_data[103:96]);   // Byte 3
                crc = crc16_byte(crc, tile_data[95:88]);    // Byte 4
                crc = crc16_byte(crc, tile_data[87:80]);    // Byte 5
                crc = crc16_byte(crc, tile_data[79:72]);    // Byte 6
                crc = crc16_byte(crc, tile_data[71:64]);    // Byte 7

                crc_partial <= crc;
                tile_data_reg <= tile_data;
                stage <= 1'b1;
            end else if (stage) begin
                // Stage 2: Process bytes 8-15
                logic [15:0] crc;
                crc = crc_partial;
                crc = crc16_byte(crc, tile_data_reg[63:56]);   // Byte 8
                crc = crc16_byte(crc, tile_data_reg[55:48]);   // Byte 9
                crc = crc16_byte(crc, tile_data_reg[47:40]);   // Byte 10
                crc = crc16_byte(crc, tile_data_reg[39:32]);   // Byte 11
                crc = crc16_byte(crc, tile_data_reg[31:24]);   // Byte 12
                crc = crc16_byte(crc, tile_data_reg[23:16]);   // Byte 13
                crc = crc16_byte(crc, tile_data_reg[15:8]);    // Byte 14
                crc = crc16_byte(crc, tile_data_reg[7:0]);     // Byte 15

                hash_out <= crc;
                hash_valid <= 1'b1;
                stage <= 1'b0;
            end
        end
    end

endmodule
