
// Sweep the whole screen once when we enter PLAY (KEY2 pressed)
always @(posedge CLOCK_50 or negedge Resetn) begin
    if (!Resetn) begin
        clearing_play <= 1'b0;
        clear_x       <= {nX{1'b0}};
        clear_y       <= {nY{1'b0}};
    end
    else begin
        // Start a full-screen clear when KEY2 is pressed in GS_START
        if (start_press && (game_state == GS_START)) begin
            clearing_play <= 1'b1;
            clear_x       <= {nX{1'b0}};
            clear_y       <= {nY{1'b0}};
        end
        else if (clearing_play) begin
            // x = 0 .. XSCREEN-1, y = 0 .. YSCREEN-1
            if (clear_x == XSCREEN-1) begin
                clear_x <= {nX{1'b0}};
                if (clear_y == YSCREEN-1) begin
                    clear_y       <= {nY{1'b0}};
                    clearing_play <= 1'b0;  // done clearing
                end
                else begin
                    clear_y <= clear_y + 1'b1;
                end
            end
            else begin
                clear_x <= clear_x + 1'b1;
            end
        end
    end
end
