// composites 2 layers
module composite(color_top, color_bottom, composited);

input [7:0] color_top, color_bottom;
output logic [7:0] composited;

logic select;
always_comb begin : mux
  select = color_top == 0; // transparent pixel on top layer
  composited = select ? color_bottom : color_top;
end

endmodule