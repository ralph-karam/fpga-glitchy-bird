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

//take keyboard input and display it on hex display; set obj_move to 1 if space is pressed
//also set obj_move to 1 if KEY[1] is pressed
module user_input (CLOCK_50, KEY, PS2_CLK, PS2_DAT, HEX5, HEX4, HEX3, HEX2, HEX1, HEX0, obj_move, Resetn);
    input wire CLOCK_50;	
    input wire [3:0] KEY;
    inout wire PS2_CLK, PS2_DAT;
    output wire [6:0] HEX5, HEX4, HEX3, HEX2, HEX1, HEX0;
    output reg obj_move;

    wire Resetn;
    reg prev_ps2_clk;               // ps2_clk value in the previous clock cycle
    wire negedge_ps2_clk;           // used for PS2 keyboard signals
    wire ps2_rec;                   // set when a PS2 packet has been received
    reg [32:0] Serial;              // each PS2 serial data packet has 11 bits:
                                    // STOP (1) PARITY d7 d6 d5 d4 d3 d2 d1 d0 START (0)
                                    // 33 total bits are received (scancode/release/scancode
    reg [3:0] Packet;               // used to know when 11 bits have been received
    wire [7:0] scancode;            // used to save the current ps2 scancode
    reg Esc;                        // enable scancode register

    wire PS2_CLK_S, PS2_DAT_S;      // synchronized versions of PS2 signals
    
    assign Resetn = KEY[0];

    sync S1 (PS2_CLK, Resetn, CLOCK_50, PS2_CLK_S);
    sync S2 (PS2_DAT, Resetn, CLOCK_50, PS2_DAT_S);

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
        
    // 'count' ps2 data bits
    always @(posedge CLOCK_50) begin    // specify a 34-bit shift register
        if (!Resetn || Packet == 'd11)
            Packet <= 'b0;
        else if (negedge_ps2_clk) begin
            Packet <= Packet + 'b1;
        end
    end
        
    // used to start an object move. Key press makes scancode/release/scancode, so we check
    // for Serial[30:23] == Serial[8:1]. Key repeat makes scancode/scancode/...
    assign ps2_rec = (Packet == 'd11) && (Serial[30:23] == Serial[8:1]);

    // ps2 scancode is in Serial[8:1]
    regn USC (Serial[8:1], Resetn, Esc, CLOCK_50, scancode);

    // display PS2 data
    hex7seg H0 (Serial[4:1], HEX0);
    hex7seg H1 (Serial[8:5], HEX1);
    hex7seg H2 (Serial[15:12], HEX2);
    hex7seg H3 (Serial[19:16], HEX3);
    hex7seg H4 (Serial[26:23], HEX4);
    hex7seg H5 (Serial[30:27], HEX5);

    always @ (*) 
        //scancode for space = 29
        if (!Resetn & ((scancode == 8'h29) | (KEY[1] == 1'b0)))
            obj_move = 1'b1;
        else
            obj_move = 1'b0;
    
endmodule

//implement a moving object that can be moved up with user input and falls continuously due to gravity
module player (Resetn, Clock, go, ps2_rec, dir, VGA_x, VGA_y, VGA_color, VGA_write, done);
    // specify the number of bits needed for an X (column) pixel coordinate on the VGA display
    parameter nX = 10;
    // specify the number of bits needed for a Y (row) pixel coordinate on the VGA display
    parameter nY = 9;
    // by default, use offsets to place the object on the left of the VGA display
    parameter XOFFSET = 160;
    parameter YOFFSET = 240;
    parameter xOBJ = 4, yOBJ = 4;   // object size is 2^xOBJ x 2^yOBJ
    parameter BOX_SIZE_X = 1 << xOBJ;
    parameter BOX_SIZE_Y = 1 << yOBJ;
    parameter Mn = xOBJ + yOBJ; // address lines needed for the object memory
    parameter INIT_FILE = "./MIF/object_mem_16_16_9.mif"
endmodule