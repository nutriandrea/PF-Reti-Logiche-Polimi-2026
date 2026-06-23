# PF Reti Logiche — Politecnico di Milano 2025/26

[![GHDL](https://img.shields.io/badge/simulated-GHDL-7851a9)](https://ghdl.github.io/ghdl/)
[![VHDL-2008](https://img.shields.io/badge/VHDL-2008-blue)](https://en.wikipedia.org/wiki/VHDL)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

VHDL implementation of the **"Progetto di Reti Logiche"** final assignment for the *Digital Logic Design* course at Politecnico di Milano (A.Y. 2025/26).

The module, `project_reti_logiche`, manages a priority-ordered task list stored in an external single-port Block RAM (Write-First mode). It supports four operations: priority increment, remove-first, ordered insert, and clear.

## Authors

- **Andrea Cacioppo** — 10902819
- **Andrea Carbone** — 10907106

*Course:* Reti Logiche (Digital Logic Design)  
*Academic Year:* 2025/2026

## Features

- Fully synchronous FSM with asynchronous reset.
- Single-process Control Unit + Datapath for deterministic RAM access.
- Priority-ordered insert with FIFO ordering within the same priority.
- Priority saturation at `P = 3` during increment.
- START/DONE handshake protocol.
- Handles edge cases: empty list, single element, reset during operation, back-to-back operations, and held START.
- Validated with:
  - The official example testbench (`project_tb`).
  - A custom extended edge-case testbench (`tb_edge_cases`) with 27 scenarios / 78 operations.

## Repository Structure

```text
.
├── src/                          # VHDL source
│   └── project_reti_logiche.vhd  # Main module
├── tb/                           # Testbenches
│   ├── project_tb.vhd            # Official example testbench
│   └── tb_edge_cases.vhd         # Extended edge-case testbench
├── docs/
│   ├── report/                   # LaTeX report
│   │   ├── main.tex
│   │   └── assets/logo_polimi.png
│   └── specs/                    # Official assignment specs
│       ├── PFRL_Specifiche_2526_V1.pdf
│       └── PFRL_Regole_2526.pdf
├── delivery/                     # Files as submitted for grading
│   └── 10902819_10907106.vhd
├── scripts/
│   └── simulate.sh               # Convenience simulation script
├── sim/results/                  # Output directory for waveforms/logs
├── Makefile                      # GHDL build & simulation targets
├── .gitignore
├── LICENSE
└── README.md
```

## Memory Model

| Address | Content |
|---------|---------|
| 0       | Task count (`count`, 6 bit) |
| 1 … N   | One task per byte: `ID_TASK(5:0) & PRIORITY(1:0)` |

Priorities are encoded as `0` (highest) … `3` (lowest).

## Operations

| `i_op` | Operation | Description |
|--------|-----------|-------------|
| `00`   | Increment priority | Increase every task priority by 1, saturating at `3`. |
| `01`   | Remove first | Remove the task at address 1, shift the remaining tasks left, output the removed `ID_TASK`. |
| `10`   | Insert | Insert a new task at the end of its priority group, preserving order. |
| `11`   | Clear | Reset the task counter to 0. |

## Simulation

### Requirements

- [GHDL](https://ghdl.github.io/ghdl/) (tested with GHDL 6.0.0, LLVM backend)
- GNU Make (optional, for `Makefile` targets)

### Quick Start

```bash
# Run both testbenches
make

# Run only the official example testbench
make run-official

# Run only the extended edge-case testbench
make run-edge

# Clean generated artifacts
make clean
```

Alternatively, use the provided convenience script:

```bash
./scripts/simulate.sh
```

Expected output: both testbenches terminate with `TEST PASSATO` / `ALL EDGE CASE TESTS PASSED` and exit status `0`.

### Capture Waveforms

To generate a GHW waveform file (e.g., for GTKWave):

```bash
make analyze
ghdl -e --std=08 -frelaxed project_tb
ghdl -r --std=08 -frelaxed project_tb --wave=sim/results/project_tb.ghw
```

## Synthesis

The design has been synthesized with **Xilinx Vivado WebPACK 2018.3** targeting an **Artix-7 xc7a200tfbg484-1** FPGA at 50 MHz (20 ns clock period).

Summary of post-synthesis results:

| Resource            | Used | Available |
|---------------------|------|-----------|
| Slice LUTs          | 93   | 8,000     |
| Slice Registers     | 83   | 16,000    |
| Bonded IOB          | 54   | 150       |
| BUFGCTRL            | 1    | 32        |

Timing closure was achieved with positive slack.

To synthesize in Vivado:

1. Create a new RTL project.
2. Add `src/project_reti_logiche.vhd` as design source.
3. Add `tb/project_tb.vhd` (or `tb/tb_edge_cases.vhd`) as simulation source.
4. Select the target FPGA (e.g., `xc7a200tfbg484-1`).
5. Run **Simulation** → **Run Behavioral Simulation**.
6. Optionally run **Run Synthesis** and **Run Implementation**.

## Documentation

The full project report is available in `docs/report/main.tex` (Italian). It covers specifications, architecture, FSM description, design choices, test methodology, simulation results, and synthesis results.

The original assignment documents are included under `docs/specs/`.

## License

This project is released under the [MIT License](LICENSE) for educational reference. Please respect your institution's academic integrity policies before reusing any part of this work.

## Acknowledgments

Project developed for the *Reti Logiche* course at Politecnico di Milano, Prof. Fornaciari, Prof. Palermo, Prof. Salice.
