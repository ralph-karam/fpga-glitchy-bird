`default_nettype none

module obstacles(CLOCK_50, SW, KEY, LEDR, VGA_R, VGA_G, VGA_B,
				VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK);
	
    // specify the number of bits needed for an X (column) pixel coordinate on the VGA display
    parameter nX = 10;
    // specify the number of bits needed for a Y (row) pixel coordinate on the VGA display
    parameter nY = 9;

    // state codes for FSM that choses which object to draw at a given time
    parameter A = 3'b000, B = 3'b001, C = 3'b010, D = 3'b011, E = 3'b100, F = 3'b101, G = 3'b110;

	input wire CLOCK_50;	
	input wire [9:0] SW;
	input wire [0:0] KEY;
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
	
    reg gnt_top1, gnt_top2, gnt_top3;
	reg gnt_btm1, gnt_btm2, gnt_btm3;
	
	reg [nX-1:0] MUX_x;
	reg [nY-1:0] MUX_y;
	reg [8:0] MUX_color;
    reg MUX_write;
	reg [2:0] y_Q, Y_D;
	
    wire Resetn, faster, slower;

    assign Resetn = KEY[0];

    always @ (*)
        case (y_Q)
			A:  if (req_top1) Y_D = B;          // see if object 1 wants to be drawn
			else if (req_btm1) Y_D = C;     // see if object 2 wants to be drawn
			else if (req_top2) Y_D = D;
			else if (req_btm2) Y_D = E;
			else if (req_top3) Y_D = F;
			else if (req_btm3) Y_D = G;
                else Y_D = A;
					 
			B:  if (req_top1) Y_D = B;          // wait for object 1 drawing cycle
                else Y_D = A;
			C:  if (req_btm1) Y_D = C;          // wait for object 2 drawing cycle
                else Y_D = A;
					 
			D:  if (req_top2) Y_D = D;          // wait for object 3 drawing cycle
                else Y_D = A;
			E:  if (req_btm2) Y_D = E;          // wait for object 4 drawing cycle
                else Y_D = A;
			
			F:  if (req_top3) Y_D = F;          // wait for object 5 drawing cycle
                else Y_D = A;
			G:  if (req_btm3) Y_D = G;          // wait for object 6 drawing cycle
                else Y_D = A;
			
            default:  Y_D = A;
        endcase

    // FSM outputs to drive the VGA display from either object 1 or object 2
    always @ (*)
    begin
        // default assignments
        gnt_top1 = 1'b0; gnt_btm1 = 1'b0; gnt_top2 = 1'b0; gnt_btm2 = 1'b0; gnt_top3 = 1'b0; gnt_btm3 = 1'b0;
		MUX_write = 1'b0; MUX_x = x_top1; MUX_y = y_top1; MUX_color = color_top1;
        case (y_Q)
            A:  ;
            B:  begin gnt_top1 = 1'b1; MUX_write = write_top1; 
                      MUX_x = x_top1; MUX_y = y_top1; MUX_color = color_top1; end
            C:  begin gnt_btm1 = 1'b1; MUX_write = write_btm1; 
                      MUX_x = x_btm1; MUX_y = y_btm1; MUX_color = color_btm1; end
			
            D:  begin gnt_top2 = 1'b1; MUX_write = write_top2; 
                      MUX_x = x_top2; MUX_y = y_top2; MUX_color = color_top2; end
            E:  begin gnt_btm2 = 1'b1; MUX_write = write_btm2; 
                      MUX_x = x_btm2; MUX_y = y_btm2; MUX_color = color_btm2; end
			
            F:  begin gnt_top3 = 1'b1; MUX_write = write_top3; 
                      MUX_x = x_top3; MUX_y = y_top3; MUX_color = color_top3; end
            G:  begin gnt_btm3 = 1'b1; MUX_write = write_btm3; 
                      MUX_x = x_btm3; MUX_y = y_btm3; MUX_color = color_btm3; end
				
        endcase
    end

    // FSM state flip-flops
    always @(posedge CLOCK_50)
        if (Resetn == 0)   // wait until ready
            y_Q <= A;
        else
            y_Q <= Y_D;


	
// top1
object top1 (Resetn, CLOCK_50, gnt_top1, faster, slower, req_top1, x_top1, y_top1, color_top1, write_top1);
    defparam top1.nX    = nX;
    defparam top1.nY    = nY;
    defparam top1.COLOR = 9'b000_111_000;

// btm1
object btm1 (Resetn, CLOCK_50, gnt_btm1, faster, slower, req_btm1, x_btm1, y_btm1, color_btm1, write_btm1);
    defparam btm1.nX     = nX;
    defparam btm1.nY     = nY;
    defparam btm1.X_INIT = 10'd620;
    defparam btm1.Y_INIT = 9'd280;
    defparam btm1.COLOR  = 9'b000_111_000;

// top2
object top2 (Resetn, CLOCK_50, gnt_top2, faster, slower, req_top2, x_top2, y_top2, color_top2, write_top2);
    defparam top2.nX     = nX;
    defparam top2.nY     = nY;
    defparam top2.X_INIT = 10'd420;
    defparam top2.COLOR  = 9'b000_000_111;

// btm2
object btm2 (Resetn, CLOCK_50, gnt_btm2, faster, slower, req_btm2, x_btm2, y_btm2, color_btm2, write_btm2);
    defparam btm2.nX     = nX;
    defparam btm2.nY     = nY;
    defparam btm2.X_INIT = 10'd420;
    defparam btm2.Y_INIT = 9'd280;
    defparam btm2.COLOR  = 9'b000_000_111;

// top3
object top3 (Resetn, CLOCK_50, gnt_top3, faster, slower, req_top3, x_top3, y_top3, color_top3, write_top3);
    defparam top3.nX     = nX;
    defparam top3.nY     = nY;
    defparam top3.X_INIT = 10'd220;
    defparam top3.COLOR  = 9'b111_000_000;

// btm3
object btm3 (Resetn, CLOCK_50, gnt_btm3, faster, slower, req_btm3, x_btm3, y_btm3, color_btm3, write_btm3);
    defparam btm3.nX     = nX;
    defparam btm3.nY     = nY;
    defparam btm3.X_INIT = 10'd220;
    defparam btm3.Y_INIT = 9'd280;
    defparam btm3.COLOR  = 9'b111_000_000;


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
        // choose background image 
		defparam VGA.BACKGROUND_IMAGE = "./MIF/scenery.mif";
    assign LEDR[9:0] = 10'b0;

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

// implements a moving colored object
module object (Resetn, Clock, gnt, faster, slower, req,  
               VGA_x, VGA_y, VGA_color, VGA_write);

    // specify the number of bits needed for an X (column) pixel coordinate on the VGA display
    parameter nX = 10;
    // specify the number of bits needed for a Y (row) pixel coordinate on the VGA display
    parameter nY = 9;

    parameter XSCREEN = 640;
    parameter YSCREEN = 480;

    parameter XDIM = 50, YDIM = 200; // object's width and height

    // default initial location of the object 
    parameter X_INIT = 10'd620;
    parameter Y_INIT = 9'd0;

	// default color of the object
	parameter COLOR = 9'b111111111;

	//erasure color
	parameter ALT = 9'b000_000_000;

    parameter KK = 19; // controls animation speed (use 16 for DESim, 5 for ModelSim)
    parameter MM = 8;  // animation speed up/down mask (use 6 for DESim, 2 for ModelSim)

    // state codes
    parameter A = 4'b0000, B = 4'b0001, C = 4'b0010, D = 4'b0011,
              E = 4'b0100, F = 4'b0101, G = 4'b0110, H = 4'b0111,
              I = 4'b1000, J = 4'b1001, K = 4'b1010, L = 4'b1011;
	wire [nX-1:0] X_RIGHT = XSCREEN[nX-1:0] - XDIM[nX-1:0];

    input wire Resetn, Clock;
    input wire gnt;  // set to 1 when this object is selected for VGA display
    input wire faster, slower;   // used to increase/decrease the object's speed
    output reg req; // object sets this request to 1 when it wants to be displayed
	output wire [nX-1:0] VGA_x;  // pixel x coordinate output
	output wire [nY-1:0] VGA_y;  // pixel y coordinate ouput
	output wire [8:0] VGA_color; // pixel color output
    output wire VGA_write;       // control output to write a pixel

	wire [nX-1:0] X, XC, X0;    // used to traverse the object's width
	wire [nY-1:0] Y, YC, Y0;    // used to traverse the object's height
	wire [8:0] color = COLOR;
    wire [KK-1:0] slow;         // used to synchronize the object's speed using a counter
	 
    reg Lx, Ly, Ex, Lxc, Lyc, Exc, Eyc; // load and enable signals for the object's 
                                        // location (x,y) and the counters that traverse 
                                        // the object's pixels (XC, YC)
    wire sync;    // sync is for the slow counter, Ydir is the direction of moving
    reg erase, Tdir;    // erase is used to erase the object. TDir is used to set Ydir
    reg [3:0] y_Q, Y_D; // FSM for controlling drawing/erasing of the object
    reg write;          // used to write to a pixel

    // mask logic (speed control)
    reg [2:0] ys_Q, Ys_D;   // FSM to control the object's speed
    reg sll, srl;           // shift the mask left or right
    reg [MM-1:0] mask;      // the mask (see FSM description below)

    assign X0 = X_INIT;
    assign Y0 = Y_INIT;

    
    UpDn_count U2 (X0, Clock, Resetn, Ex, Lx, 1'b0, X);    // object's column location // X moves left only: count down and wrap via Lx
        defparam U2.n = nX;

    UpDn_count U1 (Y0, Clock, Resetn, 1'b0, Ly, 1'b1, Y);      // object's row location // Y stays fixed (load once) no enable 
        defparam U1.n = nY;
	

    UpDn_count U3 ({nX{1'd0}}, Clock, Resetn, Exc, Lxc, 1'b1, XC); // object column counter
        defparam U3.n = nX;
    UpDn_count U4 ({nY{1'd0}}, Clock, Resetn, Eyc, Lyc, 1'b1, YC); // object row counter
        defparam U4.n = nY;

    Up_count U6 (Clock, Resetn, slow);  // counter to control the speed of moving
        defparam U6.n = KK;

 
    assign sync = ((slow | (mask << KK-MM)) == {KK{1'b1}});


    assign VGA_x = X + XC;                          // pixel x coordinate
    assign VGA_y = Y + YC;                          // pixel y coordinate
    assign VGA_color = erase == 0 ? color : ALT;    // pixel color to draw/erase
    assign VGA_write = write;                       // pixel write control



    always @ (*)
        case (y_Q)
            A:  Y_D = B;                        // initialize counters, registers

            B:  if (XC != XDIM-1) Y_D = B;      // initial draw, done once
                else Y_D = C;
            C:  if (YC != YDIM-1) Y_D = B;
                else Y_D = D;

            D:  if (!sync) Y_D = D;             // wait for object's delay time
                else Y_D = E;
            E:  if (!gnt) Y_D = E;              // wait for VGA grant
                else Y_D = F;

            F:  if (XC != XDIM-1) Y_D = F;      // erase object
                else Y_D = G;
            G:  if (YC != YDIM-1) Y_D = F;
                else Y_D = H;

            H:  Y_D = I;                        // move the object
            I:  Y_D = J;

            J:  if (XC != XDIM-1) Y_D = J;      // draw the object
                else Y_D = K;
            K:  if (YC != YDIM-1) Y_D = J;
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

            B:  begin Exc = 1'b1; write = 1'b1; end   // color a pixel, incr XC
            C:  begin Lxc = 1'b1; Eyc = 1'b1; end     // reload XC, incr YC

            D:  Lyc = 1'b1; // reload YC
            E:  req = 1'b1; // request a drawing cycle

            // erase the object
            F:  begin req = 1'b1; Exc = 1'b1; erase = 1'b1; write = 1'b1; end
            G:  begin req = 1'b1; Lxc = 1'b1; Eyc = 1'b1; end

            H:  begin req = 1'b1; Lyc = 1'b1; Tdir = (Y == 'd0) || (Y == YSCREEN-YDIM); end

            // move the object
            I:  begin req = 1'b1; Ex = 1'b1; Lx = (X == 'd0); end

            // draw the object
            J:  begin req = 1'b1; Exc = 1'b1; write = 1'b1; end
            K:  begin req = 1'b1; Lxc = 1'b1; Eyc = 1'b1; end
            L:  Lyc = 1'b1; // reload YC, and release the request
        endcase
    end

    // FSM FFs 
    always @(posedge Clock)
        if (Resetn == 0)
            y_Q <= A;
        else
            y_Q <= Y_D;

    // specify the mask shift register. Shift in 1's from the MSB to speed up an object's
    // movement, and shift in 0's from the LSB to slow down an object's movement
    always @(posedge Clock) begin
        if (Resetn == 0)
            mask <= 'b0;
        else if (srl) begin
            mask[MM-2:0] <= mask[MM-1:1];
            mask[MM-1] <= 1'b1;
        end
        else if (sll) begin
            mask[MM-1:1] <= mask[MM-2:0];
            mask[0] <= 1'b0;
        end
    end

    // state codes for controlling the mask shift register
    parameter As = 3'b000, Bs = 3'b001, Cs = 3'b010, Ds = 3'b011, Es = 3'b100;

    // FSM for controlling speed of movement
    always @ (*)
        case (ys_Q)
            As: if (faster) Ys_D = Bs;
                else if (slower) Ys_D = Ds;
                else Ys_D = As;
            Bs: Ys_D = Cs;    // one cycle to shift
            Cs: if (faster) Ys_D = Cs; // wait for KEY release
                else Ys_D = As;
            Ds: Ys_D = Es;    // one cycle to shift
            Es: if (slower) Ys_D = Es; // wait for KEY release
                else Ys_D = As;
            default: Ys_D = As;
        endcase
    // FSM outputs
    always @ (*)
    begin
        // default assignments
        sll = 1'b0; srl = 1'b0;
        case (ys_Q)
            As:  ;
            Bs:  srl = 1'b1;    // shift in a 1 from the MSB
            Cs:  ;
            Ds:  sll = 1'b1;    // shift in a 0 from the LSB
            Es:  ;
        endcase
    end

    always @(posedge Clock)
        if (Resetn == 0)
            ys_Q <= As;
        else
            ys_Q <= Ys_D;

endmodule



//This is animation demo with the following changes: XDIM YDIM XINI YINI
// Updwn counters function declarations Ey becomes 0 and reg Ex appears. Ydir becomes 1 and Xdir appears
// State I becomes // move the object I:  begin req = 1'b1; Ex = 1'b1; Lx = (X == 'd0); end
