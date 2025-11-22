
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
