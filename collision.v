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
  
  input Resetn, Clock;
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
  
