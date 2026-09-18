`timescale 1ns / 1ps

module tb_top_fsm_system;

    // Inputs
    reg clk;
    reg pbin;
    reg [15:0] physical_sw;

    // Outputs
    wire [15:0] physical_leds;

    // Instantiate the Unit Under Test (UUT)
    top_fsm_system uut (
        .clk(clk),
        .pbin(pbin),
        .physical_sw(physical_sw),
        .physical_leds(physical_leds)
    );

    // Clock Generation (100 MHz System Clock -> 10ns period)
    always #5 clk = ~clk;

    initial begin
        // Initialize Inputs
        clk = 0;
        pbin = 0;
        physical_sw = 16'h0000;

        // 1. Apply Reset
        #100;
        pbin = 1; // Assert reset button
        #100;
        pbin = 0; // De-assert reset button
        #100;

        // 2. Set Switches to 3 (binary 16'h0003) to trigger COUNTDOWN
        physical_sw = 16'h0003;
        #200;

        // 3. Change switches while counting down (Verify switch lockout)
        physical_sw = 16'h00FF; // FSM should IGNORE this change during countdown
        
        // Wait long enough for the slow clock ticks to run the countdown down to 0
        #5000;

        // 4. Return switches to 0
        physical_sw = 16'h0000;
        #500;

        // 5. Test Mid-Countdown Reset Functionality
        physical_sw = 16'h0005; // Trigger new countdown from 5
        #1000;
        pbin = 1;               // Press reset mid-countdown
        #100;
        pbin = 0;
        physical_sw = 16'h0000;

        #500;
        $finish;
    end

endmodule