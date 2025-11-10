module random #(parameter seedInitial = 8'd67) (reset, Clock, seed);
    input reset;
    input Clock;
    output reg [7:0] seed;

    wire next;
    assign next = seed[7] ^ seed[5] ^ seed[4] ^ seed[3];

    always @(posedge Clock) begin
        if (reset) begin
            seed <= seedInitial;
        end else begin
            seed <= {seed[6:0], next};
        end
    end
endmodule
