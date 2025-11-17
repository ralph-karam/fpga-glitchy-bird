`default_nettype none

module obstacles(
    input  wire        CLOCK_50,
    input  wire [9:0]  SW,
    input  wire        KEY,             // KEY[0]
    output wire [9:0]  LEDR,
    output wire [7:0]  VGA_R,
    output wire [7:0]  VGA_G,
    output wire [7:0]  VGA_B,
    output wire        VGA_HS,
    output wire        VGA_VS,
    output wire        VGA_BLANK_N,
    output wire        VGA_SYNC_N,
    output wire        VGA_CLK
);

    localparam XSCREEN = 640;
    localparam YSCREEN = 480;
    localparam GAP     = 9'd80;
    localparam MIN_H   = 9'd100;
    localparam RANGE_H = 9'd201;

    wire Resetn = KEY;      // active-low reset (KEY0)

    // ============================================================
    // GAME START CONTROL
    // ============================================================

    reg started  = 1'b0;    // becomes 1 AFTER first KEY release
    reg clearing = 1'b0;

    reg [9:0] clear_x = 0;
    reg [8:0] clear_y = 0;

    // Start + clear FSM
    always @(posedge CLOCK_50 or negedge Resetn) begin
        if (!Resetn) begin
            // When KEY0 is pressed: DO NOT start game yet.
            started  <= 1'b0;
            clearing <= 1'b0;
            clear_x  <= 0;
            clear_y  <= 0;
        end
        else if (!started) begin
            // FIRST release of KEY0 → start game + clear screen
            started  <= 1'b1;
            clearing <= 1'b1;
            clear_x  <= 0;
            clear_y  <= 0;
        end
        else if (clearing) begin
            // Clear the screen black
            if (clear_x == XSCREEN-1) begin
                clear_x <= 0;
                if (clear_y == YSCREEN-1) begin
                    clear_y <= 0;
                    clearing <= 1'b0;      // done clearing
                end
                else begin
                    clear_y <= clear_y + 1'b1;
                end
            end
            else begin
                clear_x <= clear_x + 1'b1;
            end
        end
    end

    // Global game-active signal
    wire game_active = started && !clearing;

    // ============================================================
    // RANDOM GENERATOR (for pillar heights)
    // ============================================================

    wire [7:0] rnd;
    random U_rand(~Resetn, CLOCK_50, rnd);

    wire [8:0] rand_mod = rnd % RANGE_H;
    wire [8:0] rand_h   = MIN_H + rand_mod;

    // ============================================================
    // PILLAR HEIGHT LOGIC
    // ============================================================

    reg [8:0] top_h1, btm_h1, btm_y1;
    reg [8:0] top_h2, btm_h2, btm_y2;
    reg [8:0] top_h3, btm_h3, btm_y3;

    wire wrap_top1, wrap_top2, wrap_top3;
    wire wrap_btm1, wrap_btm2, wrap_btm3;  // unused

    always @(posedge CLOCK_50 or negedge Resetn) begin
        if (!Resetn) begin
            // Set initial top heights directly
            top_h1 <= 9'd200;
            top_h2 <= 9'd150;
            top_h3 <= 9'd220;

            btm_y1 <= 9'd200 + GAP;
            btm_h1 <= YSCREEN - (9'd200 + GAP);

            btm_y2 <= 9'd150 + GAP;
            btm_h2 <= YSCREEN - (9'd150 + GAP);

            btm_y3 <= 9'd220 + GAP;
            btm_h3 <= YSCREEN - (9'd220 + GAP);
        end
        else begin
            // On wrap, assign new random heights
            if (wrap_top1) begin
                top_h1 <= rand_h;
                btm_y1 <= rand_h + GAP;
                btm_h1 <= YSCREEN - (rand_h + GAP);
            end
            if (wrap_top2) begin
                top_h2 <= rand_h;
                btm_y2 <= rand_h + GAP;
                btm_h2 <= YSCREEN - (rand_h + GAP);
            end
            if (wrap_top3) begin
                top_h3 <= rand_h;
                btm_y3 <= rand_h + GAP;
                btm_h3 <= YSCREEN - (rand_h + GAP);
            end
        end
    end

    // ============================================================
    // INSTANTIATE ALL OBJECTS (BUT FREEZE IF !game_active)
    // ============================================================

    wire [9:0] x_top1, x_btm1, x_top2, x_btm2, x_top3, x_btm3;
    wire [8:0] y_top1, y_btm1, y_top2, y_btm2, y_top3, y_btm3;

    wire [8:0] color_top1, color_btm1, color_top2, color_btm2, color_top3, color_btm3;
    wire write_top1, write_btm1, write_top2, write_btm2, write_top3, write_btm3;

    wire req_top1, req_btm1, req_top2, req_btm2, req_top3, req_btm3;

    // Global gating of requests BEFORE game start:
    wire req_top1_g = game_active ? req_top1 : 1'b0;
    wire req_btm1_g = game_active ? req_btm1 : 1'b0;
    wire req_top2_g = game_active ? req_top2 : 1'b0;
    wire req_btm2_g = game_active ? req_btm2 : 1'b0;
    wire req_top3_g = game_active ? req_top3 : 1'b0;
    wire req_btm3_g = game_active ? req_btm3 : 1'b0;

    reg gnt_top1, gnt_btm1, gnt_top2, gnt_btm2, gnt_top3, gnt_btm3;

    // Top 1
    object top1(
        Resetn, CLOCK_50,
        gnt_top1 & game_active, req_top1,
        9'd0, top_h1,
        x_top1, y_top1, color_top1, write_top1,
        wrap_top1
    );
    defparam top1.COLOR = 9'b000_111_000;

    // Bottom 1
    object btm1(
        Resetn, CLOCK_50,
        gnt_btm1 & game_active, req_btm1,
        btm_y1, btm_h1,
        x_btm1, y_btm1, color_btm1, write_btm1,
        wrap_btm1
    );
    defparam btm1.X_INIT = 10'd620;
    defparam btm1.COLOR  = 9'b000_111_000;

    // Top 2
    object top2(
        Resetn, CLOCK_50,
        gnt_top2 & game_active, req_top2,
        9'd0, top_h2,
        x_top2, y_top2, color_top2, write_top2,
        wrap_top2
    );
    defparam top2.X_INIT = 10'd420;
    defparam top2.COLOR  = 9'b000_000_111;

    // Bottom 2
    object btm2(
        Resetn, CLOCK_50,
        gnt_btm2 & game_active, req_btm2,
        btm_y2, btm_h2,
        x_btm2, y_btm2, color_btm2, write_btm2,
        wrap_btm2
    );
    defparam btm2.X_INIT = 10'd420;
    defparam btm2.COLOR  = 9'b000_000_111;

    // Top 3
    object top3(
        Resetn, CLOCK_50,
        gnt_top3 & game_active, req_top3,
        9'd0, top_h3,
        x_top3, y_top3, color_top3, write_top3,
        wrap_top3
    );
    defparam top3.X_INIT = 10'd220;
    defparam top3.COLOR  = 9'b111_000_000;

    // Bottom 3
    object btm3(
        Resetn, CLOCK_50,
        gnt_btm3 & game_active, req_btm3,
        btm_y3, btm_h3,
        x_btm3, y_btm3, color_btm3, write_btm3,
        wrap_btm3
    );
    defparam btm3.X_INIT = 10'd220;
    defparam btm3.COLOR  = 9'b111_000_000;

    // ============================================================
    // ARBITER FSM — FULLY FIXED FOR BACKGROUND-ONLY START
    // ============================================================

    // States
    localparam SA = 3'b000, SB = 3'b001, SC = 3'b010,
               SD = 3'b011, SE = 3'b100, SF = 3'b101, SG = 3'b110;

    reg [2:0] y_Q, Y_D;

    always @(*) begin
        if (!game_active) begin
            Y_D = SA;     // force idle before KEY0
        end
        else begin
            case (y_Q)
                SA: if (req_top1_g)      Y_D = SB;
                    else if (req_btm1_g) Y_D = SC;
                    else if (req_top2_g) Y_D = SD;
                    else if (req_btm2_g) Y_D = SE;
                    else if (req_top3_g) Y_D = SF;
                    else if (req_btm3_g) Y_D = SG;
                    else                 Y_D = SA;

                SB: Y_D = (req_top1_g) ? SB : SA;
                SC: Y_D = (req_btm1_g) ? SC : SA;
                SD: Y_D = (req_top2_g) ? SD : SA;
                SE: Y_D = (req_btm2_g) ? SE : SA;
                SF: Y_D = (req_top3_g) ? SF : SA;
                SG: Y_D = (req_btm3_g) ? SG : SA;

                default: Y_D = SA;
            endcase
        end
    end

    // ============================================================
    // MUX OUTPUTS TO VGA
    // ============================================================

    reg [9:0] MUX_x;
    reg [8:0] MUX_y;
    reg [8:0] MUX_color;
    reg       MUX_write;

    always @(*) begin
        // Default: no writes, no grants
        gnt_top1 = 0; gnt_btm1 = 0;
        gnt_top2 = 0; gnt_btm2 = 0;
        gnt_top3 = 0; gnt_btm3 = 0;

        MUX_write = 0;
        MUX_x     = 0;
        MUX_y     = 0;
        MUX_color = 9'b0;

        if (!started) begin
            // BEFORE KEY0 → background only
            MUX_write = 0;
        end
        else if (clearing) begin
            // CLEARING SCREEN
            MUX_x     = clear_x;
            MUX_y     = clear_y;
            MUX_color = 9'b000_000_000;
            MUX_write = 1;
        end
        else begin
            // GAME ACTIVE: select objects normally
            case (y_Q)
                SB: begin gnt_top1  = 1; MUX_write = write_top1;
                          MUX_x     = x_top1; MUX_y = y_top1; MUX_color = color_top1; end
                SC: begin gnt_btm1  = 1; MUX_write = write_btm1;
                          MUX_x     = x_btm1; MUX_y = y_btm1; MUX_color = color_btm1; end

                SD: begin gnt_top2  = 1; MUX_write = write_top2;
                          MUX_x     = x_top2; MUX_y = y_top2; MUX_color = color_top2; end
                SE: begin gnt_btm2  = 1; MUX_write = write_btm2;
                          MUX_x     = x_btm2; MUX_y = y_btm2; MUX_color = color_btm2; end

                SF: begin gnt_top3  = 1; MUX_write = write_top3;
                          MUX_x     = x_top3; MUX_y = y_top3; MUX_color = color_top3; end
                SG: begin gnt_btm3  = 1; MUX_write = write_btm3;
                          MUX_x     = x_btm3; MUX_y = y_btm3; MUX_color = color_btm3; end
            endcase
        end
    end

    always @(posedge CLOCK_50)
        y_Q <= Y_D;

    // ============================================================
    // VGA ADAPTER
    // ============================================================

    vga_adapter VGA(
        .resetn(Resetn),
        .clock(CLOCK_50),
        .color(MUX_color),
        .x(MUX_x),
        .y(MUX_y),
        .write(MUX_write),
        .VGA_R(VGA_R),
        .VGA_G(VGA_G),
        .VGA_B(VGA_B),
        .VGA_HS(VGA_HS),
        .VGA_VS(VGA_VS),
        .VGA_BLANK_N(VGA_BLANK_N),
        .VGA_SYNC_N(VGA_SYNC_N),
        .VGA_CLK(VGA_CLK)
    );

    defparam VGA.RESOLUTION = "640x480";
    defparam VGA.BITS_PER_COLOUR_CHANNEL = 3;  // WIDTH=9
    defparam VGA.BACKGROUND_IMAGE = "startscreen.mif";

    assign LEDR = 10'b0;

endmodule
