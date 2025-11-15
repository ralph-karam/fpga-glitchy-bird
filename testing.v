`default_nettype none

//======================== TOP ========================//
module obstacles(
    CLOCK_50, SW, KEY, LEDR, VGA_R, VGA_G, VGA_B,
    VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK
);
    parameter nX = 10;  // 0..639
    parameter nY = 9;   // 0..479

    // arbiter states
    parameter SA=3'b000, SB=3'b001, SC=3'b010, SD=3'b011, SE=3'b100, SF=3'b101, SG=3'b110;

    input  wire        CLOCK_50;
    input  wire [9:0]  SW;
    input  wire [0:0]  KEY;
    output wire [9:0]  LEDR;
    output wire [7:0]  VGA_R, VGA_G, VGA_B;
    output wire        VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK;

    // reset: nothing happens until KEY[0] is asserted
    wire Resetn = KEY[0];

    // speed inputs (unused; tied low)
    wire faster = 1'b0;
    wire slower = 1'b0;

    // six objects (3 columns: top/bottom)
    wire [nX-1:0] x_top1, x_btm1, x_top2, x_btm2, x_top3, x_btm3;
    wire [nY-1:0] y_top1, y_btm1, y_top2, y_btm2, y_top3, y_btm3;

    wire [8:0] color_top1, color_btm1, color_top2, color_btm2, color_top3, color_btm3;

    wire write_top1, write_btm1, write_top2, write_btm2, write_top3, write_btm3;
    wire req_top1,   req_btm1,   req_top2,   req_btm2,   req_top3,   req_btm3;

    reg  gnt_top1, gnt_btm1, gnt_top2, gnt_btm2, gnt_top3, gnt_btm3;

    // VGA MUX
    reg  [nX-1:0] MUX_x;
    reg  [nY-1:0] MUX_y;
    reg  [8:0]    MUX_color;
    reg           MUX_write;

    // arbiter FSM
    reg  [2:0] st_q, st_d;

    // ---------- next state ---------- //
    always @(*) begin
        case (st_q)
            SA: begin
                if      (req_top1) st_d = SB;
                else if (req_btm1) st_d = SC;
                else if (req_top2) st_d = SD;
                else if (req_btm2) st_d = SE;
                else if (req_top3) st_d = SF;
                else if (req_btm3) st_d = SG;
                else               st_d = SA;
            end
            SB: st_d = req_top1 ? SB : SA;
            SC: st_d = req_btm1 ? SC : SA;
            SD: st_d = req_top2 ? SD : SA;
            SE: st_d = req_btm2 ? SE : SA;
            SF: st_d = req_top3 ? SF : SA;
            SG: st_d = req_btm3 ? SG : SA;
            default: st_d = SA;
        endcase
    end

    // ---------- outputs/MUX ---------- //
    always @(*) begin
        // defaults
        gnt_top1=0; gnt_btm1=0; gnt_top2=0; gnt_btm2=0; gnt_top3=0; gnt_btm3=0;
        MUX_write=0; MUX_x=x_top1; MUX_y=y_top1; MUX_color=color_top1;

        case (st_q)
            SA: ; // idle
            SB: begin gnt_top1=1; MUX_write=write_top1; MUX_x=x_top1; MUX_y=y_top1; MUX_color=color_top1; end
            SC: begin gnt_btm1=1; MUX_write=write_btm1; MUX_x=x_btm1; MUX_y=y_btm1; MUX_color=color_btm1; end
            SD: begin gnt_top2=1; MUX_write=write_top2; MUX_x=x_top2; MUX_y=y_top2; MUX_color=color_top2; end
            SE: begin gnt_btm2=1; MUX_write=write_btm2; MUX_x=x_btm2; MUX_y=y_btm2; MUX_color=color_btm2; end
            SF: begin gnt_top3=1; MUX_write=write_top3; MUX_x=x_top3; MUX_y=y_top3; MUX_color=color_top3; end
            SG: begin gnt_btm3=1; MUX_write=write_btm3; MUX_x=x_btm3; MUX_y=y_btm3; MUX_color=color_btm3; end
        endcase
    end

    // ---------- state FF ---------- //
    always @(posedge CLOCK_50) begin
        if (Resetn==0) st_q <= SA;
        else           st_q <= st_d;
    end

    // ===== objects: share SEED within a pair to keep fixed gap =====

    // pair 1 (rightmost)
    object top1 (Resetn, CLOCK_50, gnt_top1, faster, slower, req_top1, x_top1, y_top1, color_top1, write_top1);
        defparam top1.nX = nX;
        defparam top1.nY = nY;
        defparam top1.X_INIT = 10'd620;
        defparam top1.TOP = 1;
        defparam top1.SEED = 8'd13;
        defparam top1.COLOR = 9'b111_000_000;

    object btm1 (Resetn, CLOCK_50, gnt_btm1, faster, slower, req_btm1, x_btm1, y_btm1, color_btm1, write_btm1);
        defparam btm1.nX = nX;
        defparam btm1.nY = nY;
        defparam btm1.X_INIT = 10'd620;
        defparam btm1.TOP = 0;
        defparam btm1.SEED = 8'd13;
        defparam btm1.COLOR = 9'b111_000_000;

    // pair 2
    object top2 (Resetn, CLOCK_50, gnt_top2, faster, slower, req_top2, x_top2, y_top2, color_top2, write_top2);
        defparam top2.nX = nX;
        defparam top2.nY = nY;
        defparam top2.X_INIT = 10'd420;
        defparam top2.TOP = 1;
        defparam top2.SEED = 8'd77;
        defparam top2.COLOR = 9'b111_000_000;

    object btm2 (Resetn, CLOCK_50, gnt_btm2, faster, slower, req_btm2, x_btm2, y_btm2, color_btm2, write_btm2);
        defparam btm2.nX = nX;
        defparam btm2.nY = nY;
        defparam btm2.X_INIT = 10'd420;
        defparam btm2.TOP = 0;
        defparam btm2.SEED = 8'd77;
        defparam btm2.COLOR = 9'b111_000_000;

    // pair 3
    object top3 (Resetn, CLOCK_50, gnt_top3, faster, slower, req_top3, x_top3, y_top3, color_top3, write_top3);
        defparam top3.nX = nX;
        defparam top3.nY = nY;
        defparam top3.X_INIT = 10'd220;
        defparam top3.TOP = 1;
        defparam top3.SEED = 8'd201;
        defparam top3.COLOR = 9'b111_000_000;

    object btm3 (Resetn, CLOCK_50, gnt_btm3, faster, slower, req_btm3, x_btm3, y_btm3, color_btm3, write_btm3);
        defparam btm3.nX = nX;
        defparam btm3.nY = nY;
        defparam btm3.X_INIT = 10'd220;
        defparam btm3.TOP = 0;
        defparam btm3.SEED = 8'd201;
        defparam btm3.COLOR = 9'b111_000_000;

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

//================== UTILITY COUNTERS ==================//
module UpDn_count (R, Clock, Resetn, E, L, UpDn, Q);
    parameter n = 10;
    input  wire [n-1:0] R;
    input  wire Clock, Resetn, E, L, UpDn;
    output reg  [n-1:0] Q;
    always @(posedge Clock) begin
        if (Resetn==0) Q <= {n{1'b0}};
        else if (L)     Q <= R;
        else if (E)     Q <= UpDn ? (Q + 1'b1) : (Q - 1'b1);
    end
endmodule

module Up_count (Clock, Resetn, Q);
    parameter n = 20;
    input  wire Clock, Resetn;
    output reg  [n-1:0] Q;
    always @(posedge Clock) begin
        if (Resetn==0) Q <= {n{1'b0}};
        else           Q <= Q + 1'b1;
    end
endmodule

//======================== LFSR ========================//
module random #(parameter seedInitial = 8'd67) (reset, Clock, seed);
    input  wire reset;
    input  wire Clock;
    output reg  [7:0] seed;
    wire next = seed[7] ^ seed[5] ^ seed[4] ^ seed[3];
    always @(posedge Clock) begin
        if (reset) seed <= seedInitial;
        else       seed <= {seed[6:0], next};
    end
endmodule

//==================== OBJECT (pillar) ====================//
module object (
    Resetn, Clock, gnt, faster, slower, req,
    VGA_x, VGA_y, VGA_color, VGA_write
);
    // geometry / params
    parameter nX=10, nY=9;
    parameter XSCREEN=640, YSCREEN=480;
    parameter XDIM=50,  YDIM=200;      // width uses XDIM; height is dynamic
    parameter X_INIT=10'd620;
    parameter TOP=1;                   // 1=top pillar, 0=bottom pillar
    parameter COLOR=9'b111_000_000;
    parameter ALT  =9'b000_000_000;
    parameter KK=21, MM=8;

    // randomization
    parameter SEED = 8'd67;
    parameter GAP  = 9'd120;          // opening height

    // I/O
    input  wire Resetn, Clock, gnt, faster, slower;
    output reg  req;
    output wire [nX-1:0] VGA_x;
    output wire [nY-1:0] VGA_y;
    output wire [8:0]    VGA_color;
    output wire          VGA_write;

    // positions/counters
    wire [nX-1:0] X_RIGHT = XSCREEN[nX-1:0] - XDIM[nX-1:0];
    wire [nX-1:0] X, XC, X0;
    wire [nY-1:0] Y, YC, Y0;

    reg  Lx, Ly, Ex, Lxc, Lyc, Exc, Eyc;
    reg  erase, write;
    reg  [3:0] fsm_q, fsm_d;

    // speed mask (kept)
    reg  [2:0] spd_q, spd_d;
    reg  sll, srl;
    reg  [MM-1:0] mask;
    wire [KK-1:0] slow;
    // align mask width to KK (avoid illegal left-shift width)
    wire [KK-1:0] mask_align = {{(KK-MM){1'b0}}, mask};
    wire          sync = ((slow | mask_align) == {KK{1'b1}});

    // RNG (runs continuously; sampled on wrap)
    wire [7:0] rnd;
    random #(.seedInitial(SEED)) RNG (~Resetn, Clock, rnd);

    // clamp for top height so bottom is >=1
    localparam [9:0] TOP_MAX10 = 10'd479 - GAP; // = 480-1-GAP
    wire [9:0] cand10 = {2'b00, rnd} + 10'd60;  // 60..315
    wire [9:0] top_h_next10 = (cand10 > TOP_MAX10) ? TOP_MAX10 : cand10;

    // runtime Y base and height for this pillar
    reg  [nY-1:0] y_base_reg;
    reg  [nY-1:0] ydim_reg;

    // wrap detection and X reload
    wire wrap_load = (fsm_q==4'h8) && (X=='d0);         // state I (4'h8)
    wire [nX-1:0] X_RLOAD = wrap_load ? X_RIGHT : X_INIT;

    // connect base Y
    assign X0 = X_RLOAD;
    assign Y0 = y_base_reg;

    // counters
    UpDn_count Ux (X0, Clock, Resetn, Ex, Lx, 1'b0, X);    defparam Ux.n = nX;
    UpDn_count Uy (Y0, Clock, Resetn, 1'b0, Ly, 1'b1, Y);  defparam Uy.n = nY;

    UpDn_count Uxc ({nX{1'b0}}, Clock, Resetn, Exc, Lxc, 1'b1, XC); defparam Uxc.n = nX;
    UpDn_count Uyc ({nY{1'b0}}, Clock, Resetn, Eyc, Lyc, 1'b1, YC); defparam Uyc.n = nY;

    Up_count    Us (Clock, Resetn, slow);                 defparam Us.n = KK;

    // VGA
    assign VGA_x     = X + XC;
    assign VGA_y     = Y + YC;
    assign VGA_color = erase ? ALT : COLOR;
    assign VGA_write = write;

    // -------- FSM states (unique names) -------- //
    localparam S0=4'b0000, S1=4'b0001, S2=4'b0010, S3=4'b0011,
               S4=4'b0100, S5=4'b0101, S6=4'b0110, S7=4'b0111,
               S8=4'b1000, S9=4'b1001, SA=4'b1010, SB=4'b1011;

    // next state
    always @(*) begin
        case (fsm_q)
            S0: fsm_d = S1;

            S1: fsm_d = (XC!=(XDIM-1)) ? S1 : S2;        // initial draw (one time)
            S2: fsm_d = (YC!=(ydim_reg-1)) ? S1 : S3;

            S3: fsm_d = (!sync) ? S3 : S4;               // wait speed tick
            S4: fsm_d = (!gnt)  ? S4 : S5;               // wait grant

            S5: fsm_d = (XC!=(XDIM-1)) ? S5 : S6;        // erase
            S6: fsm_d = (YC!=(ydim_reg-1)) ? S5 : S7;

            S7: fsm_d = S8;                               // move
            S8: fsm_d = S9;

            S9: fsm_d = (XC!=(XDIM-1)) ? S9 : SA;        // draw
            SA: fsm_d = (YC!=(ydim_reg-1)) ? S9 : SB;
            SB: fsm_d = S3;
            default: fsm_d = S0;
        endcase
    end

    // outputs
    always @(*) begin
        Lx=0; Ly=0; Lxc=0; Lyc=0; Exc=0; Eyc=0; Ex=0;
        erase=0; write=0; req=0;

        case (fsm_q)
            S0: begin Lx=1; Ly=1; Lxc=1; Lyc=1; end
            S1: begin Exc=1; write=1; end
            S2: begin Lxc=1; Eyc=1; end
            S3: begin Lyc=1; end
            S4: begin req=1; end
            S5: begin req=1; Exc=1; erase=1; write=1; end
            S6: begin req=1; Lxc=1; Eyc=1; end
            S7: begin req=1; Lyc=1; end
            S8: begin req=1; Ex=1; Lx=(X=='d0); end
            S9: begin req=1; Exc=1; write=1; end
            SA: begin req=1; Lxc=1; Eyc=1; end
            SB: begin Lyc=1; end
        endcase
    end

    // state FF
    always @(posedge Clock) begin
        if (Resetn==0) fsm_q <= S0;
        else           fsm_q <= fsm_d;
    end

    // -------- dynamic height/base update --------
    always @(posedge Clock) begin
        if (Resetn==0) begin
            if (TOP) begin
                y_base_reg <= {nY{1'b0}};                           // top from y=0
                ydim_reg   <= top_h_next10[nY-1:0];
            end else begin
                // bottom from (top_h + GAP) to bottom
                // use 10-bit math to avoid overflow, then truncate
                // sum = top_h_next10 + GAP
                y_base_reg <= (top_h_next10 + GAP)[nY-1:0];
                ydim_reg   <= (10'd480 - (top_h_next10 + GAP))[nY-1:0];
            end
        end else if (wrap_load) begin
            if (TOP) begin
                y_base_reg <= {nY{1'b0}};
                ydim_reg   <= top_h_next10[nY-1:0];
            end else begin
                y_base_reg <= (top_h_next10 + GAP)[nY-1:0];
                ydim_reg   <= (10'd480 - (top_h_next10 + GAP))[nY-1:0];
            end
        end
    end

    // -------- speed mask FSM (keys tied low) --------
    localparam Q0=3'b000, Q1=3'b001, Q2=3'b010, Q3=3'b011, Q4=3'b100;

    always @(*) begin
        case (spd_q)
            Q0: spd_d = (faster ? Q1 : (slower ? Q3 : Q0));
            Q1: spd_d = Q2;
            Q2: spd_d = (faster ? Q2 : Q0);
            Q3: spd_d = Q4;
            Q4: spd_d = (slower ? Q4 : Q0);
            default: spd_d = Q0;
        endcase
    end

    always @(*) begin
        sll=1'b0; srl=1'b0;
        case (spd_q)
            Q1: srl=1'b1;
            Q3: sll=1'b1;
            default: ;
        endcase
    end

    always @(posedge Clock) begin
        if (Resetn==0) spd_q <= Q0;
        else           spd_q <= spd_d;
    end

    always @(posedge Clock) begin
        if (Resetn==0) mask <= {MM{1'b0}};
        else if (srl)  mask <= {1'b1, mask[MM-1:1]};
        else if (sll)  mask <= {mask[MM-2:0], 1'b0};
    end

endmodule
