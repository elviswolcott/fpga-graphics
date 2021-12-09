# Lab 2: Etch a Sketch

In this lab we're going to build logic to make an "etch a sketch" or sketchpad hardware device. Over the course of the lab you will learn how to:
* Design your own specifications for complex sequential and combinational logic blocks.
* Implement controllers for the popular SPI and i2c serial interfaces.
* Learn how to interface with both ROM and RAM memories.
* Get better at 

We're using [Adafruit's 2.8" TFT LCD with Cap Touch Breakout Board w/MicroSD Socket](https://www.adafruit.com/product/2090). Through the course of the lab we'll interface with following components on the breakout board:
- a 240x320 RGB TFT Display
- an ILI9341 Display Controller [datasheet](https://cdn-shop.adafruit.com/datasheets/ILI9341.pdf)
- an FT6206 Capacitive Touch Controller [datasheet](https://cdn-shop.adafruit.com/datasheets/FT6x06+Datasheet_V0.1_Preliminary_20120723.pdf) and [app note](https://cdn-shop.adafruit.com/datasheets/FT6x06_AN_public_ver0.1.3.pdf)

## Lab Checklist

- [*] Pulse generator
- [*] PWM Module
- [*] SPI Controller for Display
- [*] i2c Controller for touchscreen
- [ ] main system FSM 
  - [x] clear memory on button press
  - [x] update memory based on touch values
  - [x] emit draw signals based on memory
  - [ ] bonus: add colors, different modes
  - [ ] stretch bonus: add fonts/textures! (hint, you can create more ROMs or learn how to use the display controllers draw from SD card features).

# Part 4
