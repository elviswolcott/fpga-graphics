#!/usr/bin/env python3

import argparse
from PIL import Image

# Based on defines from: https: # github.com/adafruit/Adafruit_ILI9341
# and from Section 8.1 of the Datasheet

ILI9341_REGISTERS = dict(
    NOP=0x00,       # no-op register(do nothing)
    SWRESET=0x01,   # software reset
    RDDID=0x04,     # read display id info
    RDDST=0x09,     # read display status

    SLPIN=0x10,     # enter sleep mode
    SLPOUT=0x11,    # exist sleep mode
    PLTON=0x12,     # partial mode on
    NORON=0x13,     # normal mode on

    RDMODE=0x0A,    # read display power mode
    RDMADCTL=0x0B,  # read display MADCTL
    RDPIXFMT=0x0C,  # Read Display Pixel Format
    RDIMGFMT=0x0D,   # Read Display Image Format

    RDSELFDIAG=0x0F,  # Read Display Self-Diagnostic Result
    INVOFF=0x20,   # / < Display Inversion OFF
    INVON=0x21,   # / < Display Inversion ON
    GAMMASET=0x26,  # / < Gamma Set
    DISPOFF=0x28,  # / < Display OFF
    DISPON=0x29,   # / < Display ON

    CASET=0x2A,  # / < Column Address Set
    PASET=0x2B,  # / < Page Address Set
    RAMWR=0x2C,  # / < Memory Write
    RAMRD=0x2E,  # / < Memory Read

    PTLAR=0x30,    # / < Partial Area
    VSCRDEF=0x33,  # / < Vertical Scrolling Definition
    MADCTL=0x36,   # / < Memory Access Control
    VSCRSADD=0x37,  # / < Vertical Scrolling Start Address
    PIXFMT=0x3A,   # / < COLMOD: Pixel Format Set

    FRMCTR1=0xB1,  # / < Frame Rate Control(In Normal Mode/Full Colors)
    FRMCTR2=0xB2,  # / < Frame Rate Control(In Idle Mode/8 colors)
    FRMCTR3=0xB3,  # / < Frame Rate control(In Partial Mode/Full Colors)
    INVCTR=0xB4,  # / < Display Inversion Control
    DFUNCTR=0xB6,  # / < Display Function Control

    PWCTR1=0xC0,  # / < Power Control 1
    PWCTR2=0xC1,  # / < Power Control 2
    PWCTR3=0xC2,  # / < Power Control 3
    PWCTR4=0xC3,  # / < Power Control 4
    PWCTR5=0xC4,  # / < Power Control 5
    VMCTR1=0xC5,  # / < VCOM Control 1
    VMCTR2=0xC7,  # / < VCOM Control 2

    RDID1=0xDA,  # / < Read ID 1
    RDID2=0xDB,  # / < Read ID 2
    RDID3=0xDC,  # / < Read ID 3
    RDID4=0xDD,  # / < Read ID 4

    GMCTRP1=0xE0,  # / < Positive Gamma Correction
    GMCTRN1=0xE1,  # / < Negative Gamma Correction
    PWCTR6=0xFC
)

ILI9341_INIT_SEQUENCE = [
    0xFF, ILI9341_REGISTERS['SWRESET'],
    3, 0xEF, 0x03, 0x80, 0x02,
    3, 0xCF, 0x00, 0xC1, 0x30,
    4, 0xED, 0x64, 0x03, 0x12, 0x81,
    3, 0xE8, 0x85, 0x00, 0x78,
    5, 0xCB, 0x39, 0x2C, 0x00, 0x34, 0x02,
    1, 0xF7, 0x20,
    2, 0xEA, 0x00, 0x00,
    1, ILI9341_REGISTERS['PWCTR1'], 0x23,             # Power control VRH[5:0]
    1, ILI9341_REGISTERS['PWCTR2'], 0x10,             # Power control SAP[2:0]; BT[3:0] # noqa
    2, ILI9341_REGISTERS['VMCTR1'], 0x3e, 0x28,       # VCM control
    1, ILI9341_REGISTERS['VMCTR2'], 0x86,             # VCM control2
    1, ILI9341_REGISTERS['MADCTL'], 0x48,             # Memory Access Control
    1, ILI9341_REGISTERS['VSCRSADD'], 0x00,             # Vertical scroll zero
    1, ILI9341_REGISTERS['PIXFMT'], 0x55,
    2, ILI9341_REGISTERS['FRMCTR1'], 0x00, 0x18,
    3, ILI9341_REGISTERS['DFUNCTR'], 0x08, 0x82, 0x27,  # Display Function Control # noqa
    1, 0xF2, 0x00,                         # 3Gamma Function Disable # noqa
    1, ILI9341_REGISTERS['GAMMASET'], 0x01,             # Gamma curve selected
    15, ILI9341_REGISTERS['GMCTRP1'], 0x0F, 0x31, 0x2B, 0x0C, 0x0E, 0x08, 0x4E, 0xF1, 0x37, 0x07, 0x10, 0x03, 0x0E, 0x09, 0x00,  # Set Gamma # noqa
    15, ILI9341_REGISTERS['GMCTRN1'], 0x00, 0x0E, 0x14, 0x03, 0x11, 0x07, 0x31, 0xC1, 0x48, 0x08, 0x0F, 0x0C, 0x31, 0x36, 0x0F,  # Set Gamma # noqa
    0xFF, ILI9341_REGISTERS['SLPOUT'],                # Exit Sleep # noqa
    0xFF, ILI9341_REGISTERS['DISPON'],                # Display on # noqa
    4, ILI9341_REGISTERS['CASET'], 0x0, 0x0, 0x0, 0xef,  # set X window
    4, ILI9341_REGISTERS['PASET'], 0x0, 0x0, 0x01, 0xef,  # set Y window
    0x00  # Signifies end of command.
]


