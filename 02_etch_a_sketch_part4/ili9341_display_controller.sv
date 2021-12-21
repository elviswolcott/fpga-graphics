`include "ili9341_defines.sv"
`include "spi_types.sv"
`include "ft6206_defines.sv"

/*
Display controller for the ili9341 chip on Adafruit's breakout baord.
Based on logic from: https://github.com/adafruit/Adafruit_ILI9341

*/

/*
The display controller first sends the init sequence from ROM to the display.
Then, it scans through the pixels and sends the pixel value from ROM.
It also paints a cursor on top.
*/

module ili9341_display_controller(
  clk, rst, ena, display_rstb,
  interface_mode,
  spi_csb, spi_clk, spi_mosi, spi_miso, data_commandb,
  vsync, hsync,
  touch,
  vram_rd_addr, vram_rd_data
);

parameter CLK_HZ = 12_000_000; // aka ticks per second
parameter DISPLAY_WIDTH = 240; // width of display in pixels
parameter DISPLAY_HEIGHT = 320; // height of display in pixels
parameter VRAM_L = (DISPLAY_HEIGHT*DISPLAY_WIDTH) / 4; // length, used for address of each pixel
parameter CFG_CMD_DELAY = CLK_HZ*150/1000; // wait 150ms after certain configuration commands
parameter ROM_LENGTH=125; // Set this based on the output of generate_memories.py

input wire clk, rst, ena;
output logic display_rstb; // Need a separate value because the display has an opposite reset polarity.
always_comb display_rstb = ~rst; // Fix the active low reset

// SPI Interface
// this will go into our spi_controller
output logic spi_csb, spi_clk, spi_mosi;
input wire spi_miso;

// Sets the mode (many parallel and serial options, see page 10 of the datasheet).
output logic [3:0] interface_mode;
always_comb interface_mode = 4'b1110; // Standard SPI 8-bit mode is 4'b1110.

output logic data_commandb; // Set to 1 to send data, 0 to send commands. Read as Data/Command_Bar

// currently unused, would be useful if adapting to some analog standards that use vsync/hsync
output logic vsync; // Should combinationally be high for one clock cycle when drawing the last pixel (239,319)
output logic hsync; // Should combinationally be high for one clock cycle when drawing the last pixel of any row (x = 239).

input touch_t touch; // Current touch event. 

// display controller takes VRAM data and paints it to the display
input [7:0] vram_rd_data; // VRAM rd data
output logic [$clog2(VRAM_L)-1:0] vram_rd_addr; // VRAM rd addr.

ILI9341_color_t vram_rd_color;

color_decompress DECOMPRESSOR(.compressed(vram_rd_data), .color(vram_rd_color));

// SPI Controller that talks to the ILI9341 chip
// spi controller takes care of the lower level stuff
spi_transaction_t spi_mode;
wire i_ready;
logic i_valid;
logic [15:0] i_data;
logic o_ready;
wire o_valid;
wire [23:0] o_data;
wire [4:0] spi_bit_counter;
spi_controller SPI0(
    .clk(clk), .rst(rst), 
    .sclk(spi_clk), .csb(spi_csb), .mosi(spi_mosi), .miso(spi_miso),
    .spi_mode(spi_mode), .i_ready(i_ready), .i_valid(i_valid), .i_data(i_data),
    .o_ready(o_ready), .o_valid(o_valid), .o_data(o_data),
    .bit_counter(spi_bit_counter)
);

// ROM that stores the configuration sequence the display needs
wire [7:0] rom_data;
logic [$clog2(ROM_LENGTH)-1:0] rom_addr;
// initalize a ROM with the sequence so that it is available on the FPGA
block_rom #(.INIT("memories/ili9341_init.memh"), .W(8), .L(ROM_LENGTH)) ILI9341_INIT_ROM (
  .clk(clk), .addr(rom_addr), .data(rom_data)
);


// Main FSM
enum logic [2:0] {
  S_INIT = 0, // send the sequence from ROM
  S_INCREMENT_PIXEL = 1, // used while painting a frame
  S_START_FRAME = 2, // start a new frame
  S_TX_PIXEL_DATA_START = 3, // rest are just related to SPI state, self explanatory
  S_TX_PIXEL_DATA_BUSY = 4,
  S_WAIT_FOR_SPI = 5,
  S_ERROR //very useful for debugging
} state, state_after_wait;

// Configuration FSM
// for sending init sequence
enum logic [2:0] {
  S_CFG_GET_DATA_SIZE = 0,
  S_CFG_GET_CMD = 1,
  S_CFG_SEND_CMD = 2,
  S_CFG_GET_DATA = 3,
  S_CFG_SEND_DATA = 4,
  S_CFG_SPI_WAIT = 5,
  S_CFG_MEM_WAIT = 6,
  S_CFG_DONE
} cfg_state, cfg_state_after_wait;

ILI9341_color_t pixel_color; // color to paint
// splitting into x,y lets us to some logic that would be much harder treating the memory as just a single line
logic [$clog2(DISPLAY_WIDTH):0] pixel_x; // pixel to paint
logic [$clog2(DISPLAY_HEIGHT):0] pixel_y;

ILI9341_register_t current_command;

// Comb. outputs
/* Note - it's pretty critical that you keep always_comb blocks small and separate.
   there's a weird order of operations that can mess up your synthesis or simulation.  
*/

// i_valid is high while sending pixels or config
always_comb case(state)
  S_START_FRAME, S_TX_PIXEL_DATA_START : i_valid = 1;
  S_INIT : begin
    case(cfg_state)
      S_CFG_SEND_CMD, S_CFG_SEND_DATA: i_valid = 1;
      default: i_valid = 0;
    endcase
  end
  default: i_valid = 0;
endcase

// when starting a frame tell the display we are sending values to memory
always_comb case (state) 
  S_START_FRAME : current_command = RAMWR;
  default : current_command = NOP;
endcase

always_comb case(state)
  S_INIT: i_data = {8'd0, rom_data}; // send config data
  S_START_FRAME: i_data = {8'd0, current_command}; // send the RAMWR command
  default: i_data = pixel_color; // send the current pixel color (while painting a frame)
endcase

// set SPI size
always_comb case (state)
  S_INIT, S_START_FRAME: spi_mode = WRITE_8;
  default : spi_mode = WRITE_16;
endcase

// set h/v sync pixels at the end of row and columns
always_comb begin
  hsync = pixel_x == (DISPLAY_WIDTH-1);
  vsync = hsync & (pixel_y == (DISPLAY_HEIGHT-1));
end



// Show cursor when touching screen
always_comb begin  : draw_cursor_logic
  // basically going rshift division here to make a square
  if(touch.valid & (touch.x[8:2] == pixel_x[8:2]) 
    & (touch.y[8:2] == pixel_y[8:2])) begin
    pixel_color = BLACK;
  end else begin
    // read appropriate value from RAM
    vram_rd_addr = (pixel_x >> 1) + ((pixel_y >> 1)*(DISPLAY_WIDTH>>1));
    pixel_color = vram_rd_color;
  end
end

// buffer and counter for reading config ROM
logic [$clog2(CFG_CMD_DELAY):0] cfg_delay_counter;
logic [7:0] cfg_bytes_remaining;

always_ff @(posedge clk) begin : main_fsm
  if(rst) begin
    state <= S_INIT; // send the config first
    cfg_state <= S_CFG_GET_DATA_SIZE;
    cfg_state_after_wait <= S_CFG_GET_DATA_SIZE;
    cfg_delay_counter <= 0;
    state_after_wait <= S_INIT;
    pixel_x <= 0; // reset
    pixel_y <= 0;
    rom_addr <= 0;
    data_commandb <= 1;
  end
  else if(ena) begin
    case (state)
      S_INIT: begin
        // send config data over from ROM
        // all of this is just dealing with the config ROM
        case (cfg_state)
          S_CFG_GET_DATA_SIZE : begin
            cfg_state_after_wait <= S_CFG_GET_CMD;
            cfg_state <= S_CFG_MEM_WAIT;
            rom_addr <= rom_addr + 1; // move through ROM
            case(rom_data) 
              8'hFF: begin
                cfg_bytes_remaining <= 0;
                cfg_delay_counter <= CFG_CMD_DELAY;
              end
              8'h00: begin
                // done sending (NULL byte)
                cfg_bytes_remaining <= 0;
                cfg_delay_counter <= 0;
                cfg_state <= S_CFG_DONE;
              end
              default: begin
                cfg_bytes_remaining <= rom_data;
                cfg_delay_counter <= 0;
              end
            endcase
          end
          S_CFG_GET_CMD: begin
            // after getting a command send it
            cfg_state_after_wait <= S_CFG_SEND_CMD;
            cfg_state <= S_CFG_MEM_WAIT; // wait for read
          end
          S_CFG_SEND_CMD : begin
            // send a command
            data_commandb <= 0;
            if(rom_data == 0) begin
              cfg_state <= S_CFG_DONE;
            end else begin
              cfg_state <= S_CFG_SPI_WAIT;
              cfg_state_after_wait <= S_CFG_GET_DATA;
            end
          end
          S_CFG_GET_DATA: begin
            // get data from the memory
            data_commandb <= 1;
            rom_addr <= rom_addr + 1; // incriment command
            if(cfg_bytes_remaining > 0) begin
              cfg_state_after_wait <= S_CFG_SEND_DATA;
              cfg_state <= S_CFG_MEM_WAIT; // wait for memory read
              cfg_bytes_remaining <= cfg_bytes_remaining - 1;
            end else begin
              cfg_state_after_wait <= S_CFG_GET_DATA_SIZE;
              cfg_state <= S_CFG_MEM_WAIT; // wait for memory read
            end
          end
          S_CFG_SEND_DATA: begin
            // send data to the memory
            cfg_state_after_wait <= S_CFG_GET_DATA;
            cfg_state <= S_CFG_SPI_WAIT;
          end
          S_CFG_DONE : begin
            // ready to paint frames
            state <= S_START_FRAME;
          end
          S_CFG_SPI_WAIT : begin
            // wait for SPI transaction
            if(cfg_delay_counter > 0) cfg_delay_counter <= cfg_delay_counter-1;
            else if (i_ready) begin
               cfg_state <= cfg_state_after_wait;
               cfg_delay_counter <= 0;
               data_commandb <= 1;
            end
          end
          S_CFG_MEM_WAIT : begin
            // If you had a memory with larger or unknown latency you would put checks in this state to wait till the data was ready.
            cfg_state <= cfg_state_after_wait;
          end
          default: cfg_state <= S_CFG_DONE;
        endcase
      end
      S_WAIT_FOR_SPI: begin
        if(i_ready) begin
          // wait for SPI transaction
          state <= state_after_wait;
        end
      end
      S_START_FRAME: begin
        data_commandb <= 0;
        state <= S_WAIT_FOR_SPI;
        state_after_wait <= S_TX_PIXEL_DATA_START; // next start sending pixels
      end
      S_TX_PIXEL_DATA_START: begin
        data_commandb <= 1;
        state_after_wait <= S_INCREMENT_PIXEL; // iterate through pixels
        state <= S_WAIT_FOR_SPI;
      end
      S_TX_PIXEL_DATA_BUSY: begin
        if(i_ready) state <= S_INCREMENT_PIXEL; // wait for ready signal
      end
      S_INCREMENT_PIXEL: begin
        // move through vertical and horizontal lines
        state <= S_TX_PIXEL_DATA_START;
        if(pixel_x < (DISPLAY_WIDTH-1)) begin
          pixel_x <= pixel_x + 1;
        end else begin
          pixel_x <= 0;
          if (pixel_y < (DISPLAY_HEIGHT-1)) begin
            pixel_y <= pixel_y + 1;
          end else begin
            pixel_y <= 0;
            state <= S_START_FRAME;
          end
        end
      end
      default: begin
        // error state
        state <= S_ERROR;
        pixel_y <= -1;
        pixel_x <= -1;
      end
    endcase
  end
end

endmodule