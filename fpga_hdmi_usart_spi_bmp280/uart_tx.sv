// uart_tx.sv — UART TX 8N1 com NCO + realinhamento de fase por frame
module uart_tx #(
  parameter int unsigned CLK_HZ = 25_000_000,
  parameter int unsigned BAUD   = 9600
)(
  input  logic clk,
  input  logic rst_n,
  input  logic [7:0] tx_data,
  input  logic tx_start,     // pulso 1 ciclo p/ iniciar frame
  output logic tx_busy,      // 1 enquanto transmite
  output logic tx            // linha TX (idle=1)
);

  // ---------- NCO (baud tick) com "phase reset" ----------
  logic [31:0] acc;
  logic        baud_tick;
  logic        phase_reset_req;   // pedido de reset de fase (no tx_start)

  // Registramos o pedido para evitar races entre always_ff distintos
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) phase_reset_req <= 1'b0;
    else        phase_reset_req <= tx_start;  // 1 ciclo quando novo frame começa
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      acc       <= 32'd0;
      baud_tick <= 1'b0;
    end else begin
      baud_tick <= 1'b0;

      // Se vamos iniciar um frame, realinhe a fase (acc=0)
      if (phase_reset_req) begin
        acc <= 32'd0;
      end else begin
        acc <= acc + BAUD;
        if (acc >= CLK_HZ) begin
          acc       <= acc - CLK_HZ;
          baud_tick <= 1'b1;
        end
      end
    end
  end

  // ---------- FSM TX 8N1 ----------
  typedef enum logic [1:0] {U_IDLE, U_START, U_DATA, U_STOP} ustate_t;
  ustate_t st;

  logic [2:0]  bitn;
  logic [7:0]  sh;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      st      <= U_IDLE;
      tx      <= 1'b1;
      tx_busy <= 1'b0;
      bitn    <= '0;
      sh      <= 8'h00;
    end else begin
      case (st)
        U_IDLE: begin
          tx      <= 1'b1;
          tx_busy <= 1'b0;
          if (tx_start) begin
            tx_busy <= 1'b1;
            sh      <= tx_data;
            bitn    <= 3'd0;
            tx      <= 1'b0;        // start bit
            st      <= U_START;     // segura até PRÓXIMO baud_tick (agora alinhado)
          end
        end

        U_START: begin
          if (baud_tick) begin
            tx <= sh[0];            // 1º data bit
            st <= U_DATA;
          end
        end

        U_DATA: begin
          if (baud_tick) begin
            if (bitn == 3'd7) begin
              tx <= 1'b1;           // stop
              st <= U_STOP;
            end else begin
              bitn <= bitn + 1;
              sh   <= {1'b0, sh[7:1]};
              tx   <= sh[1];
            end
          end
        end

        U_STOP: begin
          if (baud_tick) begin
            st <= U_IDLE;
          end
        end
      endcase
    end
  end
endmodule
