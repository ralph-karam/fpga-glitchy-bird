`default_nettype none

//============================= TOP =============================
module obstacles(
    CLOCK_50, SW, KEY, LEDR, VGA_R, VGA_G, VGA_B,
    VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK);

    // pixel coordinate widths
    parameter nX = 10;
    parameter nY = 9;

    // FSM states (arbiter)
    parameter A = 3'b000, B = 3'b001, C = 3'b010, D = 3'b011,
              E = 3'b100, F = 3'b101, G = 3'b110;

    input  wire CLOCK_50;
    input  wire [9:0] SW;
    input  wire [0:0] KEY;
    output wire [9:0] LEDR;
    output wire [7:0] VGA_R, VGA_G, VGA_B;
    output wire VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK;

    // ---------- object I/O ----------
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

    // expose each object's base X and height interface
    wire [nX-1:0] base_top1, base_btm1, base_top2, base_btm2, base_top3, base_btm3;
    wire [nY-1:0] h_top1_cur, h_btm1_cur, h_top2_cur, h_btm2_cur, h_top3_cur, h_btm3_cur;
    reg           hload_top1, hload_btm1, hload_top2, hload_btm2, hload_top3, hload_btm3;
    wire [nY-1:0] hval_top1,  hval_btm1,  hval_top2,  hval_btm2,  hval_top3,  hval_btm3;

    // VGA mux
    reg  [nX-1:0] MUX_x;
    reg  [nY-1:0] MUX_y;
    reg  [8:0]    MUX_color;
    reg           MUX_write;
    reg  [2:0]    y_Q, Y_D;

    wire Resetn = KEY[0];
    wire faster, slower;
    assign faster = 1'b0;   // no speed control keys
    assign slower = 1'b0;

    // ---------------- RNGs (one per pair) ----------------
    wire [7:0] rnd1, rnd2, rnd3;
    random RNG1(~Resetn, CLOCK_50, rnd1);
    random RNG2(~Resetn, CLOCK_50, rnd2);
    random RNG3(~Resetn, CLOCK_50, rnd3);
    defparam RNG1.seedInitial = 8'd67;
    defparam RNG2.seedInitial = 8'd123;
    defparam RNG3.seedInitial = 8'd201;

    // gap config
    localparam integer GAP   = 120;   // vertical opening size
    localparam integer H_MIN = 40;    // min top height
    localparam integer STEP  = 8;     // quantization step
    localparam integer YSCR  = 480;

    // new heights per wrap (same gap within a pair)
    wire [nY-1:0] top1_h_new = H_MIN + {5'd0, rnd1[7:4]} * STEP;
    wire [nY-1:0] top2_h_new = H_MIN + {5'd0, rnd2[7:4]} * STEP;
    wire [nY-1:0] top3_h_new = H_MIN + {5'd0, rnd3[7:4]} * STEP;

    assign hval_top1 = top1_h_new;
    assign hval_btm1 = (YSCR - GAP) - top1_h_new;
    assign hval_top2 = top2_h_new;
    assign hval_btm2 = (YSCR - GAP) - top2_h_new;
    assign hval_top3 = top3_h_new;
    assign hval_btm3 = (YSCR - GAP) - top3_h_new;

    // wrap detect on each pair's TOP pillar (one-shot pulse)
    reg w1_d, w2_d, w3_d;
    wire w1 = (base_top1 == {nX{1'b0}});
    wire w2 = (base_top2 == {nX{1'b0}});
    wire w3 = (base_top3 == {nX{1'b0}});

    always @(posedge CLOCK_50 or negedge Resetn) begin
        if (!Resetn) begin w1_d<=1'b0; w2_d<=1'b0; w3_d<=1'b0; end
        else begin w1_d<=w1; w2_d<=w2; w3_d<=w3; end
    end

    wire pulse1 = w1 & ~w1_d;
    wire pulse2 = w2 & ~w2_d;
    wire pulse3 = w3 & ~w3_d;

    always @(*) begin
        hload_top1 = pulse1; hload_btm1 = pulse1;
        hload_top2 = pulse2; hload_btm2 = pulse2;
        hload_top3 = pulse3; hload_btm3 = pulse3;
    end

    // ---------------- Arbiter (unchanged logic, 6 objs) ----------------
    always @(*)
        case (y_Q)
            A: if      (req_top1) Y_D = B;
               else if (req_btm1) Y_D = C;
               else if (req_top2) Y_D = D;
               else if (req_btm2) Y_D = E;
               else if (req_top3) Y_D = F;
               else if (req_btm3) Y_D = G;
               else Y_D = A;
            B: Y_D = req_top1 ? B : A;
            C: Y_D = req_btm1 ? C : A;
            D: Y_D = req_top2 ? D : A;
            E: Y_D = req_btm2 ? E : A;
            F: Y_D = req_top3 ? F : A;
            G: Y_D = req_btm3 ? G : A;
            default: Y_D = A;
        endcase

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
        if (Resetn==0) y_Q <= A;
        else           y_Q <= Y_D;

    // ---------------- Object instances ----------------
    // top1
    object top1 (Resetn, CLOCK_50, gnt_top1, faster, slower, req_top1,
                 x_top1, y_top1, color_top1, write_top1,
                 base_top1, h_top1_cur, hload_top1, hval_top1);
        defparam top1.nX     = nX;
        defparam top1.nY     = nY;
        defparam top1.X_INIT = 10'd620;
        defparam top1.Y_INIT = 9'd0;
        defparam top1.COLOR  = 9'b000_111_000;
        defparam top1.BOTTOM = 1'b0;

    // btm1
    object btm1 (Resetn, CLOCK_50, gnt_btm1, faster, slower, req_btm1,
                 x_btm1, y_btm1, color_btm1, write_btm1,
                 base_btm1, h_btm1_cur, hload_btm1, hval_btm1);
        defparam btm1.nX     = nX;
        defparam btm1.nY     = nY;
        defparam btm1.X_INIT = 10'd620;
        defparam btm1.Y_INIT = 9'd0;
        defparam btm1.COLOR  = 9'b000_111_000;
        defparam btm1.BOTTOM = 1'b1;

    // top2
    object top2 (Resetn, CLOCK_50, gnt_top2, faster, slower, req_top2,
                 x_top2, y_top2, color_top2, write_top2,
                 base_top2, h_top2_cur, hload_top2, hval_top2);
        defparam top2.nX     = nX;
        defparam top2.nY     = nY;
        defparam top2.X_INIT = 10'd420;
        defparam top2.Y_INIT = 9'd0;
        defparam top2.COLOR  = 9'b000_000_111;
        defparam top2.BOTTOM = 1'b0;

    // btm2
    object btm2 (Resetn, CLOCK_50, gnt_btm2, faster, slower, req_btm2,
                 x_btm2, y_btm2, color_btm2, write_btm2,
                 base_btm2, h_btm2_cur, hload_btm2, hval_btm2);
        defparam btm2.nX     = nX;
        defparam btm2.nY     = nY;
        defparam btm2.X_INIT = 10'd420;
        defparam btm2.Y_INIT = 9'd0;
        defparam btm2.COLOR  = 9'b000_000_111;
        defparam btm2.BOTTOM = 1'b1;

    // top3
    object top3 (Resetn, CLOCK_50, gnt_top3, faster, slower, req_top3,
                 x_top3, y_top3, color_top3, write_top3,
                 base_top3, h_top3_cur, hload_top3, hval_top3);
        defparam top3.nX     = nX;
        defparam top3.nY     = nY;
        defparam top3.X_INIT = 10'd220;
        defparam top3.Y_INIT = 9'd0;
        defparam top3.COLOR  = 9'b111_000_000;
        defparam top3.BOTTOM = 1'b0;

    // btm3
    object btm3 (Resetn, CLOCK_50, gnt_btm3, faster, slower, req_btm3,
                 x_btm3, y_btm3, color_btm3, write_btm3,
                 base_btm3, h_btm3_cur, hload_btm3, hval_btm3);
        defparam btm3.nX     = nX;
        defparam btm3.nY     = nY;
        defparam btm3.X_INIT = 10'd220;
        defparam btm3.Y_INIT = 9'd0;
        defparam btm3.COLOR  = 9'b111_000_000;
        defparam btm3.BOTTOM = 1'b1;

    // ---------------- VGA ----------------
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
    defparam VGA.BACKGROUND_IMAGE = "./MIF/scenery.mif";

    assign LEDR = 10'b0;
endmodule

//============================= OBJECT ==========================
module object (
    Resetn, Clock, gnt, faster, slower, req,
    VGA_x, VGA_y, VGA_color, VGA_write,
    obj_x, obj_h, h_load, h_val
);
    parameter nX = 10;
    parameter nY = 9;

    parameter XSCREEN = 640;
    parameter YSCREEN = 480;

    parameter XDIM = 50, YDIM = 200;      // default height
    parameter X_INIT = 10'd620;
    parameter Y_INIT = 9'd0;

    parameter COLOR  = 9'b111_111_111;
    parameter ALT    = 9'b000_000_000;    // erase color
    parameter KK     = 21;
    parameter MM     = 8;
    parameter BOTTOM = 1'b0;              // 1 => anchor to floor

    // states
    parameter A = 4'b0000, B = 4'b0001, C = 4'b0010, D = 4'b0011,
              E = 4'b0100, F = 4'b0101, G = 4'b0110, H = 4'b0111,
              I = 4'b1000, J = 4'b1001, K = 4'b1010, L = 4'b1011;

    input  wire Resetn, Clock, gnt, faster, slower;
    output reg  req;
    output wire [nX-1:0] VGA_x;
    output wire [nY-1:0] VGA_y;
    output wire [8:0]    VGA_color;
    output wire          VGA_write;

    output wire [nX-1:0] obj_x;
    output wire [nY-1:0] obj_h;
    input  wire          h_load;
    input  wire [nY-1:0] h_val;

    wire [nX-1:0] X_RIGHT = XSCREEN[nX-1:0] - XDIM[nX-1:0];

    wire [nX-1:0] X, XC, X0;
    wire [nY-1:0] Y, YC, Y0;
    wire [8:0]    color = COLOR;
    wire [KK-1:0] slow;

    reg Lx, Ly, Ex, Lxc, Lyc, Exc, Eyc;
    wire sync;
    reg  erase;
    reg  [3:0] y_Q, Y_D;
    reg  write;

    // speed mask (kept from your code)
    reg [2:0] ys_Q, Ys_D;
    reg sll, srl;
    reg [MM-1:0] mask;

    // ---- height register ----
    reg [nY-1:0] height;
    assign obj_x = X;
    assign obj_h = height;

    always @(posedge Clock) begin
        if (!Resetn) height <= YDIM[nY-1:0];
        else if (h_load) height <= h_val;
    end

    // Y load value: top anchored at Y_INIT, bottom anchored to floor - height
    wire [nY-1:0] Y_RLOAD = (BOTTOM ? (YSCREEN[nY-1:0] - height) : Y_INIT[nY-1:0]);

    // respawn-at-right logic
    wire wrap_load = (y_Q == I) && (X == {nX{1'b0}});
    wire [nX-1:0] X_RLOAD = wrap_load ? X_RIGHT : X_INIT;

    assign X0 = X_RLOAD;
    assign Y0 = Y_RLOAD;

    UpDn_count U2 (X0, Clock, Resetn, Ex, Lx, 1'b0, X);  defparam U2.n = nX;
    UpDn_count U1 (Y0, Clock, Resetn, 1'b0, Ly, 1'b1, Y);defparam U1.n = nY;
    UpDn_count U3 ({nX{1'd0}}, Clock, Resetn, Exc, Lxc, 1'b1, XC); defparam U3.n = nX;
    UpDn_count U4 ({nY{1'd0}}, Clock, Resetn, Eyc, Lyc, 1'b1, YC); defparam U4.n = nY;
    Up_count    U6 (Clock, Resetn, slow);                 defparam U6.n = KK;

    assign sync = ((slow | (mask << KK-MM)) == {KK{1'b1}});
    assign VGA_x = X + XC;
    assign VGA_y = Y + YC;
    assign VGA_color = erase ? ALT : color;
    assign VGA_write = write;

    // next-state
    always @(*) case (y_Q)
        A: Y_D = B;
        B: Y_D = (XC != XDIM-1) ? B : C;
        C: Y_D = (YC != height-1) ? B : D;  // use height here
        D: Y_D = (!sync) ? D : E;
        E: Y_D = (!gnt)  ? E : F;
        F: Y_D = (XC != XDIM-1) ? F : G;
        G: Y_D = (YC != height-1) ? F : H;  // and here
        H: Y_D = I;
        I: Y_D = J;
        J: Y_D = (XC != XDIM-1) ? J : K;
        K: Y_D = (YC != height-1) ? J : L;
        L: Y_D = D;
        default: Y_D = A;
    endcase

    // outputs
    always @(*) begin
        Lx=0; Ly=0; Lxc=0; Lyc=0; Exc=0; Eyc=0; erase=0; write=0; Ex=0; req=0;
        case (y_Q)
            A: begin Lx=1; Ly=1; Lxc=1; Lyc=1; end
            B: begin Exc=1; write=1; end
            C: begin Lxc=1; Eyc=1; end
            D: Lyc=1;
            E: req=1;
            F: begin req=1; Exc=1; erase=1; write=1; end
            G: begin req=1; Lxc=1; Eyc=1; end
            H: begin req=1; Lyc = (X=={nX{1'b0}}); end // recompute Y on wrap for bottoms
            I: begin req=1; Ex=1; Lx = (X=={nX{1'b0}}); end
            J: begin req=1; Exc=1; write=1; end
            K: begin req=1; Lxc=1; Eyc=1; end
            L: Lyc=1;
        endcase
    end

    always @(posedge Clock)
        if (!Resetn) y_Q <= A;
        else         y_Q <= Y_D;

    // speed mask FSM
    parameter As = 3'b000, Bs = 3'b001, Cs = 3'b010, Ds = 3'b011, Es = 3'b100;

    always @(*) case (ys_Q)
        As: Ys_D = (faster ? Bs : (slower ? Ds : As));
        Bs: Ys_D = Cs;
        Cs: Ys_D = (faster ? Cs : As);
        Ds: Ys_D = Es;
        Es: Ys_D = (slower ? Es : As);
        default: Ys_D = As;
    endcase

    always @(*) begin sll=0; srl=0;
        case (ys_Q)
            Bs: srl=1;
            Ds: sll=1;
        endcase
    end

    always @(posedge Clock) begin
        if (!Resetn) mask <= {MM{1'b0}};
        else if (srl) begin mask[MM-2:0] <= mask[MM-1:1]; mask[MM-1] <= 1'b1; end
        else if (sll) begin mask[MM-1:1] <= mask[MM-2:0]; mask[0]    <= 1'b0; end
    end

    always @(posedge Clock)
        if (!Resetn) ys_Q <= As;
        else         ys_Q <= Ys_D;

endmodule

//====================== SUPPORT MODULES =======================
module UpDn_count (R, Clock, Resetn, E, L, UpDn, Q);
    parameter n = 10;
    input wire [n-1:0] R;
    input wire Clock, Resetn, E, L, UpDn;
    output reg [n-1:0] Q;
    always @(posedge Clock)
        if (!Resetn) Q <= {n{1'b0}};
        else if (L)  Q <= R;
        else if (E)  Q <= (UpDn ? (Q + 1'b1) : (Q - 1'b1));
endmodule

module Up_count (Clock, Resetn, Q);
    parameter n = 20;
    input wire Clock, Resetn;
    output reg [n-1:0] Q;
    always @(posedge Clock)
        if (!Resetn) Q <= {n{1'b0}};
        else         Q <= Q + 1'b1;
endmodule

// simple 8-bit LFSR (x^8 + x^6 + x^5 + x^4 + 1) like you had
module random #(parameter seedInitial = 8'd67) (reset, Clock, seed);
    input  reset, Clock;
    output reg [7:0] seed;
    wire next = seed[7] ^ seed[5] ^ seed[4] ^ seed[3];
    always @(posedge Clock) begin
        if (reset) seed <= seedInitial;
        else       seed <= {seed[6:0], next};
    end
endmodule
