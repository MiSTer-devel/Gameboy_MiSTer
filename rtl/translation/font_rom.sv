//------------------------------------------------------------------------------
// font_rom.sv
//
// 8x8 ASCII bitmap font ROM for caption rendering.
// Contains 128 characters (0x00-0x7F), each 8 bytes (8x8 pixels, 1bpp).
// Total: 1024 bytes.
//
// Font format: Each byte represents one row, MSB is leftmost pixel.
//------------------------------------------------------------------------------

module font_rom (
    input  logic        clk,
    input  logic [10:0] addr,   // [10:3] = char code, [2:0] = row
    output logic [7:0]  data
);

    // 128 characters * 8 bytes = 1024 bytes
    logic [7:0] rom [0:1023];

    // Initialize with embedded font data
    // This is a basic 8x8 ASCII font
    initial begin
        // Initialize all to zero first
        for (int i = 0; i < 1024; i++) begin
            rom[i] = 8'h00;
        end

        // Space (0x20)
        rom['h100] = 8'h00; rom['h101] = 8'h00; rom['h102] = 8'h00; rom['h103] = 8'h00;
        rom['h104] = 8'h00; rom['h105] = 8'h00; rom['h106] = 8'h00; rom['h107] = 8'h00;

        // ! (0x21)
        rom['h108] = 8'h18; rom['h109] = 8'h18; rom['h10A] = 8'h18; rom['h10B] = 8'h18;
        rom['h10C] = 8'h18; rom['h10D] = 8'h00; rom['h10E] = 8'h18; rom['h10F] = 8'h00;

        // " (0x22)
        rom['h110] = 8'h6C; rom['h111] = 8'h6C; rom['h112] = 8'h24; rom['h113] = 8'h00;
        rom['h114] = 8'h00; rom['h115] = 8'h00; rom['h116] = 8'h00; rom['h117] = 8'h00;

        // # (0x23)
        rom['h118] = 8'h6C; rom['h119] = 8'h6C; rom['h11A] = 8'hFE; rom['h11B] = 8'h6C;
        rom['h11C] = 8'hFE; rom['h11D] = 8'h6C; rom['h11E] = 8'h6C; rom['h11F] = 8'h00;

        // ... (continuing for all printable ASCII)
        // For brevity, including key characters:

        // A (0x41)
        rom['h208] = 8'h10; rom['h209] = 8'h38; rom['h20A] = 8'h6C; rom['h20B] = 8'hC6;
        rom['h20C] = 8'hFE; rom['h20D] = 8'hC6; rom['h20E] = 8'hC6; rom['h20F] = 8'h00;

        // B (0x42)
        rom['h210] = 8'hFC; rom['h211] = 8'h66; rom['h212] = 8'h66; rom['h213] = 8'h7C;
        rom['h214] = 8'h66; rom['h215] = 8'h66; rom['h216] = 8'hFC; rom['h217] = 8'h00;

        // C (0x43)
        rom['h218] = 8'h3C; rom['h219] = 8'h66; rom['h21A] = 8'hC0; rom['h21B] = 8'hC0;
        rom['h21C] = 8'hC0; rom['h21D] = 8'h66; rom['h21E] = 8'h3C; rom['h21F] = 8'h00;

        // D (0x44)
        rom['h220] = 8'hF8; rom['h221] = 8'h6C; rom['h222] = 8'h66; rom['h223] = 8'h66;
        rom['h224] = 8'h66; rom['h225] = 8'h6C; rom['h226] = 8'hF8; rom['h227] = 8'h00;

        // E (0x45)
        rom['h228] = 8'hFE; rom['h229] = 8'h62; rom['h22A] = 8'h68; rom['h22B] = 8'h78;
        rom['h22C] = 8'h68; rom['h22D] = 8'h62; rom['h22E] = 8'hFE; rom['h22F] = 8'h00;

        // F (0x46)
        rom['h230] = 8'hFE; rom['h231] = 8'h62; rom['h232] = 8'h68; rom['h233] = 8'h78;
        rom['h234] = 8'h68; rom['h235] = 8'h60; rom['h236] = 8'hF0; rom['h237] = 8'h00;

        // G (0x47)
        rom['h238] = 8'h3C; rom['h239] = 8'h66; rom['h23A] = 8'hC0; rom['h23B] = 8'hC0;
        rom['h23C] = 8'hCE; rom['h23D] = 8'h66; rom['h23E] = 8'h3E; rom['h23F] = 8'h00;

        // H (0x48)
        rom['h240] = 8'hC6; rom['h241] = 8'hC6; rom['h242] = 8'hC6; rom['h243] = 8'hFE;
        rom['h244] = 8'hC6; rom['h245] = 8'hC6; rom['h246] = 8'hC6; rom['h247] = 8'h00;

        // I (0x49)
        rom['h248] = 8'h3C; rom['h249] = 8'h18; rom['h24A] = 8'h18; rom['h24B] = 8'h18;
        rom['h24C] = 8'h18; rom['h24D] = 8'h18; rom['h24E] = 8'h3C; rom['h24F] = 8'h00;

        // J (0x4A)
        rom['h250] = 8'h1E; rom['h251] = 8'h0C; rom['h252] = 8'h0C; rom['h253] = 8'h0C;
        rom['h254] = 8'hCC; rom['h255] = 8'hCC; rom['h256] = 8'h78; rom['h257] = 8'h00;

        // K (0x4B)
        rom['h258] = 8'hE6; rom['h259] = 8'h66; rom['h25A] = 8'h6C; rom['h25B] = 8'h78;
        rom['h25C] = 8'h6C; rom['h25D] = 8'h66; rom['h25E] = 8'hE6; rom['h25F] = 8'h00;

        // L (0x4C)
        rom['h260] = 8'hF0; rom['h261] = 8'h60; rom['h262] = 8'h60; rom['h263] = 8'h60;
        rom['h264] = 8'h62; rom['h265] = 8'h66; rom['h266] = 8'hFE; rom['h267] = 8'h00;

        // M (0x4D)
        rom['h268] = 8'hC6; rom['h269] = 8'hEE; rom['h26A] = 8'hFE; rom['h26B] = 8'hFE;
        rom['h26C] = 8'hD6; rom['h26D] = 8'hC6; rom['h26E] = 8'hC6; rom['h26F] = 8'h00;

        // N (0x4E)
        rom['h270] = 8'hC6; rom['h271] = 8'hE6; rom['h272] = 8'hF6; rom['h273] = 8'hDE;
        rom['h274] = 8'hCE; rom['h275] = 8'hC6; rom['h276] = 8'hC6; rom['h277] = 8'h00;

        // O (0x4F)
        rom['h278] = 8'h38; rom['h279] = 8'h6C; rom['h27A] = 8'hC6; rom['h27B] = 8'hC6;
        rom['h27C] = 8'hC6; rom['h27D] = 8'h6C; rom['h27E] = 8'h38; rom['h27F] = 8'h00;

        // P (0x50)
        rom['h280] = 8'hFC; rom['h281] = 8'h66; rom['h282] = 8'h66; rom['h283] = 8'h7C;
        rom['h284] = 8'h60; rom['h285] = 8'h60; rom['h286] = 8'hF0; rom['h287] = 8'h00;

        // Q (0x51)
        rom['h288] = 8'h78; rom['h289] = 8'hCC; rom['h28A] = 8'hCC; rom['h28B] = 8'hCC;
        rom['h28C] = 8'hDC; rom['h28D] = 8'h78; rom['h28E] = 8'h1C; rom['h28F] = 8'h00;

        // R (0x52)
        rom['h290] = 8'hFC; rom['h291] = 8'h66; rom['h292] = 8'h66; rom['h293] = 8'h7C;
        rom['h294] = 8'h6C; rom['h295] = 8'h66; rom['h296] = 8'hE6; rom['h297] = 8'h00;

        // S (0x53)
        rom['h298] = 8'h78; rom['h299] = 8'hCC; rom['h29A] = 8'hE0; rom['h29B] = 8'h70;
        rom['h29C] = 8'h1C; rom['h29D] = 8'hCC; rom['h29E] = 8'h78; rom['h29F] = 8'h00;

        // T (0x54)
        rom['h2A0] = 8'hFC; rom['h2A1] = 8'hB4; rom['h2A2] = 8'h30; rom['h2A3] = 8'h30;
        rom['h2A4] = 8'h30; rom['h2A5] = 8'h30; rom['h2A6] = 8'h78; rom['h2A7] = 8'h00;

        // U (0x55)
        rom['h2A8] = 8'hCC; rom['h2A9] = 8'hCC; rom['h2AA] = 8'hCC; rom['h2AB] = 8'hCC;
        rom['h2AC] = 8'hCC; rom['h2AD] = 8'hCC; rom['h2AE] = 8'hFC; rom['h2AF] = 8'h00;

        // V (0x56)
        rom['h2B0] = 8'hCC; rom['h2B1] = 8'hCC; rom['h2B2] = 8'hCC; rom['h2B3] = 8'hCC;
        rom['h2B4] = 8'hCC; rom['h2B5] = 8'h78; rom['h2B6] = 8'h30; rom['h2B7] = 8'h00;

        // W (0x57)
        rom['h2B8] = 8'hC6; rom['h2B9] = 8'hC6; rom['h2BA] = 8'hC6; rom['h2BB] = 8'hD6;
        rom['h2BC] = 8'hFE; rom['h2BD] = 8'hEE; rom['h2BE] = 8'hC6; rom['h2BF] = 8'h00;

        // X (0x58)
        rom['h2C0] = 8'hC6; rom['h2C1] = 8'hC6; rom['h2C2] = 8'h6C; rom['h2C3] = 8'h38;
        rom['h2C4] = 8'h38; rom['h2C5] = 8'h6C; rom['h2C6] = 8'hC6; rom['h2C7] = 8'h00;

        // Y (0x59)
        rom['h2C8] = 8'hCC; rom['h2C9] = 8'hCC; rom['h2CA] = 8'hCC; rom['h2CB] = 8'h78;
        rom['h2CC] = 8'h30; rom['h2CD] = 8'h30; rom['h2CE] = 8'h78; rom['h2CF] = 8'h00;

        // Z (0x5A)
        rom['h2D0] = 8'hFE; rom['h2D1] = 8'hC6; rom['h2D2] = 8'h8C; rom['h2D3] = 8'h18;
        rom['h2D4] = 8'h32; rom['h2D5] = 8'h66; rom['h2D6] = 8'hFE; rom['h2D7] = 8'h00;

        // Lowercase letters (0x61-0x7A)
        // a (0x61)
        rom['h308] = 8'h00; rom['h309] = 8'h00; rom['h30A] = 8'h78; rom['h30B] = 8'h0C;
        rom['h30C] = 8'h7C; rom['h30D] = 8'hCC; rom['h30E] = 8'h76; rom['h30F] = 8'h00;

        // b (0x62)
        rom['h310] = 8'hE0; rom['h311] = 8'h60; rom['h312] = 8'h60; rom['h313] = 8'h7C;
        rom['h314] = 8'h66; rom['h315] = 8'h66; rom['h316] = 8'hDC; rom['h317] = 8'h00;

        // c (0x63)
        rom['h318] = 8'h00; rom['h319] = 8'h00; rom['h31A] = 8'h78; rom['h31B] = 8'hCC;
        rom['h31C] = 8'hC0; rom['h31D] = 8'hCC; rom['h31E] = 8'h78; rom['h31F] = 8'h00;

        // d (0x64)
        rom['h320] = 8'h1C; rom['h321] = 8'h0C; rom['h322] = 8'h0C; rom['h323] = 8'h7C;
        rom['h324] = 8'hCC; rom['h325] = 8'hCC; rom['h326] = 8'h76; rom['h327] = 8'h00;

        // e (0x65)
        rom['h328] = 8'h00; rom['h329] = 8'h00; rom['h32A] = 8'h78; rom['h32B] = 8'hCC;
        rom['h32C] = 8'hFC; rom['h32D] = 8'hC0; rom['h32E] = 8'h78; rom['h32F] = 8'h00;

        // f (0x66)
        rom['h330] = 8'h38; rom['h331] = 8'h6C; rom['h332] = 8'h60; rom['h333] = 8'hF0;
        rom['h334] = 8'h60; rom['h335] = 8'h60; rom['h336] = 8'hF0; rom['h337] = 8'h00;

        // g (0x67)
        rom['h338] = 8'h00; rom['h339] = 8'h00; rom['h33A] = 8'h76; rom['h33B] = 8'hCC;
        rom['h33C] = 8'hCC; rom['h33D] = 8'h7C; rom['h33E] = 8'h0C; rom['h33F] = 8'hF8;

        // h (0x68)
        rom['h340] = 8'hE0; rom['h341] = 8'h60; rom['h342] = 8'h6C; rom['h343] = 8'h76;
        rom['h344] = 8'h66; rom['h345] = 8'h66; rom['h346] = 8'hE6; rom['h347] = 8'h00;

        // i (0x69)
        rom['h348] = 8'h30; rom['h349] = 8'h00; rom['h34A] = 8'h70; rom['h34B] = 8'h30;
        rom['h34C] = 8'h30; rom['h34D] = 8'h30; rom['h34E] = 8'h78; rom['h34F] = 8'h00;

        // j (0x6A)
        rom['h350] = 8'h0C; rom['h351] = 8'h00; rom['h352] = 8'h0C; rom['h353] = 8'h0C;
        rom['h354] = 8'h0C; rom['h355] = 8'hCC; rom['h356] = 8'hCC; rom['h357] = 8'h78;

        // k (0x6B)
        rom['h358] = 8'hE0; rom['h359] = 8'h60; rom['h35A] = 8'h66; rom['h35B] = 8'h6C;
        rom['h35C] = 8'h78; rom['h35D] = 8'h6C; rom['h35E] = 8'hE6; rom['h35F] = 8'h00;

        // l (0x6C)
        rom['h360] = 8'h70; rom['h361] = 8'h30; rom['h362] = 8'h30; rom['h363] = 8'h30;
        rom['h364] = 8'h30; rom['h365] = 8'h30; rom['h366] = 8'h78; rom['h367] = 8'h00;

        // m (0x6D)
        rom['h368] = 8'h00; rom['h369] = 8'h00; rom['h36A] = 8'hCC; rom['h36B] = 8'hFE;
        rom['h36C] = 8'hFE; rom['h36D] = 8'hD6; rom['h36E] = 8'hC6; rom['h36F] = 8'h00;

        // n (0x6E)
        rom['h370] = 8'h00; rom['h371] = 8'h00; rom['h372] = 8'hF8; rom['h373] = 8'hCC;
        rom['h374] = 8'hCC; rom['h375] = 8'hCC; rom['h376] = 8'hCC; rom['h377] = 8'h00;

        // o (0x6F)
        rom['h378] = 8'h00; rom['h379] = 8'h00; rom['h37A] = 8'h78; rom['h37B] = 8'hCC;
        rom['h37C] = 8'hCC; rom['h37D] = 8'hCC; rom['h37E] = 8'h78; rom['h37F] = 8'h00;

        // p (0x70)
        rom['h380] = 8'h00; rom['h381] = 8'h00; rom['h382] = 8'hDC; rom['h383] = 8'h66;
        rom['h384] = 8'h66; rom['h385] = 8'h7C; rom['h386] = 8'h60; rom['h387] = 8'hF0;

        // q (0x71)
        rom['h388] = 8'h00; rom['h389] = 8'h00; rom['h38A] = 8'h76; rom['h38B] = 8'hCC;
        rom['h38C] = 8'hCC; rom['h38D] = 8'h7C; rom['h38E] = 8'h0C; rom['h38F] = 8'h1E;

        // r (0x72)
        rom['h390] = 8'h00; rom['h391] = 8'h00; rom['h392] = 8'hDC; rom['h393] = 8'h76;
        rom['h394] = 8'h66; rom['h395] = 8'h60; rom['h396] = 8'hF0; rom['h397] = 8'h00;

        // s (0x73)
        rom['h398] = 8'h00; rom['h399] = 8'h00; rom['h39A] = 8'h7C; rom['h39B] = 8'hC0;
        rom['h39C] = 8'h78; rom['h39D] = 8'h0C; rom['h39E] = 8'hF8; rom['h39F] = 8'h00;

        // t (0x74)
        rom['h3A0] = 8'h10; rom['h3A1] = 8'h30; rom['h3A2] = 8'h7C; rom['h3A3] = 8'h30;
        rom['h3A4] = 8'h30; rom['h3A5] = 8'h34; rom['h3A6] = 8'h18; rom['h3A7] = 8'h00;

        // u (0x75)
        rom['h3A8] = 8'h00; rom['h3A9] = 8'h00; rom['h3AA] = 8'hCC; rom['h3AB] = 8'hCC;
        rom['h3AC] = 8'hCC; rom['h3AD] = 8'hCC; rom['h3AE] = 8'h76; rom['h3AF] = 8'h00;

        // v (0x76)
        rom['h3B0] = 8'h00; rom['h3B1] = 8'h00; rom['h3B2] = 8'hCC; rom['h3B3] = 8'hCC;
        rom['h3B4] = 8'hCC; rom['h3B5] = 8'h78; rom['h3B6] = 8'h30; rom['h3B7] = 8'h00;

        // w (0x77)
        rom['h3B8] = 8'h00; rom['h3B9] = 8'h00; rom['h3BA] = 8'hC6; rom['h3BB] = 8'hD6;
        rom['h3BC] = 8'hFE; rom['h3BD] = 8'hFE; rom['h3BE] = 8'h6C; rom['h3BF] = 8'h00;

        // x (0x78)
        rom['h3C0] = 8'h00; rom['h3C1] = 8'h00; rom['h3C2] = 8'hC6; rom['h3C3] = 8'h6C;
        rom['h3C4] = 8'h38; rom['h3C5] = 8'h6C; rom['h3C6] = 8'hC6; rom['h3C7] = 8'h00;

        // y (0x79)
        rom['h3C8] = 8'h00; rom['h3C9] = 8'h00; rom['h3CA] = 8'hCC; rom['h3CB] = 8'hCC;
        rom['h3CC] = 8'hCC; rom['h3CD] = 8'h7C; rom['h3CE] = 8'h0C; rom['h3CF] = 8'hF8;

        // z (0x7A)
        rom['h3D0] = 8'h00; rom['h3D1] = 8'h00; rom['h3D2] = 8'hFC; rom['h3D3] = 8'h98;
        rom['h3D4] = 8'h30; rom['h3D5] = 8'h64; rom['h3D6] = 8'hFC; rom['h3D7] = 8'h00;

        // Numbers 0-9 (0x30-0x39)
        // 0
        rom['h180] = 8'h7C; rom['h181] = 8'hC6; rom['h182] = 8'hCE; rom['h183] = 8'hDE;
        rom['h184] = 8'hF6; rom['h185] = 8'hE6; rom['h186] = 8'h7C; rom['h187] = 8'h00;

        // 1
        rom['h188] = 8'h30; rom['h189] = 8'h70; rom['h18A] = 8'h30; rom['h18B] = 8'h30;
        rom['h18C] = 8'h30; rom['h18D] = 8'h30; rom['h18E] = 8'hFC; rom['h18F] = 8'h00;

        // 2
        rom['h190] = 8'h78; rom['h191] = 8'hCC; rom['h192] = 8'h0C; rom['h193] = 8'h38;
        rom['h194] = 8'h60; rom['h195] = 8'hCC; rom['h196] = 8'hFC; rom['h197] = 8'h00;

        // 3
        rom['h198] = 8'h78; rom['h199] = 8'hCC; rom['h19A] = 8'h0C; rom['h19B] = 8'h38;
        rom['h19C] = 8'h0C; rom['h19D] = 8'hCC; rom['h19E] = 8'h78; rom['h19F] = 8'h00;

        // 4
        rom['h1A0] = 8'h1C; rom['h1A1] = 8'h3C; rom['h1A2] = 8'h6C; rom['h1A3] = 8'hCC;
        rom['h1A4] = 8'hFE; rom['h1A5] = 8'h0C; rom['h1A6] = 8'h1E; rom['h1A7] = 8'h00;

        // 5
        rom['h1A8] = 8'hFC; rom['h1A9] = 8'hC0; rom['h1AA] = 8'hF8; rom['h1AB] = 8'h0C;
        rom['h1AC] = 8'h0C; rom['h1AD] = 8'hCC; rom['h1AE] = 8'h78; rom['h1AF] = 8'h00;

        // 6
        rom['h1B0] = 8'h38; rom['h1B1] = 8'h60; rom['h1B2] = 8'hC0; rom['h1B3] = 8'hF8;
        rom['h1B4] = 8'hCC; rom['h1B5] = 8'hCC; rom['h1B6] = 8'h78; rom['h1B7] = 8'h00;

        // 7
        rom['h1B8] = 8'hFC; rom['h1B9] = 8'hCC; rom['h1BA] = 8'h0C; rom['h1BB] = 8'h18;
        rom['h1BC] = 8'h30; rom['h1BD] = 8'h30; rom['h1BE] = 8'h30; rom['h1BF] = 8'h00;

        // 8
        rom['h1C0] = 8'h78; rom['h1C1] = 8'hCC; rom['h1C2] = 8'hCC; rom['h1C3] = 8'h78;
        rom['h1C4] = 8'hCC; rom['h1C5] = 8'hCC; rom['h1C6] = 8'h78; rom['h1C7] = 8'h00;

        // 9
        rom['h1C8] = 8'h78; rom['h1C9] = 8'hCC; rom['h1CA] = 8'hCC; rom['h1CB] = 8'h7C;
        rom['h1CC] = 8'h0C; rom['h1CD] = 8'h18; rom['h1CE] = 8'h70; rom['h1CF] = 8'h00;

        // Common punctuation
        // . (0x2E)
        rom['h170] = 8'h00; rom['h171] = 8'h00; rom['h172] = 8'h00; rom['h173] = 8'h00;
        rom['h174] = 8'h00; rom['h175] = 8'h30; rom['h176] = 8'h30; rom['h177] = 8'h00;

        // , (0x2C)
        rom['h160] = 8'h00; rom['h161] = 8'h00; rom['h162] = 8'h00; rom['h163] = 8'h00;
        rom['h164] = 8'h30; rom['h165] = 8'h30; rom['h166] = 8'h20; rom['h167] = 8'h00;

        // : (0x3A)
        rom['h1D0] = 8'h00; rom['h1D1] = 8'h30; rom['h1D2] = 8'h30; rom['h1D3] = 8'h00;
        rom['h1D4] = 8'h00; rom['h1D5] = 8'h30; rom['h1D6] = 8'h30; rom['h1D7] = 8'h00;

        // - (0x2D)
        rom['h168] = 8'h00; rom['h169] = 8'h00; rom['h16A] = 8'h00; rom['h16B] = 8'h7C;
        rom['h16C] = 8'h00; rom['h16D] = 8'h00; rom['h16E] = 8'h00; rom['h16F] = 8'h00;

        // / (0x2F)
        rom['h178] = 8'h00; rom['h179] = 8'h06; rom['h17A] = 8'h0C; rom['h17B] = 8'h18;
        rom['h17C] = 8'h30; rom['h17D] = 8'h60; rom['h17E] = 8'hC0; rom['h17F] = 8'h00;

        // ? (0x3F)
        rom['h1F8] = 8'h78; rom['h1F9] = 8'hCC; rom['h1FA] = 8'h0C; rom['h1FB] = 8'h18;
        rom['h1FC] = 8'h30; rom['h1FD] = 8'h00; rom['h1FE] = 8'h30; rom['h1FF] = 8'h00;
    end

    always_ff @(posedge clk) begin
        data <= rom[addr];
    end

endmodule
