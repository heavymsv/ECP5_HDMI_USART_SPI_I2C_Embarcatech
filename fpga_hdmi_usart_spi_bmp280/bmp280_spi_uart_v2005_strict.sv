
// =============================================================
// bmp280_spi_uart_v2005_strict.v
// - Pure Verilog-2005 (no tasks, no automatic, no always_ff)
// - UART banner on boot ("BMP280 SPI v2005\r\n")
// - Reads CHIP_ID (0xD0) and prints "ID=0xXY\r\n"
// - Then configures and reads/prints T/P periodically
// =============================================================
module bmp280_spi_uart_v2005
#(
  parameter CLK_HZ = 25000000,
  parameter BAUD   = 9600,
  parameter SCK_HZ = 250000
)(
  input  wire clk,
  input  wire rst_n,
  // SPI
  output reg  spi_csn,
  output wire spi_sck,
  output reg  spi_mosi,
  input  wire spi_miso,
  // UART
  output wire uart_tx
);

  // ---------- UART ----------
  reg  [7:0] tx_data;
  reg        tx_start;
  wire       tx_busy;

  uart_tx #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) UTX (
    .clk(clk), .rst_n(rst_n),
    .tx_data(tx_data), .tx_start(tx_start),
    .tx_busy(tx_busy), .tx(uart_tx)
  );

  // Byte sender handshake (edge-to-edge)
  reg send_req, send_ackd;
  reg [1:0] sst;
  localparam S_IDLE=2'd0, S_PULSE=2'd1, S_WAITBUSY=2'd2, S_WAITIDLE=2'd3;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin tx_start<=1'b0; sst<=S_IDLE; send_ackd<=1'b0; end
    else begin
      tx_start<=1'b0; send_ackd<=1'b0;
      case (sst)
        S_IDLE: if (send_req && !tx_busy) begin tx_start<=1'b1; sst<=S_PULSE; end
        S_PULSE: sst<=S_WAITBUSY;
        S_WAITBUSY: if (tx_busy) sst<=S_WAITIDLE;
        S_WAITIDLE: if (!tx_busy) begin send_ackd<=1'b1; sst<=S_IDLE; end
      endcase
    end
  end

  // ---------- SPI clock ----------
  localparam integer DIV = (CLK_HZ/(2*SCK_HZ) < 2) ? 2 : (CLK_HZ/(2*SCK_HZ));
  reg [15:0] sdiv; reg sck_en, sck_level, sck_edge;
  assign spi_sck = sck_en ? sck_level : 1'b0;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin sdiv<=0; sck_en<=0; sck_level<=0; sck_edge<=0; end
    else begin
      sck_edge<=1'b0;
      if (!sck_en) begin sdiv<=0; sck_level<=0; end
      else if (sdiv==DIV-1) begin sdiv<=0; sck_level<=~sck_level; sck_edge<=1'b1; end
      else sdiv<=sdiv+1;
    end
  end

  // ---------- SPI shifter (byte) ----------
  localparam SB_IDLE=2'd0, SB_LOAD=2'd1, SB_SHIFT=2'd2, SB_DONE=2'd3;
  reg [1:0] sbst; reg [4:0] bitn; reg [7:0] sh_tx, sh_rx;
  reg spi_go, spi_done; reg [7:0] spi_tx_byte, spi_rx_byte;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sbst<=SB_IDLE; bitn<=0; sh_tx<=8'h00; sh_rx<=8'h00; spi_done<=0; spi_mosi<=0; sck_en<=0; spi_rx_byte<=8'h00;
    end else begin
      spi_done<=0;
      case(sbst)
        SB_IDLE: begin sck_en<=0; if (spi_go) begin sh_tx<=spi_tx_byte; sh_rx<=8'h00; bitn<=5'd7; sck_en<=1; sbst<=SB_LOAD; end end
        SB_LOAD: begin spi_mosi<=sh_tx[7]; sbst<=SB_SHIFT; end
        SB_SHIFT: begin
          if (sck_edge && sck_level) sh_rx <= {sh_rx[6:0], spi_miso};
          if (sck_edge && !sck_level) begin
            if (bitn==0) sbst<=SB_DONE;
            else begin bitn<=bitn-1; sh_tx<={sh_tx[6:0],1'b0}; spi_mosi<=sh_tx[6]; end
          end
        end
        SB_DONE: begin sck_en<=0; spi_rx_byte<=sh_rx; spi_done<=1; sbst<=SB_IDLE; end
      endcase
    end
  end

  // ---------- Command FSM ----------
  localparam C_IDLE=3'd0, C_CS_ASSERT=3'd1, C_SEND=3'd2, C_WAIT=3'd3, C_DEASSERT=3'd4, C_DONE=3'd5;
  reg [2:0] cst; reg cmd_start, cmd_done; reg [7:0] txbuf [0:63]; reg [7:0] rxbuf [0:63];
  reg [6:0] nbytes, idx;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin cst<=C_IDLE; spi_csn<=1; cmd_done<=0; spi_go<=0; idx<=0; nbytes<=0; end
    else begin
      cmd_done<=0; spi_go<=0;
      case(cst)
        C_IDLE: begin spi_csn<=1; if (cmd_start) begin idx<=0; cst<=C_CS_ASSERT; end end
        C_CS_ASSERT: begin spi_csn<=0; cst<=C_SEND; end
        C_SEND: begin if (idx<nbytes) begin spi_tx_byte<=txbuf[idx]; spi_go<=1; cst<=C_WAIT; end else cst<=C_DEASSERT; end
        C_WAIT: begin if (spi_done) begin rxbuf[idx]<=spi_rx_byte; idx<=idx+1; cst<=C_SEND; end end
        C_DEASSERT: begin spi_csn<=1; cst<=C_DONE; end
        C_DONE: begin cmd_done<=1; cst<=C_IDLE; end
      endcase
    end
  end

  // ---------- Registers ----------
  localparam [7:0] REG_ID       = 8'hD0;
  localparam [7:0] REG_RESET    = 8'hE0;
  localparam [7:0] REG_STATUS   = 8'hF3;
  localparam [7:0] REG_CTRL_MEAS= 8'hF4;
  localparam [7:0] REG_CONFIG   = 8'hF5;
  localparam [7:0] REG_PRESS_MSB= 8'hF7;
  localparam [7:0] REG_CALIB0   = 8'h88;

  reg [15:0]        dig_T1; reg signed [15:0] dig_T2, dig_T3;
  reg [15:0]        dig_P1; reg signed [15:0] dig_P2, dig_P3, dig_P4, dig_P5, dig_P6, dig_P7, dig_P8, dig_P9;
  reg [19:0] adc_T, adc_P;
  reg signed [31:0] t_fine, T_centi; reg [31:0] P_Pa;

  function [7:0] decch; input [3:0] d; begin decch="0"+d[3:0]; end endfunction
  function [19:0] u20; input [7:0] msb,lsb,xlsb; begin u20={msb,lsb,xlsb[7:4]}; end endfunction

  // ---------- String ROMs for banner and "ID=0x" ----------
  reg [7:0] banner [0:16];
  reg [7:0] idhdr  [0:4];
  initial begin
    banner[0]="B"; banner[1]="M"; banner[2]="P"; banner[3]="2"; banner[4]="8"; banner[5]="0"; banner[6]=" ";
    banner[7]="S"; banner[8]="P"; banner[9]="I"; banner[10]=" "; banner[11]="v"; banner[12]="2"; banner[13]="0"; banner[14]="0"; banner[15]="5"; banner[16]=8'h0A; // '\n'
    idhdr[0]="I"; idhdr[1]="D"; idhdr[2]="="; idhdr[3]="0"; idhdr[4]="x";
  end

  // ---------- Nibble to hex ASCII ----------
  function [7:0] hexch; input [3:0] n;
    begin hexch = (n>9) ? (8'h41 + (n-10)) : (8'h30 + n); end
  endfunction

  // ---------- Main FSM ----------
  localparam ST_BOOT=5'd0, ST_BANNER=5'd1, ST_BANNER_SEND=5'd2,
             ST_ID_CMD=5'd3, ST_ID_WAIT=5'd4, ST_ID_PRINT_HDR=5'd5, ST_ID_PRINT_N1=5'd6, ST_ID_PRINT_N0=5'd7, ST_NL=5'd8,
             ST_RESET0=5'd9, ST_RESET1=5'd10, ST_READ_CAL_PRE=5'd11, ST_WAIT_CAL=5'd12, ST_PARSE_CAL=5'd13,
             ST_SET_CTRL_PRE=5'd14, ST_SET_CFG_PRE=5'd15, ST_WAIT=5'd16,
             ST_READ_RAW_PRE=5'd17, ST_WAIT_RAW=5'd18, ST_COMP=5'd19, ST_FMT=5'd20, ST_PRINT=5'd21, ST_DELAY=5'd22;
  reg [4:0] st; reg [31:0] delay_cnt; reg [7:0] chip_id;
  reg [7:0] str_idx;

  // temps for math
  reg signed [63:0] var1, var2, p, adc_Ts, adc_Ps;
  reg [31:0] tmp;
  reg [4:0] ufmt;
  localparam U_IDLE=5'd0, U_T=5'd1, U_EQ1=5'd2, U_SIGN=5'd3, U_T2=5'd4, U_T1=5'd5, U_T0=5'd6, U_DOT=5'd7, U_TC=5'd8,
             U_SP=5'd9, U_P=5'd10, U_EQ2=5'd11, U_P5=5'd12, U_P4=5'd13, U_P3=5'd14, U_P2=5'd15, U_P1=5'd16, U_P0=5'd17,
             U_Pa=5'd18, U_CR=5'd19, U_LF=5'd20;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      st<=ST_BOOT; delay_cnt<=0; str_idx<=0; send_req<=0; ufmt<=U_IDLE; cmd_start<=0; nbytes<=0;
    end else begin
      send_req<=0; cmd_start<=0;
      case (st)
        ST_BOOT: begin
          if (delay_cnt < CLK_HZ/50) delay_cnt<=delay_cnt+1; else begin delay_cnt<=0; str_idx<=0; st<=ST_BANNER; end
        end
        ST_BANNER: begin
          if (str_idx <= 16) begin
            if (!tx_busy) begin tx_data <= banner[str_idx]; send_req<=1; if (send_ackd) begin send_req<=0; str_idx<=str_idx+1; end end
          end else begin
            st<=ST_ID_CMD;
          end
        end
        ST_ID_CMD: begin
          txbuf[0] <= {1'b1, REG_ID[6:0]}; txbuf[1] <= 8'h00; nbytes<=2; cmd_start<=1'b1; st<=ST_ID_WAIT;
        end
        ST_ID_WAIT: begin
          if (cmd_done) begin chip_id <= rxbuf[1]; str_idx<=0; st<=ST_ID_PRINT_HDR; end
        end
        ST_ID_PRINT_HDR: begin
          if (str_idx <= 4) begin
            if (!tx_busy) begin tx_data <= idhdr[str_idx]; send_req<=1; if (send_ackd) begin send_req<=0; str_idx<=str_idx+1; end end
          end else st<=ST_ID_PRINT_N1;
        end
        ST_ID_PRINT_N1: begin
          if (!tx_busy) begin tx_data<=hexch(chip_id[7:4]); send_req<=1; if (send_ackd) begin send_req<=0; st<=ST_ID_PRINT_N0; end end
        end
        ST_ID_PRINT_N0: begin
          if (!tx_busy) begin tx_data<=hexch(chip_id[3:0]); send_req<=1; if (send_ackd) begin send_req<=0; st<=ST_NL; end end
        end
        ST_NL: begin
          if (!tx_busy) begin tx_data<=8'h0A; send_req<=1; if (send_ackd) begin send_req<=0; st<=ST_RESET0; end end
        end

        // RESET & calibration
        ST_RESET0: begin
          txbuf[0] <= {1'b0, REG_RESET[6:0]}; txbuf[1] <= 8'hB6; nbytes<=2; cmd_start<=1'b1; st<=ST_RESET1;
        end
        ST_RESET1: begin
          if (delay_cnt < CLK_HZ/100) delay_cnt<=delay_cnt+1; else begin delay_cnt<=0; st<=ST_READ_CAL_PRE; end
        end
        ST_READ_CAL_PRE: begin
          txbuf[0] <= {1'b1, REG_CALIB0[6:0]};
          txbuf[1] <= 8'h00; txbuf[2] <= 8'h00; txbuf[3] <= 8'h00; txbuf[4] <= 8'h00; txbuf[5] <= 8'h00; txbuf[6] <= 8'h00;
          txbuf[7] <= 8'h00; txbuf[8] <= 8'h00; txbuf[9] <= 8'h00; txbuf[10] <= 8'h00; txbuf[11] <= 8'h00; txbuf[12] <= 8'h00;
          txbuf[13] <= 8'h00; txbuf[14] <= 8'h00; txbuf[15] <= 8'h00; txbuf[16] <= 8'h00; txbuf[17] <= 8'h00; txbuf[18] <= 8'h00;
          txbuf[19] <= 8'h00; txbuf[20] <= 8'h00; txbuf[21] <= 8'h00; txbuf[22] <= 8'h00; txbuf[23] <= 8'h00; txbuf[24] <= 8'h00;
          nbytes<=25; cmd_start<=1'b1; st<=ST_WAIT_CAL;
        end
        ST_WAIT_CAL: begin
          if (cmd_done) st<=ST_PARSE_CAL;
        end
        ST_PARSE_CAL: begin
          dig_T1 <= {rxbuf[2], rxbuf[1]};
          dig_T2 <= $signed({rxbuf[4], rxbuf[3]});
          dig_T3 <= $signed({rxbuf[6], rxbuf[5]});
          dig_P1 <= {rxbuf[8], rxbuf[7]};
          dig_P2 <= $signed({rxbuf[10], rxbuf[9]});
          dig_P3 <= $signed({rxbuf[12], rxbuf[11]});
          dig_P4 <= $signed({rxbuf[14], rxbuf[13]});
          dig_P5 <= $signed({rxbuf[16], rxbuf[15]});
          dig_P6 <= $signed({rxbuf[18], rxbuf[17]});
          dig_P7 <= $signed({rxbuf[20], rxbuf[19]});
          dig_P8 <= $signed({rxbuf[22], rxbuf[21]});
          dig_P9 <= $signed({rxbuf[24], rxbuf[23]});
          st <= ST_SET_CTRL_PRE;
        end
        ST_SET_CTRL_PRE: begin
          txbuf[0] <= {1'b0, REG_CTRL_MEAS[6:0]}; txbuf[1] <= 8'h27; nbytes<=2; cmd_start<=1'b1; st<=ST_SET_CFG_PRE;
        end
        ST_SET_CFG_PRE: begin
          txbuf[0] <= {1'b0, REG_CONFIG[6:0]}; txbuf[1] <= 8'h00; nbytes<=2; cmd_start<=1'b1; st<=ST_WAIT;
        end
        ST_WAIT: begin
          if (delay_cnt < CLK_HZ/50) delay_cnt<=delay_cnt+1; else begin delay_cnt<=0; st<=ST_READ_RAW_PRE; end
        end

        // Read raw
        ST_READ_RAW_PRE: begin
          txbuf[0] <= {1'b1, REG_PRESS_MSB[6:0]};
          txbuf[1] <= 8'h00; txbuf[2] <= 8'h00; txbuf[3] <= 8'h00;
          txbuf[4] <= 8'h00; txbuf[5] <= 8'h00; txbuf[6] <= 8'h00;
          nbytes<=7; cmd_start<=1'b1; st<=ST_WAIT_RAW;
        end
        ST_WAIT_RAW: begin
          if (cmd_done) st<=ST_COMP;
        end
        ST_COMP: begin
          adc_P  <= u20(rxbuf[1], rxbuf[2], rxbuf[3]);
          adc_T  <= u20(rxbuf[4], rxbuf[5], rxbuf[6]);
          // Temp
          adc_Ts = {44'd0, adc_T};
          var1 = (((adc_Ts>>>3) - ({{48{1'b0}},dig_T1}<<<1)) * {{48{dig_T2[15]}},dig_T2}) >>> 11;
          var2 = (((((adc_Ts>>>4) - {{48{1'b0}},dig_T1}) * ((adc_Ts>>>4) - {{48{1'b0}},dig_T1})) >>> 12) *
                  {{48{dig_T3[15]}},dig_T3}) >>> 14;
          t_fine <= (var1 + var2);
          T_centi <= ((var1 + var2) * 5 + 128) >>> 8;
          // Pressure
          adc_Ps = {44'd0, adc_P};
          var1 = (t_fine) - 128000;
          var2 = var1 * var1 * {{48{dig_P6[15]}},dig_P6};
          var2 = var2 + ((var1 * {{48{dig_P5[15]}},dig_P5}) <<< 17);
          var2 = var2 + ({{48{dig_P4[15]}},dig_P4} <<< 35);
          var1 = ((var1 * var1 * {{48{dig_P3[15]}},dig_P3}) >>> 8) + ((var1 * {{48{dig_P2[15]}},dig_P2}) <<< 12);
          var1 = ((((64'd1 <<< 47) + var1)) * {{48{1'b0}},dig_P1}) >>> 33;
          if (var1 == 0) begin P_Pa <= 0; end else begin
            p = 1048576 - adc_Ps;
            p = (((p <<< 31) - var2) * 3125) / var1;
            var1 = ({{48{dig_P9[15]}},dig_P9} * (p >>> 13) * (p >>> 13)) >>> 25;
            var2 = ({{48{dig_P8[15]}},dig_P8} * p) >>> 19;
            p = ((p + var1 + var2) >>> 8) + ({{48{dig_P7[15]}},dig_P7} <<< 4);
            P_Pa <= p[39:8];
          end
          st <= ST_FMT;
        end

        // Print "T=xxx.x C P=xxxxxx Pa\r\n"
        ST_FMT: begin ufmt<=U_T; st<=ST_PRINT; end
        ST_PRINT: begin
          case (ufmt)
            U_T:   begin if(!tx_busy) begin tx_data<="T"; send_req<=1; if(send_ackd) begin send_req<=0; ufmt<=U_EQ1; end end end
            U_EQ1: begin if(!tx_busy) begin tx_data<="="; send_req<=1; if(send_ackd) begin send_req<=0; ufmt<=U_SIGN; end end end
            U_SIGN: begin
              if ($signed(T_centi) < 0) begin if(!tx_busy) begin tx_data <= "-"; send_req<=1; if(send_ackd) begin send_req<=0; tmp <= -$signed(T_centi); ufmt<=U_T2; end end end
              else begin tmp <= T_centi; ufmt<=U_T2; end
            end
            U_T2:  begin if(!tx_busy) begin tx_data<=decch((tmp/1000)%10); send_req<=1; if(send_ackd) begin send_req<=0; ufmt<=U_T1; end end end
            U_T1:  begin if(!tx_busy) begin tx_data<=decch((tmp/100)%10);  send_req<=1; if(send_ackd) begin send_req<=0; ufmt<=U_T0; end end end
            U_T0:  begin if(!tx_busy) begin tx_data<=decch((tmp/10)%10);   send_req<=1; if(send_ackd) begin send_req<=0; ufmt<=U_DOT; end end end
            U_DOT: begin if(!tx_busy) begin tx_data<="."; send_req<=1; if(send_ackd) begin send_req<=0; ufmt<=U_TC; end end end
            U_TC:  begin if(!tx_busy) begin tx_data<=decch(tmp%10); send_req<=1; if(send_ackd) begin send_req<=0; ufmt<=U_SP; end end end
            U_SP:  begin if(!tx_busy) begin tx_data<=" "; send_req<=1; if(send_ackd) begin send_req<=0; ufmt<=U_P; end end end
            U_P:   begin if(!tx_busy) begin tx_data<="P"; send_req<=1; if(send_ackd) begin send_req<=0; ufmt<=U_EQ2; end end end
            U_EQ2: begin if(!tx_busy) begin tx_data<="="; send_req<=1; if(send_ackd) begin send_req<=0; ufmt<=U_P5; tmp<=P_Pa; end end end
            U_P5:  begin if(!tx_busy) begin tx_data<=decch((tmp/100000)%10); send_req<=1; if(send_ackd) begin send_req<=0; ufmt<=U_P4; end end end
            U_P4:  begin if(!tx_busy) begin tx_data<=decch((tmp/10000)%10);  send_req<=1; if(send_ackd) begin send_req<=0; ufmt<=U_P3; end end end
            U_P3:  begin if(!tx_busy) begin tx_data<=decch((tmp/1000)%10);   send_req<=1; if(send_ackd) begin send_req<=0; ufmt<=U_P2; end end end
            U_P2:  begin if(!tx_busy) begin tx_data<=decch((tmp/100)%10);    send_req<=1; if(send_ackd) begin send_req<=0; ufmt<=U_P1; end end end
            U_P1:  begin if(!tx_busy) begin tx_data<=decch((tmp/10)%10);     send_req<=1; if(send_ackd) begin send_req<=0; ufmt<=U_P0; end end end
            U_P0:  begin if(!tx_busy) begin tx_data<=decch(tmp%10);          send_req<=1; if(send_ackd) begin send_req<=0; ufmt<=U_Pa; end end end
            U_Pa:  begin if(!tx_busy) begin tx_data<="P"; send_req<=1; if(send_ackd) begin send_req<=0; ufmt<=U_CR; end end end
            U_CR:  begin if(!tx_busy) begin tx_data<=8'h0D; send_req<=1; if(send_ackd) begin send_req<=0; ufmt<=U_LF; end end end
            U_LF:  begin if(!tx_busy) begin tx_data<=8'h0A; send_req<=1; if(send_ackd) begin send_req<=0; ufmt<=U_IDLE; st<=ST_DELAY; end end end
            default: ;
          endcase
        end
        ST_DELAY: begin
          if (delay_cnt < CLK_HZ/10) delay_cnt<=delay_cnt+1; else begin delay_cnt<=0; st<=ST_READ_RAW_PRE; end
        end

        default: st<=ST_BOOT;
      endcase
    end
  end

endmodule
