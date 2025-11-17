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




`timescale 1ns/1ps

module random_tb;

    // Testbench signals
    reg        reset;
    reg        Clock;
    wire [7:0] seed;

    // Instantiate your DUT (Device Under Test)
    // If you want a different initial seed, change 8'd67 below.
    random #(.seedInitial(8'd67)) dut (
        .reset (reset),
        .Clock (Clock),
        .seed  (seed)
    );

    // Clock generator: 20 ns period (50 MHz equivalent)
    initial begin
        Clock = 1'b0;
        forever #10 Clock = ~Clock;
    end

    // Stimulus
    initial begin
        // Optional: initialize reset
        reset = 1'b1;
        #50;              // keep reset high for a bit

        reset = 1'b0;     // release reset, LFSR starts running

        // Let it run for some cycles
        #1000;

        $stop;            // stop simulation in ModelSim
    end

    // Monitoring
    initial begin
        $display(" time(ns)  reset  seed (dec)  seed (hex)");
        $monitor("%8t   %b      %3d       0x%0h",
                 $time, reset, seed, seed);
    end

endmodule
