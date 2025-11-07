// Project F: FPGA Graphics - Flag of Ethiopia (ULX3S)
// Copyright Will Green, open source hardware released under the MIT License
// Learn more at https://projectf.io/posts/fpga-graphics/

`default_nettype none
`timescale 1ns / 1ps

module top (
    input  wire logic clk,       // 25 MHz clock
    //input  wire logic btn_rst_n,     // reset button

    //input  wire logic [15:0] T_in,   // valor T (testando agora)
    //input  wire logic [15:0] P_in,   // valor P (testando agora)

    output      logic [3:0] gpdi_dp  // DVI out
    );

    logic [15:0] T_val = 16'd1234;
    logic [15:0] P_val = 16'd5678;

    // generate pixel clock
    logic clk_pix;
    logic clk_pix_5x;
    logic clk_pix_locked;
    clock2_gen #(  // 74 MHz (PLL can't do exact 74.25 MHz for 720p)
        .CLKI_DIV(5),
        .CLKFB_DIV(74),
        .CLKOP_DIV(2),
        .CLKOP_CPHASE(1),
        .CLKOS_DIV(10),
        .CLKOS_CPHASE(5)
    ) clock2_gen_inst (
       .clk_in(clk),
       .clk_5x_out(clk_pix_5x),
       .clk_out(clk_pix),
       .clk_locked(clk_pix_locked)
    );

    // display sync signals and coordinates
    localparam CORDW = 12;  // screen coordinate width in bits
    logic [CORDW-1:0] sx, sy;
    logic hsync, vsync, de;
    simple_720p display_inst (
        .clk_pix,
        .rst_pix(!clk_pix_locked),  // wait for clock lock
        .sx,
        .sy,
        .hsync,
        .vsync,
        .de
    );

    // === NOVO: texto no HDMI ===
    logic [7:0] text_r, text_g, text_b;

    text_renderer_720p u_text (
        .clk_pix(clk_pix),
        .rst_pix(!clk_pix_locked),
        .sx(sx), .sy(sy), .de(de),
        //.t_value(T_in),      // entra T
        //.p_value(P_in),      // entra P
        .t_value(T_val),      // entra T
        .p_value(P_val),
        .r(text_r), .g(text_g), .b(text_b)
    );


    // DVI signals (8 bits per colour channel)
    logic [7:0] dvi_r, dvi_g, dvi_b;
    logic dvi_hsync, dvi_vsync, dvi_de;
    always_ff @(posedge clk_pix) begin
        dvi_hsync <= hsync;
        dvi_vsync <= vsync;
        dvi_de <= de;
        dvi_r <= text_r;
        dvi_g <= text_g;
        dvi_b <= text_b;
    end

    // TMDS encoding and serialization
    logic tmds_ch0_serial, tmds_ch1_serial, tmds_ch2_serial, tmds_clk_serial;
    dvi_generator dvi_out (
        .clk_pix,
        .clk_pix_5x,
        .rst_pix(!clk_pix_locked),
        .de(dvi_de),
        .data_in_ch0(dvi_b),
        .data_in_ch1(dvi_g),
        .data_in_ch2(dvi_r),
        .ctrl_in_ch0({dvi_vsync, dvi_hsync}),
        .ctrl_in_ch1(2'b00),
        .ctrl_in_ch2(2'b00),
        .tmds_ch0_serial(gpdi_dp[0]),
        .tmds_ch1_serial(gpdi_dp[1]),
        .tmds_ch2_serial(gpdi_dp[2]),
        .tmds_clk_serial(gpdi_dp[3])
    );
endmodule
