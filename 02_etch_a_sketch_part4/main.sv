`default_nettype none

/*
  Etch-a-sketch lab: Part 2: Touch input.
*/

`include "ft6206_defines.sv"
`include "ili9341_defines.sv"

module main(
  // On board signals
  sysclk, buttons, leds, rgb, pmod,
  // Display signals
  interface_mode,
  touch_i2c_scl, touch_i2c_sda, touch_irq,
  backlight, display_rstb, data_commandb,
  display_csb, spi_mosi, spi_miso, spi_clk
);
parameter SYS_CLK_HZ = 12_000_000.0; // aka ticks per second
parameter SYS_CLK_PERIOD_NS = (1_000_000_000.0/SYS_CLK_HZ);
parameter CLK_HZ = 5*SYS_CLK_HZ; // aka ticks per second
parameter CLK_PERIOD_NS = (1_000_000_000.0/CLK_HZ); // Approximation.
parameter PWM_PERIOD_US = 100; 
parameter PWM_WIDTH = $clog2(320);
parameter PERIOD_MS_FADE = 100;
parameter PWM_TICKS = CLK_HZ*PWM_PERIOD_US/1_000_000; //1kHz modulation frequency. // Always multiply before dividing, it avoids truncation.
parameter human_divider = 23; // A clock divider parameter - 12 MHz / 2^23 is about 1 Hz (human visible speed).
parameter DISPLAY_WIDTH = 240;
parameter DISPLAY_HEIGHT = 320;
parameter LAYER_WIDTH = 296;
parameter LAYER_HEIGHT = 120;
parameter LAYER_L = LAYER_WIDTH * LAYER_HEIGHT;
parameter BUFFER_WIDTH = 160;
parameter BUFFER_HEIGHT = 120;
parameter VRAM_L = BUFFER_WIDTH * BUFFER_HEIGHT;
// using compressed colors reduces the BRAM usage
// colors have to be decompressed before sending
// try to find 8 bit assets to prevent color loss!
parameter VRAM_W = 8;
parameter ILI9341_color_t VRAM_CLEAR = WHITE; // clear base color


//Module I/O and parameters
input wire sysclk;
wire clk;
input wire [1:0] buttons;
logic rst; always_comb rst = buttons[0]; // Use button 0 as a reset signal.
output logic [1:0] leds;
output logic [2:0] rgb;
output logic [7:0] pmod;  always_comb pmod = {6'b0, sysclk, clk}; // You can use the pmod port for debugging!

// Display driver signals
output wire [3:0] interface_mode;
output wire touch_i2c_scl;
inout wire touch_i2c_sda;
input wire touch_irq;
output wire backlight, display_rstb, data_commandb;
output wire display_csb, spi_clk, spi_mosi;
input wire spi_miso;

ILI9341_color_t vram_wr_color;

// Pixel color to draw with
ILI9341_color_t draw_color;
//always_comb draw_color = BLACK; // Default color to black

// Create a faster clock using internal PLL hardware.
`ifdef SIMULATION
assign clk = sysclk;
`else 
wire clk_feedback;
MMCME2_BASE #(
  .BANDWIDTH("OPTIMIZED"),
  .CLKFBOUT_MULT_F(64.0), //2.0 to 64.0 in increments of 0.125
  .CLKIN1_PERIOD(SYS_CLK_PERIOD_NS),
  .CLKOUT0_DIVIDE_F(12.5), // Divide amount for CLKOUT0 (1.000-128.000).
  .DIVCLK_DIVIDE(1), // Master division value (1-106)
  .CLKOUT0_DUTY_CYCLE(0.5),.CLKOUT0_PHASE(0.0),
  .STARTUP_WAIT("FALSE") // Delays DONE until MMCM is locked (FALSE, TRUE)
)
MMCME2_BASE_inst (
.CLKOUT0(clk),
.CLKIN1(sysclk),
.PWRDWN(0),
.RST(buttons[1]),
.CLKFBOUT(clk_feedback),
.CLKFBIN(clk_feedback)
// .CLKFBIN(CLKFBIN) // 1-bit input: Feedback clock
);
// End
`endif // SIMULATION


// Touch signals
touch_t touch0, touch1;

// Video RAM signals
wire [$clog2(VRAM_L)-1:0] vram_rd_addr;
logic [$clog2(VRAM_L)-1:0] vram_wr_addr, vram_clear_counter, image_rd_addr;
logic vram_wr_ena;
wire [7:0] vram_rd_data;
logic [7:0] vram_wr_data;
enum logic {S_VRAM_CLEARING, S_VRAM_ACTIVE } vram_state;

// the vram/frame buffer is what the display controller draws from
// we can paint into it and trust that it will show up on screen
// it is ordered by collumn
block_ram #(.W(VRAM_W), .L(VRAM_L), .INIT("memories/layer0.memh")) VRAM(
  .clk(clk), .rd_addr(vram_rd_addr), .rd_data(vram_rd_data),
  .wr_ena(vram_wr_ena), .wr_addr(vram_wr_addr), .wr_data(vram_wr_data)
);

wire [7:0] image_data; // data out from ROM
// shadows the wr_addr for reseting 
block_rom #(.INIT("memories/dots.memh"), .W(VRAM_W), .L(VRAM_L)) IMAGE_ROM (
  .clk(clk), .addr(image_rd_addr), .data(image_data)
);

