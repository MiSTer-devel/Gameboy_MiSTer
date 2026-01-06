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
    parameter BLOOM_SIZE_BITS = 4096,       // Reduced for Quartus synthesis
    parameter BLOOM_ADDR_BITS = 12,
    parameter TABLE_BUCKETS = 256,
    parameter TABLE_ADDR_BITS = 8,
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

    //--------------------------------------------------------------------------
    // Pre-populated hash table with Medarot katakana mappings
    // Entry format: {valid[1], hash[16], char_code[8], trans_ptr[16]}
    // Using 8-bit bucket addresses (hash[7:0]) and 12-bit bloom filter
    //--------------------------------------------------------------------------
    initial begin : init_tables
        integer i;

        // Clear all entries first (1024 entries = 256 buckets * 4 chain)
        for (i = 0; i < TABLE_SIZE; i = i + 1) begin
            hash_table[i] = 41'h0;
        end

        // Clear bloom filter (4096 bits)
        for (i = 0; i < BLOOM_SIZE_BITS; i = i + 1) begin
            bloom_mem[i] = 1'b0;
        end

        //----------------------------------------------------------------------
        // Medarot Katakana Hash Table Entries (47 entries)
        // Bucket = hash[7:0], bloom indices = hash[11:0] masked
        //----------------------------------------------------------------------

        // ア (A) - hash 0x3C53
        hash_table[{8'h53, 2'd0}] = 41'h1_3C53_41_0000;
        bloom_mem[12'hC53] = 1'b1; bloom_mem[12'h33C] = 1'b1; bloom_mem[12'h609] = 1'b1;

        // イ (I) - hash 0x95EB
        hash_table[{8'hEB, 2'd0}] = 41'h1_95EB_49_0000;
        bloom_mem[12'h5EB] = 1'b1; bloom_mem[12'hB95] = 1'b1; bloom_mem[12'hFB1] = 1'b1;

        // ウ (U) - hash 0x58E0
        hash_table[{8'hE0, 2'd0}] = 41'h1_58E0_55_0000;
        bloom_mem[12'h8E0] = 1'b1; bloom_mem[12'h058] = 1'b1; bloom_mem[12'h2BA] = 1'b1;

        // エ (E) - hash 0xCF9F
        hash_table[{8'h9F, 2'd0}] = 41'h1_CF9F_45_0000;
        bloom_mem[12'hF9F] = 1'b1; bloom_mem[12'hFCF] = 1'b1; bloom_mem[12'h5C5] = 1'b1;

        // オ (O) - hash 0x93A0
        hash_table[{8'hA0, 2'd0}] = 41'h1_93A0_4F_0000;
        bloom_mem[12'h3A0] = 1'b1; bloom_mem[12'h093] = 1'b1; bloom_mem[12'h9FA] = 1'b1;

        // カ (KA) - hash 0xD47B
        hash_table[{8'h7B, 2'd0}] = 41'h1_D47B_4B_0000;
        bloom_mem[12'h47B] = 1'b1; bloom_mem[12'hBD4] = 1'b1; bloom_mem[12'hE21] = 1'b1;

        // キ (KI) - hash 0x2B00
        hash_table[{8'h00, 2'd0}] = 41'h1_2B00_4B_0000;
        bloom_mem[12'hB00] = 1'b1; bloom_mem[12'h02B] = 1'b1; bloom_mem[12'h15A] = 1'b1;

        // ク (KU) - hash 0xB9B6
        hash_table[{8'hB6, 2'd0}] = 41'h1_B9B6_4B_0000;
        bloom_mem[12'h9B6] = 1'b1; bloom_mem[12'h6B9] = 1'b1; bloom_mem[12'h3EC] = 1'b1;

        // ケ (KE) - hash 0xC8F4
        hash_table[{8'hF4, 2'd0}] = 41'h1_C8F4_4B_0000;
        bloom_mem[12'h8F4] = 1'b1; bloom_mem[12'h4C8] = 1'b1; bloom_mem[12'h2AE] = 1'b1;

        // コ (KO) - hash 0xC01D
        hash_table[{8'h1D, 2'd0}] = 41'h1_C01D_4B_0000;
        bloom_mem[12'h01D] = 1'b1; bloom_mem[12'hDC0] = 1'b1; bloom_mem[12'hA47] = 1'b1;

        // サ (SA) - hash 0xBDB8
        hash_table[{8'hB8, 2'd0}] = 41'h1_BDB8_53_0000;
        bloom_mem[12'hDB8] = 1'b1; bloom_mem[12'h8BD] = 1'b1; bloom_mem[12'h7E2] = 1'b1;

        // シ (SHI) - hash 0x381F
        hash_table[{8'h1F, 2'd0}] = 41'h1_381F_53_0000;
        bloom_mem[12'h81F] = 1'b1; bloom_mem[12'hF38] = 1'b1; bloom_mem[12'h245] = 1'b1;

        // ス (SU) - hash 0xB576
        hash_table[{8'h76, 2'd0}] = 41'h1_B576_53_0000;
        bloom_mem[12'h576] = 1'b1; bloom_mem[12'h6B5] = 1'b1; bloom_mem[12'hF2C] = 1'b1;

        // セ (SE) - hash 0x9854
        hash_table[{8'h54, 2'd0}] = 41'h1_9854_53_0000;
        bloom_mem[12'h854] = 1'b1; bloom_mem[12'h498] = 1'b1; bloom_mem[12'h20E] = 1'b1;

        // ソ (SO) - hash 0xAF36
        hash_table[{8'h36, 2'd0}] = 41'h1_AF36_53_0000;
        bloom_mem[12'hF36] = 1'b1; bloom_mem[12'h6AF] = 1'b1; bloom_mem[12'h56C] = 1'b1;

        // タ (TA) - hash 0xAE7F
        hash_table[{8'h7F, 2'd0}] = 41'h1_AE7F_54_0000;
        bloom_mem[12'hE7F] = 1'b1; bloom_mem[12'hFAE] = 1'b1; bloom_mem[12'h425] = 1'b1;

        // チ (CHI) - hash 0x98C2
        hash_table[{8'hC2, 2'd0}] = 41'h1_98C2_43_0000;
        bloom_mem[12'h8C2] = 1'b1; bloom_mem[12'h298] = 1'b1; bloom_mem[12'h298] = 1'b1;

        // ツ (TSU) - hash 0x3DE0
        hash_table[{8'hE0, 2'd1}] = 41'h1_3DE0_54_0000;  // chain slot 1 (ウ uses slot 0)
        bloom_mem[12'hDE0] = 1'b1; bloom_mem[12'h03D] = 1'b1; bloom_mem[12'h7BA] = 1'b1;

        // テ (TE) - hash 0x7A04
        hash_table[{8'h04, 2'd0}] = 41'h1_7A04_54_0000;
        bloom_mem[12'hA04] = 1'b1; bloom_mem[12'h47A] = 1'b1; bloom_mem[12'h05E] = 1'b1;

        // ト (TO) - hash 0xF66F
        hash_table[{8'h6F, 2'd0}] = 41'h1_F66F_54_0000;
        bloom_mem[12'h66F] = 1'b1; bloom_mem[12'hFF6] = 1'b1; bloom_mem[12'hC35] = 1'b1;

        // ナ (NA) - hash 0x790E
        hash_table[{8'h0E, 2'd0}] = 41'h1_790E_4E_0000;
        bloom_mem[12'h90E] = 1'b1; bloom_mem[12'hE79] = 1'b1; bloom_mem[12'h354] = 1'b1;

        // ニ (NI) - hash 0x69EB
        hash_table[{8'hEB, 2'd1}] = 41'h1_69EB_4E_0000;  // chain slot 1 (イ uses slot 0)
        bloom_mem[12'h9EB] = 1'b1; bloom_mem[12'hB69] = 1'b1; bloom_mem[12'h3B1] = 1'b1;

        // ヌ (NU) - hash 0x116C
        hash_table[{8'h6C, 2'd0}] = 41'h1_116C_4E_0000;
        bloom_mem[12'h16C] = 1'b1; bloom_mem[12'hC11] = 1'b1; bloom_mem[12'hB36] = 1'b1;

        // ネ (NE) - hash 0xD209
        hash_table[{8'h09, 2'd0}] = 41'h1_D209_4E_0000;
        bloom_mem[12'h209] = 1'b1; bloom_mem[12'h9D2] = 1'b1; bloom_mem[12'h853] = 1'b1;

        // ノ (NO) - hash 0x54AE
        hash_table[{8'hAE, 2'd0}] = 41'h1_54AE_4E_0000;
        bloom_mem[12'h4AE] = 1'b1; bloom_mem[12'hE54] = 1'b1; bloom_mem[12'hEF4] = 1'b1;

        // ハ (HA) - hash 0x0DB5
        hash_table[{8'hB5, 2'd0}] = 41'h1_0DB5_48_0000;
        bloom_mem[12'hDB5] = 1'b1; bloom_mem[12'h50D] = 1'b1; bloom_mem[12'h7EF] = 1'b1;

        // ヒ (HI) - hash 0xF8D0
        hash_table[{8'hD0, 2'd0}] = 41'h1_F8D0_48_0000;
        bloom_mem[12'h8D0] = 1'b1; bloom_mem[12'h0F8] = 1'b1; bloom_mem[12'h28A] = 1'b1;

        // フ (FU) - hash 0xA55A
        hash_table[{8'h5A, 2'd0}] = 41'h1_A55A_46_0000;
        bloom_mem[12'h55A] = 1'b1; bloom_mem[12'hAA5] = 1'b1; bloom_mem[12'hF00] = 1'b1;

        // ヘ (HE) - hash 0xC791
        hash_table[{8'h91, 2'd0}] = 41'h1_C791_48_0000;
        bloom_mem[12'h791] = 1'b1; bloom_mem[12'h1C7] = 1'b1; bloom_mem[12'hDCB] = 1'b1;

        // ホ (HO) - hash 0x1E00
        hash_table[{8'h00, 2'd1}] = 41'h1_1E00_48_0000;  // chain slot 1 (キ uses slot 0)
        bloom_mem[12'hE00] = 1'b1; bloom_mem[12'h01E] = 1'b1; bloom_mem[12'h45A] = 1'b1;

        // マ (MA) - hash 0xE1C9
        hash_table[{8'hC9, 2'd0}] = 41'h1_E1C9_4D_0000;
        bloom_mem[12'h1C9] = 1'b1; bloom_mem[12'h9E1] = 1'b1; bloom_mem[12'hB93] = 1'b1;

        // ミ (MI) - hash 0xDB1B
        hash_table[{8'h1B, 2'd0}] = 41'h1_DB1B_4D_0000;
        bloom_mem[12'hB1B] = 1'b1; bloom_mem[12'hBDB] = 1'b1; bloom_mem[12'h141] = 1'b1;

        // ム (MU) - hash 0x64EA
        hash_table[{8'hEA, 2'd0}] = 41'h1_64EA_4D_0000;
        bloom_mem[12'h4EA] = 1'b1; bloom_mem[12'hA64] = 1'b1; bloom_mem[12'hEB0] = 1'b1;

        // メ (ME) - hash 0x821B
        hash_table[{8'h1B, 2'd1}] = 41'h1_821B_4D_0000;  // chain slot 1 (ミ uses slot 0)
        bloom_mem[12'h21B] = 1'b1; bloom_mem[12'hB82] = 1'b1; bloom_mem[12'h841] = 1'b1;

        // モ (MO) - hash 0x5078
        hash_table[{8'h78, 2'd0}] = 41'h1_5078_4D_0000;
        bloom_mem[12'h078] = 1'b1; bloom_mem[12'h850] = 1'b1; bloom_mem[12'hA22] = 1'b1;

        // ヤ (YA) - hash 0x7C3B
        hash_table[{8'h3B, 2'd0}] = 41'h1_7C3B_59_0000;
        bloom_mem[12'hC3B] = 1'b1; bloom_mem[12'hB7C] = 1'b1; bloom_mem[12'h661] = 1'b1;

        // ユ (YU) - hash 0xC078
        hash_table[{8'h78, 2'd1}] = 41'h1_C078_59_0000;  // chain slot 1 (モ uses slot 0)
        bloom_mem[12'h078] = 1'b1; bloom_mem[12'h8C0] = 1'b1; bloom_mem[12'hA22] = 1'b1;

        // ヨ (YO) - hash 0x3131
        hash_table[{8'h31, 2'd0}] = 41'h1_3131_59_0000;
        bloom_mem[12'h131] = 1'b1; bloom_mem[12'h131] = 1'b1; bloom_mem[12'hB6B] = 1'b1;

        // ラ (RA) - hash 0x268F
        hash_table[{8'h8F, 2'd0}] = 41'h1_268F_52_0000;
        bloom_mem[12'h68F] = 1'b1; bloom_mem[12'hF26] = 1'b1; bloom_mem[12'hCD5] = 1'b1;

        // リ (RI) - hash 0xAEA2
        hash_table[{8'hA2, 2'd0}] = 41'h1_AEA2_52_0000;
        bloom_mem[12'hEA2] = 1'b1; bloom_mem[12'h2AE] = 1'b1; bloom_mem[12'h4F8] = 1'b1;

        // ル (RU) - hash 0x87C5
        hash_table[{8'hC5, 2'd0}] = 41'h1_87C5_52_0000;
        bloom_mem[12'h7C5] = 1'b1; bloom_mem[12'h587] = 1'b1; bloom_mem[12'hD9F] = 1'b1;

        // レ (RE) - hash 0xC996
        hash_table[{8'h96, 2'd0}] = 41'h1_C996_52_0000;
        bloom_mem[12'h996] = 1'b1; bloom_mem[12'h6C9] = 1'b1; bloom_mem[12'h3CC] = 1'b1;

        // ロ (RO) - hash 0xA23E
        hash_table[{8'h3E, 2'd0}] = 41'h1_A23E_52_0000;
        bloom_mem[12'h23E] = 1'b1; bloom_mem[12'hEA2] = 1'b1; bloom_mem[12'h864] = 1'b1;

        // ワ (WA) - hash 0xD7F5
        hash_table[{8'hF5, 2'd0}] = 41'h1_D7F5_57_0000;
        bloom_mem[12'h7F5] = 1'b1; bloom_mem[12'h5D7] = 1'b1; bloom_mem[12'hDAF] = 1'b1;

        // ヲ (WO) - hash 0xAE8A
        hash_table[{8'h8A, 2'd0}] = 41'h1_AE8A_57_0000;
        bloom_mem[12'hE8A] = 1'b1; bloom_mem[12'hAAE] = 1'b1; bloom_mem[12'h4D0] = 1'b1;

        // ン (N) - hash 0xE288
        hash_table[{8'h88, 2'd0}] = 41'h1_E288_4E_0000;
        bloom_mem[12'h288] = 1'b1; bloom_mem[12'h8E2] = 1'b1; bloom_mem[12'h8D2] = 1'b1;

        // ー (long vowel) - hash 0x563C
        hash_table[{8'h3C, 2'd0}] = 41'h1_563C_2D_0000;
        bloom_mem[12'h63C] = 1'b1; bloom_mem[12'hC56] = 1'b1; bloom_mem[12'hC66] = 1'b1;
    end

endmodule
