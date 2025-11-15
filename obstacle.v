`default_nettype none

//======================== TOP MODULE ========================//
module obstacles(CLOCK_50, SW, KEY, LEDR, VGA_R, VGA_G, VGA_B,
                 VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK);

    // VGA coordinate bitwidths
    parameter nX = 10;  // 0..639
    parameter nY = 9;   // 0..479

    // simple round-robin arbiter states (3 bits)
    parameter A=3'b000, B=3'b001, C=3'b010, D=3'b011, E=3'b100, F=3'b101, G=3'b110;

    input  wire        CLOCK_50;
    input  wire [9:0]  SW;
    input  wire [0:0]  KEY;
    output wire [9:0]  LEDR;
    output wire [7:0]  VGA_R, VGA_G, VGA_B;
    output wire        VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK;

    // one reset key only; nothing happens until this is pressed (goes 1)
    wire Resetn = KEY[0];

    // we aren't using speed keys for now; tie low
    wire faster = 1'b0, slower = 1'b0;

    // six objects (top/btm for three columns)
    wire [nX-1:0] x_top1, x_btm1, x_top2, x_btm2, x_top3, x_btm3;
    wire [nY-1:0] y_top1, y_btm1, y_top2, y_btm2, y_top3, y_btm3;
    wire [8:0]    color_top1, color_btm1, color_top2, color_btm2, color_top3, color_btm3;
    wire          write_top1, write_btm1, write_top2, write_btm2, write_top3, write_btm3;
    wire          req_top1,   req_btm1,   req_top2,   req_btm2,   req_top3,   req_btm3;
    reg           gnt_top1,   gnt_btm1,   gnt_top2,   gnt_btm2,   gnt_top3,   gnt_btm3;

    // VGA MUX
    reg  [nX-1:0] MUX_x;
    reg  [nY-1:0] MUX_y;
    reg  [8:0]    MUX_color;
    reg           MUX_write;

    // arbiter FSM
    reg  [2:0] y_Q, Y_D;

    // --------- Arbiter: next state --------- //
    always @(*) begin
        case (y_Q)
            A:      if      (req_top1) Y_D = B;
                    else if (req_btm1) Y_D = C;
                    else if (req_top2) Y_D = D;
                    else if (req_btm2) Y_D = E;
                    else if (req_top3) Y_D = F;
                    else if (req_btm3) Y_D = G;
                    else                Y_D = A;
            B:      Y_D = (req_top1) ? B : A;
            C:      Y_D = (req_btm1) ? C : A;
            D:      Y_D = (req_top2) ? D : A;
            E:      Y_D = (req_btm2) ? E : A;
            F:      Y_D = (req_top3) ? F : A;
            G:      Y_D = (req_btm3) ? G : A;
            default:Y_D = A;
        endcase
    end

    // --------- Arbiter: outputs/MUX --------- //
    always @(*) begin
        // defaults
        gnt_top1 = 1'b0; gnt_btm1 = 1'b0; gnt_top2 = 1'b0;
        gnt_btm2 = 1'b0; gnt_top3 = 1'b0; gnt_btm3 = 1'b0;
        MUX_write = 1'b0; MUX_x = x_top1; MUX_y = y_top1; MUX_color = color_top1;

        case (y_Q)
            A: ; // idle
            B: begin gnt_top1 = 1'b1; MUX_write = write_top1; MUX_x = x_top1; MUX_y = y_top1; MUX_color = color_top1; end
            C: begin gnt_btm1 = 1'b1; MUX_write = write_btm1; MUX_x = x_btm1; MUX_y = y_btm1; MUX_color = color_btm1; end
            D: begin gnt_top2 = 1'b1; MUX_write = write_top2; MUX_x = x_top2; MUX_y = y_top2; MUX_color = color_top2; end
            E: begin gnt_btm2 = 1'b1; MUX_write = write_btm2; MUX_x = x_btm2; MUX_y = y_btm2; MUX_color = color_btm2; end
            F: begin gnt_top3 = 1'b1; MUX_write = write_top3; MUX_x = x_top3; MUX_y = y_top3; MUX_color = color_top3; end
            G: begin gnt_btm3 = 1'b1; MUX_write = write_btm3; MUX_x = x_btm3; MUX_y = y_btm3; MUX_color = color_btm3; end
        endcase
    end

    // --------- Arbiter FF --------- //
    always @(posedge CLOCK_50)
        if (Resetn == 0) y_Q <= A;
        else             y_Q <= Y_D;

    // ===== Objects (pairs share SEED; TOP=1 for top, 0 for bottom) ===== //

    // pair 1 at the right edge
    object top1 (Resetn, CLOCK_50, gnt_top1, faster, slower, req_top1, x_top1, y_top1, color_top1, write_top1);
        defparam top1.nX = nX, top1.nY = nY;
        defparam top1.X_INIT = 10'd620;  // start near right border
        defparam top1.TOP = 1,   top1.SEED = 8'd13, top1.COLOR = 9'b111_000_000;

    object btm1 (Resetn, CLOCK_50, gnt_btm1, faster, slower, req_btm1, x_btm1, y_btm1, color_btm1, write_btm1);
        defparam btm1.nX = nX, btm1.nY = nY;
        defparam btm1.X_INIT = 10'd620;
        defparam btm1.TOP = 0,   btm1.SEED = 8'd13, btm1.COLOR = 9'b111_000_000;

    // pair 2
    object top2 (Resetn, CLOCK_50, gnt_top2, faster, slower, req_top2, x_top2, y_top2, color_top2, write_top2);
        defparam top2.nX = nX, top2.nY = nY;
        defparam top2.X_INIT = 10'd420;
        defparam top2.TOP = 1,   top2.SEED = 8'd77, top2.COLOR = 9'b111_000_000;

    object btm2 (Resetn, CLOCK_50, gnt_btm2, faster, slower, req_btm2, x_btm2, y_btm2, color_btm2, write_btm2);
        defparam btm2.nX = nX, btm2.nY = nY;
        defparam btm2.X_INIT = 10'd420;
        defparam btm2.TOP = 0,   btm2.SEED = 8'd77, btm2.COLOR = 9'b111_000_000;

    // pair 3
    object top3 (Resetn, CLOCK_50, gnt_top3, faster, slower, req_top3, x_top3, y_top3, color_top3, write_top3);
        defparam top3.nX = nX, top3.nY = nY;
        defparam top3.X_INIT = 10'd220;
        defparam top3.TOP = 1,   top3.SEED = 8'd201, top3.COLOR = 9'b111_000_000;

    object btm3 (Resetn, CLOCK_50, gnt_btm3, faster, slower, req_btm3, x_btm3, y_btm3, color_btm3, write_btm3);
        defparam btm3.nX = nX, btm3.nY = nY;
        defparam btm3.X_INIT = 10'd220;
        defparam btm3.TOP = 0,   btm3.SEED = 8'd201, btm3.COLOR = 9'b111_000_000;

    // VGA adapter
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

//================== SMALL COUNTERS ==================//
module UpDn_count (R, Clock, Resetn, E, L, UpDn, Q);
    parameter n = 10;
    input  wire [n-1:0] R;
    input  wire Clock, Resetn, E, L, UpDn;
    output reg  [n-1:0] Q;
    always @(posedge Clock)
        if (Resetn == 0) Q <= {n{1'b0}};
        else if (L)      Q <= R;
        else if (E)      Q <= UpDn ? (Q + 1'b1) : (Q - 1'b1);
endmodule

module Up_count (Clock, Resetn, Q);
    parameter n = 20;
    input  wire Clock, Resetn;
    output reg  [n-1:0] Q;
    always @(posedge Clock)
        if (Resetn == 0) Q <= {n{1'b0}};
        else             Q <= Q + 1'b1;
endmodule

//======================== LFSR ========================//
// (kept exactly like you wrote; runs continuously)
module random #(parameter seedInitial = 8'd67) (reset, Clock, seed);
    input  wire reset;
    input  wire Clock;
    output reg  [7:0] seed;
    wire next = seed[7] ^ seed[5] ^ seed[4] ^ seed[3];
    always @(posedge Clock)
        if (reset)     seed <= seedInitial;
        else           seed <= {seed[6:0], next};
endmodule

//==================== OBJECT (pillar) ====================//
module object (Resetn, Clock, gnt, faster, slower, req,
               VGA_x, VGA_y, VGA_color, VGA_write);

    // geometry
    parameter nX=10, nY=9;
    parameter XSCREEN=640, YSCREEN=480;
    parameter XDIM=50,  YDIM=200;       // NOT used for height anymore (kept for width)
    parameter X_INIT=10'd620;
    parameter TOP=1;                    // 1 = top pillar, 0 = bottom pillar
    parameter COLOR=9'b111_000_000;
    parameter ALT  =9'b000_000_000;     // erase color
    parameter KK=21, MM=8;

    // randomizer
    parameter SEED = 8'd67;
    parameter GAP  = 9'd120;            // fixed opening
    parameter TOP_MIN = 9'd40;          // clamp for top height

    // ports
    input  wire Resetn, Clock, gnt, faster, slower;
    output reg  req;
    output wire [nX-1:0] VGA_x;
    output wire [nY-1:0] VGA_y;
    output wire [8:0]    VGA_color;
    output wire          VGA_write;

    // internal position/counters
    wire [nX-1:0] X_RIGHT = XSCREEN[nX-1:0] - XDIM[nX-1:0];
    wire [nX-1:0] X, XC, X0;
    wire [nY-1:0] Y, YC, Y0;

    reg  Lx, Ly, Ex, Lxc, Lyc, Exc, Eyc;
    reg  erase, Tdir, write;
    reg  [3:0] y_Q, Y_D;

    // speed mask FSM (kept, but keys tied low by top)
    reg  [2:0] ys_Q, Ys_D;
    reg  sll, srl;
    reg  [MM-1:0] mask;
    wire [KK-1:0] slow;

    // ---------- random height & base ---------- //
    // run LFSR continuously, sample on wrap
    wire [7:0] rnd;
    random #(.seedInitial(SEED)) RNG (~Resetn, Clock, rnd);

    // clamp candidate into legal top height range
    localparam [8:0] TOP_MAX = YSCREEN - GAP - 1;  // 480 - GAP - 1
    wire [8:0] cand_h = {1'b0, rnd} + 9'd60;       // 60..315 (already within range)
    wire [8:0] top_h_next = (cand_h > TOP_MAX) ? TOP_MAX : cand_h;

    // registers holding this pillar's current base Y and height
    reg  [nY-1:0] y_base_reg;   // where to start drawing vertically
    reg  [nY-1:0] ydim_reg;     // how tall to draw (runtime height)

    // choose dynamic load for X so wrap goes to right edge
    wire wrap_load = (y_Q==I) && (X == 'd0);
    wire [nX-1:0] X_RLOAD = wrap_load ? X_RIGHT : X_INIT;

    // Y is dynamic: base is y_base_reg
    assign X0 = X_RLOAD;
    assign Y0 = y_base_reg;

    // counters
    UpDn_count Ux (X0, Clock, Resetn, Ex, Lx, 1'b0, X);   defparam Ux.n = nX; // move left only
    UpDn_count Uy (Y0, Clock, Resetn, 1'b0, Ly, 1'b1, Y); defparam Uy.n = nY; // hold Y (load only)

    UpDn_count Uxc ({nX{1'b0}}, Clock, Resetn, Exc, Lxc, 1'b1, XC); defparam Uxc.n = nX;
    UpDn_count Uyc ({nY{1'b0}}, Clock, Resetn, Eyc, Lyc, 1'b1, YC); defparam Uyc.n = nY;

    Up_count    Us (Clock, Resetn, slow); defparam Us.n = KK;

    // sync for speed control
    wire sync = ((slow | (mask << (KK-MM))) == {KK{1'b1}});

    // VGA outs
    assign VGA_x     = X + XC;
    assign VGA_y     = Y + YC;
    assign VGA_color = erase ? ALT : COLOR;
    assign VGA_write = write;

    // ---------- FSM (draw/erase/move) ---------- //
    parameter A0=4'b0000, B0=4'b0001, C0=4'b0010, D0=4'b0011,
              E0=4'b0100, F0=4'b0101, G0=4'b0110, H0=4'b0111,
              I =4'b1000, J =4'b1001, K =4'b1010, L =4'b1011; // I named explicitly

    // next state
    always @(*) begin
        case (y_Q)
            A0: Y_D = B0;

            B0: Y_D = (XC != (XDIM-1)) ? B0 : C0;     // initial draw (one time)
            C0: Y_D = (YC != (ydim_reg-1)) ? B0 : D0;

            D0: Y_D = (!sync) ? D0 : E0;              // wait for speed tick
            E0: Y_D = (!gnt)  ? E0 : F0;              // wait for grant

            F0: Y_D = (XC != (XDIM-1)) ? F0 : G0;     // erase
            G0: Y_D = (YC != (ydim_reg-1)) ? F0 : H0;

            H0: Y_D = I;                               // prepare to move
            I : Y_D = J;                               // move+wrap handled in outputs

            J : Y_D = (XC != (XDIM-1)) ? J  : K;      // draw
            K : Y_D = (YC != (ydim_reg-1)) ? J : L;
            L : Y_D = D0;
            default: Y_D = A0;
        endcase
    end

    // outputs
    always @(*) begin
        // defaults
        Lx=0; Ly=0; Lxc=0; Lyc=0; Exc=0; Eyc=0; Ex=0;
        erase=0; write=0; req=0; Tdir=0;

        case (y_Q)
            A0: begin Lx=1; Ly=1; Lxc=1; Lyc=1; end  // init counters

            B0: begin Exc=1; write=1; end            // color a pixel, incr XC
            C0: begin Lxc=1; Eyc=1; end              // next row

            D0: Lyc=1;                               // reload YC
            E0: req=1;                               // request draw/erase window

            F0: begin req=1; Exc=1; erase=1; write=1; end // erase
            G0: begin req=1; Lxc=1; Eyc=1; end

            H0: begin req=1; Lyc=1; end

            I : begin req=1; Ex=1; Lx=(X=='d0); end  // move; wrap when at left edge

            J : begin req=1; Exc=1; write=1; end     // draw
            K : begin req=1; Lxc=1; Eyc=1; end
            L : Lyc=1;
        endcase
    end

    // state FFs
    always @(posedge Clock)
        if (Resetn==0) y_Q <= A0;
        else           y_Q <= Y_D;

    // ---------- dynamic height/base update ----------
    // On reset: seed top height; top starts at y=0; bottom uses same top height + GAP
    // On each wrap: sample RNG and update to a new top height (both top & bottom sample
    // the same rnd because they share SEED and move in lockstep).
    always @(posedge Clock) begin
        if (Resetn==0) begin
            if (TOP) begin
                y_base_reg <= {nY{1'b0}};           // top anchored at y=0
                ydim_reg   <= top_h_next[nY-1:0];
            end else begin
                // bottom: base = top_h + GAP, height = rest of screen
                y_base_reg <= (top_h_next + GAP)[nY-1:0];
                ydim_reg   <= (YSCREEN - (top_h_next + GAP))[nY-1:0];
            end
        end else if (wrap_load) begin
            if (TOP) begin
                y_base_reg <= {nY{1'b0}};
                ydim_reg   <= top_h_next[nY-1:0];
            end else begin
                y_base_reg <= (top_h_next + GAP)[nY-1:0];
                ydim_reg   <= (YSCREEN - (top_h_next + GAP))[nY-1:0];
            end
        end
    end

    // ---------- speed mask FSM (unchanged, keys tied low) ----------
    parameter As=3'b000, Bs=3'b001, Cs=3'b010, Ds=3'b011, Es=3'b100;
    always @(*) begin
        case (ys_Q)
            As:  Ys_D = (faster ? Bs : (slower ? Ds : As));
            Bs:  Ys_D = Cs;
            Cs:  Ys_D = (faster ? Cs : As);
            Ds:  Ys_D = Es;
            Es:  Ys_D = (slower ? Es : As);
            default: Ys_D = As;
        endcase
    end
    always @(*) begin
        sll=1'b0; srl=1'b0;
        case (ys_Q)
            Bs: srl=1'b1;
            Ds: sll=1'b1;
            default: ;
        endcase
    end
    always @(posedge Clock)
        if (Resetn==0) ys_Q <= As;
        else           ys_Q <= Ys_D;

    always @(posedge Clock) begin
        if (Resetn==0) mask <= {MM{1'b0}};
        else if (srl)  mask <= {1'b1, mask[MM-1:1]};
        else if (sll)  mask <= {mask[MM-2:0], 1'b0};
    end

endmodule
