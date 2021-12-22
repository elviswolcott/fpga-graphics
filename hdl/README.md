# Parallax Code for the FPGA

*This code is based on what we did for [Part 4 of the Etch-A-Sketch lab](https://github.com/mkazc/olin-cafe-f21/tree/main/02_etch_a_sketch_part4).*

We're using [Adafruit's 2.8" TFT LCD with Cap Touch Breakout Board w/MicroSD Socket](https://www.adafruit.com/product/2090)
- a 240x320 RGB TFT Display
- an ILI9341 Display Controller [datasheet](https://cdn-shop.adafruit.com/datasheets/ILI9341.pdf)
- an FT6206 Capacitive Touch Controller [datasheet](https://cdn-shop.adafruit.com/datasheets/FT6x06+Datasheet_V0.1_Preliminary_20120723.pdf) and [app note](https://cdn-shop.adafruit.com/datasheets/FT6x06_AN_public_ver0.1.3.pdf)

## Scripts and Folders
- `memories` Location for all .memh files of layer colors and inits
- `tests` Location for all tests for display controllers
- `main.sv` Access memories, update VRAM and create the parallax effect
- `color_decompress.sv` Decompresses 8-bit into 16-bit hex colors
- `composite.sv` For compositing two layers together
- `spi_controller.sv` SPI Controller for Display
- `ili9341_display_controller.sv` ILI9341 Display Controller
- some additional unused modules are available for adding additional functionality using the buttons 