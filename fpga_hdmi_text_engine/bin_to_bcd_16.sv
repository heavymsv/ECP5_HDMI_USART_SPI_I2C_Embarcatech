`default_nettype none
`timescale 1ns/1ps

module bin_to_bcd_16(
    input  logic        clk,
    input  logic        start,      // pulso 1 ciclo
    input  logic [15:0] bin,
    output logic        busy,
    output logic        done,
    output logic [3:0]  d4, d3, d2, d1, d0  // milhar..unidade
);
    // Algoritmo double-dabble sequencial (32 ciclos máx)
    logic [21:0] shift;   // [21:16]=d4..d0 alto nibble; [15:0]=bin
    logic [5:0]  cnt;

    function automatic [3:0] add3(input [3:0] v);
        add3 = (v > 4) ? v + 3 : v;
    endfunction

    always_ff @(posedge clk) begin
        if (start && !busy) begin
            shift <= {6'd0, 16'(bin)};
            cnt   <= 6'd16;
            busy  <= 1'b1;
            done  <= 1'b0;
        end else if (busy) begin
            // ajustar cada dígito (5 nibbles)
            shift[21:18] <= { add3(shift[21:18][3:0]),
                              add3(shift[17:14]), add3(shift[13:10]),
                              add3(shift[9:6]),   add3(shift[5:2]) }; // expandido logo abaixo
            // o bloco acima está compactado; fazemos manual:
            shift[21:18] <= add3(shift[21:18]);
            shift[17:14] <= add3(shift[17:14]);
            shift[13:10] <= add3(shift[13:10]);
            shift[9:6]   <= add3(shift[9:6]);
            shift[5:2]   <= add3(shift[5:2]);

            // shift-esquerda
            shift <= {shift[20:0], 1'b0};
            cnt   <= cnt - 1;
            if (cnt == 0) begin
                busy <= 1'b0;
                done <= 1'b1;
            end
        end else begin
            done <= 1'b0;
        end
    end

    assign d4 = shift[21:18];
    assign d3 = shift[17:14];
    assign d2 = shift[13:10];
    assign d1 = shift[9:6];
    assign d0 = shift[5:2];
endmodule
