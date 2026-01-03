`timescale 1ns / 1ps
//------------------------------------------------------------------------------
// hash_lookup_table.sv
//
// Two-tier lookup system for Japanese character tile identification:
// 1. Bloom filter (fast reject for non-Japanese tiles)
// 2. Hash table (precise character matching)
//
// Bloom Filter:
//   - Configurable size (default 8KB = 65536 bits)
//   - 3 hash functions (variants of input hash)
//   - ~2% false positive rate at 3000 entries
//
// Hash Table:
//   - Configurable buckets (default 4096)
//   - 4-entry chaining per bucket
//   - Entry format: {valid[1], hash[16], char_code[8], translation_ptr[16]}
//
// Rewritten for Icarus Verilog compatibility.
//------------------------------------------------------------------------------

module hash_lookup_table #(
    parameter BLOOM_SIZE_BITS = 65536,      // 8KB
    parameter BLOOM_ADDR_BITS = 16,
    parameter TABLE_BUCKETS = 4096,
    parameter TABLE_ADDR_BITS = 12,
    parameter CHAIN_DEPTH = 4
) (
    input  wire        clk,
    input  wire        rst_n,

    // Hash input
    input  wire        hash_valid,
    input  wire [15:0] hash_in,

    // Match output
    output wire        match_found,
    output wire        lookup_done,
    output wire [7:0]  char_code,
    output wire [15:0] translation_ptr,

    // External memory interface (for large dictionaries)
    output wire        ext_mem_rd,
    output wire [23:0] ext_mem_addr,
    input  wire [31:0] ext_mem_rdata,
    input  wire        ext_mem_rvalid,

    // Dictionary loading interface
    input  wire        dict_load_en,
    input  wire [15:0] dict_load_addr,
    input  wire [40:0] dict_load_data,
    input  wire        bloom_load_en,
    input  wire [15:0] bloom_load_addr,
    input  wire        bloom_load_bit
);

    //--------------------------------------------------------------------------
    // Bloom filter memory
    //--------------------------------------------------------------------------
    reg bloom_mem [0:BLOOM_SIZE_BITS-1];

    // Three hash function variants for Bloom filter
    wire [BLOOM_ADDR_BITS-1:0] bloom_hash1 = hash_in[BLOOM_ADDR_BITS-1:0];
    wire [BLOOM_ADDR_BITS-1:0] bloom_hash2 = {hash_in[7:0], hash_in[15:8]};
    wire [BLOOM_ADDR_BITS-1:0] bloom_hash3 = hash_in[BLOOM_ADDR_BITS-1:0] ^ 16'h5A5A;

    reg bloom_bit1, bloom_bit2, bloom_bit3;
    wire bloom_positive;

    //--------------------------------------------------------------------------
    // Hash table memory - flattened structure
    // Entry: valid[1] + hash[16] + char_code[8] + trans_ptr[16] = 41 bits
    //--------------------------------------------------------------------------
    localparam TABLE_SIZE = TABLE_BUCKETS * CHAIN_DEPTH;
    localparam ENTRY_WIDTH = 41;

    reg [ENTRY_WIDTH-1:0] hash_table [0:TABLE_SIZE-1];

    // Entry field positions
    localparam VALID_BIT = 40;
    localparam HASH_HI = 39;
    localparam HASH_LO = 24;
    localparam CHAR_HI = 23;
    localparam CHAR_LO = 16;
    localparam PTR_HI = 15;
    localparam PTR_LO = 0;

    //--------------------------------------------------------------------------
    // State machine
    //--------------------------------------------------------------------------
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] BLOOM_CHECK = 3'd1;
    localparam [2:0] TABLE_LOOKUP= 3'd2;
    localparam [2:0] CHAIN_SEARCH= 3'd3;
    localparam [2:0] DONE        = 3'd4;

    reg [2:0] state, next_state;

    reg [15:0] current_hash;
    reg [TABLE_ADDR_BITS-1:0] table_bucket;
    reg [1:0]  chain_index;

    // Current entry being examined
    reg [ENTRY_WIDTH-1:0] current_entry;
    wire current_valid      = current_entry[VALID_BIT];
    wire [15:0] current_stored_hash = current_entry[HASH_HI:HASH_LO];
    wire [7:0]  current_char_code   = current_entry[CHAR_HI:CHAR_LO];
    wire [15:0] current_trans_ptr   = current_entry[PTR_HI:PTR_LO];

    //--------------------------------------------------------------------------
    // Bloom filter logic
    //--------------------------------------------------------------------------

    // Bloom filter reads (registered for timing)
    always @(posedge clk) begin
        bloom_bit1 <= bloom_mem[bloom_hash1];
        bloom_bit2 <= bloom_mem[bloom_hash2];
        bloom_bit3 <= bloom_mem[bloom_hash3];
    end

    // Bloom positive if all three bits are set
    assign bloom_positive = bloom_bit1 && bloom_bit2 && bloom_bit3;

    // Bloom filter write (for loading)
    always @(posedge clk) begin
        if (bloom_load_en) begin
            bloom_mem[bloom_load_addr[BLOOM_ADDR_BITS-1:0]] <= bloom_load_bit;
        end
    end

    //--------------------------------------------------------------------------
    // Hash table bucket calculation
    //--------------------------------------------------------------------------
    wire [TABLE_ADDR_BITS-1:0] hash_bucket = hash_in[TABLE_ADDR_BITS-1:0];

    //--------------------------------------------------------------------------
    // State machine - sequential logic
    //--------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_hash <= 16'h0;
            table_bucket <= 0;
            chain_index <= 2'b0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    if (hash_valid) begin
                        current_hash <= hash_in;
                        table_bucket <= hash_bucket;
                        chain_index <= 2'b0;
                    end
                end

                CHAIN_SEARCH: begin
                    if (chain_index < CHAIN_DEPTH - 1) begin
                        chain_index <= chain_index + 1;
                    end
                end
            endcase
        end
    end

    //--------------------------------------------------------------------------
    // State machine - combinational logic
    //--------------------------------------------------------------------------
    always @(*) begin
        next_state = state;

        case (state)
            IDLE: begin
                if (hash_valid) begin
                    next_state = BLOOM_CHECK;
                end
            end

            BLOOM_CHECK: begin
                // Wait one cycle for bloom filter read
                if (bloom_positive)
                    next_state = TABLE_LOOKUP;
                else
                    next_state = DONE;
            end

            TABLE_LOOKUP: begin
                next_state = CHAIN_SEARCH;
            end

            CHAIN_SEARCH: begin
                if (current_valid && current_stored_hash == current_hash) begin
                    // Match found
                    next_state = DONE;
                end else if (chain_index == CHAIN_DEPTH - 1 || !current_valid) begin
                    // End of chain or invalid entry
                    next_state = DONE;
                end
                // Otherwise continue searching chain
            end

            DONE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    //--------------------------------------------------------------------------
    // Hash table read
    //--------------------------------------------------------------------------
    wire [13:0] table_addr = {table_bucket, chain_index};

    always @(posedge clk) begin
        current_entry <= hash_table[table_addr];
    end

    //--------------------------------------------------------------------------
    // Hash table write (for loading)
    //--------------------------------------------------------------------------
    always @(posedge clk) begin
        if (dict_load_en) begin
            hash_table[dict_load_addr[13:0]] <= dict_load_data[ENTRY_WIDTH-1:0];
        end
    end

    //--------------------------------------------------------------------------
    // Output logic
    //--------------------------------------------------------------------------
    reg match_found_reg;
    reg [7:0] char_code_reg;
    reg [15:0] trans_ptr_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            match_found_reg <= 1'b0;
            char_code_reg <= 8'h0;
            trans_ptr_reg <= 16'h0;
        end else if (state == CHAIN_SEARCH &&
                     current_valid &&
                     current_stored_hash == current_hash) begin
            match_found_reg <= 1'b1;
            char_code_reg <= current_char_code;
            trans_ptr_reg <= current_trans_ptr;
        end else if (state == IDLE) begin
            match_found_reg <= 1'b0;
        end
    end

    assign lookup_done = (state == DONE);
    assign match_found = match_found_reg && (state == DONE);
    assign char_code = char_code_reg;
    assign translation_ptr = trans_ptr_reg;

    // External memory not used in this simple implementation
    assign ext_mem_rd = 1'b0;
    assign ext_mem_addr = 24'h0;

endmodule
