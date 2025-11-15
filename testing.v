`default_nettype none

// -------------------- LFSR (your original) --------------------
module random #(parameter seedInitial = 8'd67) (reset, Clock, seed);
    input reset;
    input Clock;
    output reg [7:0] seed;

    wire next;
    assign next = seed[7] ^ seed[5] ^ seed[4] ^ seed[3];

    always @(posedge Clock) begin
        if (reset) begin
            seed <= seedInitial;
        end else begin
            seed <= {seed[6:0], next};
        end
    end
endmodule

// -------------------- Up/Down counter --------------------
module UpDn_count (R, Clock, Resetn, E, L, UpDn, Q);
    parameter n = 10;
    input  wire [n-1:0] R;
    input  wire Clock, Resetn, E, L, UpDn;
    output reg  [n-1:0] Q;

    always @ (posedge Clock)
        if (Resetn == 0)
            Q <= {n{1'b0}};
        else if (L == 1)
            Q <= R;
        else if (E)
            if (UpDn == 1)
                Q <= Q + 1'b1;
            else
                Q <= Q - 1'b1;
endmodule

// -------------------- Up counter --------------------
module Up_count (Clock, Resetn, Q);
    parameter n = 20;
    input  wire Clock, Resetn;
    output reg  [n-1:0] Q;

    always @ (posedge Clock)
        if (Resetn == 0)
            Q <= {n{1'b0}};
        else 
            Q <= Q + 1'b1;
endmodule

// -------------------- OBJECT (adds randomized vertical gap; no motion before Resetn) --------------------
module object (Resetn, Clock, gnt, faster, slower, req,  
               VGA_x, VGA_y, VGA_color, VGA_write);

    // coordinate widths
    parameter nX = 10;
    parameter nY = 9;

    // screen geometry
    parameter XSCREEN = 640;
    parameter YSCREEN = 480;

    // base geometry (X width fixed; Y height becomes runtime via ydim_reg)
    parameter XDIM = 50;
    parameter YDIM = 200;      // default initial height (top pipe uses until first wrap)

    // default initial location (used only before first wrap)
    parameter X_INIT = 10'd620;
    parameter Y_INIT = 9'd0;

    // color params
    parameter COLOR = 9'b111_111_111;
    parameter ALT   = 9'b000_000_000;

    // motion timing
    parameter KK = 21;
    parameter MM = 8;

    // pipe role & gap
    parameter TOP  = 1;           // 1 = top pipe anchored at Y=0, 0 = bottom pipe below gap
    parameter GAP  = 9'd120;      // constant gap height
    parameter SEED = 8'd67;       // unique per pair (top/btm) or per lane

    // FSM states
    parameter A = 4'b0000, B = 4'b0001, C = 4'b0010, D = 4'b0011,
              E = 4'b0100, F = 4'b0101, G = 4'b0110, H = 4'b0111,
              I = 4'b1000, J = 4'b1001, K = 4'b1010, L = 4'b1011;

    // cast to widths used
    localparam [nX-1:0] XSCR_NX = 10'd640;
    localparam [nX-1:0] XDIM_NX = 10'd50;
    wire [nX-1:0] X_RIGHT = XSCR_NX - XDIM_NX;

    input  wire Resetn, Clock;
    input  wire gnt;
    input  wire faster, slower;
    output reg  req;
    output wire [nX-1:0] VGA_x;
    output wire [nY-1:0] VGA_y;
    output wire [8:0]    VGA_color;
    output wire          VGA_write;

    // position and traversers
    wire [nX-1:0] X, XC, X0;
    wire [nY-1:0] Y, YC, Y0;

    // runtime geometry
    reg  [nY-1:0] y_base_reg;   // vertical start of this rectangle
    reg  [nY-1:0] ydim_reg;     // runtime height

    // color & slow counter
    wire [8:0]    color = COLOR;
    wire [KK-1:0] slow;

    // control
    reg  Lx, Ly, Ex, Lxc, Lyc, Exc, Eyc;
    wire sync;
    reg  erase;
    reg  [3:0] y_Q, Y_D;
    reg  write;

    // speed control FSM and mask (single declaration here; no duplicates)
    reg  [2:0] ys_Q, Ys_D;
    reg  sll, srl;
    reg  [MM-1:0] mask;

    // ---------- RANDOM ----------
    wire [7:0] lfsr_seed;
    random #(SEED) RND (.reset(~Resetn), .Clock(Clock), .seed(lfsr_seed));
    // Map to a safe top height range: keep margins so bottom pipe won’t clip
    localparam [nY-1:0] MIN_TOP  = 9'd24;
    localparam [nY-1:0] MAX_TOP  = YSCREEN - GAP - 9'd24;
    wire [nY-1:0] rnd127         = {1'b0, lfsr_seed[7:1]};        // 0..127
    wire [nY-1:0] top_h_candidate= MIN_TOP + rnd127;              // 24..151 (typ.)
    wire [nY-1:0] top_h_clamped  = (top_h_candidate > MAX_TOP) ? MAX_TOP : top_h_candidate;

    // wrap detection (in move state, when X hits 0)
    wire wrap_load = (y_Q == I) && (X == 'd0);

    // X reload source: right edge at wrap; initial X otherwise
    wire [nX-1:0] X_RLOAD = wrap_load ? X_RIGHT : X_INIT[nX-1:0];

    // hook base registers as counter load sources
    assign X0 = X_RLOAD;
    assign Y0 = y_base_reg;

    // X position (count left; load when Lx asserted)
    UpDn_count U2 (X0, Clock, Resetn, Ex, Lx, 1'b0, X);
        defparam U2.n = nX;

    // Y position (constant within frame; reload from y_base_reg when Ly asserted)
    UpDn_count U1 (Y0, Clock, Resetn, 1'b0, Ly, 1'b1, Y);
        defparam U1.n = nY;

    // pixel traversers
    UpDn_count U3 ({nX{1'b0}}, Clock, Resetn, Exc, Lxc, 1'b1, XC);
        defparam U3.n = nX;
    UpDn_count U4 ({nY{1'b0}}, Clock, Resetn, Eyc, Lyc, 1'b1, YC);
        defparam U4.n = nY;

    // slow counter
    Up_count U6 (Clock, Resetn, slow);
        defparam U6.n = KK;

    // speed mask gate
    assign sync = ((slow | (mask << (KK-MM))) == {KK{1'b1}});

    // VGA outputs
    assign VGA_x     = X + XC;
    assign VGA_y     = Y + YC;
    assign VGA_color = (erase == 1'b0) ? color : ALT;
    assign VGA_write = write;

    // runtime Y geometry update (nothing moves while Resetn==0)
    always @(posedge Clock) begin
        if (Resetn == 0) begin
            // Hold a benign initial geometry until user releases Reset
            if (TOP) begin
                y_base_reg <= {nY{1'b0}};          // top starts at Y=0
                ydim_reg   <= YDIM[nY-1:0];
            end else begin
                y_base_reg <= Y_INIT[nY-1:0];      // your default for bottom
                ydim_reg   <= YSCREEN[nY-1:0] - y_base_reg;
            end
        end else if (wrap_load) begin
            // At each wrap, pick a new gap position using the LFSR
            if (TOP) begin
                y_base_reg <= {nY{1'b0}};                  // anchored at top
                ydim_reg   <= (top_h_clamped == 9'd0) ? 9'd1 : top_h_clamped;
            end else begin
                y_base_reg <= top_h_clamped + GAP[nY-1:0]; // start below gap
                // ensure positive height
                if (YSCREEN[nY-1:0] > (top_h_clamped + GAP[nY-1:0]))
                    ydim_reg <= YSCREEN[nY-1:0] - (top_h_clamped + GAP[nY-1:0]);
                else
                    ydim_reg <= 9'd1;
            end
        end
    end

    // --------------- DRAW/ERASE/MOVE FSM ----------------
    always @(*) begin
        case (y_Q)
            A:  Y_D = B;                                   // init
            B:  Y_D = (XC != XDIM-1)     ? B : C;          // draw row
            C:  Y_D = (YC != ydim_reg-1) ? B : D;          // next row / done
            D:  Y_D = (!sync)            ? D : E;          // wait speed
            E:  Y_D = (!gnt)             ? E : F;          // get VGA grant
            F:  Y_D = (XC != XDIM-1)     ? F : G;          // erase row
            G:  Y_D = (YC != ydim_reg-1) ? F : H;          // next row / done
            H:  Y_D = I;                                   // move phase
            I:  Y_D = J;                                   // (one-cycle move bookkeeping)
            J:  Y_D = (XC != XDIM-1)     ? J : K;          // redraw row
            K:  Y_D = (YC != ydim_reg-1) ? J : L;          // next row / done
            L:  Y_D = D;                                   // back to delay
            default: Y_D = A;
        endcase
    end

    always @(*) begin
        // defaults
        Lx=1'b0; Ly=1'b0; Lxc=1'b0; Lyc=1'b0; Exc=1'b0; Eyc=1'b0;
        erase=1'b0; write=1'b0; Ex=1'b0; req=1'b0;

        case (y_Q)
            A:  begin Lx=1'b1; Ly=1'b1; Lxc=1'b1; Lyc=1'b1; end
            B:  begin Exc=1'b1; write=1'b1; end
            C:  begin Lxc=1'b1; Eyc=1'b1; end
            D:  Lyc=1'b1;
            E:  req=1'b1;
            F:  begin req=1'b1; Exc=1'b1; erase=1'b1; write=1'b1; end
            G:  begin req=1'b1; Lxc=1'b1; Eyc=1'b1; end
            H:  begin req=1'b1; Lyc=1'b1; end
            I:  begin req=1'b1; Ex=1'b1; Lx=(X=='d0); Ly=(X=='d0); end  // reload X (to right edge) and Y (new gap) at wrap
            J:  begin req=1'b1; Exc=1'b1; write=1'b1; end
            K:  begin req=1'b1; Lxc=1'b1; Eyc=1'b1; end
            L:  Lyc=1'b1;
        endcase
    end

    always @(posedge Clock) begin
        if (Resetn == 0) y_Q <= A;
        else             y_Q <= Y_D;
    end

    // --------------- SPEED MASK FSM ----------------
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
        sll=1'b0; srl=1'b0;
        case (ys_Q)
            As: ;
            Bs: srl=1'b1;           // speed up
            Cs: ;
            Ds: sll=1'b1;           // slow down
            Es: ;
        endcase
    end

    always @(posedge Clock) begin
        if (Resetn == 0) ys_Q <= As;
        else             ys_Q <= Ys_D;
    end

    always @(posedge Clock) begin
        if (Resetn == 0)
            mask <= {MM{1'b0}};
        else if (srl) begin
            mask[MM-2:0] <= mask[MM-1:1];
            mask[MM-1]   <= 1'b1;
        end else if (sll) begin
            mask[MM-1:1] <= mask[MM-2:0];
            mask[0]      <= 1'b0;
        end
    end

endmodule

// -------------------- OBSTACLES (unchanged structure; adds defparams only) --------------------
module obstacles(CLOCK_50, SW, KEY, LEDR, VGA_R, VGA_G, VGA_B,
                 VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK);

    parameter nX = 10;
    parameter nY = 9;

    // FSM state encodings for arbiter
    parameter A = 3'b000, B = 3'b001, C = 3'b010, D = 3'b011, E = 3'b100, F = 3'b101, G = 3'b110;

    input  wire CLOCK_50;	
    input  wire [9:0] SW;
    input  wire [0:0] KEY;
    output wire [9:0] LEDR;
    output wire [7:0] VGA_R;
    output wire [7:0] VGA_G;
    output wire [7:0] VGA_B;
    output wire VGA_HS;
    output wire VGA_VS;
    output wire VGA_BLANK_N;
    output wire VGA_SYNC_N;
    output wire VGA_CLK;	

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

    reg [nX-1:0] MUX_x;
    reg [nY-1:0] MUX_y;
    reg [8:0]    MUX_color;
    reg          MUX_write;
    reg [2:0]    y_Q, Y_D;

    wire Resetn, faster, slower;
    assign Resetn = KEY[0];

    // if you prefer, tie faster/slower from switches; otherwise leaving as wires is fine
    // assign faster = SW[1];
    // assign slower = SW[0];

    // -------- Arbiter FSM --------
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
        gnt_top1=1'b0; gnt_btm1=1'b0; gnt_top2=1'b0; gnt_btm2=1'b0; gnt_top3=1'b0; gnt_btm3=1'b0;
        MUX_write=1'b0; MUX_x=x_top1; MUX_y=y_top1; MUX_color=color_top1;

        case (y_Q)
            A: ;
            B: begin gnt_top1=1'b1; MUX_write=write_top1; MUX_x=x_top1; MUX_y=y_top1; MUX_color=color_top1; end
            C: begin gnt_btm1=1'b1; MUX_write=write_btm1; MUX_x=x_btm1; MUX_y=y_btm1; MUX_color=color_btm1; end
            D: begin gnt_top2=1'b1; MUX_write=write_top2; MUX_x=x_top2; MUX_y=y_top2; MUX_color=color_top2; end
            E: begin gnt_btm2=1'b1; MUX_write=write_btm2; MUX_x=x_btm2; MUX_y=y_btm2; MUX_color=color_btm2; end
            F: begin gnt_top3=1'b1; MUX_write=write_top3; MUX_x=x_top3; MUX_y=y_top3; MUX_color=color_top3; end
            G: begin gnt_btm3=1'b1; MUX_write=write_btm3; MUX_x=x_btm3; MUX_y=y_btm3; MUX_color=color_btm3; end
        endcase
    end

    always @(posedge CLOCK_50) begin
        if (Resetn == 0) y_Q <= A;
        else             y_Q <= Y_D;
    end

    // -------- Instances (three pairs). Color = red (111_000_000). Same GAP per pair. --------
    // Lane 1 (rightmost spawn)
    object top1 (Resetn, CLOCK_50, gnt_top1, faster, slower, req_top1, x_top1, y_top1, color_top1, write_top1);
        defparam top1.nX     = nX;
        defparam top1.nY     = nY;
        defparam top1.COLOR  = 9'b111_000_000;
        defparam top1.TOP    = 1;
        defparam top1.GAP    = 9'd120;
        defparam top1.SEED   = 8'd11;
        defparam top1.X_INIT = 10'd620;    // start at right edge
        defparam top1.Y_INIT = 9'd0;

    object btm1 (Resetn, CLOCK_50, gnt_btm1, faster, slower, req_btm1, x_btm1, y_btm1, color_btm1, write_btm1);
        defparam btm1.nX     = nX;
        defparam btm1.nY     = nY;
        defparam btm1.COLOR  = 9'b111_000_000;
        defparam btm1.TOP    = 0;
        defparam btm1.GAP    = 9'd120;
        defparam btm1.SEED   = 8'd11;      // same seed as its top mate
        defparam btm1.X_INIT = 10'd620;
        defparam btm1.Y_INIT = 9'd280;

    // Lane 2 (middle)
    object top2 (Resetn, CLOCK_50, gnt_top2, faster, slower, req_top2, x_top2, y_top2, color_top2, write_top2);
        defparam top2.nX     = nX;
        defparam top2.nY     = nY;
        defparam top2.COLOR  = 9'b111_000_000;
        defparam top2.TOP    = 1;
        defparam top2.GAP    = 9'd120;
        defparam top2.SEED   = 8'd23;
        defparam top2.X_INIT = 10'd420;
        defparam top2.Y_INIT = 9'd0;

    object btm2 (Resetn, CLOCK_50, gnt_btm2, faster, slower, req_btm2, x_btm2, y_btm2, color_btm2, write_btm2);
        defparam btm2.nX     = nX;
        defparam btm2.nY     = nY;
        defparam btm2.COLOR  = 9'b111_000_000;
        defparam btm2.TOP    = 0;
        defparam btm2.GAP    = 9'd120;
        defparam btm2.SEED   = 8'd23;      // same seed as its top mate
        defparam btm2.X_INIT = 10'd420;
        defparam btm2.Y_INIT = 9'd280;

    // Lane 3 (leftmost)
    object top3 (Resetn, CLOCK_50, gnt_top3, faster, slower, req_top3, x_top3, y_top3, color_top3, write_top3);
        defparam top3.nX     = nX;
        defparam top3.nY     = nY;
        defparam top3.COLOR  = 9'b111_000_000;
        defparam top3.TOP    = 1;
        defparam top3.GAP    = 9'd120;
        defparam top3.SEED   = 8'd37;
        defparam top3.X_INIT = 10'd220;
        defparam top3.Y_INIT = 9'd0;

    object btm3 (Resetn, CLOCK_50, gnt_btm3, faster, slower, req_btm3, x_btm3, y_btm3, color_btm3, write_btm3);
        defparam btm3.nX     = nX;
        defparam btm3.nY     = nY;
        defparam btm3.COLOR  = 9'b111_000_000;
        defparam btm3.TOP    = 0;
        defparam btm3.GAP    = 9'd120;
        defparam btm3.SEED   = 8'd37;      // same seed as its top mate
        defparam btm3.X_INIT = 10'd220;
        defparam btm3.Y_INIT = 9'd280;

    // -------- VGA adapter (unchanged) --------
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
