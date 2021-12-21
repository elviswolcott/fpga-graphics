// shifts from 8 bit color to 16 bit color
module color_decompress(compressed, color);

input [7:0] compressed;
output logic [15:0] color;

always_comb begin : expand
  // F E D C B A 9 8 7 6 5 4 3 2 1 0
  // r r r r r g g g g g g b b b b b
  //                 r r r g g g b b
  // r
  color[15:13] = compressed[7:5];
  color[13:12] = 0;
  // g
  color[10:8] = compressed[4:2];
  color[7:5] = 0;
  // b
  color[4:3] = compressed[1:0];
  color[2:0] = 0;
end

endmodule