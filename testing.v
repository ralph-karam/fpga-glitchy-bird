// top1
object top1 (Resetn, CLOCK_50, gnt_top1, req_top1,
             9'd0, top_h1,              // Y_init, Y_dim
             x_top1, y_top1, color_top1, write_top1,
             wrap_top1);
    defparam top1.nX    = nX;
    defparam top1.nY    = nY;
    defparam top1.COLOR = 9'b000_111_000;

// btm1
object btm1 (Resetn, CLOCK_50, gnt_btm1, req_btm1,
             btm_y1, btm_h1,             // Y_init, Y_dim
             x_btm1, y_btm1, color_btm1, write_btm1,
             wrap_btm1);
    defparam btm1.nX     = nX;
    defparam btm1.nY     = nY;
    defparam btm1.X_INIT = 10'd620;
    // defparam btm1.Y_INIT = 9'd280;   // no longer needed
    defparam btm1.COLOR  = 9'b000_111_000;

// top2
object top2 (Resetn, CLOCK_50, gnt_top2, req_top2,
             9'd0, top_h2,              // Y_init, Y_dim
             x_top2, y_top2, color_top2, write_top2,
             wrap_top2);
    defparam top2.nX     = nX;
    defparam top2.nY     = nY;
    defparam top2.X_INIT = 10'd420;
    defparam top2.COLOR  = 9'b000_000_111;

// btm2
object btm2 (Resetn, CLOCK_50, gnt_btm2, req_btm2,
             btm_y2, btm_h2,             // Y_init, Y_dim
             x_btm2, y_btm2, color_btm2, write_btm2,
             wrap_btm2);
    defparam btm2.nX     = nX;
    defparam btm2.nY     = nY;
    defparam btm2.X_INIT = 10'd420;
    // defparam btm2.Y_INIT = 9'd280;   // no longer needed
    defparam btm2.COLOR  = 9'b000_000_111;

// top3
object top3 (Resetn, CLOCK_50, gnt_top3, req_top3,
             9'd0, top_h3,              // Y_init, Y_dim
             x_top3, y_top3, color_top3, write_top3,
             wrap_top3);
    defparam top3.nX     = nX;
    defparam top3.nY     = nY;
    defparam top3.X_INIT = 10'd220;
    defparam top3.COLOR  = 9'b111_000_000;

// btm3
object btm3 (Resetn, CLOCK_50, gnt_btm3, req_btm3,
             btm_y3, btm_h3,             // Y_init, Y_dim
             x_btm3, y_btm3, color_btm3, write_btm3,
             wrap_btm3);
    defparam btm3.nX     = nX;
    defparam btm3.nY     = nY;
    defparam btm3.X_INIT = 10'd220;
    // defparam btm3.Y_INIT = 9'd280;   // no longer needed
    defparam btm3.COLOR  = 9'b111_000_000;
