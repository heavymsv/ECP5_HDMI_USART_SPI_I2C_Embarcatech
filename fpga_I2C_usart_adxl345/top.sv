module top #(
    parameter CLK_HZ = 25000000,
    parameter I2C_HZ = 100000,
    parameter BAUD   = 9600
)(
    input  wire clk,
    input  wire rst_n,
    inout  wire i2c_sda,
    inout  wire i2c_scl,
    output wire uart_tx
);
    // UART
    wire       tx_busy;
    reg        tx_start;
    reg [7:0]  tx_data;

    uart_tx #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) U_UART (
        .clk(clk), .rst_n(rst_n),
        .tx_start(tx_start), .tx_data(tx_data),
        .tx_busy(tx_busy), .tx(uart_tx)
    );

    // I2C engine
    reg        op_start, op_stop, op_write, op_read;
    reg [7:0]  wr_data;
    reg        rd_send_nack;
    wire       i2c_busy, i2c_done;
    wire [7:0] rd_data;
    wire       wr_ack;

    i2c_byte_engine #(.CLK_HZ(CLK_HZ), .I2C_HZ(I2C_HZ)) U_I2C (
        .clk(clk), .rst_n(rst_n),
        .sda(i2c_sda), .scl(i2c_scl),
        .op_start_stb(op_start),
        .op_stop_stb(op_stop),
        .op_write_stb(op_write),
        .op_read_stb(op_read),
        .wr_data(wr_data),
        .rd_send_nack(rd_send_nack),
        .busy(i2c_busy),
        .done(i2c_done),
        .rd_data(rd_data),
        .wr_ack(wr_ack)
    );

    // Protocolo ADXL345
    localparam [6:0] DEV = 7'h53;
    localparam [7:0] REG_POWER_CTL = 8'h2D;
    localparam [7:0] REG_DATA_FMT  = 8'h31;
    localparam [7:0] REG_BW_RATE   = 8'h2C;
    localparam [7:0] REG_DATAX0    = 8'h32;

    localparam H_RESET=5'd0,
               H_I1_S=5'd1,  H_I1_D=5'd2,  H_I1_R=5'd3,  H_I1_V=5'd4,  H_I1_P=5'd5,
               H_I2_S=5'd6,  H_I2_D=5'd7,  H_I2_R=5'd8,  H_I2_V=5'd9,  H_I2_P=5'd10,
               H_I3_S=5'd11, H_I3_D=5'd12, H_I3_R=5'd13, H_I3_V=5'd14, H_I3_P=5'd15,
               H_RS_S=5'd16, H_RS_D=5'd17, H_RS_R=5'd18, H_RS_P=5'd19,
               H_RD_S=5'd20, H_RD_D=5'd21, H_RD_B=5'd22, H_RD_P=5'd23,
               H_UART=5'd24, H_WAIT=5'd25;

    reg [4:0] hst;

    // buffers dos 6 bytes
    reg [7:0] x0,x1,y0,y1,z0,z1;
    reg [2:0] idx;
    reg [15:0] waitc;
    reg [5:0]  tx_idx;

    // util: HEX
    function [7:0] hex8; input [3:0] n; begin hex8 = (n<10) ? ("0"+n) : ("A"+(n-10)); end endfunction

    // frame "X=HHHH,Y=HHHH,Z=HHHH\r\n"
    localparam SEQ_LEN=22;
    function [7:0] seq_char;
        input [5:0] k; input [7:0] fx0,fx1,fy0,fy1,fz0,fz1;
        begin
            case(k)
                // X=
                0:  seq_char = 8'h58; // 'X'
                1:  seq_char = 8'h3D; // '='
                2:  seq_char = hex8(fx1[7:4]);
                3:  seq_char = hex8(fx1[3:0]);
                4:  seq_char = hex8(fx0[7:4]);
                5:  seq_char = hex8(fx0[3:0]);
                6:  seq_char = 8'h2C; // ','
                // Y=
                7:  seq_char = 8'h59; // 'Y'
                8:  seq_char = 8'h3D; // '='
                9:  seq_char = hex8(fy1[7:4]);
                10: seq_char = hex8(fy1[3:0]);
                11: seq_char = hex8(fy0[7:4]);
                12: seq_char = hex8(fy0[3:0]);
                13: seq_char = 8'h2C; // ','
                // Z=
                14: seq_char = 8'h5A; // 'Z'
                15: seq_char = 8'h3D; // '='
                16: seq_char = hex8(fz1[7:4]);
                17: seq_char = hex8(fz1[3:0]);
                18: seq_char = hex8(fz0[7:4]);
                19: seq_char = hex8(fz0[3:0]);
                20: seq_char = 8'h0D; // '\r'
                21: seq_char = 8'h0A; // '\n'
                default: seq_char = 8'h20; // ' '
            endcase
        end
    endfunction

    // strobe helper
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin op_start<=0; op_stop<=0; op_write<=0; op_read<=0; end
        else begin
            // limpar strobes automaticamente
            if(op_start && i2c_busy) op_start<=0;
            if(op_stop  && i2c_busy) op_stop <=0;
            if(op_write && i2c_busy) op_write<=0;
            if(op_read  && i2c_busy) op_read <=0;
        end
    end

    // FSM alto nível
    localparam H_HELLO = 5'd26;
    reg [5:0] hello_idx;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            hst <= H_HELLO;   // começa no HELLO
            tx_start <= 0;
            tx_data <= 8'h00;
            hello_idx <= 0;
            wr_data <= 8'h00;
            rd_send_nack <= 1'b1;
            x0<=0;x1<=0;y0<=0;y1<=0;z0<=0;z1<=0;
            idx<=0; waitc<=0; tx_idx<=0;
        end else begin
            tx_start<=1'b0;

            case(hst)
            H_RESET: begin
                if(!i2c_busy) begin op_start<=1; hst<=H_I1_S; end
            end
            // POWER_CTL=0x08
            H_I1_S: if(i2c_done) begin wr_data<={7'h53,1'b0}; op_write<=1; hst<=H_I1_D; end
            H_I1_D: if(i2c_done) begin wr_data<=REG_POWER_CTL; op_write<=1; hst<=H_I1_R; end
            H_I1_R: if(i2c_done) begin wr_data<=8'h08; op_write<=1; hst<=H_I1_V; end
            H_I1_V: if(i2c_done) begin op_stop<=1; hst<=H_I1_P; end
            H_I1_P: if(i2c_done) begin op_start<=1; hst<=H_I2_S; end

            // DATA_FORMAT=0x08
            H_I2_S: if(i2c_done) begin wr_data<={7'h53,1'b0}; op_write<=1; hst<=H_I2_D; end
            H_I2_D: if(i2c_done) begin wr_data<=REG_DATA_FMT; op_write<=1; hst<=H_I2_R; end
            H_I2_R: if(i2c_done) begin wr_data<=8'h08; op_write<=1; hst<=H_I2_V; end
            H_I2_V: if(i2c_done) begin op_stop<=1; hst<=H_I2_P; end
            H_I2_P: if(i2c_done) begin op_start<=1; hst<=H_I3_S; end

            // BW_RATE=0x0A
            H_I3_S: if(i2c_done) begin wr_data<={7'h53,1'b0}; op_write<=1; hst<=H_I3_D; end
            H_I3_D: if(i2c_done) begin wr_data<=REG_BW_RATE; op_write<=1; hst<=H_I3_R; end
            H_I3_R: if(i2c_done) begin wr_data<=8'h0A; op_write<=1; hst<=H_I3_V; end
            H_I3_V: if(i2c_done) begin op_stop<=1; hst<=H_I3_P; end

            // apontar subaddr 0x32
            H_I3_P: if(i2c_done) begin op_start<=1; hst<=H_RS_S; end
            H_RS_S: if(i2c_done) begin wr_data<={7'h53,1'b0}; op_write<=1; hst<=H_RS_D; end
            H_RS_D: if(i2c_done) begin wr_data<=REG_DATAX0; op_write<=1; hst<=H_RS_R; end
            H_RS_R: if(i2c_done) begin op_stop<=1; hst<=H_RS_P; end

            // re-START + leitura de 6 bytes
            H_RS_P: if(i2c_done) begin op_start<=1; hst<=H_RD_S; end
            H_RD_S: if(i2c_done) begin wr_data<={7'h53,1'b1}; op_write<=1; idx<=0; hst<=H_RD_D; end
            H_RD_D: if(i2c_done) begin rd_send_nack <= (idx==3'd5); op_read<=1; hst<=H_RD_B; end
            H_RD_B: if(i2c_done) begin
                case(idx)
                    3'd0: x0<=rd_data; 3'd1: x1<=rd_data; 3'd2: y0<=rd_data;
                    3'd3: y1<=rd_data; 3'd4: z0<=rd_data; default: z1<=rd_data;
                endcase
                if(idx==3'd5) begin op_stop<=1; hst<=H_RD_P; end
                else begin idx<=idx+1; hst<=H_RD_D; end
            end
            H_RD_P: if(i2c_done) begin tx_idx<=0; hst<=H_UART; end

            // envia por UART
            H_UART: begin
                if(!tx_busy) begin
                    tx_data  <= seq_char(tx_idx, x0,x1,y0,y1,z0,z1);
                    tx_start <= 1'b1;
                    if(tx_idx==SEQ_LEN-1) begin tx_idx<=0; hst<=H_WAIT; waitc<=0; end
                    else tx_idx<=tx_idx+1;
                end
            end

            // ~5 ms
            H_WAIT: begin
                if(waitc < (CLK_HZ/200)) waitc <= waitc + 1;
                else begin waitc<=0; op_start<=1; hst<=H_RS_S; end
            end

            H_HELLO: begin
                // envia "INIT\r\n" uma vez no boot
                if(!tx_busy) begin
                    case(hello_idx)
                        6: tx_data = 8'h49; // 'I'
                        7: tx_data = 8'h4E; // 'N'
                        8: tx_data = 8'h49; // 'I'
                        9: tx_data = 8'h54; // 'T'
                        10: tx_data = 8'h0D; // '\r'
                        11: tx_data = 8'h0A; // '\n'
                        default: tx_data = 8'h00;
                    endcase
                    tx_start <= 1'b1;
                    hello_idx <= hello_idx + 1;
                    if(hello_idx == 5'd12) begin
                        hello_idx <= 0;
                        hst <= H_RESET; // depois da mensagem, vai pro fluxo normal
                    end
                end
            end

            default: hst<=H_RESET;
            endcase
        end
    end
endmodule
