`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Muddassir Ali

// Module Name: top_fsm_system
// Project Name: Counter
// Target Devices: Basys 3
// 
//////////////////////////////////////////////////////////////////////////////////

module top_fsm_system (
    input wire clk,
    input wire pbin,
    input wire [15:0] physical_sw,
    output wire [15:0] physical_leds
);

    // DEBOUNCER (Cleans up the physical reset button signal)
    wire rst_clean;
    wire [31:0] switch_data; // hold the value read from the switches
    reg [31:0] led_write_data = 32'd0; // counter value here
    wire slow_clk;
  
    debouncer rst_db (
        .clk(clk),
        .pbin(pbin), 
        .pbout(rst_clean)    // generated a clean signal
    ); 

    leds switch_reader (
        .clk(clk), 
        .rst(rst_clean),
        .btns(16'd0),            // Not used for this FSM
        .writeData(32'd0),       // We don't write to switches
        .writeEnable(1'b0),      // Disabled
        .readEnable(1'b1),       // Always ON so we can monitor switches
        .memAddress(30'd0),       
        .switches(physical_sw),  // Plug in the physical switches
        .readData(switch_data)   // output data 
    );
    
    switches led_writer (
        .clk(clk), 
        .rst(rst_clean),
        .writeData(led_write_data),
        .writeEnable(1'b1),         // Always ON so LEDs update instantly
        .readEnable(1'b0), 
        .memAddress(30'd0),
        .readData(),                // Ignored
        .leds(physical_leds)      
    );
    
    clock_divider ticker (
        .clk_in(clk),               // Feed it the 100MHz fast clock
        .rst(rst_clean),            // Feed it the clean reset signal
        .clk_out(slow_clk)          // It spits out the 1Hz slow clock!
    );


    // State Encoding
    localparam WAIT_INPUT = 2'b00;
    localparam COUNTDOWN  = 2'b01;
    localparam DONE       = 2'b10;

    reg [1:0] current_state, next_state;
    reg [15:0] counter;

    // 1. State Register (Sequential Logic on slow 1Hz Clock)
    always @(posedge slow_clk or posedge rst_clean) begin
        if (rst_clean)
            current_state <= WAIT_INPUT;
        else
            current_state <= next_state;
    end

    // 2. Next-State Combinational Logic
    always @(*) begin
        case (current_state)
            WAIT_INPUT: begin
                // Check if any switch is flipped (non-zero input)
                if (switch_data[15:0] != 16'b0)
                    next_state = COUNTDOWN;
                else
                    next_state = WAIT_INPUT;
            end

            COUNTDOWN: begin
                // Transition to DONE when counter reaches 1 (so next step hits 0)
                if (counter == 16'd1)
                    next_state = DONE;
                else
                    next_state = COUNTDOWN;
            end

            DONE: begin
                // Transient state: automatically return to waiting for input
                next_state = WAIT_INPUT;
            end

            default: next_state = WAIT_INPUT;
        endcase
    end

    // 3. Counter Register & LED Output Drive (Sequential Logic on slow 1Hz Clock)
    always @(posedge slow_clk or posedge rst_clean) begin
        if (rst_clean) begin
            counter        <= 16'd0;
            led_write_data <= 32'd0;
        end else begin
            case (current_state)
                WAIT_INPUT: begin
                    if (switch_data[15:0] != 16'b0) begin
                        // Latch the switch value into the counter and LEDs
                        counter        <= switch_data[15:0];
                        led_write_data <= {16'd0, switch_data[15:0]};
                    end else begin
                        counter        <= 16'd0;
                        led_write_data <= 32'd0;
                    end
                end

                COUNTDOWN: begin
                    // Decrement counter and update LED output display
                    counter        <= counter - 1'b1;
                    led_write_data <= {16'd0, counter - 1'b1};
                end

                DONE: begin
                    // Clear registers on completion
                    counter        <= 16'd0;
                    led_write_data <= 32'd0;
                end

                default: begin
                    counter        <= 16'd0;
                    led_write_data <= 32'd0;
                end
            endcase
        end
    end

endmodule