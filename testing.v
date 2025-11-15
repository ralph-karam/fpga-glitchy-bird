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

    // -------- OBJECT INSTANTIATIONS (no #(...)) --------
    // Pair 1
    object top1 (Resetn, CLOCK_50, gnt_top1, faster, slower, req_top1, x_top1, y_top1, color_top1, write_top1);
      defparam top1.nX= nX,  top1.nY= nY;
      defparam top1.COLOR = 9'b000_111_000; // green

    object btm1 (Resetn, CLOCK_50, gnt_btm1, faster, slower, req_btm1, x_btm1, y_btm1, color_btm1, write_btm1);
      defparam btm1.nX= nX,  btm1.nY= nY;
      defparam btm1.X_INIT = 10'd620, btm1.Y_INIT = 9'd0; // Y will be runtime set
      defparam btm1.COLOR = 9'b000_111_000;

    // Pair 2
    object top2 (Resetn, CLOCK_50, gnt_top2, faster, slower, req_top2, x_top2, y_top2, color_top2, write_top2);
      defparam top2.nX= nX,  top2.nY= nY;
      defparam top2.X_INIT = 10'd420;
      defparam top2.COLOR = 9'b111_000_000; // red

    object btm2 (Resetn, CLOCK_50, gnt_btm2, faster, slower, req_btm2, x_btm2, y_btm2, color_btm2, write_btm2);
      defparam btm2.nX= nX,  btm2.nY= nY;
      defparam btm2.X_INIT = 10'd420, btm2.Y_INIT = 9'd0;
      defparam btm2.COLOR = 9'b111_000_000;

    // Pair 3
    object top3 (Resetn, CLOCK_50, gnt_top3, faster, slower, req_top3, x_top3, y_top3, color_top3, write_top3);
      defparam top3.nX= nX,  top3.nY= nY;
      defparam top3.X_INIT = 10'd220;
      defparam top3.COLOR = 9'b000_000_111; // blue

    object btm3 (Resetn, CLOCK_50, gnt_btm3, faster, slower, req_btm3, x_btm3, y_btm3, color_btm3, write_btm3);
      defparam btm3.nX= nX,  btm3.nY= nY;
      defparam btm3.X_INIT = 10'd220, btm3.Y_INIT = 9'd0;
      defparam btm3.COLOR = 9'b000_000_111;

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


