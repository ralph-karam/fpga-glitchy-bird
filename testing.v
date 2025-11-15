`default_nettype none

module obstacles(CLOCK_50, SW, KEY, LEDR, VGA_R, VGA_G, VGA_B,
                 VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK);

    // pixel coordinate widths
    parameter nX = 10;
    parameter nY = 9;

    // arbiter states
    parameter A = 3'b000, B = 3'b001, C = 3'b010, D = 3'b011,
              E = 3'b100, F = 3'b101, G = 3'b110;

    input  wire        CLOCK_50;
    input  wire [9:0]  SW;
    input  wire [0:0]  KEY;
    output wire [9:0]  LEDR;
    output wire [7:0]  VGA_R;
    output wire [7:0]  VGA_G;
    output wire [7:0]  VGA_B;
    output wire        VGA_HS;
    output wire        VGA_VS;
    output wire        VGA_BLANK_N;
    output wire        VGA_SYNC_N;
    output wire        VGA_CLK;

    // six objects: top1/btm1, top2/btm2, top3/btm3
    wire [nX-1:0] x_top1, x_btm1, x_top2, x_btm2, x_top3, x_btm3;
    wire [nY-1:0] y_top1, y_btm1, y_top2, y_btm2, y_top3, y_btm3;

    wire [8:0]  color_top1, color_top2, color_top3;
    wire [8:0]  color_btm1, color_btm2, color_btm3;

    wire        write_top1, write_top2, write_top3;
    wire        write_btm1, write_btm2, write_btm3;

    wire        req_top1, req_top2, req_top3;
    wire        req_btm1, req_btm2, req_btm3;

    reg         gnt_top1, gnt_top2, gnt_top3;
    reg         gnt_btm1, gnt_btm2, gnt_btm3;

    reg  [nX-1:0] MUX_x;
    reg  [nY-1:0] MUX_y;
    reg  [8:0]    MUX_color;
    reg           MUX_write;
    reg  [2:0]    y_Q, Y_D;

    wire Resetn = KEY[0];
    wire faster = SW[0];
    wire slower = SW[1];

    // -------- Arbiter (unchanged shape, extended to 6 objects) --------
    always @(*) begin
        case (y_Q)
            A:  if (req_top1) Y_D = B;
                else if (req_btm1) Y_D = C;
                else if (req_top2) Y_D = D;
                else if (req_btm2) Y_D = E;
                else if (req_top3) Y_D = F;
                else if (req_btm3) Y_D = G;
                else Y_D = A;

            B:  Y_D = (req_top1 ) ? B : A;
            C:  Y_D = (req_btm1 ) ? C : A;
            D:  Y_D = (req_top2 ) ? D : A;
            E:  Y_D = (req_btm2 ) ? E : A;
            F:  Y_D = (req_top3 ) ? F : A;
            G:  Y_D = (req_btm3 ) ? G : A;
            default: Y_D = A;
        endcase
    end

    always @(*) begin
        gnt_top1=0; gnt_btm1=0; gnt_top2=0; gnt_btm2=0; gnt_top3=0; gnt_btm3=0;
        MUX_write=0; MUX_x=x_top1; MUX_y=y_top1; MUX_color=color_top1;
        case (y_Q)
            A: ;
            B: begin gnt_top1=1; MUX_write=write_top1; MUX_x=x_top1; MUX_y=y_top1; MUX_color=color_top1; end
            C: begin gnt_btm1=1; MUX_write=write_btm1; MUX_x=x_btm1; MUX_y=y_btm1; MUX_color=color_btm1; end
            D: begin gnt_top2=1; MUX_write=write_top2; MUX_x=x_top2; MUX_y=y_top2; MUX_color=color_top2; end
            E: begin gnt_btm2=1; MUX_write=write_btm2; MUX_x=x_btm2; MUX_y=y_btm2; MUX_color=color_btm2; end
            F: begin gnt_top3=1; MUX_write=write_top3; MUX_x=x_top3; MUX_y=y_top3; MUX_color=color_top3; end
            G: begin gnt_btm3=1; MUX_write=write_btm3; MUX_x=x_btm3; MUX_y=y_btm3; MUX_color=color_btm3; end
        endcase
    end

    always @(posedge CLOCK_50)
        if (!Resetn) y_Q <= A;
        else         y_Q <= Y_D;

    // ------------------- OBJECT INSTANTIATIONS -------------------
    // Pair 1 (green), X=620, seed 101
    object top1 (Resetn, CLOCK_50, gnt_top1, faster, slower, req_top1, x_top1, y_top1, color_top1, write_top1);
        defparam top1.nX      = nX;
        defparam top1.nY      = nY;
        defparam top1.X_INIT  = 10'd620;
        defparam top1.COLOR   = 9'b000_111_000;
        defparam top1.IS_TOP  = 1;
        defparam top1.SEED    = 8'd101;   // pair seed
        defparam top1.GAP     = 9'd120;
        defparam top1.MIN_TOP = 9'd20;
        defparam top1.MIN_BTM = 9'd20;

    object btm1 (Resetn, CLOCK_50, gnt_btm1, faster, slower, req_btm1, x_btm1, y_btm1, color_btm1, write_btm1);
        defparam btm1.nX      = nX;
        defparam btm1.nY      = nY;
        defparam btm1.X_INIT  = 10'd620;
        defparam btm1.COLOR   = 9'b000_111_000;
        defparam btm1.IS_TOP  = 0;
        defparam btm1.SEED    = 8'd101;   // same seed as top1
        defparam btm1.GAP     = 9'd120;
        defparam btm1.MIN_TOP = 9'd20;
        defparam btm1.MIN_BTM = 9'd20;

    // Pair 2 (blue), X=420, seed 77
    object top2 (Resetn, CLOCK_50, gnt_top2, faster, slower, req_top2, x_top2, y_top2, color_top2, write_top2);
        defparam top2.nX      = nX;
        defparam top2.nY      = nY;
        defparam top2.X_INIT  = 10'd420;
        defparam top2.COLOR   = 9'b000_000_111;
        defparam top2.IS_TOP  = 1;
        defparam top2.SEED    = 8'd77;
        defparam top2.GAP     = 9'd120;
        defparam top2.MIN_TOP = 9'd20;
        defparam top2.MIN_BTM = 9'd20;

    object btm2 (Resetn, CLOCK_50, gnt_btm2, faster, slower, req_btm2, x_btm2, y_btm2, color_btm2, write_btm2);
        defparam btm2.nX      = nX;
        defparam btm2.nY      = nY;
        defparam btm2.X_INIT  = 10'd420;
        defparam btm2.COLOR   = 9'b000_000_111;
        defparam btm2.IS_TOP  = 0;
        defparam btm2.SEED    = 8'd77;   // same seed as top2
        defparam btm2.GAP     = 9'd120;
        defparam btm2.MIN_TOP = 9'd20;
        defparam btm2.MIN_BTM = 9'd20;

    // Pair 3 (red), X=220, seed 203
    object top3 (Resetn, CLOCK_50, gnt_top3, faster, slower, req_top3, x_top3, y_top3, color_top3, write_top3);
        defparam top3.nX      = nX;
        defparam top3.nY      = nY;
        defparam top3.X_INIT  = 10'd220;
        defparam top3.COLOR   = 9'b111_000_000;
        defparam top3.IS_TOP  = 1;
        defparam top3.SEED    = 8'd203;
        defparam top3.GAP     = 9'd120;
        defparam top3.MIN_TOP = 9'd20;
        defparam top3.MIN_BTM = 9'd20;

    object btm3 (Resetn, CLOCK_50, gnt_btm3, faster, slower, req_btm3, x_btm3, y_btm3, color_btm3, write_btm3);
        defparam btm3.nX      = nX;
        defparam btm3.nY      = nY;
        defparam btm3.X_INIT  = 10'd220;
        defparam btm3.COLOR   = 9'b111_000_000;
        defparam btm3.IS_TOP  = 0;
        defparam btm3.SEED    = 8'd203; // same seed as top3
        defparam btm3.GAP     = 9'd120;
        defparam btm3.MIN_TOP = 9'd20;
        defparam btm3.MIN_BTM = 9'd20;

    // VGA
    vga_adapter VGA (
        .resetn (KEY[0]),
        .clock  (CLOCK_50),
        .color  (MUX_color),
        .x      (MUX_x),
        .y      (MUX_y),
        .write  (MUX_write),
        .VGA_R  (VGA_R),
        .VGA_G  (VGA_G),
        .VGA_B  (VGA_B),
        .VGA_HS (VGA_HS),
        .VGA_VS (VGA_VS),
        .VGA_BLANK_N (VGA_BLANK_N),
        .VGA_SYNC_N  (VGA_SYNC_N),
        .VGA_CLK     (VGA_CLK)
    );
    defparam VGA.BACKGROUND_IMAGE = "./MIF/scenery.mif";

    assign LEDR = 10'b0;
endmodule


// -------------------- Up/Down counter --------------------
module UpDn_count (R, Clock, Resetn, E, L, UpDn, Q);
    parameter n = 10;
    input  wire [n-1:0] R;
    input  wire         Clock, Resetn, E, L, UpDn;
    output reg  [n-1:0] Q;

    always @(posedge Clock) begin
        if (!Resetn)      Q <= {n{1'b0}};
        else if (L)       Q <= R;
        else if (E)       Q <= (UpDn ? (Q + 1'b1) : (Q - 1'b1));
    end
endmodule

// -------------------- Up counter --------------------
module Up_count (Clock, Resetn, Q);
    parameter n = 20;
    input  wire Clock, Resetn;
    output reg  [n-1:0] Q;
    always @(posedge Clock) begin
        if (!Resetn) Q <= {n{1'b0}};
        else         Q <= Q + 1'b1;
    end
endmodule


// ===================== OBJECT with random gap =====================
module object (Resetn, Clock, gnt, faster, slower, req,
               VGA_x, VGA_y, VGA_color, VGA_write);

    // geometry / screen
    parameter nX = 10;
    parameter nY = 9;
    parameter XSCREEN = 640;
    parameter YSCREEN = 480;

    // pillar width; height is dynamic now
    parameter XDIM = 50;

    // fixed initial X and top/btm flag
    parameter X_INIT = 10'd620;
    parameter IS_TOP = 1;           // 1=top (anchored at y=0), 0=bottom (anchored at bottom)

    // colors
    parameter COLOR = 9'b111_111_111;
    parameter ALT   = 9'b000_000_000;

    // speed controls (unchanged)
    parameter KK = 21;
    parameter MM = 8;

    // gap + bounds
    parameter GAP     = 9'd120;     // vertical opening size (constant for all wraps)
    parameter MIN_TOP = 9'd20;      // minimum height for top pillar
    parameter MIN_BTM = 9'd20;      // minimum height for bottom pillar

    // LFSR seed (per pair): top and bottom of the same pair must share SEED
    parameter SEED    = 8'd67;

    // FSM states (unchanged)
    parameter A = 4'b0000, B = 4'b0001, C = 4'b0010, D = 4'b0011,
              E = 4'b0100, F = 4'b0101, G = 4'b0110, H = 4'b0111,
              I = 4'b1000, J = 4'b1001, K = 4'b1010, L = 4'b1011;

    input  wire Resetn, Clock;
    input  wire gnt, faster, slower;
    output reg  req;
    output wire [nX-1:0] VGA_x;
    output wire [nY-1:0] VGA_y;
    output wire [8:0]    VGA_color;
    output wire          VGA_write;

    // position & raster
    wire [nX-1:0] X_RIGHT = XSCREEN[nX-1:0] - XDIM[nX-1:0];

    wire [nX-1:0] X, XC;
    wire [nY-1:0] Y, YC;
    reg           Lx, Ly, Ex, Lxc, Lyc, Exc, Eyc; // controls
    reg           erase, write;
    reg  [3:0]    y_Q, Y_D;

    // dynamic height and base Y (for top: base=0; for bottom: base=YSCREEN-YDIMr)
    reg  [nY-1:0] YDIMr;     // current pillar height
    reg  [nY-1:0] YBASEr;    // current base Y (0 for top, else bottom anchor)

    // slow counter + mask (unchanged)
    wire [KK-1:0] slow;
    reg  [MM-1:0] mask;
    reg  [2:0]    ys_Q, Ys_D;
    reg           sll, srl;
    wire          sync;

    // -------- Random LFSR (advance only on wrap) --------
    reg  [7:0] lfsr;
    wire       lfsr_next = lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3];

    // detect wrap in move state
    wire wrap_cycle = (y_Q == I) && (X == {nX{1'b0}});

    // map LFSR to a valid gap center range
    // ymin = MIN_TOP + GAP/2
    // ymax = YSCREEN - (MIN_BTM + GAP/2)
    // center = ymin + (lfsr * (ymax - ymin)) >> 8
    // top_height  = center - GAP/2
    // btm_height  = YSCREEN - (center + GAP/2)
    // clamp via MIN_*

    wire [9:0] half_gap = {1'b0, GAP} >> 1; // 10-bit safe
    wire [9:0] ymin10   = {1'b0, MIN_TOP} + half_gap;
    wire [9:0] ymax10   = 10'd480 - ({1'b0, MIN_BTM} + half_gap);
    wire [9:0] range10  = (ymax10 > ymin10) ? (ymax10 - ymin10) : 10'd0;

    wire [17:0] mult    = lfsr * range10;           // 8x10 -> 18 bits
    wire [9:0]  scaled  = mult[17:8];               // >> 8
    wire [9:0]  ycenter = ymin10 + scaled;          // 10-bit center

    wire [9:0]  top_h10 = (ycenter > half_gap) ? (ycenter - half_gap) : 10'd0;
    wire [9:0]  btm_h10 = (10'd480 > (ycenter + half_gap)) ? (10'd480 - (ycenter + half_gap)) : 10'd0;

    // clamp each side to its minimum
    wire [9:0] top_h_clamp = (top_h10  < {1'b0, MIN_TOP}) ? {1'b0, MIN_TOP} : top_h10;
    wire [9:0] btm_h_clamp = (btm_h10  < {1'b0, MIN_BTM}) ? {1'b0, MIN_BTM} : btm_h10;

    // next height/base computed from LFSR
    wire [nY-1:0] next_YDIMr  = IS_TOP ? top_h_clamp[nY-1:0] : btm_h_clamp[nY-1:0];
    wire [nY-1:0] next_YBASEr = IS_TOP ? {nY{1'b0}} : (10'd480 - next_YDIMr);

    // choose X load value: always respawn at right edge
    wire [nX-1:0] X_RLOAD = wrap_cycle ? X_RIGHT : X_INIT[nX-1:0];

    // choose Y load value from current base
    wire [nY-1:0] Y0_dyn = YBASEr;

    // counters
    UpDn_count U2 (X_RLOAD, Clock, Resetn, Ex, Lx, 1'b0, X);   // X moves left; load on Lx
        defparam U2.n = nX;

    UpDn_count U1 (Y0_dyn,  Clock, Resetn, 1'b0, Ly, 1'b1, Y); // Y fixed; load on Ly
        defparam U1.n = nY;

    UpDn_count U3 ({nX{1'b0}}, Clock, Resetn, Exc, Lxc, 1'b1, XC); // horizontal raster
        defparam U3.n = nX;

    UpDn_count U4 ({nY{1'b0}}, Clock, Resetn, Eyc, Lyc, 1'b1, YC); // vertical raster
        defparam U4.n = nY;

    Up_count    U6 (Clock, Resetn, slow); // speed
        defparam U6.n = KK;

    assign sync = ((slow | (mask << (KK-MM))) == {KK{1'b1}});

    // pixel outputs
    assign VGA_x     = X + XC;
    assign VGA_y     = Y + YC;
    assign VGA_color = (erase == 1'b0) ? COLOR : ALT;
    assign VGA_write = write;

    // ---------------- Draw/Erase/Move FSM (unchanged sequencing) ----------------
    always @(*) begin
        case (y_Q)
            A: Y_D = B;
            B: Y_D = (XC != (XDIM-1)) ? B : C;
            C: Y_D = (YC != (YDIMr-1)) ? B : D;
            D: Y_D = (!sync) ? D : E;
            E: Y_D = (!gnt)  ? E : F;
            F: Y_D = (XC != (XDIM-1)) ? F : G;
            G: Y_D = (YC != (YDIMr-1)) ? F : H;
            H: Y_D = I;
            I: Y_D = J;
            J: Y_D = (XC != (XDIM-1)) ? J : K;
            K: Y_D = (YC != (YDIMr-1)) ? J : L;
            L: Y_D = D;
            default: Y_D = A;
        endcase
    end

    always @(*) begin
        // defaults
        Lx=0; Ly=0; Lxc=0; Lyc=0; Exc=0; Eyc=0;
        erase=0; write=0; Ex=0; req=0;

        case (y_Q)
            A: begin Lx=1; Ly=1; Lxc=1; Lyc=1; end

            // draw
            B: begin Exc=1; write=1; end
            C: begin Lxc=1; Eyc=1; end

            // wait & request
            D: Lyc=1;
            E: req=1;

            // erase
            F: begin req=1; Exc=1; erase=1; write=1; end
            G: begin req=1; Lxc=1; Eyc=1; end

            // compute next Y base at wrap; also reload Y when wrapping
            H: begin
                req=1;
                Lyc=1;
            end

            // move X left; reload at left edge; also reload Y at wrap
            I: begin
                req=1;
                Ex=1;
                Lx = (X == {nX{1'b0}});
                Ly = (X == {nX{1'b0}});
            end

            // draw
            J: begin req=1; Exc=1; write=1; end
            K: begin req=1; Lxc=1; Eyc=1; end
            L: Lyc=1;
        endcase
    end

    // FSM FFs
    always @(posedge Clock) begin
        if (!Resetn) y_Q <= A;
        else         y_Q <= Y_D;
    end

    // speed mask FSM (unchanged)
    parameter As = 3'b000, Bs = 3'b001, Cs = 3'b010, Ds = 3'b011, Es = 3'b100;

    always @(*) begin
        case (ys_Q)
            As: if (faster) Ys_D = Bs;
                else if (slower) Ys_D = Ds;
                else Ys_D = As;
            Bs: Ys_D = Cs;
            Cs: Ys_D = (faster) ? Cs : As;
            Ds: Ys_D = Es;
            Es: Ys_D = (slower) ? Es : As;
            default: Ys_D = As;
        endcase
    end

    always @(*) begin
        sll=0; srl=0;
        case (ys_Q)
            As: ;
            Bs: srl=1;
            Cs: ;
            Ds: sll=1;
            Es: ;
        endcase
    end

    always @(posedge Clock) begin
        if (!Resetn) ys_Q <= As;
        else         ys_Q <= Ys_D;
    end

    always @(posedge Clock) begin
        if (!Resetn)       mask <= {MM{1'b0}};
        else if (srl)      mask <= {1'b1, mask[MM-1:1]};
        else if (sll)      mask <= {mask[MM-2:0], 1'b0};
    end

    // ---------- LFSR & dynamic height/base registers ----------
    always @(posedge Clock) begin
        if (!Resetn) begin
            lfsr   <= SEED[7:0];
            // initialize height/base to a valid configuration
            YDIMr  <= IS_TOP ? (MIN_TOP + (GAP>>1)) : (YSCREEN[nY-1:0] - (MIN_BTM + (GAP>>1)));
            YBASEr <= IS_TOP ? {nY{1'b0}} : (YSCREEN[nY-1:0] - YDIMr);
        end else begin
            if (wrap_cycle) begin
                // advance RNG and latch new height & base
                lfsr   <= {lfsr[6:0], lfsr_next};
                YDIMr  <= next_YDIMr;
                YBASEr <= next_YBASEr;
            end
        end
    end

endmodule
