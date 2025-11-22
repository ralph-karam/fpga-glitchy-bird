module object (Resetn, Clock, gnt, req, Y_init, Y_dim,  
               VGA_x, VGA_y, VGA_color, VGA_write, wrap, pillar_x);
	
	parameter SKYBLUE = 9'b010_101_111;
	parameter PILLARGREEN = 9'b000_111_001;
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

            B:  if (XC != XDIM-1) Y_D = B;      // initial draw, done once
                else Y_D = C;
            C:  if (YC != Y_dim-1) Y_D = B;
                else Y_D = D;

            D:  if (!sync) Y_D = D;             // wait for object's delay time
                else Y_D = E;
            E:  if (!gnt) Y_D = E;              // wait for VGA grant
                else Y_D = F;

            F:  if (XC != XDIM-1) Y_D = F;      // erase object
                else Y_D = G;
            G:  if (YC != Y_dim-1) Y_D = F;
                else Y_D = H;

            H:  Y_D = I;                        // move the object
            I:  Y_D = J;

            J:  if (XC != XDIM-1) Y_D = J;      // draw the object
                else Y_D = K;
            K:  if (YC != Y_dim-1) Y_D = J;
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

            H: begin req = 1'b1; Lyc = 1'b1; end

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

    
endmodule
