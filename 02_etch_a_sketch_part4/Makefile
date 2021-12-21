# -Wall turns on all warnings
# -g2012 selects the 2012 version of iVerilog
IVERILOG=iverilog -g2012 -Wall -y ./ -I ./
VVP=vvp
VVP_POST=-fst
VIVADO=vivado -mode batch -source

ILI9341_SRCS=spi_controller.sv ili9341_display_controller.sv spi_types.sv ili9341_defines.sv block_rom.sv
FT6206_SRCS=i2c_controller.sv ft6206_controller.sv i2c_types.sv ft6206_defines.sv 
# Add any new source files needed for the final bitstream here
MAIN_SRCS=main.sv pulse_generator.sv pwm.sv triangle_generator.sv block_ram.sv edge_detector.sv debouncer.sv led_example.sv ${ILI9341_SRCS} ${FT6206_SRCS}

# Look up .PHONY rules for Makefiles
.PHONY: clean submission remove_solutions

test_pulse_generator: tests/test_pulse_generator.sv pulse_generator.sv
	${IVERILOG} $^ -o test_pulse_generator.bin && ${VVP} test_pulse_generator.bin ${VVP_POST}

test_pwm: tests/test_pwm.sv pulse_generator.sv pwm.sv
	@echo "This might take a while, we're testing a lot of clock cycles!"
	${IVERILOG} $^ -o test_pwm.bin && ${VVP} test_pwm.bin ${VVP_POST}

test_triangle_generator: tests/test_triangle_generator.sv triangle_generator.sv
	${IVERILOG} $^ -o test_triangle_generator.bin && ${VVP} test_triangle_generator.bin ${VVP_POST}

test_spi_controller : tests/test_spi_controller.sv spi_controller.sv spi_defines.sv
	${IVERILOG} $^ -o test_spi_controller.bin && ${VVP} test_spi_controller.bin ${VVP_POST}
waves_spi_controller: test_spi_controller
	gtkwave spi_controller.fst -a tests/spi_controller.gtkw

test_i2c_controller : tests/test_i2c_controller.sv i2c_controller.sv i2c_types.sv
	${IVERILOG} $^ -o test_i2c_controller.bin && ${VVP} test_i2c_controller.bin ${VVP_POST}
waves_i2c_controller: test_i2c_controller
	gtkwave i2c_controller.fst -a tests/i2c_controller.gtkw

memories/ili9341_init.memh: generate_memories.py
	./generate_memories.py --memory ili9341 --out memories/ili9341_init.memh

memories/fibonacci.memh: generate_memories.py
	./generate_memories.py --memory fibonacci --out memories/fibonacci.memh

test_block_rom : memories/fibonacci.memh block_rom.sv tests/test_block_rom.sv
	${IVERILOG} block_rom.sv tests/test_block_rom.sv -o test_block_rom.bin && ${VVP} test_block_rom.bin ${VVP_POST}

test_ili9341_display_controller : tests/test_ili9341_display_controller.sv $(ILI9341_SRCS) memories/ili9341_init.memh
	${IVERILOG} ${ILI9341_SRCS} tests/test_ili9341_display_controller.sv  -o test_ili9341_display_controller.bin && ${VVP} test_ili9341_display_controller.bin ${VVP_POST}
waves_ili9341_display_controller: test_ili9341_display_controller
	gtkwave ili9341_display_controller.fst -a tests/ili9341_display_controller.gtkw

test_ft6206_controller : tests/test_ft6206_controller.sv tests/ft6206_model.sv $(FT6206_SRCS)
	${IVERILOG} ${FT6206_SRCS} tests/test_ft6206_controller.sv tests/ft6206_model.sv -o test_ft6206.bin && ${VVP} test_ft6206.bin ${VVP_POST}
waves_ft6206_controller: test_ft6206_controller
	gtkwave ft6206_controller.fst -a tests/ft6206_controller.gtkw

test_main: tests/test_main.sv ${MAIN_SRCS} memories/ili9341_init.memh tests/ft6206_model.sv
	@echo "This might take a while, we're testing a lot of clock cycles!"
	${IVERILOG} tests/test_main.sv tests/ft6206_model.sv ${MAIN_SRCS} -o test_main.bin && ${VVP} test_main.bin ${VVP_POST}

main.bit: main.sv $(MAIN_SRCS) memories/ili9341_init.memh build.tcl
	@echo "########################################"
	@echo "#### Building FPGA bitstream        ####"
	@echo "########################################"
	${VIVADO} build.tcl

program_fpga_vivado: main.bit build.tcl program.tcl
	@echo "########################################"
	@echo "#### Programming FPGA (Vivado)      ####"
	@echo "########################################"
	${VIVADO} program.tcl

program_fpga_digilent: main.bit build.tcl
	@echo "########################################"
	@echo "#### Programming FPGA (Digilent)    ####"
	@echo "########################################"
	djtgcfg enum
	djtgcfg prog -d CmodA7 -i 0 -f main.bit


# Call this to clean up all your generated files
clean:
	rm -f *.bin *.vcd *.fst vivado*.log *.jou vivado*.str *.log *.checkpoint *.bit *.html *.xml
	rm -rf .Xil

# Call this to generate your submission zip file.
submission:
	zip submission.zip Makefile *.sv README.md docs/* *.tcl *.xdc tests/*.sv *.pdf