def generate_ili9341_rom(fn="memories/ili9341_init.memh"):
    print(f"Writing ili9341 display controller init sequence to {fn}.")
    with open(fn, 'w') as f:
        for b in ILI9341_INIT_SEQUENCE:
            f.write("%02x\n" % b)
    print(f"Wrote {len(ILI9341_INIT_SEQUENCE)} bytes to {fn}.")
    print("You can set the parameter ROM_LENGTH to this number of bytes.")

MASK_5_BITS = 0xF8
MASK_6_BITS = 0xFC
MASK_3_BITS = 0xE0
MASK_2_BITS = 0xC0

# convert 24bit hex colors into 16bit format, RGB565
def convert_24_to_16(color):
    r,g,b = color
    r_data = (r & MASK_5_BITS) << 8
    g_data = (g & MASK_6_BITS) << 3
    b_data = (b & MASK_5_BITS) // 8

    return r_data | b_data | g_data

# convert 24bit hex colors into 8bit format, RGB332
def convert_24_to_8(color):
    if (len(color) == 3):
        r,g,b = color
    else:
        r,g,b,a = color
        # treat rgb(0,0,0) as transparent
        if (a == 0):
            return 0
    r_data = (r & MASK_3_BITS)
    g_data = (g & MASK_3_BITS) // 8
    b_data = (b & MASK_2_BITS) // 64

    return r_data | b_data | g_data

def generate_image_rom(infile, outfile="memories/image.memh", bits=8, downsample=1):
    # open the image and get the pixels
    # using pillow for this means almost any image file should work
    im = Image.open(infile)
    w, h = im.size
    # crop height around center
    top = (h - 240) // 2
    im = im.crop((0, top, w, top + 240))
    pixels = list(im.getdata())
    w, h = im.size
    print((w,h))
    
    # go through pixels and save to a file as hex
    print(f"Writing ili9341 display file for image to {outfile}.")
    # this could be replaced with a color table to compress the images
    # but for the sake of our MVP, that was out of scope
    with open(outfile, 'w') as f:
        for col in range(w // downsample):
            for row in range(h // downsample):
                pixel = pixels[(row * downsample * w) + col * downsample]
                if (bits == 8):
                    pixel = convert_24_to_8(pixel)
                    f.write("%02x\n" % pixel)
                elif (bits == 16):
                    pixel = convert_24_to_16(pixel)
                    f.write("%04x\n" % pixel)

def generate_gradient_rom(outfile="memories/grad.memh", bits=8, downsample=2):
    w = 320
    h = 240
    # go through pixels and save to a file as hex
    print(f"Writing gradient to {outfile}.")
    with open(outfile, 'w') as f:
        for col in range(w // downsample):
            for row in range(h // downsample):
                pixel = (row, col, 0)
                if (bits == 8):
                    pixel = convert_24_to_8(pixel)
                    f.write("%02x\n" % pixel)
                elif (bits == 16):
                    pixel = convert_24_to_16(pixel)
                    f.write("%04x\n" % pixel)

def generate_bar_rom(outfile="memories/bars.memh", bars=2, bits=8, downsample=2):
    w = 320
    h = 240
    # go through pixels and save to a file as hex
    print(f"Writing bars to {outfile}.")
    with open(outfile, 'w') as f:
        for col in range(w // downsample):
            for row in range(h // downsample):
                wrap = w // downsample * (bars // 2);
                if (col % wrap < wrap//2):
                    pixel = (255,255,255)
                else:
                    pixel = (0,0,0)
                if (bits == 8):
                    pixel = convert_24_to_8(pixel)
                    f.write("%02x\n" % pixel)
                elif (bits == 16):
                    pixel = convert_24_to_16(pixel)
                    f.write("%04x\n" % pixel)



_fibonacci_cache = {0: 0, 1: 1}


def fibonacci(x):
    if x in _fibonacci_cache:
        return _fibonacci_cache[x]
    _fibonacci_cache[x] = fibonacci(x-1) + fibonacci(x-2)
    return _fibonacci_cache[x]


def generate_fibonacci_rom(fn="memories/fibonacci.memh"):
    print(f"Writing fibonacci sequence to {fn}.")
    with open(fn, 'w') as f:
        for i in range(48):
            f.write("%08x\n" % fibonacci(i))
    print(f"Wrote 48 bytes to {fn}.")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--memory', choices=['ili9341', 'fibonacci', 'image', 'gradient', 'bars'])
    parser.add_argument('--file')
    parser.add_argument('--bitdepth', choices=['8', '16'])
    parser.add_argument('--out')
    parser.add_argument('--downsample')
    parser.add_argument('--count')

    args = parser.parse_args()
    if not args.out:
        return

    if args.memory == 'image':
        if not args.file or not args.bitdepth:
            return
        generate_image_rom(args.file, args.out, int(args.bitdepth), int(args.downsample))
    elif args.memory == 'ili9341':
        generate_ili9341_rom(args.out)
    elif args.memory == 'fibonacci':
        generate_fibonacci_rom(fn=args.out)
    elif args.memory == 'gradient':
        generate_gradient_rom(args.out)
    elif args.memory == 'bars':
        generate_bar_rom(args.out, int(args.count))


if __name__ == "__main__":
    main()
