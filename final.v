`default_nettype none

module obstacles(CLOCK_50, SW, KEY, LEDR, PS2_CLK, PS2_DAT, VGA_R, VGA_G, VGA_B,
				VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK);
	parameter nX = 10;
	parameter nY = 9;
	
	parameter SKYBLUE = 9'b010_101_111;
	parameter PILLARGREEN = 9'b001_111_001;
	
    // state codes for FSM that choses which object to draw at a given time
   parameter A = 3'b000, B = 3'b001, C = 3'b010, D = 3'b011, E = 3'b100, F = 3'b101, G = 3'b110, H = 3'b111;
	parameter XSCREEN = 640;
	
	inout wire PS2_CLK, PS2_DAT;
	
		 reg prev_ps2_clk;               // ps2_clk value in the previous clock cycle
    wire negedge_ps2_clk;           // used for PS2 keyboard signals
	 wire req_bird;
	 reg gnt_bird;
   
    reg [32:0] Serial;              // each PS2 serial data packet has 11 bits:
                                    // STOP (1) PARITY d7 d6 d5 d4 d3 d2 d1 d0 START (0)
                                    // 33 total bits are received (scancode/release/scancode

    wire [7:0] scancode;            // used to save the current ps2 scancode
   
    wire O1_done;    // object move completed
	 
	 wire [10-1:0] O1_x;    // x coordinate multiplexer
	 wire [9-1:0] O1_y;    // y coordinate multiplexer
	 wire [8:0] O1_color; // color multiplexer
	 wire O1_write; // write control multiplexer
	 wire [nX-1:0] player_x;
	 wire [nY-1:0] player_y;
            
    wire [1:0] O1_dir;      // used to set direction of moving for objects

    wire KEY1;        // Reset, and synchronized versions of KEYs
    wire PS2_CLK_S, PS2_DAT_S;      // synchronized versions of PS2 signals

	input wire CLOCK_50;	
	input wire [9:0] SW;
	input wire [3:0] KEY;
	output wire [9:0] LEDR;
	output wire [7:0] VGA_R;
	output wire [7:0] VGA_G;
	output wire [7:0] VGA_B;
	output wire VGA_HS;
	output wire VGA_VS;
	output wire VGA_BLANK_N;
	output wire VGA_SYNC_N;
	output wire VGA_CLK;	

	wire [9:0] x_top1, x_btm1, x_top2, x_btm2, x_top3, x_btm3;
	wire [8:0] y_top1, y_btm1, y_top2, y_btm2, y_top3, y_btm3;
	wire [nX-1:0] pillar1_x, pillar2_x, pillar3_x;
	
	wire [8:0] color_top1, color_top2, color_top3;
	wire [8:0] color_btm1, color_btm2, color_btm3;
	
	wire write_top1, write_top2, write_top3;
	wire write_btm1, write_btm2, write_btm3;
	
	
	wire req_top1, req_top2, req_top3;
	wire req_btm1, req_btm2, req_btm3;
	
    reg gnt_top1, gnt_top2, gnt_top3;
	reg gnt_btm1, gnt_btm2, gnt_btm3;
	
	reg [9:0] MUX_x;
	reg [8:0] MUX_y;
	reg [8:0] MUX_color;
    reg MUX_write;
	reg [2:0] y_Q, Y_D;
	wire Resetn;
	
	assign Resetn = KEY[0];
	

	
	//--------------------------random-----------------------------
	
	parameter [8:0] GAP = 9'd80;
	parameter [8:0] YSCREEN = 9'd480;
	parameter [8:0] MIN_H = 9'd100;
	parameter [8:0] RANGE_H = 9'd201;
	
	wire [7:0] rnd;
	
	random U1(~Resetn, CLOCK_50, rnd);
	
	wire [8:0] rand_mod = rnd % RANGE_H; 	//0 to 200
	wire [8:0] rand_h = MIN_H + rand_mod;	//100 to 300
	
	// AFTER – add initial values
	reg [8:0] top_h1 = 9'd200;
	reg [8:0] btm_h1 = (9'd480 - 9'd80) - 9'd200;  // (YSCREEN - GAP) - top_h1
	reg [8:0] btm_y1 = 9'd200 + 9'd80;            // top_h1 + GAP

	reg [8:0] top_h2 = 9'd150;
	reg [8:0] btm_h2 = (9'd480 - 9'd80) - 9'd150;
	reg [8:0] btm_y2 = 9'd150 + 9'd80;

	reg [8:0] top_h3 = 9'd220;
	reg [8:0] btm_h3 = (9'd480 - 9'd80) - 9'd220;
	reg [8:0] btm_y3 = 9'd220 + 9'd80;
	
	wire wrap_top1, wrap_top2, wrap_top3;
	wire wrap_btm1, wrap_btm2, wrap_btm3;		//unused, here to avoid floating ports
	
	wire any_wrap = wrap_top1 | wrap_top2 | wrap_top3 | wrap_btm1 | wrap_btm2 | wrap_btm3;
	
	 // update pillar heights when the top wraps
    always @(posedge CLOCK_50 or negedge Resetn) begin
        if (!Resetn) begin
            // initial heights
            top_h1 <= 9'd200;
            top_h2 <= 9'd150;
            top_h3 <= 9'd220;

            btm_h1 <= (YSCREEN - GAP) - top_h1;
            btm_y1 <= top_h1 + GAP;

            btm_h2 <= (YSCREEN - GAP) - top_h2;
            btm_y2 <= top_h2 + GAP;

            btm_h3 <= (YSCREEN - GAP) - top_h3;
            btm_y3 <= top_h3 + GAP;
        end
        else begin
            // when a top pillar wraps picks a new height and recomputes the bottom pillar
            if (wrap_top1) begin
                top_h1 <= rand_h;
                btm_h1 <= (YSCREEN - GAP) - rand_h;
                btm_y1 <= rand_h + GAP;
            end

            if (wrap_top2) begin
                top_h2 <= rand_h;
                btm_h2 <= (YSCREEN - GAP) - rand_h;
                btm_y2 <= rand_h + GAP;
            end

            if (wrap_top3) begin
                top_h3 <= rand_h;
                btm_h3 <= (YSCREEN - GAP) - rand_h;
                btm_y3 <= rand_h + GAP;
            end
        end
    end
	
	//----------------------To fix aesthetic of left "ghosts"-------------------

	localparam [nX-1:0] PILLAR_WIDTH = 10'd60;

reg clear_left;
reg [nX-1:0] clear_x_left;
reg [nY-1:0] clear_y_left;

// when any pillar wraps, clear a left strip (width = PILLAR_WIDTH) to black once
always @(posedge CLOCK_50 or negedge Resetn) begin
    if (!Resetn) begin
        clear_left   <= 1'b0;
        clear_x_left <= {nX{1'b0}};
        clear_y_left <= {nY{1'b0}};
    end
    else if (!clear_left && any_wrap) begin
        // start clearing on first wrap pulse
        clear_left   <= 1'b1;
        clear_x_left <= {nX{1'b0}};  // x = 0
        clear_y_left <= {nY{1'b0}};  // y = 0
    end
    else if (clear_left) begin
        // sweep a rectangle: x = 0..PILLAR_WIDTH-1, y = 0..YSCREEN-1
        if (clear_x_left == PILLAR_WIDTH-1) begin
            clear_x_left <= {nX{1'b0}};  // restart x at 0
            if (clear_y_left == YSCREEN-1) begin
                // done, whole strip cleared
                clear_left   <= 1'b0;
                clear_y_left <= {nY{1'b0}};
            end
            else begin
                clear_y_left <= clear_y_left + 1'b1;
            end
        end
        else begin
            clear_x_left <= clear_x_left + 1'b1;
        end
    end
end


	//----------------------------Main FSM------------------------
	
    // FSM next-state logic
	always @(*) begin
    	Y_D = A;
        	case (y_Q)
				A:  if (req_top1)      Y_D = B;      // see if object 1 wants to be drawn
                else if (req_btm1) Y_D = C;          // see if object 2 wants to be drawn
                else if (req_top2) Y_D = D;
                else if (req_btm2) Y_D = E;
                else if (req_top3) Y_D = F;
                else if (req_btm3) Y_D = G;
                else if (req_bird) Y_D = H;
					 else Y_D = A;

            B:  Y_D = (req_top1) ? B : A;            // wait for object 1 drawing cycle
            C:  Y_D = (req_btm1) ? C : A;            // wait for object 2 drawing cycle
            D:  Y_D = (req_top2) ? D : A;            // wait for object 3 drawing cycle
            E:  Y_D = (req_btm2) ? E : A;            // wait for object 4 drawing cycle
            F:  Y_D = (req_top3) ? F : A;            // wait for object 5 drawing cycle
            G:  Y_D = (req_btm3) ? G : A;            // wait for object 6 drawing cycle
				H:  Y_D = (req_bird) ? H : A;            // wait for bird drawing cycle

            	default: Y_D = A;
        	endcase
    	end


	// FSM outputs to drive the VGA display
	always @(*) begin
    	// default assignments
    	gnt_top1 = 1'b0; gnt_btm1 = 1'b0;
    	gnt_top2 = 1'b0; gnt_btm2 = 1'b0;
    	gnt_top3 = 1'b0; gnt_btm3 = 1'b0;
		gnt_bird = 1'b0;

    	MUX_x = 10'd0;
    	MUX_y = 9'd0;
    	MUX_color = 9'b000_000_000;
    	MUX_write = 1'b0;

    if (clear_left) begin
		MUX_x = clear_x_left;
		MUX_y = clear_y_left;
		MUX_color = SKYBLUE;
		MUX_write = 1'b1;
    end
    else begin
        case (y_Q)
            A: ;
            B: begin
                gnt_top1  = 1'b1;
                MUX_write = write_top1;
                MUX_x = x_top1;
                MUX_y = y_top1;
                MUX_color = color_top1;
            end
            C: begin
                gnt_btm1  = 1'b1;
                MUX_write = write_btm1;
                MUX_x = x_btm1;
                MUX_y = y_btm1;
                MUX_color = color_btm1;
            end
            D: begin
                gnt_top2  = 1'b1;
                MUX_write = write_top2;
                MUX_x = x_top2;
                MUX_y = y_top2;
                MUX_color = color_top2;
            end
            E: begin
                gnt_btm2  = 1'b1;
                MUX_write = write_btm2;
                MUX_x = x_btm2;
                MUX_y = y_btm2;
                MUX_color = color_btm2;
            end
            F: begin
                gnt_top3  = 1'b1;
                MUX_write = write_top3;
                MUX_x = x_top3;
                MUX_y = y_top3;
                MUX_color = color_top3;
            end
            G: begin
                gnt_btm3  = 1'b1;
                MUX_write = write_btm3;
                MUX_x = x_btm3;
                MUX_y = y_btm3;
                MUX_color = color_btm3;
            end
				H: begin
				   gnt_bird = 1'b1;
					MUX_write = O1_write;
					MUX_x = O1_x;
					MUX_y = O1_y;
					MUX_color = O1_color;
				end
        	endcase
    	end
	end


    // FSM state flip-flops
    always @(posedge CLOCK_50)
        if (Resetn == 0)   // wait until ready
            y_Q <= A;
        else
            y_Q <= Y_D;


	
	object top1 (Resetn, CLOCK_50, gnt_top1, req_top1,
             9'd0, top_h1,              // Y_init, Y_dim
             x_top1, y_top1, color_top1, write_top1,
             wrap_top1, pillar1_x);
    defparam top1.COLOR = PILLARGREEN;

	object btm1 (Resetn, CLOCK_50, gnt_btm1, req_btm1,
             btm_y1, btm_h1,             // Y_init, Y_dim
             x_btm1, y_btm1, color_btm1, write_btm1,
             wrap_btm1);
    defparam btm1.X_INIT = 10'd620;
    defparam btm1.COLOR  = PILLARGREEN;

	object top2 (Resetn, CLOCK_50, gnt_top2, req_top2,
             9'd0, top_h2,              // Y_init, Y_dim
             x_top2, y_top2, color_top2, write_top2,
             wrap_top2, pillar2_x);
    defparam top2.X_INIT = 10'd420;
    defparam top2.COLOR  = PILLARGREEN;

	object btm2 (Resetn, CLOCK_50, gnt_btm2, req_btm2,
             btm_y2, btm_h2,             // Y_init, Y_dim
             x_btm2, y_btm2, color_btm2, write_btm2,
             wrap_btm2);
    defparam btm2.X_INIT = 10'd420;
    defparam btm2.COLOR  = PILLARGREEN;

	object top3 (Resetn, CLOCK_50, gnt_top3, req_top3,
             9'd0, top_h3,              // Y_init, Y_dim
             x_top3, y_top3, color_top3, write_top3,
             wrap_top3, pillar3_x);
    defparam top3.X_INIT = 10'd220;
    defparam top3.COLOR  = PILLARGREEN;

	object btm3 (Resetn, CLOCK_50, gnt_btm3, req_btm3,
             btm_y3, btm_h3,             // Y_init, Y_dim
             x_btm3, y_btm3, color_btm3, write_btm3,
             wrap_btm3);
    defparam btm3.X_INIT = 10'd220;
    defparam btm3.COLOR  = PILLARGREEN;
	 
	 
	 //------------------------------------Bird------------------
	 


    sync S1 (~KEY[1], Resetn, CLOCK_50, KEY1);

    sync S3 (PS2_CLK, Resetn, CLOCK_50, PS2_CLK_S);
    sync S4 (PS2_DAT, Resetn, CLOCK_50, PS2_DAT_S);

    always @(posedge CLOCK_50)  // record PS2 clock value in previous CLOCK_50 cycle
        prev_ps2_clk <= PS2_CLK_S;

    // check when PS2_CLK has changed from 1 to 0
    assign negedge_ps2_clk = (prev_ps2_clk & !PS2_CLK_S);

    // save PS2 data packet
    always @(posedge CLOCK_50) begin    // specify a 33-bit shift register
        if (Resetn == 0)
            Serial <= 33'b0;
        else if (negedge_ps2_clk) begin
            Serial[31:0] <= Serial[32:1];
            Serial[32] <= PS2_DAT_S;
        end
    end


    // select object according to which PS2 key was pressed. 
    // scancode[4] == 1 for a/s/w/z and 0 for d/f/r/c
    assign O1_dir = (Serial[19:12] == 8'h1D) ? 2'b01: 2'b10; // 'W' pressed

// instantiate bird
player bird(Resetn, CLOCK_50, KEY1, 1'b1, O1_dir, O1_x, O1_y, 
               O1_color, O1_write, O1_done, gnt_bird, req_bird, player_x, player_y);
        defparam bird.LEFT  = 2'b00;  // 'a'
        defparam bird.RIGHT = 2'b11;  // 's'
        defparam bird.UP    = 2'b01;  // 'w'
        defparam bird.DOWN =  2'b10;  // 'z'
		  
		  
		  
//-------------------------------Collision------------------------------
		  
wire hit1, hit2, hit3;

collision col1 (
    .player_x (player_x),
    .player_y (player_y),
    .pillar_x (pillar1_x),
    .top_h    (top_h1),
    .btm_y    (btm_y1),
    .hit      (hit1)
);

collision col2 (
    .player_x (player_x),
    .player_y (player_y),
    .pillar_x (pillar2_x),
    .top_h    (top_h2),
    .btm_y    (btm_y2),
    .hit      (hit2)
);

collision col3 (
    .player_x (player_x),
    .player_y (player_y),
    .pillar_x (pillar3_x),
    .top_h    (top_h3),
    .btm_y    (btm_y3),
    .hit      (hit3)
);

// example debug: light LEDR[0] if any collision
assign LEDR[0] = hit1 | hit2 | hit3;

    // connect to VGA controller
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
		.VGA_CLK(VGA_CLK));
		// defparam VGA.BACKGROUND_IMAGE = "./MIF/startscreen.mif";
    assign LEDR[9:1] = 9'b0;

endmodule

// up/down counter with reset, enable, and load controls
module UpDn_count (R, Clock, Resetn, E, L, UpDn, Q);
    parameter n = 10;
    input wire [n-1:0] R;
    input wire Clock, Resetn, E, L, UpDn;
    output reg [n-1:0] Q;

    always @ (posedge Clock)
        if (Resetn == 0)
            Q <= 0;
        else if (L == 1)
            Q <= R;
        else if (E)
            if (UpDn == 1)
                Q <= Q + 1'b1;
            else
                Q <= Q - 1'b1;
endmodule

// counter
module Up_count (Clock, Resetn, Q);
    parameter n = 20;
    input wire Clock, Resetn;
    output reg [n-1:0] Q;

    always @ (posedge Clock)
        if (Resetn == 0)
            Q <= 'b0;
        else 
            Q <= Q + 1'b1;
endmodule

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



module object (Resetn, Clock, gnt, req, Y_init, Y_dim,  
               VGA_x, VGA_y, VGA_color, VGA_write, wrap, pillar_x);
	
	parameter SKYBLUE = 9'b010_101_111;
	parameter PILLARGREEN = 9'b001_111_001;
    parameter nX = 10;
    parameter nY = 9;
    parameter XDIM = 50, YDIM = 200;
	parameter XSCREEN = 640;
    parameter YSCREEN = 480;
    parameter X_INIT = 10'd620;
    parameter Y_INIT = 9'd0;
	parameter COLOR = 9'b111_111_111;	//default color
	parameter ALT = SKYBLUE;		//erasure color
    parameter KK = 20; // speed 
  
    parameter A = 4'b0000, B = 4'b0001, C = 4'b0010, D = 4'b0011,
              E = 4'b0100, F = 4'b0101, G = 4'b0110, H = 4'b0111,
              I = 4'b1000, J = 4'b1001, K = 4'b1010, L = 4'b1011;
	
    input wire Resetn, Clock;
    input wire gnt;  // set to 1 when this object is selected for VGA display
    output reg req; // object sets this request to 1 when it wants to be displayed
	output wire [9:0] VGA_x;  // pixel x coordinate output
	output wire [8:0] VGA_y;  // pixel y coordinate ouput
	output wire [8:0] VGA_color; // pixel color output
    output wire VGA_write;       // control output to write a pixel
	
	input wire [8:0] Y_init;
	input wire [8:0] Y_dim;
	output wire wrap;
	output wire [9:0] pillar_x;

	wire [9:0] X, XC, X0;    // used to traverse the object's width
	wire [8:0] YC, Y_base;    // used to traverse the object's height
	wire [8:0] color = COLOR;
    wire [KK-1:0] slow;         // used to synchronize the object's speed using a counter
	 
	reg Lx, Ly, Ex, Lxc, Lyc, Exc, Eyc; // load and enable signals for the object's location (x,y) and the counters that traverse the object's pixels (XC, YC)
	wire sync;    // sync is for the slow counter, Ydir is the direction of moving
	reg erase, Tdir;    // erase is used to erase the object. TDir is used to set Ydir
	reg [3:0] y_Q, Y_D; // FSM for controlling drawing/erasing of the object
	reg write;          // used to write to a pixel

	wire [9:0] X_RIGHT = XSCREEN[9:0] - XDIM[9:0];

	// true only when in the move state and about to wrap
	wire wrap_load = (y_Q == I) && (X == 'd0);

	// value that UpDn_count will load into X on Lx
	wire [9:0] X_RLOAD = wrap_load ? X_RIGHT : X_INIT;
	
	assign wrap = wrap_load;
	assign pillar_x = X;

    assign X0 = X_INIT;
    assign Y_base = Y_init;
	 

    
	UpDn_count U2 (X_RLOAD, Clock, Resetn, Ex, Lx, 1'b0, X);    // object's column location // X moves left only: count down and wrap via Lx
        defparam U2.n = nX;
   UpDn_count U3 ({nX{1'd0}}, Clock, Resetn, Exc, Lxc, 1'b1, XC); // object column counter
        defparam U3.n = nX;
   UpDn_count U4 ({nY{1'd0}}, Clock, Resetn, Eyc, Lyc, 1'b1, YC); // object row counter
        defparam U4.n = nY;
   Up_count U6 (Clock, Resetn, slow);  // counter to control the speed of moving
     defparam U6.n = KK;

   assign sync = (slow == {KK{1'b1}});

   	assign VGA_x = X + XC;                          // pixel x coordinate
    assign VGA_y = Y_base + YC;                          // pixel y coordinate
    assign VGA_color = erase == 0 ? color : ALT;    // pixel color to draw/erase
    assign VGA_write = write;                       // pixel write control

	
    always @ (*)
        case (y_Q)
            A:  Y_D = B;                        // initialize counters, registers

            B:  if (YC != Y_dim-1) Y_D = B;      // initial draw, done once
                else Y_D = C;
            C:  if (XC != XDIM-1) Y_D = B;
                else Y_D = D;

            D:  if (!sync) Y_D = D;             // wait for object's delay time
                else Y_D = E;
            E:  if (!gnt) Y_D = E;              // wait for VGA grant
                else Y_D = F;

            F:  if (YC != Y_dim-1) Y_D = F;      // erase object
                else Y_D = G;
            G:  if (XC != XDIM-1) Y_D = F;
                else Y_D = H;

            H:  Y_D = I;                        // move the object
            I:  Y_D = J;

            J:  if (YC != Y_dim-1) Y_D = J;      // draw the object
                else Y_D = K;
            K:  if (XC != XDIM-1) Y_D = J;
                else Y_D = L;
            L:  Y_D = D;
            default: Y_D = A;
        endcase

    always @ (*)
    begin
        // default assignments
        Lx = 1'b0; Ly = 1'b0; Lxc = 1'b0; Lyc = 1'b0; Exc = 1'b0; Eyc = 1'b0; 
        erase = 1'b0; write = 1'b0; Ex = 1'b0; Tdir = 1'b0; req = 1'b0;
        case (y_Q)
            A:  begin Lx = 1'b1; Ly = 1'b1; Lxc = 1'b1; Lyc = 1'b1; end // initialization

            B:  begin Eyc = 1'b1; write = 1'b1; end   // color a pixel, incr YC
            C:  begin Lyc = 1'b1; Eyc = 1'b1; end     // reload YC, incr XC

            D:  Lyc = 1'b1; // reload YC
            E:  req = 1'b1; // request a drawing cycle

            // erase the object
            F:  begin req = 1'b1; Eyc = 1'b1; erase = 1'b1; write = 1'b1; end
            G:  begin req = 1'b1; Lyc = 1'b1; Exc = 1'b1; end

            H: begin req = 1'b1; Lyc = 1'b1; end

            // move the object
            I:  begin req = 1'b1; Ex = 1'b1; Lx = (X == 'd0); end

            // draw the object
            J:  begin req = 1'b1; Eyc = 1'b1; write = 1'b1; end
            K:  begin req = 1'b1; Lyc = 1'b1; Exc = 1'b1; end
            L:  Lyc = 1'b1; // reload YC, and release the request
        endcase
    end

    // FSM FFs 
    always @(posedge Clock)
        if (Resetn == 0)
            y_Q <= A;
        else
            y_Q <= Y_D;

    
endmodule

// syncronizer, implemented as two FFs in series
module sync(D, Resetn, Clock, Q);
    input wire D;
    input wire Resetn, Clock;
    output reg Q;

    reg Qi; // internal node

    always @(posedge Clock)
        if (Resetn == 0) begin
            Qi <= 1'b0;
            Q <= 1'b0;
        end
        else begin
            Qi <= D;
            Q <= Qi;
        end
endmodule


// n-bit register with enable
module regn(R, Resetn, E, Clock, Q);
    parameter n = 8;
    input wire [n-1:0] R;
    input wire Resetn, E, Clock;
    output reg [n-1:0] Q;

    always @(posedge Clock)
        if (!Resetn)
            Q <= 0;
        else if (E)
            Q <= R;
endmodule

// n-bit up/down-counter with reset, load, enable, and direction control
module upDn_count (R, Clock, Resetn, L, E, Dir, Q);
    parameter n = 8;
    input wire [n-1:0] R;
    input wire Clock, Resetn, E, L, Dir;
    output reg [n-1:0] Q;

    always @ (posedge Clock)
        if (Resetn == 0)
            Q <= {n{1'b0}};
        else if (L == 1)
            Q <= R;
        else if (E)
            if (!Dir)
                Q <= Q + {{n-1{1'b0}},1'b1};
            else
                Q <= Q - {{n-1{1'b0}},1'b1};
endmodule

module half_second_counter (CLOCK_50, half_second_enable, Resetn);
    input CLOCK_50, Resetn;
    output reg half_second_enable;

    reg [24:0] count;

    always @ (posedge CLOCK_50)
        if (!Resetn)
            begin
                count <= 25'd0;
                half_second_enable <= 1'b1;
            end
        else
             begin
                 count <= count + 1;
                 if (count == 25'd500000) 
					      begin
                     half_second_enable <= 1'b1;
							count <= 25'd0;
							end
                 else
                     half_second_enable <= 1'b0;
             end
endmodule

module object_mem (address, clock, q);
    parameter n = 3;    // memory width
    parameter Mn = 6;   // address bits
    parameter INIT_FILE = "./MIF/object_mem_8_8_3.mif";

	input wire [Mn-1:0] address;
	input wire clock;
	output [n-1:0]  q;
	wire [n-1:0] sub_wire0;
	wire [n-1:0] q = sub_wire0[n-1:0];

	altsyncram	altsyncram_component (
				.address_a (address),
				.clock0 (clock),
				.q_a (sub_wire0),
				.aclr0 (1'b0),
				.aclr1 (1'b0),
				.address_b (1'b1),
				.addressstall_a (1'b0),
				.addressstall_b (1'b0),
				.byteena_a (1'b1),
				.byteena_b (1'b1),
				.clock1 (1'b1),
				.clocken0 (1'b1),
				.clocken1 (1'b1),
				.clocken2 (1'b1),
				.clocken3 (1'b1),
				.data_a ({n{1'b1}}),
				.data_b (1'b1),
				.eccstatus (),
				.q_b (),
				.rden_a (1'b1),
				.rden_b (1'b1),
				.wren_a (1'b0),
				.wren_b (1'b0));
	defparam
		altsyncram_component.address_aclr_a = "NONE",
		altsyncram_component.clock_enable_input_a = "BYPASS",
		altsyncram_component.clock_enable_output_a = "BYPASS",
		altsyncram_component.init_file = INIT_FILE,
		altsyncram_component.intended_device_family = "Cyclone V",
		altsyncram_component.lpm_hint = "ENABLE_RUNTIME_MOD=NO",
		altsyncram_component.lpm_type = "altsyncram",
		altsyncram_component.numwords_a = 1 << Mn,
		altsyncram_component.operation_mode = "ROM",
		altsyncram_component.outdata_aclr_a = "NONE",
		altsyncram_component.outdata_reg_a = "UNREGISTERED",
		altsyncram_component.widthad_a = Mn,
		altsyncram_component.width_a = n,
		altsyncram_component.width_byteena_a = 1;
endmodule



module player (Resetn, Clock, go, ps2_rec, dir, VGA_x, VGA_y, VGA_color, VGA_write, done, gnt_bird, rec, bird_x, bird_y);
	parameter SKYBLUE = 9'b010_101_111;
	parameter PILLARGREEN = 9'b001_111_001;
    // specify the number of bits needed for an X (column) pixel coordinate on the VGA display
    parameter nX = 10;
    // specify the number of bits needed for a Y (row) pixel coordinate on the VGA display
    parameter nY = 9;
    // by default, use offsets to center the object on the VGA display
    parameter XOFFSET = 100;
    parameter YOFFSET = 100;
    parameter LEFT = 2'b00 /*'a'*/, RIGHT = 2'b11/*'s'*/, UP = 2'b01/*'w'*/, DOWN = 2'b10/*'z'*/;
    parameter xOBJ = 5, yOBJ = 5;   // object size is 2^xOBJ x 2^yOBJ
    parameter BOX_SIZE_X = 1 << xOBJ;
    parameter BOX_SIZE_Y = 1 << yOBJ;
    parameter Mn = xOBJ + yOBJ; // address lines needed for the object memory
    parameter INIT_FILE = "./MIF/bird_32_32_9.mif";

    // state names for the FSM that draws the object
    parameter A = 3'b000, B = 3'b001, C = 3'b010, D = 3'b011, E = 3'b100,
              F = 3'b101, G = 3'b110, H = 3'b111;
    
    input wire Resetn, Clock;
    input wire go;                              // can be used to draw at initial position
    input wire ps2_rec;                         // PS2 data received
    input wire [1:0] dir;                       // movement direction
	output wire [nX-1:0] VGA_x;                 // for syncing with object memory
	output wire [nY-1:0] VGA_y;                 // for syncing with object memory
	output wire [8:0] VGA_color;                // used to draw pixels
    output wire VGA_write;                      // pixel write control
    output reg done;                            // done drawing cycle
	input wire gnt_bird;
	output reg rec;
	// ADD THESE TWO LINES:
output wire [nX-1:0] bird_x;
output wire [nY-1:0] bird_y;


	wire [nX-1:0] X, X0;    // starting X location 
	wire [nY-1:0] Y, Y0;    // starting Y location 
	wire [nX-1:0] size_x = BOX_SIZE_X;   // store the X size (must be power of 2)
	wire [nY-1:0] size_y = BOX_SIZE_Y;   // store the Y size
    wire [xOBJ-1:0] XC;                  // used to access object memory
    wire [yOBJ-1:0] YC;                  // used to access object memory
    reg write, Lxc, Lyc, Exc, Eyc;       // object control signals
    reg erase;                           // erase/draw object
    wire Right, Left, Up, Down;          // object direction
    reg Lx, Ly, Ex, Ey;                  // object counter controls
    reg [2:0] y_Q, Y_D;                  // FSM
    
	wire [8:0] obj_color;    // object pixel colors, read from memory
	
	wire half_second_enable;
	
	half_second_counter (Clock, half_second_enable, Resetn);
	
    // object (x,y) location. For x, counter will be enabled when moving L/R, increment
    // for R, decrement for L. For y, counter will be enabled when moving U/D, increment 
    // for D, decrement for U
    assign X0 = XOFFSET;
    assign Y0 = YOFFSET;
    upDn_count UX (X0, Clock, Resetn, Lx, Ex, Right, X);
        defparam UX.n = nX;
    upDn_count UY (Y0, Clock, Resetn, Ly, Ey, !Down, Y);
        defparam UY.n = nY;

    // these counter are used to generate (x,y) coordinates to read the object's pixels
    upDn_count U3 ({xOBJ{1'd0}}, Clock, Resetn, Lxc, Exc, 1'b0, XC); // object column counter
        defparam U3.n = xOBJ;
    upDn_count U4 ({yOBJ{1'd0}}, Clock, Resetn, Lyc, Eyc, 1'b0, YC); // object row counter
        defparam U4.n = yOBJ;

    // these signals are used to enable the (x,y) object location counters and to make these 
    // counters increment or decrement
    assign Left = (dir == LEFT);
    assign Right = (dir == RIGHT);
    assign Up = (dir == UP);
    assign Down = (dir == DOWN);

    // FSM state table
    always @ (*)
        case (y_Q)
            A:  Y_D = B;                  // load (x,y) location counters
			   B:  if (go) Y_D = F;                // show object
			       else if (gnt_bird & half_second_enable) Y_D = C;  
                else Y_D = B; //wait					 
            C:  if (XC != size_x-1) Y_D = C;    // erase row of object
                else Y_D = D;
            D:  if (YC != size_y-1) Y_D = C;    // next row of object to erase
                else Y_D = E;                   // done erase cycle
            E:  Y_D = F;                        // +/- (x,y)
            F:  if (XC != size_x-1) Y_D = F;    // draw row of object
                else Y_D = G;
            G:  if (YC != size_y-1) Y_D = F;    // next row of object to draw
                else Y_D = H;                   // done draw cycle
            H:  Y_D = B; 	
            default: Y_D = A;
        endcase
    // FSM outputs
    always @ (*)
    begin
        // default assignments
        Lx = 1'b0; Ly = 1'b0; Ex = 1'b0; Ey = 1'b0; write = 1'b0; rec = 1'b0;
        Lxc = 1'b0; Lyc = 1'b0; Exc = 1'b0; Eyc = 1'b0; erase = 1'b0; done = 1'b0;
        case (y_Q)
            A:  begin Lx = 1'b1; Ly = 1'b1; end                   // load (X,Y) counters
            B:  begin rec = 1'b1; Lxc = 1'b1; Lyc = 1'b1; end                 // load (XC,YC) counters
            C:  begin rec = 1'b1; Exc = 1'b1; write = 1'b1; erase = 1'b1; end // enable XC, write pixel
            D:  begin rec = 1'b1; Lxc = 1'b1; Eyc = 1'b1; erase = 1'b1; end   // load XC, enable YC
            // state E is reached after erasing the object. Now, move and draw the object
            E:  begin rec = 1'b1; Ex = 1'b0; Ey = 1'b1; end                   // move L/R or U/D
            F:  begin rec = 1'b1; Exc = 1'b1; write = 1'b1; end               // enable XC, write pixel
            G:  begin rec = 1'b1; Lxc = 1'b1; Eyc = 1'b1; end                 // load XC, enable YC
            H:  done = 1'b1;
        endcase
    end

    // FSM state FFs
    always @(posedge Clock)
        if (!Resetn)
            y_Q <= 3'b0;
        else
            y_Q <= Y_D;

    // read a pixel color from the object memory. We can use {YC,XC} because the x dimension
    // of the object memory is a power of 2
    object_mem U6 ({YC,XC}, Clock, obj_color);
        defparam U6.n = 9;
        defparam U6.Mn = xOBJ + yOBJ;
        defparam U6.INIT_FILE = INIT_FILE;

    // compute the (x,y) location of the current pixel to be drawn (or erased). We subtract
    // half the object's width and height because we want the objec to be centered at its 
    // original (x,y) location. We add (Xc,YC) to form the correct address of the pixel. The
    // object memory takes one clock cycle to provide data, so we register the computed (x,y)
    // location to remain synchronized
    regn U7 (X - (size_x >> 1) + XC, Resetn, 1'b1, Clock, VGA_x);
        defparam U7.n = nX;
    regn U8 (Y - (size_y >> 1) + YC, Resetn, 1'b1, Clock, VGA_y);
        defparam U8.n = nY;

    // synchronize write signal with VGA_x, VGA_y, VGA_color 
    regn U9 (write, Resetn, 1'b1, Clock, VGA_write);
        defparam U9.n = 1;

    // use the background color (when erasing), or the object color when drawing
    // (black background is assumed below)
    assign VGA_color = erase ? SKYBLUE : obj_color;
	 
	 // NEW: expose bird's top-left position for collision logic
    assign bird_x = X - (size_x >> 1);  // X is center → convert to left edge
    assign bird_y = Y - (size_y >> 1);  // Y is center → convert to top edge

endmodule

// Bird vs one pillar pair (top + bottom)
module collision
#(
    parameter nX        = 10,
    parameter nY        = 9,
    parameter BIRD_W    = 32,      // bird width  in pixels
    parameter BIRD_H    = 32,      // bird height in pixels
    parameter PILLAR_W  = 50,      // pillar width (must match XDIM)
    parameter [nY-1:0] SCREEN_H = 9'd480  // screen height
)
(
    input  wire [nX-1:0] player_x,   // bird top-left X
    input  wire [nY-1:0] player_y,   // bird top-left Y

    input  wire [nX-1:0] pillar_x,   // pillar left X (from object)
    input  wire [nY-1:0] top_h,      // top pillar height      (top_h1/2/3)
    input  wire [nY-1:0] btm_y,      // bottom pillar start Y  (btm_y1/2/3)

    output wire          hit         // 1 = collision
);

    // bird rectangle (top-left + size)
    wire [nX-1:0] player_right  = player_x + BIRD_W - 1'b1;
    wire [nY-1:0] player_bottom = player_y + BIRD_H - 1'b1;

    // pillar strip horizontally
    wire [nX-1:0] pillar_right = pillar_x + PILLAR_W - 1'b1;

    // horizontal overlap with pillar strip
    wire overlap_x = (player_right >= pillar_x) && (player_x <= pillar_right);

    // gap is [top_h .. btm_y-1]
    // SAFE region: bird strictly inside gap, not touching edges
    wire inside_gap_top_ok    = (player_y      >  top_h);
    wire inside_gap_bottom_ok = (player_bottom <  btm_y);
    wire inside_gap           = inside_gap_top_ok && inside_gap_bottom_ok;

    // collision with pillars: overlapping in X and NOT safely inside the gap
    wire hit_pillars = overlap_x && ~inside_gap;

    // --- NEW: collision with screen top/bottom ---
    wire hit_top_screen    = (player_y == {nY{1'b0}});           // touch y=0
    wire hit_bottom_screen = (player_bottom >= SCREEN_H - 1'b1); // touch bottom

    assign hit = hit_pillars || hit_top_screen || hit_bottom_screen;

endmodule