//==============================================================
// OBJECT: draws/erases a rectangle, moves left, wraps to right,
// randomizes pair height on wrap while keeping fixed GAP.
//==============================================================
module object(
    Resetn, Clock, gnt, faster, slower, req,
    VGA_x, VGA_y, VGA_color, VGA_write
);
    parameter nX = 10;
    parameter nY = 9;

    parameter XSCREEN = 640;
    parameter YSCREEN = 480;

    parameter XDIM = 50;
    // *** runtime height is H (not a parameter) ***
    parameter H_INIT = 9'd200;

    parameter X_INIT = 10'd620;
    parameter Y_INIT = 9'd0;

    parameter COLOR = 9'b111_111_111;
    parameter ALT   = 9'b000_000_000;

    parameter KK = 21;   // speed
    parameter MM = 8;

    // Randomization controls (pairing)
    parameter IS_TOP = 1;          // 1 = top pillar, 0 = bottom pillar
    parameter GAP    = 9'd140;     // vertical opening between top & bottom
    parameter MIN_H  = 9'd40;      // minimum pillar height
    parameter SEED   = 8'd67;      // LFSR start (same for pair)

    // FSM states for raster
    parameter A=4'b0000,B=4'b0001,C=4'b0010,D=4'b0011,
              E=4'b0100,F=4'b0101,G=4'b0110,Hs=4'b0111,
              I=4'b1000,J=4'b1001,K=4'b1010,L=4'b1011;

    input  wire Resetn, Clock, gnt, faster, slower;
    output reg  req;
    output wire [nX-1:0] VGA_x;
    output wire [nY-1:0] VGA_y;
    output wire [8:0]    VGA_color;
    output wire          VGA_write;

    // position / raster counters
    wire [nX-1:0] X, XC;
    wire [nY-1:0] Y, YC;
    reg  [nY-1:0] H;                     // current pillar height (runtime)

    // slow counter/mask
    wire [KK-1:0] slow;
    reg  [MM-1:0] mask;
    reg  sll, srl;

    // control lines
    reg  Lx, Ly, Ex, Lxc, Lyc, Exc, Eyc;
    reg  erase, write;
    reg  [3:0] y_Q, Y_D;
    reg  [2:0] ys_Q, Ys_D;

    // ---------------- Random: shared within pair by SEED ----------------
    wire [7:0] rnd;
    random #(.seedInitial(SEED)) RNG0 (.reset(~Resetn), .Clock(Clock), .seed(rnd));

    // range for top height so both top & bottom >= MIN_H
    localparam integer RANGE = YSCREEN - GAP - 2*MIN_H; // >= 0
    wire [nY-1:0] topH_from_rnd = MIN_H + (rnd % (RANGE+1));
    wire [nY-1:0] next_H_top    = topH_from_rnd;
    wire [nY-1:0] next_H_btm    = (YSCREEN[nY-1:0] - GAP[nY-1:0]) - topH_from_rnd;

    // base Y depends on whether top or bottom
    wire [nY-1:0] baseY_for_H  = IS_TOP ? {nY{1'b0}} : (YSCREEN[nY-1:0] - H);

    // true only when moving and about to wrap at left edge
    wire wrap_now = (y_Q==I) && (X=={nX{1'b0}});

    // X reload: on wrap -> right edge; else use X_INIT at reset
    wire [nX-1:0] X_RLOAD = wrap_now ? (XSCREEN[nX-1:0] - XDIM[nX-1:0])
                                     : X_INIT[nX-1:0];

    // Y reload: on wrap -> recomputed base after updating H; else initial
    wire [nY-1:0] Y_RLOAD = wrap_now ? baseY_for_H : Y_INIT[nY-1:0];

    // position counters
    UpDn_count Ux (X_RLOAD, Clock, Resetn, Ex, Lx, 1'b0, X); // count down horizontally
      defparam Ux.n = nX;

    UpDn_count Uy (Y_RLOAD, Clock, Resetn, 1'b0, Ly, 1'b1, Y); // load-only vertical base
      defparam Uy.n = nY;

    // raster counters
    UpDn_count Uxc ({nX{1'b0}}, Clock, Resetn, Exc, Lxc, 1'b1, XC); // 0..XDIM-1
      defparam Uxc.n = nX;
    UpDn_count Uyc ({nY{1'b0}}, Clock, Resetn, Eyc, Lyc, 1'b1, YC); // 0..H-1 (uses Lyc test)
      defparam Uyc.n = nY;

    // speed
    Up_count Us (Clock, Resetn, slow);  defparam Us.n = KK;
    wire sync = ((slow | (mask << (KK-MM))) == {KK{1'b1}});

    // pixel outputs
    assign VGA_x     = X + XC;
    assign VGA_y     = Y + YC;
    assign VGA_color = (erase==0) ? COLOR : ALT;
    assign VGA_write = write;

    // ---------------- Raster FSM ----------------
    always @(*) begin
        case (y_Q)
            A: Y_D = B;
            B: Y_D = (XC != (XDIM-1)) ? B : C;
            C: Y_D = (YC != (H-1))    ? B : D;

            D: Y_D = (!sync) ? D : E;
            E: Y_D = (!gnt)  ? E : F;

            F: Y_D = (XC != (XDIM-1)) ? F : G;   // erase
            G: Y_D = (YC != (H-1))    ? F : Hs;

            Hs: Y_D = I;                         // move
            I : Y_D = J;

            J: Y_D = (XC != (XDIM-1)) ? J : K;   // draw
            K: Y_D = (YC != (H-1))    ? J : L;
            L: Y_D = D;
            default: Y_D = A;
        endcase
    end

    // outputs
    always @(*) begin
        // defaults
        Lx=0; Ly=0; Lxc=0; Lyc=0; Ex=0; Exc=0; Eyc=0;
        erase=0; write=0; req=0;

        case (y_Q)
            A : begin Lx=1; Ly=1; Lxc=1; Lyc=1; end
            B : begin Exc=1; write=1; end
            C : begin Lxc=1; Eyc=1; end
            D : Lyc=1;
            E : req=1;
            F : begin req=1; Exc=1; erase=1; write=1; end
            G : begin req=1; Lxc=1; Eyc=1; end
            Hs: begin req=1; Lyc=1; end
            I : begin req=1; Ex=1; Lx = (X=={nX{1'b0}});  Ly = wrap_now; end
            J : begin req=1; Exc=1; write=1; end
            K : begin req=1; Lxc=1; Eyc=1; end
            L : Lyc=1;
        endcase
    end

    // FSM FFs
    always @(posedge Clock)
        if (!Resetn) y_Q <= A;
        else         y_Q <= Y_D;

    // speed mask FSM (unchanged)
    parameter As=3'b000, Bs=3'b001, Cs=3'b010, Ds=3'b011, Es=3'b100;
    always @(*) begin
        case (ys_Q)
            As: Ys_D = (faster ? Bs : (slower ? Ds : As));
            Bs: Ys_D = Cs;
            Cs: Ys_D = (faster ? Cs : As);
            Ds: Ys_D = Es;
            Es: Ys_D = (slower ? Es : As);
            default: Ys_D = As;
        endcase
    end
    always @(*) begin
        sll=0; srl=0;
        case (ys_Q)
            Bs: srl=1;
            Ds: sll=1;
        endcase
    end
    always @(posedge Clock)
        if (!Resetn) begin ys_Q<=As; mask<={MM{1'b0}}; end
        else begin ys_Q<=Ys_D;
             if (srl) mask <= {1'b1, mask[MM-1:1]};
             else if (sll) mask <= {mask[MM-2:0], 1'b0};
        end

    // ---------------- Height update on wrap ----------------
    // Update H *before* Ly reload uses it for bottom base.
    always @(posedge Clock) begin
        if (!Resetn) begin
            H <= H_INIT[nY-1:0];
        end else if (wrap_now) begin
            if (IS_TOP) H <= next_H_top[nY-1:0];
            else         H <= next_H_btm[nY-1:0];
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
