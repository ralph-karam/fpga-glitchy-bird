`default_nettype none

module obstacles(CLOCK_50, SW, KEY, LEDR, VGA_R, VGA_G, VGA_B,
                 VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK);

    parameter nX = 10;
    parameter nY = 9;

    // FSM states (3 bits because we have up to G)
    parameter A = 3'b000, B = 3'b001, C = 3'b010, D = 3'b011,
              E = 3'b100, F = 3'b101, G = 3'b110;

    input  wire        CLOCK_50;
    input  wire [9:0]  SW;
    input  wire [0:0]  KEY;
    output wire [9:0]  LEDR;
    output wire [7:0]  VGA_R, VGA_G, VGA_B;
    output wire        VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK;

    // -------- Wires for six objects (top/btm 1..3) --------
    wire [nX-1:0] x_top1, x_btm1, x_top2, x_btm2, x_top3, x_btm3;
    wire [nY-1:0] y_top1, y_btm1, y_top2, y_btm2, y_top3, y_btm3;

    wire [8:0] color_top1, color_top2, color_top3;
    wire [8:0] color_btm1, color_btm2, color_btm3;

    wire write_top1, write_top2, write_top3;
    wire write_btm1, write_btm2, write_btm3;

    wire req_top1, req_top2, req_top3;
    wire req_btm1, req_btm2, req_btm3;

    reg  gnt_top1, gnt_top2, gnt_top3;
    reg  gnt_btm1, gnt_btm2, gnt_btm3;

    // VGA mux
    reg  [nX-1:0] MUX_x;
    reg  [nY-1:0] MUX_y;
    reg  [8:0]    MUX_color;
    reg           MUX_write;

    reg  [2:0]    y_Q, Y_D;

    wire Resetn;
    assign Resetn = KEY[0];

    // Tie speed controls low (avoid X)
    wire faster = 1'b0;
    wire slower = 1'b0;

    // ------------ Arbiter ------------
    always @(*) begin
        case (y_Q)
            A:  if (req_top1) Y_D = B;
                else if (req_btm1) Y_D = C;
                else if (req_top2) Y_D = D;
                else if (req_btm2) Y_D = E;
                else if (req_top3) Y_D = F;
                else if (req_btm3) Y_D = G;
                else Y_D = A;

            B:  Y_D = (req_top1) ? B : A;
            C:  Y_D = (req_btm1) ? C : A;
            D:  Y_D = (req_top2) ? D : A;
            E:  Y_D = (req_btm2) ? E : A;
            F:  Y_D = (req_top3) ? F : A;
            G:  Y_D = (req_btm3) ? G : A;
            default: Y_D = A;
        endcase
    end

    always @(*) begin
        // defaults
        gnt_top1 = 1'b0; gnt_btm1 = 1'b0;
        gnt_top2 = 1'b0; gnt_btm2 = 1'b0;
        gnt_top3 = 1'b0; gnt_btm3 = 1'b0;
        MUX_write = 1'b0; MUX_x = x_top1; MUX_y = y_top1; MUX_color = color_top1;

        case (y_Q)
            A: ; // idle
            B: begin gnt_top1 = 1'b1;  MUX_write = write_top1;  MUX_x = x_top1;  MUX_y = y_top1;  MUX_color = color_top1; end
            C: begin gnt_btm1 = 1'b1;  MUX_write = write_btm1;  MUX_x = x_btm1;  MUX_y = y_btm1;  MUX_color = color_btm1; end
            D: begin gnt_top2 = 1'b1;  MUX_write = write_top2;  MUX_x = x_top2;  MUX_y = y_top2;  MUX_color = color_top2; end
            E: begin gnt_btm2 = 1'b1;  MUX_write = write_btm2;  MUX_x = x_btm2;  MUX_y = y_btm2;  MUX_color = color_btm2; end
            F: begin gnt_top3 = 1'b1;  MUX_write = write_top3;  MUX_x = x_top3;  MUX_y = y_top3;  MUX_color = color_top3; end
            G: begin gnt_btm3 = 1'b1;  MUX_write = write_btm3;  MUX_x = x_btm3;  MUX_y = y_btm3;  MUX_color = color_btm3; end
        endcase
    end

    always @(posedge CLOCK_50)
        if (!Resetn) y_Q <= A;
        else         y_Q <= Y_D;

    // --------- Six objects (positional ports + defparam) ---------

    // Pair 1 (spawn right & mid)
    object top1 (Resetn, CLOCK_50, gnt_top1, faster, slower, req_top1, x_top1, y_top1, color_top1, write_top1);
        defparam top1.nX      = nX;
        defparam top1.nY      = nY;
        defparam top1.COLOR   = 9'b111_000_000; // red
        defparam top1.X_INIT  = 10'd620;
        defparam top1.Y_INIT  = 9'd0;           // top pillar base at 0
        defparam top1.MIN_TOP = 9'd20;
        defparam top1.MIN_BTM = 9'd20;
        defparam top1.GAP     = 9'd120;
        defparam top1.IS_TOP  = 1;              // <—— top

    object btm1 (Resetn, CLOCK_50, gnt_btm1, faster, slower, req_btm1, x_btm1, y_btm1, color_btm1, write_btm1);
        defparam btm1.nX      = nX;
        defparam btm1.nY      = nY;
        defparam btm1.COLOR   = 9'b111_000_000; // red
        defparam btm1.X_INIT  = 10'd620;
        defparam btm1.Y_INIT  = 9'd0;           // ignored; base fixed by logic
        defparam btm1.MIN_TOP = 9'd20;
        defparam btm1.MIN_BTM = 9'd20;
        defparam btm1.GAP     = 9'd120;
        defparam btm1.IS_TOP  = 0;              // <—— bottom

    // Pair 2 (stagger left)
    object top2 (Resetn, CLOCK_50, gnt_top2, faster, slower, req_top2, x_top2, y_top2, color_top2, write_top2);
        defparam top2.nX      = nX;
        defparam top2.nY      = nY;
        defparam top2.COLOR   = 9'b111_000_000;
        defparam top2.X_INIT  = 10'd420;
        defparam top2.Y_INIT  = 9'd0;
        defparam top2.MIN_TOP = 9'd20;
        defparam top2.MIN_BTM = 9'd20;
        defparam top2.GAP     = 9'd120;
        defparam top2.IS_TOP  = 1;

    object btm2 (Resetn, CLOCK_50, gnt_btm2, faster, slower, req_btm2, x_btm2, y_btm2, color_btm2, write_btm2);
        defparam btm2.nX      = nX;
        defparam btm2.nY      = nY;
        defparam btm2.COLOR   = 9'b111_000_000;
        defparam btm2.X_INIT  = 10'd420;
        defparam btm2.Y_INIT  = 9'd0;
        defparam btm2.MIN_TOP = 9'd20;
        defparam btm2.MIN_BTM = 9'd20;
        defparam btm2.GAP     = 9'd120;
        defparam btm2.IS_TOP  = 0;

    // Pair 3 (stagger further left)
    object top3 (Resetn, CLOCK_50, gnt_top3, faster, slower, req_top3, x_top3, y_top3, color_top3, write_top3);
        defparam top3.nX      = nX;
        defparam top3.nY      = nY;
        defparam top3.COLOR   = 9'b111_000_000;
        defparam top3.X_INIT  = 10'd220;
        defparam top3.Y_INIT  = 9'd0;
        defparam top3.MIN_TOP = 9'd20;
        defparam top3.MIN_BTM = 9'd20;
        defparam top3.GAP     = 9'd120;
        defparam top3.IS_TOP  = 1;

    object btm3 (Resetn, CLOCK_50, gnt_btm3, faster, slower, req_btm3, x_btm3, y_btm3, color_btm3, write_btm3);
        defparam btm3.nX      = nX;
        defparam btm3.nY      = nY;
        defparam btm3.COLOR   = 9'b111_000_000;
        defparam btm3.X_INIT  = 10'd220;
        defparam btm3.Y_INIT  = 9'd0;
        defparam btm3.MIN_TOP = 9'd20;
        defparam btm3.MIN_BTM = 9'd20;
        defparam btm3.GAP     = 9'd120;
        defparam btm3.IS_TOP  = 0;

    // VGA
    vga_adapter VGA (
        .resetn(KEY[0]),
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
    defparam VGA.BACKGROUND_IMAGE = "./MIF/scenery.mif";

    assign LEDR[9:0] = 10'b0;
endmodule


// ----------------- Counters -----------------
module UpDn_count (R, Clock, Resetn, E, L, UpDn, Q);
    parameter n = 10;
    input  wire [n-1:0] R;
    input  wire         Clock, Resetn, E, L, UpDn;
    output reg  [n-1:0] Q;
    always @(posedge Clock)
        if (!Resetn)        Q <= {n{1'b0}};
        else if (L)         Q <= R;
        else if (E)         Q <= UpDn ? (Q + 1'b1) : (Q - 1'b1);
endmodule

module Up_count (Clock, Resetn, Q);
    parameter n = 20;
    input  wire Clock, Resetn;
    output reg  [n-1:0] Q;
    always @(posedge Clock)
        if (!Resetn) Q <= {n{1'b0}};
        else         Q <= Q + 1'b1;
endmodule


// ----------------- Object (with exact-gap random wrap) -----------------
module object (Resetn, Clock, gnt, faster, slower, req,
               VGA_x, VGA_y, VGA_color, VGA_write);

    parameter nX = 10;
    parameter nY = 9;

    parameter XSCREEN = 640;
    parameter YSCREEN = 480;

    parameter XDIM = 50, YDIM = 200; // YDIM unused once YDIMr active (kept for compat)

    parameter X_INIT = 10'd620;
    parameter Y_INIT = 9'd0;

    parameter COLOR  = 9'b111_000_000;
    parameter ALT    = 9'b000_000_000;

    parameter KK = 21;
    parameter MM = 8;

    // gap controls (9-bit params), and which half we are
    parameter MIN_TOP = 9'd20;
    parameter MIN_BTM = 9'd20;
    parameter GAP     = 9'd120;
    parameter IS_TOP  = 1;      // 1 = top, 0 = bottom
    parameter SEED    = 8'd67;

    input  wire Resetn, Clock, gnt, faster, slower;
    output reg  req;
    output wire [nX-1:0] VGA_x;
    output wire [nY-1:0] VGA_y;
    output wire [8:0]    VGA_color;
    output wire          VGA_write;

    // Position/counters
    wire [nX-1:0] X, XC, X0;
    wire [nY-1:0] Y, YC, Y0;
    reg           Lx, Ly, Ex, Lxc, Lyc, Exc, Eyc;
    reg           erase, Tdir, write;
    reg  [3:0]    y_Q, Y_D;

    // Speed mask FSM (kept but faster/slower tied low)
    reg  [2:0]    ys_Q, Ys_D;
    reg           sll, srl;
    reg  [MM-1:0] mask;

    // Random + variable height/base (registered)
    reg  [7:0]    lfsr;
    wire          lfsr_fb = lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3];
    reg  [nY-1:0] YDIMr;     // active height of this pillar
    reg  [nY-1:0] YBASEr;    // base Y of this pillar (0 for top, 480 - YDIMr for bottom)

    // Do all math in 10 bits
    localparam [9:0] YSCR10 = 10'd480;
    wire [8:0]       color  = COLOR;

    // Slow counter for movement timing
    wire [KK-1:0] slow;
    Up_count U6 (Clock, Resetn, slow);
        defparam U6.n = KK;

    // sync timing: default scheme from your code
    wire sync = ((slow | (mask << (KK-MM))) == {KK{1'b1}});

    // VGA outputs
    assign VGA_x     = X + XC;
    assign VGA_y     = Y + YC;
    assign VGA_color = (erase == 1'b0) ? color : ALT;
    assign VGA_write = write;

    // X reload logic: on wrap, load right edge; at reset use X_INIT
    wire [nX-1:0] X_RIGHT  = XSCREEN[nX-1:0] - XDIM[nX-1:0];
    wire          wrap_now = (y_Q == 4'b1000 /* I */) && (X == {nX{1'b0}});
    wire [nX-1:0] X_RLOAD  = wrap_now ? X_RIGHT : X_INIT[nX-1:0];

    // Y0 is dynamic: always load from current YBASEr register
    assign X0 = X_RLOAD;
    assign Y0 = YBASEr;

    // Counters: X moves left (count down via Ex), Y stays fixed (we reload Ly on reset/wrap)
    UpDn_count U2 (X0, Clock, Resetn, Ex, Lx, 1'b0, X);
        defparam U2.n = nX;

    UpDn_count U1 (Y0, Clock, Resetn, 1'b0, Ly, 1'b1, Y);
        defparam U1.n = nY;

    // Pixel scan counters (XC/YC): XC up to XDIM, YC up to YDIMr
    UpDn_count U3 ({nX{1'b0}}, Clock, Resetn, Exc, Lxc, 1'b1, XC);
        defparam U3.n = nX;

    UpDn_count U4 ({nY{1'b0}}, Clock, Resetn, Eyc, Lyc, 1'b1, YC);
        defparam U4.n = nY;

    // ------------- FSM (unchanged flow; only YC limits use YDIMr) -------------
    always @(*) begin
        case (y_Q)
            4'b0000: Y_D = 4'b0001; // A->B
            4'b0001: Y_D = (XC != (XDIM-1)) ? 4'b0001 : 4'b0010; // B
            4'b0010: Y_D = (YC != (YDIMr-1)) ? 4'b0001 : 4'b0011; // C (uses YDIMr)
            4'b0011: Y_D = (!sync) ? 4'b0011 : 4'b0100;           // D
            4'b0100: Y_D = (!gnt)  ? 4'b0100 : 4'b0101;           // E
            4'b0101: Y_D = (XC != (XDIM-1)) ? 4'b0101 : 4'b0110;  // F
            4'b0110: Y_D = (YC != (YDIMr-1)) ? 4'b0101 : 4'b0111; // G (uses YDIMr)
            4'b0111: Y_D = 4'b1000;                               // H
            4'b1000: Y_D = 4'b1001;                               // I
            4'b1001: Y_D = (XC != (XDIM-1)) ? 4'b1001 : 4'b1010;  // J
            4'b1010: Y_D = (YC != (YDIMr-1)) ? 4'b1001 : 4'b1011; // K (uses YDIMr)
            4'b1011: Y_D = 4'b0011;                               // L -> D
            default: Y_D = 4'b0000;
        endcase
    end

    always @(*) begin
        // defaults
        Lx=1'b0; Ly=1'b0; Lxc=1'b0; Lyc=1'b0; Exc=1'b0; Eyc=1'b0;
        erase=1'b0; write=1'b0; Ex=1'b0; Tdir=1'b0; req=1'b0;

        case (y_Q)
            4'b0000: begin Lx=1'b1; Ly=1'b1; Lxc=1'b1; Lyc=1'b1; end // A init
            4'b0001: begin Exc=1'b1; write=1'b1; end                 // B draw scan X
            4'b0010: begin Lxc=1'b1; Eyc=1'b1; end                   // C next scan row
            4'b0011: Lyc=1'b1;                                       // D reload YC
            4'b0100: req=1'b1;                                       // E request
            4'b0101: begin req=1'b1; Exc=1'b1; erase=1'b1; write=1'b1; end // F erase scan X
            4'b0110: begin req=1'b1; Lxc=1'b1; Eyc=1'b1; end               // G
            4'b0111: begin req=1'b1; Lyc=1'b1; Tdir = (Y == {nY{1'b0}}) || (Y == (YSCREEN[nY-1:0]-YDIMr)); end // H
            4'b1000: begin req=1'b1; Ex=1'b1; Lx = (X == {nX{1'b0}}); Ly = (X == {nX{1'b0}}); end // I move + reload at wrap
            4'b1001: begin req=1'b1; Exc=1'b1; write=1'b1; end       // J draw scan X
            4'b1010: begin req=1'b1; Lxc=1'b1; Eyc=1'b1; end         // K
            4'b1011: Lyc=1'b1;                                       // L
        endcase
    end

    always @(posedge Clock)
        if (!Resetn) y_Q <= 4'b0000;
        else         y_Q <= Y_D;

    // Speed-mask FSM kept but inactive (faster/slower=0)
    parameter As = 3'b000, Bs = 3'b001, Cs = 3'b010, Ds = 3'b011, Es = 3'b100;
    always @(*) begin
        case (ys_Q)
            As: Ys_D = As;
            Bs: Ys_D = Cs;
            Cs: Ys_D = As;
            Ds: Ys_D = Es;
            Es: Ys_D = As;
            default: Ys_D = As;
        endcase
    end
    always @(*) begin sll=1'b0; srl=1'b0; if (ys_Q==Bs) srl=1'b1; else if (ys_Q==Ds) sll=1'b1; end
    always @(posedge Clock) begin
        if (!Resetn) begin mask <= {MM{1'b0}}; ys_Q <= As; end
        else begin
            ys_Q <= Ys_D;
            if (srl) begin mask[MM-2:0] <= mask[MM-1:1]; mask[MM-1] <= 1'b1; end
            else if (sll) begin mask[MM-1:1] <= mask[MM-2:0]; mask[0] <= 1'b0; end
        end
    end

    // -------- Random exact-gap logic (updates ONLY on wrap) --------
    // Compute a legal y-center range so that:
    // top height >= MIN_TOP, bottom height >= MIN_BTM, opening width exactly GAP.
    wire [9:0] HALF_GAP = {1'b0, GAP} >> 1;
    wire [9:0] ymin10   = {1'b0, MIN_TOP} + HALF_GAP;
    wire [9:0] ymax10   = YSCR10 - ({1'b0, MIN_BTM} + HALF_GAP);
    wire [9:0] range10  = (ymax10 > ymin10) ? (ymax10 - ymin10) : 10'd0;

    // scale 8-bit LFSR into [0..range10]
    wire [17:0] mult    = {10'd0, lfsr} * range10;   // 8x10 -> 18
    wire [9:0]  offs10  = mult[17:8];
    wire [9:0]  ycenter = ymin10 + offs10;

    // exact top/bottom heights so that top + GAP + bottom = 480
    wire [9:0] top_h10  = (ycenter > HALF_GAP)               ? (ycenter - HALF_GAP) : 10'd0;
    wire [9:0] btm_h10  = (YSCR10 > (ycenter + HALF_GAP))    ? (YSCR10 - (ycenter + HALF_GAP)) : 10'd0;

    wire [nY-1:0] next_YDIMr  = IS_TOP ? top_h10[nY-1:0] : btm_h10[nY-1:0];
    wire [nY-1:0] next_YBASEr = IS_TOP ? {nY{1'b0}}      : (YSCR10 - { { (10-nY){1'b0} }, next_YDIMr });

    // init to centered legal opening; update on wrap
    always @(posedge Clock) begin
        if (!Resetn) begin
            lfsr   <= SEED[7:0];
            YDIMr  <= IS_TOP
                      ? ( ({1'b0,MIN_TOP} + HALF_GAP) [nY-1:0] )
                      : ( (YSCR10 - ({1'b0,MIN_BTM} + HALF_GAP)) [nY-1:0] );
            YBASEr <= IS_TOP ? {nY{1'b0}} : (YSCR10 - { {(10-nY){1'b0}}, YDIMr });
        end else if (wrap_now) begin
            lfsr   <= {lfsr[6:0], lfsr_fb};
            YDIMr  <= next_YDIMr;
            YBASEr <= next_YBASEr;
        end
    end

endmodule
