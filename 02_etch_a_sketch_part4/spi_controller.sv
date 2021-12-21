`include "spi_types.sv"

module spi_controller(
  clk, rst, sclk, csb, mosi, miso,
  spi_mode, i_ready, i_valid, i_data, o_ready, o_valid, o_data,
  bit_counter
);

input wire clk, rst; // default signals.

// SPI Signals
output logic sclk; // Serial clock to secondary device.
output logic csb; // chip select bar, needs to go low at the start of any SPI transaction, then go high when done.
output logic mosi; // Main Out Secondary In (sends serial data to secondary device)
input wire miso; // Main In Secondary Out (receives serial data from secondary device)

// Control Signals
input spi_transaction_t spi_mode;
// Ready/valid handshake
output logic i_ready; // ready for use of incoming data
input wire i_valid; // check if incoming data is usable
input wire [15:0] i_data; // incoming data

input wire o_ready; // Unused for now.
output logic o_valid; // outgoing data is usable
output logic [23:0] o_data; // outgoing data
output logic unsigned [4:0] bit_counter; // the number of the current bit being transmit

// TX : transmitting
// RX: receiving
// question: is there a reason we can't TX & RX at the same time?
// as I understand it some SPI devices support this
enum logic [2:0] {S_IDLE, S_TXING, S_TX_DONE, S_RXING, S_RX_DONE, S_ERROR } state;

// Internal registers/counters
logic [15:0] tx_data;
logic [23:0] rx_data;

// Set Chip Select Bar low when tx/rx transaction in use, high when done or unused
always_comb begin : csb_logic
  case(state)
    S_IDLE, S_ERROR : csb = 1;
    // pull low during transaction
    S_TXING, S_TX_DONE, S_RXING, S_RX_DONE: csb = 0;
    default: csb = 1;
  endcase
end

// Determine serial data to send to secondary device based on tx
// this is a shift register
always_comb begin : mosi_logic
  mosi = tx_data[bit_counter[4:0]] & (state == S_TXING);
end

/*
This is going to be one of our more complicated FSMs. 
We need to sample inputs on the positive edge of sclk, but 
we also want to set outputs on the negative edge of the clk (it's
  the safest time to change an output given unknown peripheral
  setup/hold times).

To do this we are going to toggle sclk every cycle. We can then test
whether we are about to be on a negative edge or a positive edge by 
checking the current value of sclk. If it's 1, we're about to go negative,
so that's a negative edge.

*/
always_ff @(posedge clk) begin : spi_controller_fsm
  if(rst) begin
    state <= S_IDLE;
    sclk <= 0; // back to positive edge
    bit_counter <= 0;
    o_valid <= 0; // output is not useable yet
    i_ready <= 1; // ready to take in data
    tx_data <= 0; // reset
    rx_data <= 0;
    o_data <= 0;
  end else begin
    case(state)
      S_IDLE : begin
// SOLUTION START
        i_ready <= 1; //
        sclk <= 0;
        if(i_valid) begin
          tx_data <= i_data; // read in a bit
          rx_data <= 0;
          i_ready <= 0; // not ready anymore
          o_valid <= 0; // output still isn't useable yet
          state <= S_TXING; // start tx
          // Initialize our bit counter based on our spi mode. By initializing to a the terminal value and then counting down, we can get away with a single == comparator (instead of comparing to different values based on spi_mode)
          case (spi_mode) 
            WRITE_16 : bit_counter <= 5'd15;
            WRITE_8 : bit_counter <= 5'd7;
            default : bit_counter <= 5'd7;
          endcase
        end
// SOLUTION END
      end
      S_TXING : begin
        sclk <= ~sclk; // toggle sclk when txing
        // positive edge logic
        if(~sclk) begin // don't need to do anything on posedge
// SOLUTION START
// SOLUTION END
        end else begin // negative edge logic
          // update on negedge to be safe
          if(bit_counter != 0) begin
            bit_counter <= bit_counter - 1; // decrement
          end else begin
            state <= S_TX_DONE; // counter has reached 0, so buffer has been emptied
          end
        end
      end
      S_TX_DONE : begin
        // sclk <= ~sclk; //TODO@(avinash)
        // Next State Logic
        case (spi_mode) // move back to idle after completing TX
          WRITE_8, WRITE_16: begin
              state <= S_IDLE;
              i_ready <= 1;
          end
          default : state <= S_RXING;
        endcase
        // Bit Counter Reset Logic
        case (spi_mode) // same deal as with write, but here we're looking at the read buffer size
          WRITE_8_READ_8  : bit_counter <= 5'd7;
          WRITE_8_READ_16 : bit_counter <= 5'd15;
          WRITE_8_READ_24 : bit_counter <= 5'd23;
          default : bit_counter <= 0;
        endcase
      end
// SOLUTION START
      S_RXING : begin
        sclk <= ~sclk;
        if(~sclk) begin // positive edge logic
          if(bit_counter != 0) begin
            bit_counter <= bit_counter - 1; // decrement
          end else begin // done with RX
            o_data <= rx_data;
            o_valid <= 1; // ready to RX again
            state <= S_IDLE;
            i_ready <= 1; // This logic would have to change if we wanted to use o_ready.
          end
        end else begin // negative edge logic
          rx_data[bit_counter] <= miso;
        end
      end
// SOLUTION END
      default : state <= S_ERROR;
    endcase
  end
end

endmodule
