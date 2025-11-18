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



// ADD THESE TWO LINES:
output wire [nX-1:0] bird_x;
output wire [nY-1:0] bird_y;



// NEW: expose bird's top-left position for collision logic
    assign bird_x = X - (size_x >> 1);  // X is center → convert to left edge
    assign bird_y = Y - (size_y >> 1);  // Y is center → convert to top edge








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
    // SAFE region: bird strictly inside gap, not touching edges
    //   player_y      >  top_h    (top of bird below gap's top edge)
    //   player_bottom <  btm_y    (bottom of bird above gap's bottom edge)
    wire inside_gap_top_ok    = (player_y      >  top_h);
    wire inside_gap_bottom_ok = (player_bottom <  btm_y);
    wire inside_gap           = inside_gap_top_ok && inside_gap_bottom_ok;

    // collision if horizontally overlapping AND NOT safely inside gap
    // i.e. touching or crossing top_h or btm_y
    assign hit = overlap_x && ~inside_gap;

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

