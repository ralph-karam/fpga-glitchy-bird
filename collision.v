//for main

  collision pair1(CLOCK_50, player_x, player_y, top_h1, x_top1, collsion1);
  collision pair2(CLOCK_50, player_x, player_y, top_h2, x_top3, collsion2);
  collision pair3(CLOCK_50, player_x, player_y, top_h2, x_top3, collsion3);

  assign LEDR[0] = collision;

module collision(Clock, player_x, player_y, top_h, x_top, collsion);
  parameter player_H = 32;
  parameter player_W = 32;
  parameter pillar_W = 50;
  parameter GAP = 80; 

  parameter player_right = 116; 
  parameter player_left = 84;
  
  input Clock;
  input [9:0] player_x;
  input [8:0] player_y;
  
  input [8:0] top_h1;
  input [9:0] x_top;

  output reg collision; 

  wire [8:0] player_top, player_bottom;

  assign player_top = player_y - player_H >> 1;
  assign player_bottom = player_y + player_H >> 1;

  always @(posedge Clock)
    if (x_top > player_left && x_top < player_right)
      if (top_h > player_top || top_h + GAP < player_bottom)
            collision <= 1'b1;
   else collision <= 1'b0;
  
endmodule 






// Bird vs one pillar pair (top + bottom)
module collision
#(
    parameter nX       = 10,
    parameter nY       = 9,
    parameter BIRD_W   = 32,   // bird width  in pixels
    parameter BIRD_H   = 32,   // bird height in pixels
    parameter PILLAR_W = 50    // pillar width (must match XDIM)
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
    // if bird is completely above gap or completely below gap -> collision
    wire above_gap = (player_bottom < top_h);
    wire below_gap = (player_y   >= btm_y);

    assign hit = overlap_x && (above_gap || below_gap);

endmodule




