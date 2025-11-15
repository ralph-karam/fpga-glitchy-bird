// top pillars
defparam top1.IS_TOP = 1;  defparam top1.SEED = 8'd67;
defparam top2.IS_TOP = 1;  defparam top2.SEED = 8'd123;
defparam top3.IS_TOP = 1;  defparam top3.SEED = 8'd201;

// bottom pillars
defparam btm1.IS_TOP = 0;  defparam btm1.SEED = 8'd89;
defparam btm2.IS_TOP = 0;  defparam btm2.SEED = 8'd157;
defparam btm3.IS_TOP = 0;  defparam btm3.SEED = 8'd233;



// implements a moving colored object
module object (Resetn, Clock, gnt, faster, slower, req,
               VGA_x, VGA_y, VGA_color, VGA_write);

    parameter nX = 10;
    parameter nY = 9;

    parameter XSCREEN = 640;
    parameter YSCREEN = 480;

    parameter XDIM = 50, YDIM = 200;   // compile-time default height
    parameter X_INIT = 10'd620;
    parameter Y_INIT = 9'd0;

    parameter COLOR = 9'b111111111;
    parameter ALT   = 9'b000_000_000;

    parameter KK = 21;
    parameter MM = 8;

    // NEW: per-instance settings for randomness and pairing
    parameter SEED   = 8'd67;          // each instance can override with defparam
    parameter IS_TOP = 1;              // 1 = top pillar, 0 = bottom pillar
    parameter GAP    = 9'd120;         // constant gap size (pixels)

    parameter A = 4'b0000, B = 4'b0001, C = 4'b0010, D = 4'b0011,
              E = 4'b0100, F = 4'b0101, G = 4'b0110, H = 4'b0111,
              I = 4'b1000, J = 4'b1001, K = 4'b1010, L = 4'b1011;

    wire [nX-1:0] X_RIGHT = XSCREEN[nX-1:0] - XDIM[nX-1:0];

    input  wire Resetn, Clock;
    input  wire gnt, faster, slower;
    output reg  req;
    output wire [nX-1:0] VGA_x;
    output wire [nY-1:0] VGA_y;
    output wire [8:0]    VGA_color;
    output wire          VGA_write;

    wire [nX-1:0] X, XC, X0;
    wire [nY-1:0] Y, YC, Y0;
    wire [8:0]    color = COLOR;
    wire [KK-1:0] slow;

    reg  Lx, Ly, Ex, Lxc, Lyc, Exc, Eyc;
    wire sync;
    reg  erase, Tdir;
    reg  [3:0] y_Q, Y_D;
    reg  write;

    reg  [2:0] ys_Q, Ys_D;
    reg  sll, srl;
    reg  [MM-1:0] mask;

    assign X0 = X_INIT;
    assign Y0 = Y_INIT;

    // ------------------ NEW: runtime height H with RNG ------------------
    reg  [nY-1:0] H;                   // current height to use instead of YDIM
    wire [7:0] rnd;
    random RNG0(~Resetn, Clock, rnd);
    defparam RNG0.seedInitial = SEED;

    // pick a top height in steps of 8, with floor 40
    wire [nY-1:0] topH_rand = 9'd40 + {rnd[7:4], 3'b000};

    // bottom height chosen to keep a fixed GAP
    wire [nY-1:0] btmH_rand = (YSCREEN[nY-1:0] - GAP[nY-1:0]) - topH_rand;

    // when moving and at left edge, we’re wrapping
    wire wrap_load = (y_Q == I) && (X == {nX{1'b0}});

    // update H on wrap; init to the compile-time YDIM
    always @(posedge Clock or negedge Resetn) begin
        if (!Resetn)
            H <= YDIM[nY-1:0];
        else if (wrap_load)
            H <= (IS_TOP ? topH_rand : btmH_rand);
    end

    // compute Y to keep pillar glued to top or bottom depending on IS_TOP
    wire [nY-1:0] Y_RLOAD = (IS_TOP ? {nY{1'b0}} : (YSCREEN[nY-1:0] - H));
    // --------------------------------------------------------------------

    UpDn_count U2 (X0, Clock, Resetn, Ex, Lx, 1'b0, X);  defparam U2.n = nX;

    // NEW: load Y from Y_RLOAD so bottom pillar follows H
    UpDn_count U1 (Y_RLOAD, Clock, Resetn, 1'b0, Ly, 1'b1, Y);  defparam U1.n = nY;

    UpDn_count U3 ({nX{1'd0}}, Clock, Resetn, Exc, Lxc, 1'b1, XC); defparam U3.n = nX;
    UpDn_count U4 ({nY{1'd0}}, Clock, Resetn, Eyc, Lyc, 1'b1, YC); defparam U4.n = nY;

    Up_count U6 (Clock, Resetn, slow);  defparam U6.n = KK;

    assign sync = ((slow | (mask << KK-MM)) == {KK{1'b1}});

    assign VGA_x     = X + XC;
    assign VGA_y     = Y + YC;
    assign VGA_color = erase == 0 ? color : ALT;
    assign VGA_write = write;

    always @(*)
        case (y_Q)
            A:  Y_D = B;
            B:  if (XC != XDIM-1) Y_D = B; else Y_D = C;
            // NEW: compare YC to H-1 instead of YDIM-1
            C:  if (YC != H-1)    Y_D = B; else Y_D = D;

            D:  if (!sync) Y_D = D; else Y_D = E;
            E:  if (!gnt)  Y_D = E; else Y_D = F;

            F:  if (XC != XDIM-1) Y_D = F; else Y_D = G;
            // NEW: compare YC to H-1 instead of YDIM-1
            G:  if (YC != H-1)    Y_D = F; else Y_D = H;

            H:  Y_D = I;
            I:  Y_D = J;
            J:  if (XC != XDIM-1) Y_D = J; else Y_D = K;
            // NEW: compare YC to H-1 instead of YDIM-1
            K:  if (YC != H-1)    Y_D = J; else Y_D = L;
            L:  Y_D = D;
            default: Y_D = A;
        endcase

    always @(*) begin
        Lx = 1'b0; Ly = 1'b0; Lxc = 1'b0; Lyc = 1'b0; Exc = 1'b0; Eyc = 1'b0;
        erase = 1'b0; write = 1'b0; Ex = 1'b0; Tdir = 1'b0; req = 1'b0;

        case (y_Q)
            A:  begin Lx = 1'b1; Ly = 1'b1; Lxc = 1'b1; Lyc = 1'b1; end
            B:  begin Exc = 1'b1; write = 1'b1; end
            C:  begin Lxc = 1'b1; Eyc = 1'b1; end
            D:  Lyc = 1'b1;
            E:  req = 1'b1;

            F:  begin req = 1'b1; Exc = 1'b1; erase = 1'b1; write = 1'b1; end
            G:  begin req = 1'b1; Lxc = 1'b1; Eyc = 1'b1; end

            H:  begin req = 1'b1; Lyc = 1'b1; Tdir = (Y == 'd0) || (Y == YSCREEN-YDIM); end

            // move
            I:  begin req = 1'b1; Ex = 1'b1;
                     Lx = (X == 'd0);
                     Ly = wrap_load;  // NEW: reload Y when we wrap so bottom follows H
                end

            // draw
            J:  begin req = 1'b1; Exc = 1'b1; write = 1'b1; end
            K:  begin req = 1'b1; Lxc = 1'b1; Eyc = 1'b1; end
            L:  Lyc = 1'b1;
        endcase
    end

    always @(posedge Clock)
        if (Resetn == 0) y_Q <= A;
        else             y_Q <= Y_D;

    // speed mask FSM (unchanged)
    parameter As = 3'b000, Bs = 3'b001, Cs = 3'b010, Ds = 3'b011, Es = 3'b100;

    always @(*) begin
        case (ys_Q)
            As: if (faster) Ys_D = Bs;
                else if (slower) Ys_D = Ds;
                else Ys_D = As;
            Bs: Ys_D = Cs;
            Cs: if (faster) Ys_D = Cs; else Ys_D = As;
            Ds: Ys_D = Es;
            Es: if (slower) Ys_D = Es; else Ys_D = As;
            default: Ys_D = As;
        endcase
    end

    always @(*) begin
        sll = 1'b0; srl = 1'b0;
        case (ys_Q)
            As: ;
            Bs: srl = 1'b1;
            Cs: ;
            Ds: sll = 1'b1;
            Es: ;
        endcase
    end

    always @(posedge Clock)
        if (Resetn == 0) ys_Q <= As;
        else             ys_Q <= Ys_D;

endmodule
