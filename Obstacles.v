`default_nettype none
module obstacles(CLOCK_50, SW, KEY, LEDR, VGA_R, VGA_G, VGA_B,
				VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK);

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

	// need 10 bits for a X coordinate (640 pixels)
    parameter nX = 10;
	// need 10 bits for a Y coordinate (4800 pixels)
    parameter nY = 9;

    wire Resetn = KEY[0];
    wire [nX-1:0] topX, btmX; reg [nX-1:0] MuxX;
    wire [nY-1:0] topY, btmY; reg [nY-1:0] MuxY;
    wire topWrite, btmWrite; reg MuxWrite;
    wire topReq, btmReq; 
    reg  topGrant, btmGrant; 
    reg  [1:0] y_Q, Y_D;

    //screen size
    parameter Xscreen = 640;
    parameter Yscreen = 480;

    // state codes for FSM that choses which object to draw at a given time
    parameter A = 2'b00, B = 2'b01, C = 2'b10, D = 2'b11;
    
    always @ (*)
        case (y_Q)
            A:  if (topReq) Y_D = B;        // see if both objects want to be drawn
                else if(btmReq) Y_D = C;
                else Y_D = A;

            B:  if (topReq) Y_D = B;          // wait for object 1 drawing cycle
                else Y_D = A;

            C:  if (btmReq) Y_D = C;          // wait for object 2 drawing cycle
                else Y_D = A;
                
            default:  Y_D = A;
        endcase
    
    // FSM outputs to drive the VGA display from either object 1 or object 2
    // either draw top or draw bottom pillar
    always @ (*)
    begin
        // default assignments
        topGrant = 1'b0; btmGrant = 1'b0; MuxWrite = 1'b0;
        MuxX = topX; MuxY = topY;
        case (y_Q)
            A:  ;
            B:  begin topGrant = 1'b1; MuxWrite = topWrite; 
                      MuxX = topX; MuxY = topY; end
            C:  begin btmGrant = 1'b1; MuxWrite = btmWrite; 
                      MuxX = btmX; MuxY = btmY; end
        endcase
    end


    // FSM state flip-flops
    always @(posedge CLOCK_50)
        if (Resetn == 0)   // wait until ready
            y_Q <= A;
        else
            y_Q <= Y_D;


    object O1 (10'd620, 9'd0,   Resetn, CLOCK_50, topGrant, topReq, topX, topY, topWrite, topErase);
    object O2 (10'd620, 9'd280, Resetn, CLOCK_50, btmGrant, btmReq, btmX, btmY, btmWrite, btmErase);


    wire [8:0] fixedColor = 9'b000111000;

    // connect to VGA controller
    vga_adapter VGA (
		.resetn(KEY[0]),
		.clock(CLOCK_50),
		.color( (y_Q==B) ? (topErase ? 9'b000000000 : 9'b000111000) :
        (y_Q==C) ? (btmErase ? 9'b000000000 : 9'b000111000) :
                   9'b000111000 ),
		.x(MuxX),
		.y(MuxY),
		.write(MuxWrite),
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
module UpDwncount (R, Clock, Resetn, E, L, UpDn, Q);
    parameter n = 8;
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
module Upcount (Clock, Resetn, Q);
    parameter n = 8;
    input wire Clock, Resetn;
    output reg [n-1:0] Q;

    always @ (posedge Clock)
        if (Resetn == 0)
            Q <= 'b0;
        else 
            Q <= Q + 1'b1;
endmodule


module object#(parameter nX=10, parameter nY=9, parameter width=60, parameter height=200, parameter KK=24)
                (Xini, Yini, Resetn, Clock, grant, req, VGA_x, VGA_y, VGA_write, erase_o);        //will be called twice (for bottom and top pillar)


    output wire erase_o;
    assign erase_o = erase;
    input  wire [nX-1:0] Xini;
    input  wire [nY-1:0] Yini;
    input wire Resetn, Clock;
    input wire grant;  // set to 1 when this object is selected for VGA display
    output reg req; // object sets this request to 1 when it wants to be displayed
    output wire [nX-1:0] VGA_x;  // pixel x coordinate output
	output wire [nY-1:0] VGA_y;  // pixel y coordinate ouput
    output wire VGA_write;       // control output to write a pixel

    reg Lx, Ex, Lxc, Lyc, Exc, Eyc; // load and enable signals for the object's location (x,y) and the counters that traverse  the object's pixels (XC, YC)
    reg erase;  //to erase object
    reg write;  //to write a pixel
    reg [3:0] y_Q, Y_D; // FSM for controlling drawing/erasing of the object
    wire [nX-1:0] X, XC;    // used to traverse the object's width
	wire [nY-1:0] Y, YC;    // used to traverse the object's height
    assign Y = Yini;

    wire topErase, btmErase;

    // divider for constant speed
    wire [KK-1:0] slow;

    parameter A = 4'b0000, B = 4'b0001, C = 4'b0010, D = 4'b0011,
              E = 4'b0100, F = 4'b0101, G = 4'b0110, H = 4'b0111,
              I = 4'b1000, J = 4'b1001, K = 4'b1010, L = 4'b1011;

    UpDwncount U1 (Xini, Clock, Resetn, Ex, Lx, 1'b0, X);    // object's column location
        defparam U1.n = nX;

    // sweep across the pillar rectangle
    UpDwncount U2 ({nX{1'b0}}, Clock, Resetn, Exc, Lxc, 1'b1, XC); // column sweep
        defparam U2.n = nX;

    UpDwncount U3 ({nY{1'b0}}, Clock, Resetn, Eyc, Lyc, 1'b1, YC); // row sweep
        defparam U3.n = nY;

    Upcount U4 (Clock, Resetn, slow);    // KK picks speed (e.g., 19 ≈ 95 px/s @50 MHz)
    defparam U4.n = KK;

    wire sync = &slow;                     // use sync in your FSM’s wait state

    assign VGA_x = X + XC;                          // pixel x coordinate
    assign VGA_y = Y + YC;                          // pixel y coordinate
    assign VGA_write = write;                       // pixel write control


    //---------------------------------------------------------------------------FSM----------------------------------------------------------------------------

always @(*) begin
    case (y_Q)
        A:  Y_D = B;                               // A: init once, then start initial draw
		B:  Y_D = (XC != width-1) ? B : C;         // B: draw row across width
		C:  Y_D = (YC != height-1) ? B : D;        // C: end row, advance YC until full height done
        D:  Y_D = (!sync) ? D : E;                 // D: wait for constant-speed tick
        E:  Y_D = (!grant)  ? E : F;               // E: request bus; wait for grant
		F:  Y_D = (XC != width-1) ? F : G;         // F: erase row across width
		G:  Y_D = (YC != height-1) ? F : H;        // G: finish erase row, go to next erase row
        H:  Y_D = I;                               // H: move X left or wrap
        I:  Y_D = J;                               // I: bookkeeping (keep req high)
		J:  Y_D = (XC != width-1) ? J : K;         // J: draw row at new X
		K:  Y_D = (YC != height-1) ? J : L;        // K: finish draw row, go to next draw row
        L:  Y_D = D;                               // L: release request, wait for next tick
        default: Y_D = A;
    endcase
end

    
always @(*) begin
    Lx = 1'b0; Lxc = 1'b0; Lyc = 1'b0; Exc = 1'b0; Eyc = 1'b0; Ex = 1'b0; 
    erase = 1'b0; write = 1'b0; req = 1'b0;
    case (y_Q)
        A: begin
            // A: initialize counters/registers
            Lx  = 1'b1;             // load X to X_INIT
            Lxc = 1'b1;             // XC <- 0
            Lyc = 1'b1;             // YC <- 0
        end

        B: begin
            // B: draw a pixel, increment XC
            Exc   = 1'b1;
            write = 1'b1;
        end

        C: begin
            // C: end of row: reset XC, increment YC
            Lxc = 1'b1;
            Eyc = 1'b1;
        end

        D: begin
            // D: wait for object's delay time (speed tick)
            Lyc = 1'b1;             // ensure YC is 0 before next cycle
        end

        E: begin
            // E: request a drawing cycle (arbiter grant)
            req = 1'b1;
        end

        F: begin
            // F: erase object row (write black), increment XC
            req   = 1'b1;
            erase = 1'b1;
            write = 1'b1;
            Exc   = 1'b1;
        end

        G: begin
            // G: finish erase row and go to next erase row
            req = 1'b1;
            Lxc = 1'b1;
            Eyc = 1'b1;
        end

        H: begin
            // H: move the object left; wrap to right edge if X==0
            req = 1'b1;
            if (X == {nX{1'b0}}) begin
                Lx = 1'b1;          // wrap: reload X from X_INIT (via X0 -> UpDn_count load)
            end else begin
                Ex = 1'b1;          // step X down by 1
            end
        end

        I: begin
            // I: bookkeeping (keep request asserted during move)
            req = 1'b1;
        end

        J: begin
            // J: draw object row at new X, increment XC
            req   = 1'b1;
            write = 1'b1;
            Exc   = 1'b1;
        end

        K: begin
            // K: finish draw row and go to next draw row
            req = 1'b1;
            Lxc = 1'b1;
            Eyc = 1'b1;
        end

        L: begin
            // L: reload YC (done), release request by default
            Lyc = 1'b1;
        end
    endcase
end

        // FSM FFs 
    always @(posedge Clock)
        if (Resetn == 0)
            y_Q <= A;
        else
            y_Q <= Y_D;

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

        

