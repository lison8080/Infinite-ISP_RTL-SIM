#===============================================================================
# Makefile for Infinite-ISP RTL Simulation with VCS and Verdi
#===============================================================================

#-------------------------------------------------------------------------------
# Project Paths
#-------------------------------------------------------------------------------
PROJ_ROOT    := $(shell pwd)

#-------------------------------------------------------------------------------
# VCS Tools
#-------------------------------------------------------------------------------
VCS          := vcs
VERDI        := verdi

#-------------------------------------------------------------------------------
# Output Directory
#-------------------------------------------------------------------------------
SIM_DIR      := csrc
SIMV         := simv

#-------------------------------------------------------------------------------
# Top Module
#-------------------------------------------------------------------------------
TOP_MODULE   := tb_seq_top

#-------------------------------------------------------------------------------
# Simulation Options
#-------------------------------------------------------------------------------
# Default simulation time (adjust as needed, 100ms for ~1 frame at 50MHz)
SIM_TIME     ?= 100ms

# VCS compile options
VCS_OPTS     := -full64 -sverilog -debug_access+all -timescale=1ns/1ps \
                -kdb -lca \
				-LDFLAGS -Wl,--no-as-needed \
                +v2k +vcs+lic+wait \
                -o $(SIMV)

# FSDB dump options for Verdi
FSDB_OPTS    := -fsdb +fsdb+autoflush

# Simulation run options
SIM_OPTS     := -l sim.log

#-------------------------------------------------------------------------------
# Filelist
#-------------------------------------------------------------------------------
FILELIST     := $(PROJ_ROOT)/filelist.f

#===============================================================================
# Targets
#===============================================================================

.PHONY: all compile sim sim_fsdb verdi clean help

# Default target
all: vcs

# Compile all sources with VCS
compile:
	@echo "=============================================="
	@echo "Compiling RTL and Testbench sources with VCS..."
	@echo "=============================================="
	$(VCS) $(VCS_OPTS) $(FSDB_OPTS) -f $(FILELIST)

# Run simulation in batch mode (no GUI)
vcs: compile
	@echo "=============================================="
	@echo "Running simulation in batch mode..."
	@echo "=============================================="
	./$(SIMV) $(SIM_OPTS)

# Open waveform with Verdi
verdi:
	@echo "=============================================="
	@echo "Opening waveform with Verdi..."
	@echo "=============================================="
	$(VERDI) -sv -f $(FILELIST) -ssf $(TOP_MODULE).fsdb -top $(TOP_MODULE) &

# Clean generated files (preserves input files In_*.bin)
clean:
	@echo "=============================================="
	@echo "Cleaning generated files..."
	@echo "=============================================="
	-rm -rf csrc
	-rm -rf $(SIMV) $(SIMV).daidir
	-rm -rf *.fsdb
	-rm -rf *.log
	-rm -rf *.key
	-rm -rf novas.* verdiLog
	-rm -rf ucli.key
	-rm -rf vc_hdrs.h
	-rm -f out/RTL_*.bin out/*gain*.bin out/AE_*.bin out/DGAIN_*.bin

# Help
help:
	@echo "=============================================="
	@echo "Infinite-ISP RTL Simulation Makefile (VCS + Verdi)"
	@echo "=============================================="
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  all          - Default target, same as 'sim'"
	@echo "  compile      - Compile all RTL and testbench sources with VCS"
	@echo "  vcs          - Run simulation in batch mode (no GUI)"
	@echo "  verdi        - Open waveform with Verdi (requires filelist.f)"
	@echo "  clean        - Remove generated files"
	@echo "  help         - Show this help message"
	@echo ""
	@echo "Examples:"
	@echo "  make vcs             # Run simulation and generate FSDB"
	@echo "  make verdi           # View waveform in Verdi with KDB"
	@echo ""
	@echo "Top Module: $(TOP_MODULE)"
	@echo ""
