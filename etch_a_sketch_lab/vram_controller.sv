`timescale 1ns / 1ps
`default_nettype none
`include "ft6206_defines.sv"
`include "ili9341_defines.sv"

module vram_controller(
    clk,
    rst,
    touch,
    wr_ena,
    wr_addr,
    wr_data
);

parameter W = 8;  // Width of each row of the memory
parameter L = 32; // Length of the memory
parameter DISPLAY_HEIGHT = 320;
parameter DISPLAY_WIDTH = 240;

input wire                   clk;
input wire                   rst;
input touch_t                touch;
output logic [$clog2(L)-1:0] wr_addr;
output logic                 wr_ena;
output ILI9341_color_t       wr_data;

/*
VRAM control FSM for handling reset. An assertion of rst causes the memory to be cleared, after which the state transitions
to active. The active state is never reached until after an assertion of reset, and it does not leave the active state until
the next assertion of rst.
*/
enum logic {S_VRAM_CLEARING, S_VRAM_ACTIVE } vram_state;
logic [$clog2(L)-1:0] ram_reset_counter;

always_ff @( posedge clk ) begin : vram_controller_fsm
    if (rst) begin
        vram_state <= S_VRAM_CLEARING;
        ram_reset_counter <= 0;
    end else begin
        if (vram_state == S_VRAM_CLEARING) begin
            if (ram_reset_counter < L) begin
                ram_reset_counter = ram_reset_counter + 1;
            end else begin
                vram_state <= S_VRAM_ACTIVE;
            end
        end
    end
end

/*
VRAM control combinational logic for driving wr_addr and wr_data. Clear the data to black (meaning that the background color
is set to be black). Use WHITE as the pixel being drawn.
*/
always_comb begin : vram_controller_comb_wr_addr_data
    if (vram_state == S_VRAM_CLEARING) begin
        wr_addr = ram_reset_counter;
        wr_data = BLUE;
    end else if (touch.valid && vram_state == S_VRAM_ACTIVE) begin
        // Use VRAM storage as a row-major array representing the pixels.
        wr_addr = touch.y * DISPLAY_WIDTH + touch.x;
        wr_data = WHITE;
    end else begin
        // Use default values - does not matter because wr_ena should be 0
        wr_addr = 0;
        wr_data = wr_data.first;
    end
end

/*
VRAM control combinational logic for driving. Only assert wr_ena when clearing or when active and a touch is registered.
*/
always_comb begin : vram_controller_comb_wr_ena;
    case (vram_state)
        S_VRAM_CLEARING: begin
            wr_ena  = 1'b1;
        end
        S_VRAM_ACTIVE: begin
            if (touch.valid) begin
                wr_ena = 1'b1;
            end else begin
                wr_ena  = 1'b0;
            end
        end
        default: wr_ena = 1'b0;
    endcase
end

endmodule