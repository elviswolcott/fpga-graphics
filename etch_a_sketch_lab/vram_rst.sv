module vram_rst(clk, rst, vram_wr_ena, vram_wr_addr, vram_wr_data, draw_ena);
parameter L = 32; // Length for the memory
parameter W = 8;
parameter ILI9341_color_t VRAM_CLEAR = BLACK;

input wire clk, rst;
output logic [$clog2(L)-1:0] vram_wr_addr;
output logic vram_wr_ena, draw_ena;
output ILI9341_color_t vram_wr_data;

enum logic {S_VRAM_CLEARING, S_VRAM_ACTIVE } vram_state;
logic [$clog2(L)-1:0]  vram_clear_counter;



always_ff @( posedge clk ) begin : ramClear
  if (rst) begin
    // start clearing RAM
    vram_state <= S_VRAM_CLEARING;
    vram_clear_counter <= 0;
    //cursor <= GREEN;
    //vram_wr_data <= GREEN;
  end else if (vram_clear_counter >= L) begin
    // stop clearing, task complete
    vram_state <= S_VRAM_ACTIVE;
  end

  // counter logic
  if (vram_state == S_VRAM_CLEARING) begin
    vram_clear_counter++;
    //vram_wr_addr <= vram_clear_counter;
    //vram_wr_ena <= 1;
  end
end


always_comb begin : vramCleanInputs
  if (vram_state == S_VRAM_CLEARING) begin
    // enable while clearing
    vram_wr_ena = 1;
    draw_ena = 0;

    // address is just the counter
    vram_wr_addr = vram_clear_counter;

    // clear the address
    vram_wr_data = VRAM_CLEAR;
  end else begin
    draw_ena = 1;
  end
end
endmodule
