// I2C byte engine, open-drain via inout, 100 kHz @ CLK_HZ.
// Comandos mutuamente exclusivos via 'op_*_stb' quando busy=0.
// - START: gera condição START.
// - STOP : gera condição STOP.
// - WRITE: envia 'wr_data' e captura ACK do slave em 'wr_ack' (0=ACK).
// - READ : lê 1 byte para 'rd_data' e, em seguida, envia ACK do master conforme 'rd_send_nack' (1=NACK).
module i2c_byte_engine #(
    parameter CLK_HZ = 25000000,
    parameter I2C_HZ = 100000
)(
    input  wire clk,
    input  wire rst_n,

    inout  wire sda,
    inout  wire scl,

    // comandos
    input  wire op_start_stb,
    input  wire op_stop_stb,
    input  wire op_write_stb,
    input  wire op_read_stb,
    input  wire [7:0] wr_data,
    input  wire       rd_send_nack, // 0=ACK após read, 1=NACK (último byte)

    // status/resultados
    output reg        busy,
    output reg        done,
    output reg  [7:0] rd_data,
    output reg        wr_ack // 0=ACK do slave na escrita
);
    // open-drain: 1=Hi-Z, 0=força 0
    reg sda_oen, scl_oen;
    assign sda = sda_oen ? 1'bz : 1'b0;
    assign scl = scl_oen ? 1'bz : 1'b0;
    wire sda_in = sda;

    // gerador de tique 4x por bit
    localparam DIV = (CLK_HZ/(I2C_HZ*4));
    reg [31:0] divc;
    reg tick;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin divc<=0; tick<=0; end
        else begin
            if(divc==DIV-1) begin divc<=0; tick<=1; end
            else begin divc<=divc+1; tick<=0; end
        end
    end

    // FSM
    localparam S_IDLE  = 4'd0,
               S_START0= 4'd1, S_START1=4'd2, S_START2=4'd3,
               S_WB0   = 4'd4, S_WB1=4'd5, S_WB2=4'd6, S_WB3=4'd7, S_WACK=4'd8,
               S_RB0   = 4'd9, S_RB1=4'd10,S_RB2=4'd11,S_RB3=4'd12,S_RACK=4'd13,
               S_STOP0 = 4'd14, S_STOP1=4'd15;
    reg [3:0] st;
    reg [1:0] phase;          // 0..3 (quatro fases por bit)
    reg [7:0] sh;
    reg [2:0] bitn;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            sda_oen<=1; scl_oen<=1; busy<=0; done<=0; wr_ack<=1;
            rd_data<=8'h00; st<=S_IDLE; phase<=0; bitn<=0; sh<=8'h00;
        end else begin
            done <= 1'b0; // pulso 1 ciclo

            case(st)
            // ----- ocioso: aceita um comando -----
            S_IDLE: begin
                busy   <= 1'b0;
                sda_oen<=1; scl_oen<=1;
                if(op_start_stb) begin busy<=1; st<=S_START0; phase<=0; end
                else if(op_stop_stb) begin busy<=1; st<=S_STOP0; phase<=0; end
                else if(op_write_stb) begin busy<=1; st<=S_WB0; phase<=0; sh<=wr_data; bitn<=3'd7; end
                else if(op_read_stb)  begin busy<=1; st<=S_RB0; phase<=0; bitn<=3'd7; rd_data<=8'h00; end
            end

            // ----- START -----
            S_START0: if(tick) begin scl_oen<=1; sda_oen<=1; st<=S_START1; end
            S_START1: if(tick) begin sda_oen<=0; st<=S_START2; end
            S_START2: if(tick) begin scl_oen<=0; st<=S_IDLE; done<=1; end

            // ----- WRITE byte + ACK do slave -----
            S_WB0: if(tick) begin // F0: SCL low, coloca SDA
                sda_oen <= sh[bitn] ? 1'b1 : 1'b0; st<=S_WB1;
            end
            S_WB1: if(tick) begin st<=S_WB2; end // hold
            S_WB2: if(tick) begin // F2: SCL high, sample (nada)
                scl_oen<=1; st<=S_WB3;
            end
            S_WB3: if(tick) begin // F3: SCL low, próximo bit ou ACK
                scl_oen<=0;
                if(bitn==0) begin st<=S_WACK; sda_oen<=1; end
                else begin bitn<=bitn-1; st<=S_WB0; end
            end
            S_WACK: if(tick) begin
                // F0/1: já low, libera SDA; F2: sobe SCL e lê ACK; F3: baixa SCL
                case(phase)
                    2'd0: begin phase<=2'd1; end
                    2'd1: begin phase<=2'd2; end
                    2'd2: begin scl_oen<=1; wr_ack<=sda_in; phase<=2'd3; end
                    2'd3: begin scl_oen<=0; phase<=0; st<=S_IDLE; done<=1; end
                endcase
            end

            // ----- READ byte + ACK/NACK do master -----
            S_RB0: if(tick) begin // F0: SCL low, libera SDA
                sda_oen<=1; st<=S_RB1;
            end
            S_RB1: if(tick) begin st<=S_RB2; end // hold
            S_RB2: if(tick) begin // F2: SCL high, lê bit
                scl_oen<=1; rd_data[bitn] <= sda_in; st<=S_RB3;
            end
            S_RB3: if(tick) begin // F3: SCL low, próximo bit ou ACK do master
                scl_oen<=0;
                if(bitn==0) begin st<=S_RACK; phase<=0; end
                else begin bitn<=bitn-1; st<=S_RB0; end
            end
            // bit de ACK do master
            S_RACK: if(tick) begin
                case(phase)
                    2'd0: begin // F0: SCL low, prepara SDA (ACK=0, NACK=1)
                        sda_oen <= rd_send_nack ? 1'b1 : 1'b0;
                        phase   <= 2'd1;
                    end
                    2'd1: begin phase<=2'd2; end
                    2'd2: begin // F2: SCL high, mantém SDA
                        scl_oen<=1; phase<=2'd3;
                    end
                    2'd3: begin // F3: SCL low, solta SDA e finaliza
                        scl_oen<=0; sda_oen<=1; phase<=0; st<=S_IDLE; done<=1;
                    end
                endcase
            end

            // ----- STOP -----
            S_STOP0: if(tick) begin sda_oen<=0; scl_oen<=0; st<=S_STOP1; end
            S_STOP1: if(tick) begin scl_oen<=1; sda_oen<=1; st<=S_IDLE; done<=1; end
            default: st<=S_IDLE;
            endcase
        end
    end
endmodule
