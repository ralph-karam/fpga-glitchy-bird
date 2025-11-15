    // *** NEW *** update pillar heights when the top wraps
    always @(posedge CLOCK_50 or negedge Resetn) begin
        if (!Resetn) begin
            // some initial heights
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
            // when a top pillar wraps, pick a new height and recompute the bottom
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
