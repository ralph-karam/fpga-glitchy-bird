`default_nettype none

module obstacles(
    input  wire        CLOCK_50,
    input  wire [9:0]  SW,
    input  wire [0:0]  KEY,              // KEY[0]
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

    // ------------------- Parameters -------------------
    localparam A = 3'b000, B = 3'b001, C = 3'b010,
               D = 3'b011, E = 3'b100, F = 3'b101, G = 3'b110;

    localparam XSCREEN = 640;
    localparam YSCREEN = 9'd480;
    localparam GAP     = 9'd80;
    localparam MIN_H   = 9'd100;
    localparam RANGE_H = 9'd201;

    wire Resetn = KEY[0];    // active-low pushbutton

    // ------------------- Game start / clear -------------------

    reg started  = 1'b0;     // 0 = show background only, 1 = game logic active
    reg clearing = 1'b0;
    reg [9:0] clear_x = 10'd0;
    reg [8:0] clear_y = 9'd0;

    // KEY[0] press (Resetn goes low) starts the game and clearing
    always @(posedge CLOCK_50 or negedge Resetn) begin
        if (!Resetn) begin
            // First / any press of KEY[0] → start game + clear screen
            started  <= 1'b1;
            clearing <= 1'b1;
            clear_x  <= 10'd0;
            clear_y  <= 9'd0;
        end
        else if (clearing) begin
            // Scan whole screen and write black
            if (clear_x == XSCREEN-1) begin
                clear_x <= 0;
                if (clear_y == YSCREEN-1) begin
                    clear_y  <= 0;
                    clearing <= 1'b0;   // done clearing
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

    // ------------------- Random height -------------------

    wire [7:0] rnd;
    random U1(~Resetn, CLOCK_50, rnd);

    wire [8:0] rand_mod = rnd % RANGE_H;   // 0..200
    wire [8:0] rand_h   = MIN_H + rand_mod; // 100..300

    reg [8:0] top_h1, btm_h1, btm_y1;
    reg [8:0] top_h2, btm_h2, btm_y2;
    reg [8:0] top_h3, btm_h3, btm_y3;

    wire wrap_top1, wrap_top2, wrap_top3;
    wire wrap_btm1, wrap_btm2, wrap_btm3;  // unused, to avoid floating ports

    // Heights
    always @(posedge CLOCK_50 or negedge Resetn) begin
        if (!Resetn) begin
            // Initial fixed heights
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

    // ------------------- Object instances -------------------

    wire [9:0] x_top1, x_btm1, x_top2, x_btm2, x_top3, x_btm3;
    wire [8:0] y_top1, y_btm1, y_top2, y_btm2, y_top3, y_btm3;

    wire [8:0] color_top1, color_btm1, color_top2, color_btm2, color_top3, color_btm3;
    wire       write_top1, write_btm1, write_top2, write_btm2, write_top3, write_btm3;

    wire       req_top1, req_btm1, req_top2, req_btm2, req_top3, req_btm3;

    reg        gnt_top1, gnt_btm1, gnt_top2, gnt_btm2, gnt_top3, gnt_btm3;

    // top1
    object top1 (
        Resetn, CLOCK_50, gnt_top1, req_top1,
        9'd0, top_h1,
        x_top1, y_top1, color_top1, write_top1,
        wrap_top1
    );
    defparam top1.COLOR = 9'b000_111_000;

    // btm1
    object btm1 (
        Resetn, CLOCK_50, gnt_btm1, req_btm1,
        btm_y1, btm_h1,
        x_btm1, y_btm1, color_btm1, write_btm1,
        wrap_btm1
    );
    defparam btm1.X_INIT = 10'd620;
    defparam btm1.COLOR  = 9'b000_111_000;

    // top2
    object top2 (
        Resetn, CLOCK_50, gnt_top2, req_top2,
        9'd0, top_h2,
        x_top2, y_top2, color_top2, write_top2,
        wrap_top2
    );
    defparam top2.X_INIT = 10'd420;
    defparam top2.COLOR  = 9'b000_000_111;

    // btm2
    object btm2 (
        Resetn, CLOCK_50, gnt_btm2, req_btm2,
        btm_y2, btm_h2,
        x_btm2, y_btm2, color_btm2, write_btm2,
        wrap_btm2
    );
    defparam btm2.X_INIT = 10'd420;
    defparam btm2.COLOR  = 9'b000_000_111;

    // top3
    object top3 (
        Resetn, CLOCK_50, gnt_top3, req_top3,
        9'd0, top_h3,
        x_top3, y_top3, color_top3, write_top3,
        wrap_top3
    );
    defparam top3.X_INIT = 10'd220;
    defparam top3.COLOR  = 9'b111_000_000;

    // btm3
    object btm3 (
        Resetn, CLOCK_50, gnt_btm3, req_btm3,
        btm_y3, btm_h3,
        x_btm3, y_btm3, color_btm3, write_btm3,
        wrap_btm3
    );
    defparam btm3.X_INIT = 10'd220;
    defparam btm3.COLOR  = 9'b111_000_000;

    // ------------------- Arbiter FSM -------------------

    reg [2:0] y_Q, Y_D;

    // Next-state logic: **forced idle** if game not started or still clearing
    always @(*) begin
        if (!started || clearing) begin
            Y_D = A;  // stay idle until game starts AND clearing is done
        end
        else begin
            case (y_Q)
                A:  if (req_top1)      Y_D = B;
                    else if (req_btm1) Y_D = C;
                    else if (req_top2) Y_D = D;
                    else if (req_btm2) Y_D = E;
                    else if (req_top3) Y_D = F;
                    else if (req_btm3) Y_D = G;
                    else               Y_D = A;

                B:  Y_D = (req_top1)  ? B : A;
                C:  Y_D = (req_btm1)  ? C : A;
                D:  Y_D = (req_top2)  ? D : A;
                E:  Y_D = (req_btm2)  ? E : A;
                F:  Y_D = (req_top3)  ? F : A;
                G:  Y_D = (req_btm3)  ? G : A;

                default: Y_D = A;
            endcase
        end
    end

    // FSM state FFs
    always @(posedge CLOCK_50 or negedge Resetn) begin
        if (!Resetn)
            y_Q <= A;
        else
            y_Q <= Y_D;
    end

    // ------------------- MUX to VGA -------------------

    reg [9:0] MUX_x;
    reg [8:0] MUX_y;
    reg [8:0] MUX_color;
    reg       MUX_write;

    always @(*) begin
        // defaults
        gnt_top1 = 1'b0; gnt_btm1 = 1'b0;
        gnt_top2 = 1'b0; gnt_btm2 = 1'b0;
        gnt_top3 = 1'b0; gnt_btm3 = 1'b0;

        MUX_x     = 10'd0;
        MUX_y     = 9'd0;
        MUX_color = 9'b000_000_000;
        MUX_write = 1'b0;

        // *** KEY BEHAVIOUR ***
        // 1) Before KEY[0] is EVER pressed: started = 0 → NO WRITES
        //    VGA shows ONLY the BACKGROUND_IMAGE.
        // 2) When KEY[0] is pressed: started=1, clearing=1 → clear black.
        // 3) After clearing: objects are drawn as normal.

        if (!started) begin
            // SHOW ONLY BACKGROUND (no writes at all)
            MUX_write = 1'b0;
        end
        else if (clearing) begin
            // Clear entire screen to black
            MUX_x     = clear_x;
            MUX_y     = clear_y;
            MUX_color = 9'b000_000_000;
            MUX_write = 1'b1;
        end
        else begin
            // Normal game drawing
            case (y_Q)
                A: ; // nothing

                B: begin
                    gnt_top1  = 1'b1;
                    MUX_x     = x_top1;
                    MUX_y     = y_top1;
                    MUX_color = color_top1;
                    MUX_write = write_top1;
                end

                C: begin
                    gnt_btm1  = 1'b1;
                    MUX_x     = x_btm1;
                    MUX_y     = y_btm1;
                    MUX_color = color_btm1;
                    MUX_write = write_btm1;
                end

                D: begin
                    gnt_top2  = 1'b1;
                    MUX_x     = x_top2;
                    MUX_y     = y_top2;
                    MUX_color = color_top2;
                    MUX_write = write_top2;
                end

                E: begin
                    gnt_btm2  = 1'b1;
                    MUX_x     = x_btm2;
                    MUX_y     = y_btm2;
                    MUX_color = color_btm2;
                    MUX_write = write_btm2;
                end

                F: begin
                    gnt_top3  = 1'b1;
                    MUX_x     = x_top3;
                    MUX_y     = y_top3;
                    MUX_color = color_top3;
                    MUX_write = write_top3;
                end

                G: begin
                    gnt_btm3  = 1'b1;
                    MUX_x     = x_btm3;
                    MUX_y     = y_btm3;
                    MUX_color = color_btm3;
                    MUX_write = write_btm3;
                end
            endcase
        end
    end

    // ------------------- VGA adapter -------------------

    vga_adapter VGA (
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
    defparam VGA.RESOLUTION              = "640x480";
    defparam VGA.BITS_PER_COLOUR_CHANNEL = 3;
    defparam VGA.BACKGROUND_IMAGE        = "startscreen.mif";

    assign LEDR = 10'b0;

endmodule
