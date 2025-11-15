`default_nettype none

//==============================================================
// TOP-LEVEL: obstacles  (6 pillars: top1/btm1, top2/btm2, top3/btm3)
//==============================================================
module obstacles(
    CLOCK_50, SW, KEY, LEDR,
    VGA_R, VGA_G, VGA_B, VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK
);
    parameter nX = 10; // X bits (<= 640)
    parameter nY = 9;  // Y bits (<= 480)

    // FSM state codes for arbiter
    parameter A = 3'b000, B = 3'b001, C = 3'b010, D = 3'b011,
              E = 3'b100, F = 3'b101, G = 3'b110;

    input  wire        CLOCK_50;
    input  wire [9:0]  SW;
    input  wire [0:0]  KEY;
    output wire [9:0]  LEDR;

    output wire [7:0]  VGA_R, VGA_G, VGA_B;
    output wire        VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK;

    // -------- per-object wires --------
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

    // -------- VGA MUX --------
    reg  [nX-1:0] MUX_x;
    reg  [nY-1:0] MUX_y;
    reg  [8:0]    MUX_color;
    reg           MUX_write;

    reg  [2:0] y_Q, Y_D;

    wire Resetn = KEY[0];
    wire faster = 1'b0; // tie off unless you map to switches
    wire slower = 1'b0;

    // -------- Arbiter FSM (unchanged shape) --------
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
        gnt_top1=0; gnt_btm1=0; gnt_top2=0; gnt_btm2=0; gnt_top3=0; gnt_btm3=0;
        MUX_write=0; MUX_x = x_top1; MUX_y = y_top1; MUX_color = color_top1;
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

    // top1
object top1 (Resetn, CLOCK_50, gnt_top1, faster, slower, req_top1,
             x_top1, y_top1, color_top1, write_top1);
    defparam top1.nX = nX;
    defparam top1.nY = nY;
    defparam top1.COLOR  = 9'b111_000_000; // red
    defparam top1.X_INIT = 10'd620;        // right edge
    defparam top1.IS_TOP = 1;              // <-- top pillar
    defparam top1.SEED   = 8'd101;         // <-- pair seed
    defparam top1.GAP    = 120;
    defparam top1.MIN_TOP= 20;
    defparam top1.MIN_BTM= 20;
    defparam top1.H_INIT = 9'd160;         // initial top height

// btm1
object btm1 (Resetn, CLOCK_50, gnt_btm1, faster, slower, req_btm1,
             x_btm1, y_btm1, color_btm1, write_btm1);
    defparam btm1.nX = nX;
    defparam btm1.nY = nY;
    defparam btm1.COLOR  = 9'b111_000_000; // red
    defparam btm1.X_INIT = 10'd620;        // right edge
    defparam btm1.IS_TOP = 0;              // <-- bottom pillar
    defparam btm1.SEED   = 8'd101;         // <-- same seed as top1
    defparam btm1.GAP    = 120;
    defparam btm1.MIN_TOP= 20;
    defparam btm1.MIN_BTM= 20;
    defparam btm1.H_INIT = 9'd160;         // matches top1 init so gap is GAP

    // =====================
// Pair 2 (top2 / btm2)
// =====================
object top2 (Resetn, CLOCK_50, gnt_top2, faster, slower, req_top2,
             x_top2, y_top2, color_top2, write_top2);
    defparam top2.nX      = nX;
    defparam top2.nY      = nY;
    defparam top2.COLOR   = 9'b000_000_111; // blue (use your color)
    defparam top2.X_INIT  = 10'd420;        // your spacing
    defparam top2.IS_TOP  = 1;              // TOP pillar
    defparam top2.SEED    = 8'd77;          // <-- pair-2 seed
    defparam top2.GAP     = 120;            // gap size
    defparam top2.MIN_TOP = 20;             // min top height
    defparam top2.MIN_BTM = 20;             // min bottom height
    defparam top2.H_INIT  = 9'd160;         // initial top height

object btm2 (Resetn, CLOCK_50, gnt_btm2, faster, slower, req_btm2,
             x_btm2, y_btm2, color_btm2, write_btm2);
    defparam btm2.nX      = nX;
    defparam btm2.nY      = nY;
    defparam btm2.COLOR   = 9'b000_000_111; // blue (use your color)
    defparam btm2.X_INIT  = 10'd420;        // same as top2
    defparam btm2.IS_TOP  = 0;              // BOTTOM pillar
    defparam btm2.SEED    = 8'd77;          // <-- same seed as top2
    defparam btm2.GAP     = 120;
    defparam btm2.MIN_TOP = 20;
    defparam btm2.MIN_BTM = 20;
    defparam btm2.H_INIT  = 9'd160;

// =====================
// Pair 3 (top3 / btm3)
// =====================
object top3 (Resetn, CLOCK_50, gnt_top3, faster, slower, req_top3,
             x_top3, y_top3, color_top3, write_top3);
    defparam top3.nX      = nX;
    defparam top3.nY      = nY;
    defparam top3.COLOR   = 9'b111_000_000; // red (use your color)
    defparam top3.X_INIT  = 10'd220;        // your spacing
    defparam top3.IS_TOP  = 1;              // TOP pillar
    defparam top3.SEED    = 8'd203;         // <-- pair-3 seed
    defparam top3.GAP     = 120;
    defparam top3.MIN_TOP = 20;
    defparam top3.MIN_BTM = 20;
    defparam top3.H_INIT  = 9'd160;

object btm3 (Resetn, CLOCK_50, gnt_btm3, faster, slower, req_btm3,
             x_btm3, y_btm3, color_btm3, write_btm3);
    defparam btm3.nX      = nX;
    defparam btm3.nY      = nY;
    defparam btm3.COLOR   = 9'b111_000_000; // red (use your color)
    defparam btm3.X_INIT  = 10'd220;        // same as top3
    defparam btm3.IS_TOP  = 0;              // BOTTOM pillar
    defparam btm3.SEED    = 8'd203;         // <-- same seed as top3
    defparam btm3.GAP     = 120;
    defparam btm3.MIN_TOP = 20;
    defparam btm3.MIN_BTM = 20;
    defparam btm3.H_INIT  = 9'd160;

    // Pair-level settings via defparam:
    //   IS_TOP tells each object whether it's the top or bottom pillar.
    //   SEED selects its LFSR start so pairs share the same rnd.
    //   GAP  is the fixed opening between top & bottom for that pair.
    //   MIN_H is the minimum pillar height.
    defparam top1.IS_TOP=1, top1.SEED=8'd67,  top1.GAP=9'd140, top1.MIN_H=9'd40;
    defparam btm1.IS_TOP=0, btm1.SEED=8'd67,  btm1.GAP=9'd140, btm1.MIN_H=9'd40;

    defparam top2.IS_TOP=1, top2.SEED=8'd123, top2.GAP=9'd140, top2.MIN_H=9'd40;
    defparam btm2.IS_TOP=0, btm2.SEED=8'd123, btm2.GAP=9'd140, btm2.MIN_H=9'd40;

    defparam top3.IS_TOP=1, top3.SEED=8'd201, top3.GAP=9'd140, top3.MIN_H=9'd40;
    defparam btm3.IS_TOP=0, btm3.SEED=8'd201, btm3.GAP=9'd140, btm3.MIN_H=9'd40;

    // -------- VGA adapter (unchanged) --------
    vga_adapter VGA (
        .resetn(Resetn),
        .clock(CLOCK_50),
        .color(MUX_color),
        .x(MUX_x),
        .y(MUX_y),
        .write(MUX_write),
        .VGA_R(VGA_R), .VGA_G(VGA_G), .VGA_B(VGA_B),
        .VGA_HS(VGA_HS), .VGA_VS(VGA_VS),
        .VGA_BLANK_N(VGA_BLANK_N), .VGA_SYNC_N(VGA_SYNC_N),
        .VGA_CLK(VGA_CLK)
    );
    defparam VGA.BACKGROUND_IMAGE = "./MIF/scenery.mif";

    assign LEDR = 10'b0;
endmodule


// implements a moving colored object (with randomized gap position by pair)
module object (Resetn, Clock, gnt, faster, slower, req,
               VGA_x, VGA_y, VGA_color, VGA_write);

    // pixel coord bit widths
    parameter nX = 10;
    parameter nY = 9;

    // screen
    parameter XSCREEN = 640;
    parameter YSCREEN = 480;

    // pillar width
    parameter XDIM = 50;

    // --- NEW: gap and height constraints ---
    parameter GAP      = 120;      // constant gap size between top & bottom
    parameter MIN_TOP  = 20;       // min height for top pillar
    parameter MIN_BTM  = 20;       // min height for bottom pillar

    // initial top height seed (for first frame after reset)
    parameter H_INIT   = 9'd160;

    // pillar identity within a pair
    parameter IS_TOP   = 1;        // 1 = top pillar (Y=0), 0 = bottom pillar (Y=YSCREEN-H)

    // default initial X (right edge spawn)
    parameter X_INIT   = 10'd620;

    // color
    parameter COLOR    = 9'b111_111_111;
    parameter ALT      = 9'b000_000_000; // erase to black

    // speed control
    parameter KK = 21;
    parameter MM = 8;

    // (unchanged) FSM encodings
    parameter A = 4'b0000, B = 4'b0001, C = 4'b0010, D = 4'b0011,
              E = 4'b0100, F = 4'b0101, G = 4'b0110, Hs= 4'b0111, // renamed to Hs to avoid clash with 'H' height reg
              I = 4'b1000, J = 4'b1001, K = 4'b1010, L = 4'b1011;

    input  wire Resetn, Clock;
    input  wire gnt;
    input  wire faster, slower;
    output reg  req;
    output wire [nX-1:0] VGA_x;
    output wire [nY-1:0] VGA_y;
    output wire [8:0]     VGA_color;
    output wire           VGA_write;

    // position/counters
    wire [nX-1:0] X, XC;
    wire [nY-1:0] Y, YC;
    reg  Lx, Ly, Ex, Lxc, Lyc, Exc, Eyc;
    reg  erase, write;
    reg  [3:0] y_Q, Y_D;

    // speed mask FSM (unchanged)
    reg [2:0] ys_Q, Ys_D; reg sll, srl; reg [MM-1:0] mask;
    wire [KK-1:0] slow;
    wire sync;

    // ---------------- dynamic height ----------------
    reg  [nY-1:0] H;                  // current pillar height actually drawn
    wire [nY-1:0] H_top_next;         // next top height after wrap (randomized)
    wire [nY-1:0] H_btm_next;         // derived bottom height = YSCREEN - GAP - H_top_next

    // pair-randomization: cheap 8-bit LFSR (seed per pair via defparam)
    parameter SEED = 8'd67;           // override per pair so pairs differ
    reg  [7:0] lfsr;
    wire       lfsr_next = lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3];

    // at each clock advance the LFSR (kept simple/small)
    always @(posedge Clock) begin
        if (!Resetn) lfsr <= SEED;
        else         lfsr <= {lfsr[6:0], lfsr_next};
    end

    // map LFSR to a safe top-height range so both pillars fit with constant GAP
    // allowed range for top: [MIN_TOP, YSCREEN - GAP - MIN_BTM]
    localparam integer TOP_MAX = (YSCREEN - GAP - MIN_BTM);
    localparam integer TOP_SPAN = (TOP_MAX - MIN_TOP + 1); // number of discrete values
    wire [nY-1:0] rnd_in_span = (TOP_SPAN > 0) ? (lfsr % TOP_SPAN) : 0;
    assign H_top_next = MIN_TOP[nY-1:0] + rnd_in_span[nY-1:0];
    assign H_btm_next = (YSCREEN - GAP)[nY-1:0] - H_top_next;

    // ---------------- X wrap control ----------------
    wire [nX-1:0] X_RIGHT = XSCREEN[nX-1:0] - XDIM[nX-1:0];
    wire wrap_now = (y_Q == I) && (X == 'd0);
    wire [nX-1:0] X_RLOAD = wrap_now ? X_RIGHT : X_INIT[nX-1:0];

    // ---------------- Y load value ----------------
    // top pillar anchored at Y=0; bottom pillar anchored to bottom edge
    wire [nY-1:0] Y0 = IS_TOP ? {nY{1'b0}} : (YSCREEN[nY-1:0] - H);

    // ---------------- counters ----------------
    UpDn_count U2 (X_RLOAD, Clock, Resetn, Ex, Lx, 1'b0, X);    // X moves left, load at left edge to right
        defparam U2.n = nX;

    UpDn_count U1 (Y0, Clock, Resetn, 1'b0, Ly, 1'b1, Y);       // Y loads to anchor (top=0 or bottom=YSCREEN-H)
        defparam U1.n = nY;

    UpDn_count U3 ({nX{1'b0}}, Clock, Resetn, Exc, Lxc, 1'b1, XC); // pixel sweep X
        defparam U3.n = nX;

    UpDn_count U4 ({nY{1'b0}}, Clock, Resetn, Eyc, Lyc, 1'b1, YC); // pixel sweep Y (0..H-1)
        defparam U4.n = nY;

    Up_count U6 (Clock, Resetn, slow);
        defparam U6.n = KK;

    assign sync      = ((slow | (mask << (KK-MM))) == {KK{1'b1}});
    assign VGA_x     = X + XC;
    assign VGA_y     = Y + YC;
    assign VGA_color = (erase == 1'b0) ? COLOR : ALT;
    assign VGA_write = write;

    // ---------------- FSM next-state (unchanged names) ----------------
    always @(*) begin
        case (y_Q)
            A:  Y_D = B;                          // init sweep
            B:  Y_D = (XC != XDIM-1) ? B : C;     // draw rows: sweep X
            C:  Y_D = (YC != H-1)   ? B : D;      // draw rows: sweep Y (uses H)
            D:  Y_D = (!sync) ? D : E;            // delay
            E:  Y_D = (!gnt)  ? E : F;            // wait VGA grant
            F:  Y_D = (XC != XDIM-1) ? F : G;     // erase rows: sweep X
            G:  Y_D = (YC != H-1)   ? F : Hs;     // erase rows: sweep Y (uses H)
            Hs: Y_D = I;                           // move
            I:  Y_D = J;                           // commit move
            J:  Y_D = (XC != XDIM-1) ? J : K;     // redraw rows
            K:  Y_D = (YC != H-1)   ? J : L;
            L:  Y_D = D;
            default: Y_D = A;
        endcase
    end

    // ---------------- FSM outputs (unchanged pattern; uses H) ----------------
    always @(*) begin
        // defaults
        Lx=0; Ly=0; Lxc=0; Lyc=0; Exc=0; Eyc=0; erase=0; write=0; Ex=0; req=0;
        case (y_Q)
            A:  begin Lx=1; Ly=1; Lxc=1; Lyc=1; end
            B:  begin Exc=1; write=1; end
            C:  begin Lxc=1; Eyc=1; end
            D:  Lyc=1;
            E:  req=1;
            F:  begin req=1; Exc=1; erase=1; write=1; end
            G:  begin req=1; Lxc=1; Eyc=1; end
            Hs: begin req=1; Lyc=1; end
            I:  begin req=1; Ex=1; Lx=(X=='d0); end
            J:  begin req=1; Exc=1; write=1; end
            K:  begin req=1; Lxc=1; Eyc=1; end
            L:  Lyc=1;
        endcase
    end

    // ---------------- Height update & anchoring ----------------
    // Ensure a valid height at power-up, and update on wrap.
    always @(posedge Clock) begin
        if (!Resetn) begin
            H <= IS_TOP ? H_INIT[nY-1:0] : (YSCREEN - GAP - H_INIT)[nY-1:0];
        end else if (y_Q == A) begin
            // guarantees sane height even if KEY[0] never toggled
            H <= IS_TOP ? H_INIT[nY-1:0] : (YSCREEN - GAP - H_INIT)[nY-1:0];
        end else if (wrap_now) begin
            H <= IS_TOP ? H_top_next : H_btm_next;
        end
    end

    // ---------------- speed mask FSM (unchanged) ----------------
    always @(*) begin
        case (ys_Q)
            3'b000: Ys_D = (faster ? 3'b001 : (slower ? 3'b011 : 3'b000));
            3'b001: Ys_D = 3'b010;
            3'b010: Ys_D = (faster ? 3'b010 : 3'b000);
            3'b011: Ys_D = 3'b100;
            3'b100: Ys_D = (slower ? 3'b100 : 3'b000);
            default: Ys_D = 3'b000;
        endcase
    end
    always @(*) begin sll=0; srl=0;
        case (ys_Q)
            3'b001: srl=1;
            3'b011: sll=1;
        endcase
    end
    always @(posedge Clock) begin
        if (!Resetn) begin
            ys_Q <= 3'b000; mask <= 'b0;
        end else begin
            ys_Q <= Ys_D;
            if (srl) begin mask[MM-2:0] <= mask[MM-1:1]; mask[MM-1] <= 1'b1; end
            else if (sll) begin mask[MM-1:1] <= mask[MM-2:0]; mask[0] <= 1'b0; end
        end
    end
endmodule


//==============================================================
// Simple up/down counter with load and enable
//==============================================================
module UpDn_count(R, Clock, Resetn, E, L, UpDn, Q);
    parameter n = 10;
    input  wire [n-1:0] R;
    input  wire Clock, Resetn, E, L, UpDn;
    output reg  [n-1:0] Q;
    always @(posedge Clock)
        if (!Resetn)        Q <= {n{1'b0}};
        else if (L)         Q <= R;
        else if (E)         Q <= UpDn ? (Q + 1'b1) : (Q - 1'b1);
endmodule

//==============================================================
// Simple up counter
//==============================================================
module Up_count(Clock, Resetn, Q);
    parameter n = 20;
    input  wire Clock, Resetn;
    output reg  [n-1:0] Q;
    always @(posedge Clock)
        if (!Resetn) Q <= {n{1'b0}};
        else         Q <= Q + 1'b1;
endmodule

//==============================================================
// 8-bit LFSR (x^8 + x^6 + x^5 + x^4 + 1) — period 255 (nonzero)
//==============================================================
module random #(parameter seedInitial = 8'd67) (
    input  wire reset,
    input  wire Clock,
    output reg  [7:0] seed
);
    wire next = seed[7] ^ seed[5] ^ seed[4] ^ seed[3];
    always @(posedge Clock) begin
        if (reset) seed <= seedInitial;
        else       seed <= {seed[6:0], next};
    end
endmodule
