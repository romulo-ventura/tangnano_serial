.DEFAULT_GOAL := all
.DELETE_ON_ERROR:
RUN ?= bash ./scripts/fpga-run
LEDS ?= 1
ifneq ($(LEDS),0)
ifneq ($(LEDS),1)
$(error LEDS must be 0 or 1)
endif
endif
BUILD := build/leds$(LEDS)
RTL := rtl/uart.v rtl/byte_fifo.v rtl/uart_stream.v rtl/echo_service.v rtl/serial_status_leds.v rtl/top.v
PORT ?= /dev/cu.usbserial-20250303171
.PHONY: all sim program test test-host check resources package
all: $(BUILD)/echo.fs
build $(BUILD):
	mkdir -p $@
$(BUILD)/echo.json: $(RTL) Makefile | $(BUILD)
	$(RUN) yosys -l $(BUILD)/synthesis.log -p 'read_verilog $(RTL); chparam -set ENABLE_DIAGNOSTIC_LEDS $(LEDS) top; synth_gowin -top top -family gw2a -json $@'
$(BUILD)/echo.pnr.json: $(BUILD)/echo.json tangnano20k.cst
	$(RUN) nextpnr-himbaechel --json $< --write $@ --device GW2AR-LV18QN88C8/I7 --vopt family=GW2A-18C --vopt cst=tangnano20k.cst --freq 27 --log $(BUILD)/place-route.log
$(BUILD)/echo.fs: $(BUILD)/echo.pnr.json Makefile
	$(RUN) gowin_pack -d GW2A-18C -o $@ $<
$(BUILD)/echo_tb: $(RTL) sim/echo_tb.sv Makefile | $(BUILD)
	$(RUN) iverilog -g2012 -s echo_tb -Pecho_tb.ENABLE_DIAGNOSTIC_LEDS=$(LEDS) -o $@ $(RTL) sim/echo_tb.sv
build/core_tb: $(RTL) sim/core_tb.sv | build
	$(RUN) iverilog -g2012 -s core_tb -o $@ $^
build/service_tb: $(RTL) sim/service_tb.sv | build
	$(RUN) iverilog -g2012 -s service_tb -o $@ $^
build/fifo_tb: rtl/byte_fifo.v sim/fifo_tb.sv | build
	$(RUN) iverilog -g2012 -s fifo_tb -o $@ $^
build/leds_tb: rtl/serial_status_leds.v sim/leds_tb.sv | build
	$(RUN) iverilog -g2012 -s leds_tb -o $@ $^
build/byte_echo_example: rtl/uart.v rtl/byte_fifo.v rtl/uart_stream.v examples/byte_echo.v | build
	$(RUN) iverilog -g2012 -s byte_echo -o $@ $^
build/application_leds_example: rtl/serial_status_leds.v examples/application_leds.v | build
	$(RUN) iverilog -g2012 -s application_leds -o $@ $^
sim: $(BUILD)/echo_tb build/core_tb build/service_tb build/fifo_tb build/leds_tb
	$(RUN) vvp $(BUILD)/echo_tb
	$(RUN) vvp build/core_tb
	$(RUN) vvp build/service_tb
	$(RUN) vvp build/fifo_tb
	$(RUN) vvp build/leds_tb
program: all
	$(RUN) openFPGALoader -b tangnano20k $(BUILD)/echo.fs
test: | $(BUILD)
	python3 test_serial.py --port $(PORT) --report $(BUILD)/hardware-test.json
test-host:
	python3 -m unittest host.test_serial_client -v
check: sim test-host build/byte_echo_example build/application_leds_example
resources: all
	python3 scripts/resource_report.py $(BUILD)/place-route.log
package:
	python3 scripts/package.py
