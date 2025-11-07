module uart_tx #(
    parameter CLK_HZ = 25000000,
    parameter BAUD   = 9600
)(
    input  wire clk,
    input  wire rst_n,
    input  wire tx_start,
    input  wire [7:0] tx_data,
    output reg  tx_busy,
    output reg  tx
);
    localparam DIV = CLK_HZ / BAUD;

    localparam U_IDLE=2'd0, U_START=2'd1, U_DATA=2'd2, U_STOP=2'd3;
    reg [1:0] st;
    reg [31:0] cnt;
    reg [2:0]  bitn;
    reg [7:0]  sh;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            st<=U_IDLE; tx<=1'b1; tx_busy<=1'b0; cnt<=0; bitn<=0; sh<=8'h00;
        end else begin
            case(st)
            U_IDLE: begin
                tx<=1'b1; tx_busy<=1'b0;
                if(tx_start) begin sh<=tx_data; st<=U_START; tx_busy<=1'b1; cnt<=0; end
            end
            U_START: begin
                tx<=1'b0;
                if(cnt==DIV-1) begin cnt<=0; st<=U_DATA; bitn<=3'd0; end
                else cnt<=cnt+1;
            end
            U_DATA: begin
                tx<=sh[0];
                if(cnt==DIV-1) begin
                    cnt<=0; sh<={1'b0, sh[7:1]};
                    if(bitn==3'd7) st<=U_STOP;
                    else bitn<=bitn+1;
                end else cnt<=cnt+1;
            end
            U_STOP: begin
                tx<=1'b1;
                if(cnt==DIV-1) begin cnt<=0; st<=U_IDLE; tx_busy<=1'b0; end
                else cnt<=cnt+1;
            end
            endcase
        end
    end
endmodule