debouncer #(.BOUNCE_TICKS(8)) DEBOUNCER(sysclk, rst, buttons[1], leds[0]);

led_example #(.BOUNCE_TICKS(8)) LED_STATE_MACHINE(sysclk, rst, buttons[1], rgb_inv[0], rgb_inv[1], rgb_inv[2], draw_color);

logic [2:0] rgb_inv;
always_comb rgb = ~rgb_inv;

logic [$clog2(DISPLAY_WIDTH)-1:0] vram_x; // pixel to paint
logic [$clog2(DISPLAY_HEIGHT)-1:0] vram_y;

// Put appropriate RAM clearing logic here!
always_ff @(posedge clk) begin : ramClear
  if(rst) begin
    // set state to start clearing
    vram_clear_counter <= 0; // start over counter
    vram_x <= 0;
    vram_y <= 0;
    vram_state <= S_VRAM_CLEARING;
  end
  else if(vram_clear_counter >= VRAM_L) begin
    // set state to stop clearing
    vram_state <= S_VRAM_ACTIVE;
  end
  // counter logic
  if(vram_state == S_VRAM_CLEARING) begin
    vram_clear_counter++; // add new time to be address 
    // x and y helps do address translation
    if(vram_x < ((DISPLAY_WIDTH>>1)-1)) begin
      vram_x <= vram_x + 1;
    end else begin
      vram_x <= 0;
      if (vram_y < ((DISPLAY_HEIGHT>>1)-1)) begin
        vram_y <= vram_y + 1;
      end else begin
        vram_y <= 0;
        vram_state <= S_VRAM_ACTIVE;
      end
    end
  end
end

// Draw on or clear the screen based on vram_state
always_comb begin : vramClearDraw
  // clear the screen
  if(vram_state == S_VRAM_CLEARING) begin
    //vram_wr_ena = 1;
    vram_wr_ena = 0;
    //image_rd_addr = vram_x + (vram_y * (DISPLAY_WIDTH >> 1));
    image_rd_addr = vram_y + (vram_x * (DISPLAY_HEIGHT >> 1));
    vram_wr_addr = vram_y + (vram_x * (DISPLAY_HEIGHT >> 1));
    //vram_wr_data = image_data;
  end
  else if (touch0.valid) begin
    // write on screen when touch detected
    vram_wr_ena = 1;
    vram_wr_addr = touch0.x + (touch0.y*DISPLAY_WIDTH);
    //vram_wr_color = draw_color;
  end
end


assign backlight = 1;
ili9341_display_controller ILI9341(
  .clk(clk), .rst(rst), .ena(1'b1), .display_rstb(display_rstb), .interface_mode(interface_mode),
  .spi_csb(display_csb), .spi_clk(spi_clk), .spi_mosi(spi_mosi), .spi_miso(spi_miso),
  .data_commandb(data_commandb),
  .touch(touch0),
  .vram_rd_addr(vram_rd_addr),
  .vram_rd_data(vram_rd_data)
);

// Some useful timing signals. //TODO@(avinash) - move to a different module or use a generate to save space here...
wire step_1Hz;
pulse_generator #(.N($clog2(CLK_HZ/1))) PULSE_1Hz (
  .clk(clk), .rst(rst), .ena(1'b1), .out(step_1Hz),
  .ticks(CLK_HZ/1)
);

wire step_10Hz;
pulse_generator #(.N($clog2(CLK_HZ/10))) PULSE_10Hz (
  .clk(clk), .rst(rst), .ena(1'b1), .out(step_10Hz),
  .ticks(CLK_HZ/10)
);

wire step_100Hz;
pulse_generator #(.N($clog2(CLK_HZ/100))) PULSE_100Hz (
  .clk(clk), .rst(rst), .ena(1'b1), .out(step_100Hz),
  .ticks(CLK_HZ/100)
);


// capacitive touch controller
ft6206_controller #(.CLK_HZ(CLK_HZ), .I2C_CLK_HZ(100_000)) FT6206(
  .clk(clk), .rst(rst), .ena(1'b1), // step_100Hz),
  .scl(touch_i2c_scl), .sda(touch_i2c_sda),
  .touch0(touch0), .touch1(touch1)
);

// LED PWM logic.
logic [PWM_WIDTH-1:0] led_pwm0, led_pwm1;
always @(posedge clk) begin
  if(rst) begin
    led_pwm0 <= 0;
    led_pwm1 <= 0;
  end else begin
    if(touch0.valid) begin
      led_pwm0 <= touch0.x;
      led_pwm1 <= touch0.y;
    end
    else begin
      led_pwm0 <= 0;
      led_pwm0 <= 1;
    end
  end
end

always_comb begin : blockName
  leds[1] = buttons[1];
end

/*
pwm #(.N(PWM_WIDTH)) PWM_LED0 (
  .clk(clk), .rst(rst), .ena(1'b1), .step(1'b1), .duty(led_pwm0),
  .out(leds[0])
);

pwm #(.N(PWM_WIDTH)) PWM_LED1 (
  .clk(clk), .rst(rst), .ena(1'b1), .step(1'b1), .duty(led_pwm1),
  .out(leds[1])
);
*/

endmodule

`default_nettype wire // reengages default behaviour, needed when using 
                      // other designs that expect it.