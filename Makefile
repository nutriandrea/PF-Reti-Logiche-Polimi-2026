# GHDL configuration
GHDL      ?= ghdl
GHDLFLAGS ?= --std=08 -frelaxed

# Source files
SRC  = src/project_reti_logiche.vhd
TB   = tb/project_tb.vhd tb/tb_edge_cases.vhd

.PHONY: all analyze run-official run-edge clean

all: run-official run-edge

analyze: $(SRC) $(TB)
	$(GHDL) -a $(GHDLFLAGS) $(SRC) $(TB)

run-official: analyze
	$(GHDL) -e $(GHDLFLAGS) project_tb
	$(GHDL) -r $(GHDLFLAGS) project_tb

run-edge: analyze
	$(GHDL) -e $(GHDLFLAGS) tb_edge_cases
	$(GHDL) -r $(GHDLFLAGS) tb_edge_cases

clean:
	rm -f *.o *.cf project_tb tb_edge_cases
	rm -f work-obj08.cf e~*.o
