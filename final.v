'default_nettype none

module obstacles(CLOCK_50, SW, KEY, LEDR, PS2_CLK, PS2_DAT, VGA_R, VGA_G, VGA_B,
				VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK);
	parameter nX = 10;
	parameter nY = 9;
	
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
	
	reg [8:0] top_h1, btm_h1, btm_y1;
	reg [8:0] top_h2, btm_h2, btm_y2;
	reg [8:0] top_h3, btm_h3, btm_y3;
	
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

	localparam [nX-1:0] PILLAR_WIDTH = 10'd30;

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

 /*   if (!started) begin
        // before KEY[0] is pressed
        MUX_write = 1'b0;
    end
    else if (clearing) begin
		// after KEY[0] press, make screen black
        MUX_x = clear_x;
        MUX_y = clear_y;
        MUX_color = 9'b000_000_000;
        MUX_write = 1'b1;
    end
    else begin */
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
	// end


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
    defparam top1.COLOR = 9'b000_111_000;

	object btm1 (Resetn, CLOCK_50, gnt_btm1, req_btm1,
             btm_y1, btm_h1,             // Y_init, Y_dim
             x_btm1, y_btm1, color_btm1, write_btm1,
             wrap_btm1);
    defparam btm1.X_INIT = 10'd620;
    defparam btm1.COLOR  = 9'b000_111_000;

	object top2 (Resetn, CLOCK_50, gnt_top2, req_top2,
             9'd0, top_h2,              // Y_init, Y_dim
             x_top2, y_top2, color_top2, write_top2,
             wrap_top2, pillar2_x);
    defparam top2.X_INIT = 10'd420;
    defparam top2.COLOR  = 9'b000_000_111;

	object btm2 (Resetn, CLOCK_50, gnt_btm2, req_btm2,
             btm_y2, btm_h2,             // Y_init, Y_dim
             x_btm2, y_btm2, color_btm2, write_btm2,
             wrap_btm2);
    defparam btm2.X_INIT = 10'd420;
    defparam btm2.COLOR  = 9'b000_000_111;

	object top3 (Resetn, CLOCK_50, gnt_top3, req_top3,
             9'd0, top_h3,              // Y_init, Y_dim
             x_top3, y_top3, color_top3, write_top3,
             wrap_top3, pillar3_x);
    defparam top3.X_INIT = 10'd220;
    defparam top3.COLOR  = 9'b111_000_000;

	object btm3 (Resetn, CLOCK_50, gnt_btm3, req_btm3,
             btm_y3, btm_h3,             // Y_init, Y_dim
             x_btm3, y_btm3, color_btm3, write_btm3,
             wrap_btm3);
    defparam btm3.X_INIT = 10'd220;
    defparam btm3.COLOR  = 9'b111_000_000;
	 
	 
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
