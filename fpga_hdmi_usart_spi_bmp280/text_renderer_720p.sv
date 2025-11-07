// text_renderer_720p_v2.sv — compatível com Verilog-2005/Yosys
`default_nettype none
`timescale 1ns/1ps

module text_renderer_720p #(
    parameter H_RES = 1280,
    parameter V_RES = 720
)(
    input  wire        clk_pix,
    input  wire        rst_pix,

    // posição/sinais de vídeo
    input  wire [11:0] sx,
    input  wire [11:0] sy,
    input  wire        de,

    // números a exibir
    input  wire [15:0] t_value,
    input  wire [15:0] p_value,

    // RGB 8:8:8
    output reg  [7:0]  r,
    output reg  [7:0]  g,
    output reg  [7:0]  b
);
    // ===== helpers geom (célula 8x8, usar shifts pra evitar / %)
    localparam CELL_W = 8;
    localparam CELL_H = 8;

    wire [11:0] cx = sx >> 3;   // sx / 8
    wire [11:0] cy = sy >> 3;   // sy / 8
    wire [2:0]  px = sx[2:0];   // sx % 8
    wire [2:0]  py = sy[2:0];   // sy % 8

    // ===== conversores bin->BCD (5 dígitos cada)
    wire        start_conv = (de && (sx==12'd0) && (sy==12'd0));
    wire        busy_t, done_t, busy_p, done_p;
    wire [3:0]  t4,t3,t2,t1,t0, p4,p3,p2,p1,p0;

    bin_to_bcd_16 u_bcd_t(
        .clk  (clk_pix),
        .start(start_conv),
        .bin  (t_value),
        .busy (busy_t),
        .done (done_t),
        .d4   (t4), .d3(t3), .d2(t2), .d1(t1), .d0(t0)
    );

    bin_to_bcd_16 u_bcd_p(
        .clk  (clk_pix),
        .start(start_conv),
        .bin  (p_value),
        .busy (busy_p),
        .done (done_p),
        .d4   (p4), .d3(p3), .d2(p2), .d1(p1), .d0(p0)
    );

    // ===== fonte 8x8
    reg  [6:0] glyph_code;
    wire [7:0] glyph_bits;
    font8x8_ascii ufont(
        .char_code(glyph_code),
        .row(py),
        .bits(glyph_bits)
    );

    // ===== util: mapear dígito 0..9 para ASCII
    function [6:0] digit_to_ascii;
        input [3:0] d;
        begin
            digit_to_ascii = 7'd48 + d; // '0' + d
        end
    endfunction

    // ===== título fixo: "CONVERSOR SPI USART"
    // (sem strings: use uma função com case por índice)
    function [6:0] title_ascii;
        input [5:0] idx;  // 0..20
        begin
            // "C O N V E R S O R  _ S P I _ U S A R T"
            case (idx)
                 0: title_ascii = 7'd67;  // C
                 1: title_ascii = 7'd79;  // O
                 2: title_ascii = 7'd78;  // N
                 3: title_ascii = 7'd86;  // V
                 4: title_ascii = 7'd69;  // E
                 5: title_ascii = 7'd82;  // R
                 6: title_ascii = 7'd83;  // S
                 7: title_ascii = 7'd79;  // O
                 8: title_ascii = 7'd82;  // R
                 9: title_ascii = 7'd32;  // espaço
                10: title_ascii = 7'd83;  // S
                11: title_ascii = 7'd80;  // P
                12: title_ascii = 7'd73;  // I
                13: title_ascii = 7'd32;  // espaço
                14: title_ascii = 7'd85;  // U
                15: title_ascii = 7'd83;  // S
                16: title_ascii = 7'd65;  // A
                17: title_ascii = 7'd82;  // R
                18: title_ascii = 7'd84;  // T
                default: title_ascii = 7'd32;
            endcase
        end
    endfunction

    // ===== layout: linhas e colunas base (em células)
    // y=50 -> linha 50/8 = 6 (inteiro). y=160 -> 20. y=220 -> 27/28.
    localparam [11:0] TITLE_ROW  = 12'd6;   // ~ y=48..55
    localparam [11:0] T_ROW      = 12'd20;  // ~ y=160..167
    localparam [11:0] P_ROW      = 12'd28;  // ~ y=224..231
    localparam [11:0] TITLE_COL0 = 12'd20;  // desloc x (ajuste fino na tua tela)
    localparam [11:0] DATA_COL0  = 12'd16;

    // ===== lógica de pixels
    reg pixel_on;

    always @* begin
        // fundo preto
        r = 8'h00; g = 8'h00; b = 8'h00;
        pixel_on   = 1'b0;
        glyph_code = 7'd32; // espaço

        // ----- Linha do título -----
        if ( (cy == TITLE_ROW) ) begin
            // índice do char = cx - TITLE_COL0 (0..18)
            // sem "int": compute com wire e compare
            if (cx >= TITLE_COL0 && cx < (TITLE_COL0 + 12'd19)) begin
                // calcular idx (6 bits bastam)
                // idx = cx - TITLE_COL0
                // como não dá pra declarar "automatic int" aqui,
                // fazemos com um pequeno case por faixa
                case (cx - TITLE_COL0)
                    12'd0:  glyph_code = title_ascii(6'd0);
                    12'd1:  glyph_code = title_ascii(6'd1);
                    12'd2:  glyph_code = title_ascii(6'd2);
                    12'd3:  glyph_code = title_ascii(6'd3);
                    12'd4:  glyph_code = title_ascii(6'd4);
                    12'd5:  glyph_code = title_ascii(6'd5);
                    12'd6:  glyph_code = title_ascii(6'd6);
                    12'd7:  glyph_code = title_ascii(6'd7);
                    12'd8:  glyph_code = title_ascii(6'd8);
                    12'd9:  glyph_code = title_ascii(6'd9);
                    12'd10: glyph_code = title_ascii(6'd10);
                    12'd11: glyph_code = title_ascii(6'd11);
                    12'd12: glyph_code = title_ascii(6'd12);
                    12'd13: glyph_code = title_ascii(6'd13);
                    12'd14: glyph_code = title_ascii(6'd14);
                    12'd15: glyph_code = title_ascii(6'd15);
                    12'd16: glyph_code = title_ascii(6'd16);
                    12'd17: glyph_code = title_ascii(6'd17);
                    12'd18: glyph_code = title_ascii(6'd18);
                    default: glyph_code = 7'd32;
                endcase
                if (glyph_bits[7 - px]) pixel_on = 1'b1;
            end
        end

        // ----- Linha "T = ddddd" -----
        if (cy == T_ROW) begin
            if (cx >= DATA_COL0 && cx < (DATA_COL0 + 12'd9)) begin
                case (cx - DATA_COL0)
                    12'd0:  glyph_code = 7'd84; // 'T'
                    12'd1:  glyph_code = 7'd32; // ' '
                    12'd2:  glyph_code = 7'd61; // '='
                    12'd3:  glyph_code = 7'd32; // ' '
                    12'd4:  glyph_code = digit_to_ascii(t4);
                    12'd5:  glyph_code = digit_to_ascii(t3);
                    12'd6:  glyph_code = digit_to_ascii(t2);
                    12'd7:  glyph_code = digit_to_ascii(t1);
                    12'd8:  glyph_code = digit_to_ascii(t0);
                    default: glyph_code = 7'd32;
                endcase
                if (glyph_bits[7 - px]) pixel_on = 1'b1;
            end
        end

        // ----- Linha "P = ddddd" -----
        if (cy == P_ROW) begin
            if (cx >= DATA_COL0 && cx < (DATA_COL0 + 12'd9)) begin
                case (cx - DATA_COL0)
                    12'd0:  glyph_code = 7'd80; // 'P'
                    12'd1:  glyph_code = 7'd32; // ' '
                    12'd2:  glyph_code = 7'd61; // '='
                    12'd3:  glyph_code = 7'd32; // ' '
                    12'd4:  glyph_code = digit_to_ascii(p4);
                    12'd5:  glyph_code = digit_to_ascii(p3);
                    12'd6:  glyph_code = digit_to_ascii(p2);
                    12'd7:  glyph_code = digit_to_ascii(p1);
                    12'd8:  glyph_code = digit_to_ascii(p0);
                    default: glyph_code = 7'd32;
                endcase
                if (glyph_bits[7 - px]) pixel_on = 1'b1;
            end
        end

        // pintar se dentro da área ativa
        if (de && pixel_on) begin
            r = 8'hFF; g = 8'hFF; b = 8'hFF; // texto branco
        end
    end
endmodule
