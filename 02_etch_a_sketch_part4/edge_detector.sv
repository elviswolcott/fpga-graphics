module edge_detector(clk, rst, signal, rise, fall);
input wire clk, rst, signal;
output logic rise, fall;

logic old;


always_ff @( posedge clk) begin : edgeDetector
  if (rst) begin
    old <= 0;
  end else begin
    old <= signal;
  end
  // rising edge only
  if (old != signal) begin
    if (signal) begin
      rise <= 1;
      fall <= 0;
    end else begin
      fall <= 1;
      rise <= 0;
    end
  end else begin
    rise <= 0;
    fall <= 0;
  end
end
endmodule