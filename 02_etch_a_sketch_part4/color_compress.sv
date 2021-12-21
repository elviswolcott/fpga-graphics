// shifts from 8 bit color to 16 bit color
module color_compress(color, compressed);

input ILI9341_color_t color;
output logic [7:0] compressed;

always_comb begin : expand
  // F E D C B A 9 8 7 6 5 4 3 2 1 0
  // r r r r r g g g g g g b b b b b
  //                 r r r g g g b b
  // r
  compressed[7:5] = color[15:13];
  // g
  compressed[4:2] = color[10:8];
  // b
  compressed[1:0] = color[4:3];
end

endmodule