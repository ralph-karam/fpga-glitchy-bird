`default_nettype none

module vga_background_only(
    input  wire        CLOCK_50,
    input  wire [0:0]  KEY,       // KEY[0]
    output wire [7:0]  VGA_R,
    output wire [7:0]  VGA_G,
    output wire [7:0]  VGA_B,
    output wire        VGA_HS,
    output wire        VGA_VS,
    output wire        VGA_BLANK_N,
    output wire        VGA_SYNC_N,
    output wire        VGA_CLK
);

    wire Resetn = KEY[0];

    // Never write any pixels. Ever.
    wire [8:0] dummy_color = 9'b0;
    wire [9:0] dummy_x     = 10'd0;
    wire [8:0] dummy_y     = 9'd0;
    wire       dummy_write = 1'b0;

    vga_adapter VGA(
        .resetn(Resetn),
        .clock(CLOCK_50),
        .color(dummy_color),
        .x(dummy_x),
        .y(dummy_y),
        .write(dummy_write),
        .VGA_R(VGA_R),
        .VGA_G(VGA_G),
        .VGA_B(VGA_B),
        .VGA_HS(VGA_HS),
        .VGA_VS(VGA_VS),
        .VGA_BLANK_N(VGA_BLANK_N),
        .VGA_SYNC_N(VGA_SYNC_N),
        .VGA_CLK(VGA_CLK)
    );
    defparam VGA.BACKGROUND_IMAGE        = "startscreen.mif";

endmodule
