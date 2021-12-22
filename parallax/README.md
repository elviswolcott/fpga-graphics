# Layer Images, Compression, and `.memh` File Creation

*For testing and using the display, we needed to get the image files into a readable memory format for the FPGA-to-display to use.*

This folder contains the function used to create .memh files with 16-bit and 8-bit hexadecimal color compression, a folder of images used, and the `.memh` memory files created. A few memory files were generated in order to debug pixel placement issues. For example, `bars.memh` is half white and half black, to determine where the left and right sides of the screen were actually being positioned. Additionally, `dots.memh` is fully white except for two red dots a space apart from each other, to determine if the pixel colors that should be in the same column were actually doing so.