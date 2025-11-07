// Fonte 8x8 minimalista para A..Z, 0..9, espaço e '='
// Baseado em font8x8 pública; mantido bem compacto para o exemplo.
`default_nettype none
`timescale 1ns/1ps

module font8x8_ascii (
    input  logic [6:0] char_code,   // ASCII (ex.: "A"=65)
    input  logic [2:0] row,         // 0..7
    output logic [7:0] bits         // bit 7 = pixel mais à esquerda
);
    always_comb begin
        unique case (char_code)

            // ESPAÇO (0x20)
            7'd32: case (row)
                0: bits=8'b00000000; 1: bits=8'b00000000;
                2: bits=8'b00000000; 3: bits=8'b00000000;
                4: bits=8'b00000000; 5: bits=8'b00000000;
                6: bits=8'b00000000; 7: bits=8'b00000000;
            endcase

            // "=" (0x3D)
            7'd61: case (row)
                0: bits=8'b00000000; 1: bits=8'b00000000;
                2: bits=8'b01111110; 3: bits=8'b00000000;
                4: bits=8'b01111110; 5: bits=8'b00000000;
                6: bits=8'b00000000; 7: bits=8'b00000000;
            endcase

            // "0".."9" (0x30..0x39)
            7'd48: /*0*/ case (row)
                0: bits=8'b00111100; 1: bits=8'b01100110;
                2: bits=8'b01101110; 3: bits=8'b01110110;
                4: bits=8'b01100110; 5: bits=8'b01100110;
                6: bits=8'b00111100; 7: bits=8'b00000000;
            endcase
            7'd49: /*1*/ case (row)
                0: bits=8'b00011000; 1: bits=8'b00111000;
                2: bits=8'b00011000; 3: bits=8'b00011000;
                4: bits=8'b00011000; 5: bits=8'b00011000;
                6: bits=8'b00111100; 7: bits=8'b00000000;
            endcase
            7'd50: /*2*/ case (row)
                0: bits=8'b00111100; 1: bits=8'b01100110;
                2: bits=8'b00000110; 3: bits=8'b00011100;
                4: bits=8'b00110000; 5: bits=8'b01100000;
                6: bits=8'b01111110; 7: bits=8'b00000000;
            endcase
            7'd51: /*3*/ case (row)
                0: bits=8'b00111100; 1: bits=8'b01100110;
                2: bits=8'b00000110; 3: bits=8'b00011100;
                4: bits=8'b00000110; 5: bits=8'b01100110;
                6: bits=8'b00111100; 7: bits=8'b00000000;
            endcase
            7'd52: /*4*/ case (row)
                0: bits=8'b00001100; 1: bits=8'b00011100;
                2: bits=8'b00101100; 3: bits=8'b01001100;
                4: bits=8'b01111110; 5: bits=8'b00001100;
                6: bits=8'b00001100; 7: bits=8'b00000000;
            endcase
            7'd53: /*5*/ case (row)
                0: bits=8'b01111110; 1: bits=8'b01100000;
                2: bits=8'b01111100; 3: bits=8'b00000110;
                4: bits=8'b00000110; 5: bits=8'b01100110;
                6: bits=8'b00111100; 7: bits=8'b00000000;
            endcase
            7'd54: /*6*/ case (row)
                0: bits=8'b00111100; 1: bits=8'b01100110;
                2: bits=8'b01100000; 3: bits=8'b01111100;
                4: bits=8'b01100110; 5: bits=8'b01100110;
                6: bits=8'b00111100; 7: bits=8'b00000000;
            endcase
            7'd55: /*7*/ case (row)
                0: bits=8'b01111110; 1: bits=8'b00000110;
                2: bits=8'b00001100; 3: bits=8'b00011000;
                4: bits=8'b00110000; 5: bits=8'b00110000;
                6: bits=8'b00110000; 7: bits=8'b00000000;
            endcase
            7'd56: /*8*/ case (row)
                0: bits=8'b00111100; 1: bits=8'b01100110;
                2: bits=8'b00111100; 3: bits=8'b01100110;
                4: bits=8'b01100110; 5: bits=8'b01100110;
                6: bits=8'b00111100; 7: bits=8'b00000000;
            endcase
            7'd57: /*9*/ case (row)
                0: bits=8'b00111100; 1: bits=8'b01100110;
                2: bits=8'b01100110; 3: bits=8'b00111110;
                4: bits=8'b00000110; 5: bits=8'b01100110;
                6: bits=8'b00111100; 7: bits=8'b00000000;
            endcase

            // "A".."Z" (0x41..0x5A)
            7'd65: /*A*/ case (row)
                0: bits=8'b00011000; 1: bits=8'b00111100;
                2: bits=8'b01100110; 3: bits=8'b01100110;
                4: bits=8'b01111110; 5: bits=8'b01100110;
                6: bits=8'b01100110; 7: bits=8'b00000000;
            endcase
            7'd66: /*B*/ case (row)
                0: bits=8'b01111100; 1: bits=8'b01100110;
                2: bits=8'b01100110; 3: bits=8'b01111100;
                4: bits=8'b01100110; 5: bits=8'b01100110;
                6: bits=8'b01111100; 7: bits=8'b00000000;
            endcase
            7'd67: /*C*/ case (row)
                0: bits=8'b00111100; 1: bits=8'b01100110;
                2: bits=8'b01100000; 3: bits=8'b01100000;
                4: bits=8'b01100000; 5: bits=8'b01100110;
                6: bits=8'b00111100; 7: bits=8'b00000000;
            endcase
            7'd68: /*D*/ case (row)
                0: bits=8'b01111000; 1: bits=8'b01101100;
                2: bits=8'b01100110; 3: bits=8'b01100110;
                4: bits=8'b01100110; 5: bits=8'b01101100;
                6: bits=8'b01111000; 7: bits=8'b00000000;
            endcase
            7'd69: /*E*/ case (row)
                0: bits=8'b01111110; 1: bits=8'b01100000;
                2: bits=8'b01111000; 3: bits=8'b01100000;
                4: bits=8'b01100000; 5: bits=8'b01100000;
                6: bits=8'b01111110; 7: bits=8'b00000000;
            endcase
            7'd70: /*F*/ case (row)
                0: bits=8'b01111110; 1: bits=8'b01100000;
                2: bits=8'b01111000; 3: bits=8'b01100000;
                4: bits=8'b01100000; 5: bits=8'b01100000;
                6: bits=8'b01100000; 7: bits=8'b00000000;
            endcase
            7'd71: /*G*/ case (row)
                0: bits=8'b00111100; 1: bits=8'b01100110;
                2: bits=8'b01100000; 3: bits=8'b01111110;
                4: bits=8'b01100110; 5: bits=8'b01100110;
                6: bits=8'b00111110; 7: bits=8'b00000000;
            endcase
            7'd72: /*H*/ case (row)
                0: bits=8'b01100110; 1: bits=8'b01100110;
                2: bits=8'b01100110; 3: bits=8'b01111110; // (tip: 60->01100110)
                4: bits=8'b01100110; 5: bits=8'b01100110;
                6: bits=8'b01100110; 7: bits=8'b00000000;
            endcase
            7'd73: /*I*/ case (row)
                0: bits=8'b00111100; 1: bits=8'b00011000;
                2: bits=8'b00011000; 3: bits=8'b00011000;
                4: bits=8'b00011000; 5: bits=8'b00011000;
                6: bits=8'b00111100; 7: bits=8'b00000000;
            endcase
            7'd74: /*J*/ case (row)
                0: bits=8'b00011110; 1: bits=8'b00001100;
                2: bits=8'b00001100; 3: bits=8'b00001100;
                4: bits=8'b00001100; 5: bits=8'b01101100;
                6: bits=8'b00111000; 7: bits=8'b00000000;
            endcase
            7'd75: /*K*/ case (row)
                0: bits=8'b01100110; 1: bits=8'b01101100;
                2: bits=8'b01111000; 3: bits=8'b01110000;
                4: bits=8'b01111000; 5: bits=8'b01101100;
                6: bits=8'b01100110; 7: bits=8'b00000000;
            endcase
            7'd76: /*L*/ case (row)
                0: bits=8'b01100000; 1: bits=8'b01100000;
                2: bits=8'b01100000; 3: bits=8'b01100000;
                4: bits=8'b01100000; 5: bits=8'b01100000;
                6: bits=8'b01111110; 7: bits=8'b00000000;
            endcase
            7'd77: /*M*/ case (row)
                0: bits=8'b01100110; 1: bits=8'b01111110;
                2: bits=8'b01111110; 3: bits=8'b01100110;
                4: bits=8'b01100110; 5: bits=8'b01100110;
                6: bits=8'b01100110; 7: bits=8'b00000000;
            endcase
            7'd78: /*N*/ case (row)
                0: bits=8'b01100110; 1: bits=8'b01110110;
                2: bits=8'b01111110; 3: bits=8'b01101110;
                4: bits=8'b01100110; 5: bits=8'b01100110;
                6: bits=8'b01100110; 7: bits=8'b00000000;
            endcase
            7'd79: /*O*/ case (row)
                0: bits=8'b00111100; 1: bits=8'b01100110;
                2: bits=8'b01100110; 3: bits=8'b01100110;
                4: bits=8'b01100110; 5: bits=8'b01100110;
                6: bits=8'b00111100; 7: bits=8'b00000000;
            endcase
            7'd80: /*P*/ case (row)
                0: bits=8'b01111100; 1: bits=8'b01100110;
                2: bits=8'b01100110; 3: bits=8'b01111100;
                4: bits=8'b01100000; 5: bits=8'b01100000;
                6: bits=8'b01100000; 7: bits=8'b00000000;
            endcase
            7'd81: /*Q*/ case (row)
                0: bits=8'b00111100; 1: bits=8'b01100110;
                2: bits=8'b01100110; 3: bits=8'b01100110;
                4: bits=8'b01101110; 5: bits=8'b00111100;
                6: bits=8'b00000110; 7: bits=8'b00000000;
            endcase
            7'd82: /*R*/ case (row)
                0: bits=8'b01111100; 1: bits=8'b01100110;
                2: bits=8'b01100110; 3: bits=8'b01111100;
                4: bits=8'b01111000; 5: bits=8'b01101100;
                6: bits=8'b01100110; 7: bits=8'b00000000;
            endcase
            7'd83: /*S*/ case (row)
                0: bits=8'b00111100; 1: bits=8'b01100000;
                2: bits=8'b00111100; 3: bits=8'b00000110;
                4: bits=8'b00000110; 5: bits=8'b01100110;
                6: bits=8'b00111100; 7: bits=8'b00000000;
            endcase
            7'd84: /*T*/ case (row)
                0: bits=8'b01111110; 1: bits=8'b00011000;
                2: bits=8'b00011000; 3: bits=8'b00011000;
                4: bits=8'b00011000; 5: bits=8'b00011000;
                6: bits=8'b00011000; 7: bits=8'b00000000;
            endcase
            7'd85: /*U*/ case (row)
                0: bits=8'b01100110; 1: bits=8'b01100110;
                2: bits=8'b01100110; 3: bits=8'b01100110;
                4: bits=8'b01100110; 5: bits=8'b01100110;
                6: bits=8'b00111100; 7: bits=8'b00000000;
            endcase
            7'd86: /*V*/ case (row)
                0: bits=8'b01100110; 1: bits=8'b01100110;
                2: bits=8'b01100110; 3: bits=8'b00111100;
                4: bits=8'b00111100; 5: bits=8'b00011000;
                6: bits=8'b00011000; 7: bits=8'b00000000;
            endcase
            7'd87: /*W*/ case (row)
                0: bits=8'b01100110; 1: bits=8'b01100110;
                2: bits=8'b01100110; 3: bits=8'b01111110;
                4: bits=8'b01111110; 5: bits=8'b01100110;
                6: bits=8'b01100110; 7: bits=8'b00000000;
            endcase
            7'd88: /*X*/ case (row)
                0: bits=8'b01100110; 1: bits=8'b00111100;
                2: bits=8'b00011000; 3: bits=8'b00011000;
                4: bits=8'b00111100; 5: bits=8'b01100110;
                6: bits=8'b01100110; 7: bits=8'b00000000;
            endcase
            7'd89: /*Y*/ case (row)
                0: bits=8'b01100110; 1: bits=8'b00111100;
                2: bits=8'b00011000; 3: bits=8'b00011000;
                4: bits=8'b00011000; 5: bits=8'b00011000;
                6: bits=8'b00111100; 7: bits=8'b00000000;
            endcase
            7'd90: /*Z*/ case (row)
                0: bits=8'b01111110; 1: bits=8'b00001100;
                2: bits=8'b00011000; 3: bits=8'b00110000;
                4: bits=8'b01100000; 5: bits=8'b01100000;
                6: bits=8'b01111110; 7: bits=8'b00000000;
            endcase

            default: case (row)
                0: bits=8'b00000000; 1: bits=8'b00000000;
                2: bits=8'b00000000; 3: bits=8'b00000000;
                4: bits=8'b00000000; 5: bits=8'b00000000;
                6: bits=8'b00000000; 7: bits=8'b00000000;
            endcase
        endcase
    end
endmodule
