`default_nettype none

// ===================== obstacles (top-level) =====================
module obstacles(
    input  wire        CLOCK_50,
    input  wire [9:0]  SW,
    input  wire [0:0]  KEY,  // KEY[0] = active-high resetn to vga_adapter
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

    // coordinate bit-widths
    parameter nX = 10;
    parameter nY = 9;

    // FSM states for 6 objects
    parameter A = 3'b000, B = 3'b001, C = 3'b010,
              D = 3'b011, E = 3'b100, F = 3'b101, G = 3'b110;

    // wires from each object
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

    // arbiter state
    reg  [2:0] y_Q, Y_D;

    // simple reset and speed signals
    wire Resetn  = KEY[0];  // vga_adapter expects active-high resetn
    wire faster  = 1'b0;
    wire slower  = 1'b0;

    // ------------ Arbiter Next-State ------------
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

    // ------------ Arbiter Outputs + VGA mux ------------
    always @(*) begin
        // defaults
        gnt_top1 = 1'b0; gnt_btm1 = 1'b0; gnt_top2 = 1'b0;
        gnt_btm2 = 1'b0; gnt_top3 = 1'b0; gnt_btm3 = 1'b0;
        MUX_write = 1'b0; MUX_x = x_top1; MUX_y = y_top1; MUX_color = color_top1;

        case (y_Q)
            A: ; // idle

            B: begin
                gnt_top1  = 1'b1;
                MUX_write = write_top1;
                MUX_x     = x_top1;
                MUX_y     = y_top1;
                MUX_color = color_top1;
            end
            C: begin
                gnt_btm1  = 1'b1;
                MUX_write = write_btm1;
                MUX_x     = x_btm1;
                MUX_y     = y_btm1;
                MUX_color = color_btm1;
            end

            D: begin
                gnt_top2  = 1'b1;
                MUX_write = write_top2;
                MUX_x     = x_top2;
                MUX_y     = y_top2;
                MUX_color = color_top2;
            end
            E: begin
                gnt_btm2  = 1'b1;
                MUX_write = write_btm2;
                MUX_x     = x_btm2;
                MUX_y     = y_btm2;
                MUX_color = color_btm2;
            end

            F: begin
                gnt_top3  = 1'b1;
                MUX_write = write_top3;
                MUX_x     = x_top3;
                MUX_y     = y_top3;
                MUX_color = color_top3;
            end
            G: begin
                gnt_btm3  = 1'b1;
                MUX_write = write_btm3;
                MUX_x     = x_btm3;
                MUX_y     = y_btm3;
                MUX_color = color_btm3;
            end
        endcase
    end

    // ------------ Arbiter FF ------------
    always @(posedge CLOCK_50) begin
        if (Resetn == 1'b0) // wait until ready (active-low reset inside pipeline)
            y_Q <= A;
        else
            y_Q <= Y_D;
    end

    // ------------ Six object instances ------------
    // top1 (green)
    object top1 (Resetn, CLOCK_50, gnt_top1, faster, slower, req_top1,
                 x_top1, y_top1, color_top1, write_top1);
        defparam top1.nX     = nX;
        defparam top1.nY     = nY;
        defparam top1.X_INIT = 10'd620;
        defparam top1.Y_INIT = 9'd0;
        defparam top1.XDIM   = 50;
        defparam top1.YDIM   = 200;
        defparam top1.COLOR  = 9'b000_111_000;  // green

    // btm1 (green)
    object btm1 (Resetn, CLOCK_50, gnt_btm1, faster, slower, req_btm1,
                 x_btm1, y_btm1, color_btm1, write_btm1);
        defparam btm1.nX     = nX;
        defparam btm1.nY     = nY;
        defparam btm1.X_INIT = 10'd620;
        defparam btm1.Y_INIT = 9'd280;          // bottom
        defparam btm1.XDIM   = 50;
        defparam btm1.YDIM   = 200;
        defparam btm1.COLOR  = 9'b000_111_000;  // green

    // top2 (blue)
    object top2 (Resetn, CLOCK_50, gnt_top2, faster, slower, req_top2,
                 x_top2, y_top2, color_top2, write_top2);
        defparam top2.nX     = nX;
        defparam top2.nY     = nY;
        defparam top2.X_INIT = 10'd420;
        defparam top2.Y_INIT = 9'd0;
        defparam top2.XDIM   = 50;
        defparam top2.YDIM   = 200;
        defparam top2.COLOR  = 9'b000_000_111;  // blue

    // btm2 (blue)
    object btm2 (Resetn, CLOCK_50, gnt_btm2, faster, slower, req_btm2,
                 x_btm2, y_btm2, color_btm2, write_btm2);
        defparam btm2.nX     = nX;
        defparam btm2.nY     = nY;
        defparam btm2.X_INIT = 10'd420;
        defparam btm2.Y_INIT = 9'd280;
        defparam btm2.XDIM   = 50;
        defparam btm2.YDIM   = 200;
        defparam btm2.COLOR  = 9'b000_000_111;  // blue

    // top3 (red)
    object top3 (Resetn, CLOCK_50, gnt_top3, faster, slower, req_top3,
                 x_top3, y_top3, color_top3, write_top3);
        defparam top3.nX     = nX;
        defparam top3.nY     = nY;
        defparam top3.X_INIT = 10'd220;
        defparam top3.Y_INIT = 9'd0;
        defparam top3.XDIM   = 50;
        defparam top3.YDIM   = 200;
        defparam top3.COLOR  = 9'b111_000_000;  // red

    // btm3 (red)
    object btm3 (Resetn, CLOCK_50, gnt_btm3, faster, slower, req_btm3,
                 x_btm3, y_btm3, color_btm3, write_btm3);
        defparam btm3.nX     = nX;
        defparam btm3.nY     = nY;
        defparam btm3.X_INIT = 10'd220;
        defparam btm3.Y_INIT = 9'd280;
        defparam btm3.XDIM   = 50;
        defparam btm3.YDIM   = 200;
        defparam btm3.COLOR  = 9'b111_000_000;  // red

    // ------------ VGA adapter ------------
    vga_adapter VGA (
        .resetn(Resetn),        // adapter wants active-high resetn
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

// ===================== Up/Down counter =====================
module UpDn_count (R, Clock, Resetn, E, L, UpDn, Q);
    parameter n = 10;
    input  wire [n-1:0] R;
    input  wire Clock, Resetn, E, L, UpDn;
    output reg  [n-1:0] Q;

    always @(posedge Clock)
        if (Resetn == 1'b0)
            Q <= {n{1'b0}};
        else if (L == 1'b1)
            Q <= R;
        else if (E) begin
            if (UpDn == 1'b1) Q <= Q + 1'b1;
            else              Q <= Q - 1'b1;
        end
endmodule

// ===================== Up counter =====================
module Up_count (Clock, Resetn, Q);
    parameter n = 20;
    input  wire Clock, Resetn;
    output reg  [n-1:0] Q;

    always @(posedge Clock)
        if (Resetn == 1'b0)
            Q <= {n{1'b0}};
        else
            Q <= Q + 1'b1;
endmodule

// ===================== object (with parse fixes) =====================
module object (Resetn, Clock, gnt, faster, slower, req,
               VGA_x, VGA_y, VGA_color, VGA_write);

    // bits for coordinates
    parameter nX = 10;
    parameter nY = 9;

    // screen geometry
    parameter XSCREEN = 640;
    parameter YSCREEN = 480;

    // object size
    parameter XDIM = 50, YDIM = 200;

    // initial location
    parameter X_INIT = 10'd620;
    parameter Y_INIT = 9'd0;

    // color params
    parameter COLOR = 9'b111111111;
    parameter ALT   = 9'b000_000_000;

    // timing params
    parameter KK = 21;
    parameter MM = 8;

    // FSM states
    parameter A = 4'b0000, B = 4'b0001, C = 4'b0010, D = 4'b0011,
              E = 4'b0100, F = 4'b0101, G = 4'b0110, H = 4'b0111,
              I = 4'b1000, J = 4'b1001, K = 4'b1010, L = 4'b1011;

    // ---- FIX: avoid slicing a param with a variable range ----
    localparam [nX-1:0] XSCR_NX = 10'd640;
    wire [nX-1:0] X_RIGHT = XSCR_NX - XDIM[nX-1:0];

    input  wire Resetn, Clock;
    input  wire gnt;
    input  wire faster, slower;
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

    // speed-mask FSM
    reg  [2:0] ys_Q, Ys_D;
    reg  sll, srl;
    reg  [MM-1:0] mask;

    assign X0 = X_INIT;
    assign Y0 = Y_INIT;

    // wrap-to-right logic
    wire wrap_load = (y_Q == I) && (X == 'd0);
    wire [nX-1:0] X_RLOAD = wrap_load ? X_RIGHT : X_INIT;

    // X pos (count down, load to wrap)
    UpDn_count U2 (X_RLOAD, Clock, Resetn, Ex, Lx, 1'b0, X);
        defparam U2.n = nX;

    // Y pos (fixed at Y_INIT)
    UpDn_count U1 (Y0, Clock, Resetn, 1'b0, Ly, 1'b1, Y);
        defparam U1.n = nY;

    // pixel traversers
    UpDn_count U3 ({nX{1'd0}}, Clock, Resetn, Exc, Lxc, 1'b1, XC);
        defparam U3.n = nX;
    UpDn_count U4 ({nY{1'd0}}, Clock, Resetn, Eyc, Lyc, 1'b1, YC);
        defparam U4.n = nY;

    // slow counter
    Up_count U6 (Clock, Resetn, slow);
        defparam U6.n = KK;

    // delay qualifier with speed mask
    assign sync = ((slow | (mask << (KK-MM))) == {KK{1'b1}});

    // VGA outs
    assign VGA_x     = X + XC;
    assign VGA_y     = Y + YC;
    assign VGA_color = (erase == 1'b0) ? color : ALT;
    assign VGA_write = write;

    // state transition
    always @(*) begin
        case (y_Q)
            A:  Y_D = B;

            B:  Y_D = (XC != XDIM-1) ? B : C;
            C:  Y_D = (YC != YDIM-1) ? B : D;

            D:  Y_D = (!sync) ? D : E;
            E:  Y_D = (!gnt)  ? E : F;

            F:  Y_D = (XC != XDIM-1) ? F : G;
            G:  Y_D = (YC != YDIM-1) ? F : H;

            H:  Y_D = I;
            I:  Y_D = J;

            J:  Y_D = (XC != XDIM-1) ? J : K;
            K:  Y_D = (YC != YDIM-1) ? J : L;
            L:  Y_D = D;
            default: Y_D = A;
        endcase
    end

    // state outputs
    always @(*) begin
        // defaults
        Lx=1'b0; Ly=1'b0; Lxc=1'b0; Lyc=1'b0; Exc=1'b0; Eyc=1'b0;
        erase=1'b0; write=1'b0; Ex=1'b0; Tdir=1'b0; req=1'b0;

        case (y_Q)
            A:  begin Lx=1'b1; Ly=1'b1; Lxc=1'b1; Lyc=1'b1; end
            B:  begin Exc=1'b1; write=1'b1; end
            C:  begin Lxc=1'b1; Eyc=1'b1; end
            D:  Lyc=1'b1;
            E:  req=1'b1;
            F:  begin req=1'b1; Exc=1'b1; erase=1'b1; write=1'b1; end
            G:  begin req=1'b1; Lxc=1'b1; Eyc=1'b1; end
            H:  begin req=1'b1; Lyc=1'b1; Tdir=(Y=='d0)||(Y==YSCREEN-YDIM); end
            I:  begin req=1'b1; Ex=1'b1; Lx=(X=='d0); end
            J:  begin req=1'b1; Exc=1'b1; write=1'b1; end
            K:  begin req=1'b1; Lxc=1'b1; Eyc=1'b1; end
            L:  Lyc=1'b1;
        endcase
    end

    // FSM FFs
    always @(posedge Clock) begin
        if (Resetn == 1'b0) y_Q <= A;
        else                y_Q <= Y_D;
    end

    // speed-mask FSM
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

    reg sll, srl;
    always @(*) begin
        sll=1'b0; srl=1'b0;
        case (ys_Q)
            As: ;
            Bs: srl=1'b1;   // shift in 1 from MSB
            Cs: ;
            Ds: sll=1'b1;   // shift in 0 from LSB
            Es: ;
        endcase
    end

    reg [MM-1:0] mask;
    reg [2:0]    ys_Q, Ys_D;

    always @(posedge Clock) begin
        if (Resetn == 1'b0) ys_Q <= As;
        else                ys_Q <= Ys_D;
    end

    // mask register
    always @(posedge Clock) begin
        if (Resetn == 1'b0)
            mask <= {MM{1'b0}};
        else if (srl) begin
            mask[MM-2:0] <= mask[MM-1:1];
            mask[MM-1]   <= 1'b1;
        end
        else if (sll) begin
            mask[MM-1:1] <= mask[MM-2:0];
            mask[0]      <= 1'b0;
        end
    end

endmodule
