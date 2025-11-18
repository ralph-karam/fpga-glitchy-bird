//for main

assign LEDR[0] = collision;



module collision(Resetn, Clock, player_x, player_y, top_h1, top_h2, top_h3, collsion);
  parameter player_H = 32;
  parameter player_W = 32;
  parameter GAP = 80; 
  
  input Resetn, Clock;
  input [:] player_x, player_y;

  output reg collision; 

  wire [:] player_top, player_bottom;
  wire [:] player_right;

  assign player_top = player_y + player_H >> 1;
  assign player_bottom = player_y - player_H >> 1;
  assign player_right = player_x + player_W >> 1;
  
  

  always @(posedge Clock)
    if (player_right == 

  
  


  
endmodule 
  
