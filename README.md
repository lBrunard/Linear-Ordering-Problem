# LOP Solver — Heuristic Optimization (INFO-H-413)

Implementation of iterative improvement algorithms for the **Linear Ordering Problem (LOP)**, as part of Implementation Exercise 1.

---

## Compilation

Requires GCC. Run from the project root:

```bash
make        # compile
make clean  # remove binaries and .o files
```

The binary `lop` is produced in the project root.

---

## Running the solver

```bash
./lop -i <instance_file> [options]
```

### Required argument

| Option | Description |
|--------|-------------|
| `-i <file>` | Path to the instance file (e.g. `instances/N-tiw56r72_150`) |

### Initialisation

| Option | Description |
|--------|-------------|
| `--random` | Start from a random permutation (default) |
| `--cw` | Start from the Chenery–Watanabe greedy heuristic |

### Neighbourhood (Exercise 1.1)

| Option | Description |
|--------|-------------|
| `--transpose` | Transpose: swap two adjacent elements (default) |
| `--exchange` | Exchange: swap any two elements |
| `--insert` | Insert: move one element to another position |

### Pivoting rule (Exercise 1.1)

| Option | Description |
|--------|-------------|
| `--first` | First-improvement: accept first improving move (default) |
| `--best` | Best-improvement: apply the best improving move |

### VND (Exercise 1.2)

| Option | Description |
|--------|-------------|
| `--vnd-tei` | VND with ordering Transpose → Exchange → Insert |
| `--vnd-tie` | VND with ordering Transpose → Insert → Exchange |

### Other

| Option | Description |
|--------|-------------|
| `-v` | Verbose output (human-readable) |

---

## Examples

```bash
# Insert neighbourhood, first-improvement, CW initialisation, verbose
./lop -i instances/N-tiw56r72_150 --cw --insert --first -v

# Exchange, best-improvement, random start (compact CSV output)
./lop -i instances/N-be75eec_250 --random --exchange --best

# VND-TIE from CW initialisation
./lop -i instances/N-t70b11xx_250 --cw --vnd-tie
```

---

## Output format

In **non-verbose mode** (default), each run prints one semicolon-separated line:

```
<Instance>;<Init>;<NH>;<Pivot>;<InitialCost>;<FinalCost>;<Time_s>
```

| Field | Values |
|-------|--------|
| `Init` | 0 = Random, 1 = CW |
| `NH` | 0 = Transpose, 1 = Exchange, 2 = Insert, 3 = VND-TEI, 4 = VND-TIE |
| `Pivot` | 0 = First-improvement, 1 = Best-improvement |

---

## Running all experiments

The script `auto_run.sh` runs all 14 configurations (12 iterative improvement + 2 VND) on all instances and saves results to `results_summary.csv`:

```bash
bash auto_run.sh
```

---

## Statistical analysis (requires R)

```bash
Rscript statistical_tests.R
```

Produces:
- `summary_statistics.csv` — average RPD, std deviation, and time per configuration
- `wilcoxon_ex1_1.csv` — pairwise Wilcoxon test results for Ex 1.1
- `wilcoxon_ex1_2.csv` — Wilcoxon test result for VND-TEI vs VND-TIE
- `raw_data_for_report.txt` — raw RPD data for submission

```bash
Rscript ../generate_plots.R
```

Produces PNG charts in `../plots/`.

---

## Best known solutions

Reference values are in `best_known/best_known.txt` (one instance per line: `<name> <value>`).

---

## Project structure

```
.
├── src/
│   ├── main.c            # Argument parsing, entry point
│   ├── optimization.c/h  # All algorithms (local search, VND, delta functions)
│   ├── instance.c/h      # Instance reader
│   ├── utilities.c/h     # RNG, helper functions
│   └── timer.c/h         # Timing utilities
├── instances/            # 78 benchmark instances (sizes 150 and 250)
├── best_known/           # Best known solution values
├── auto_run.sh           # Batch experiment runner
├── statistical_tests.R   # Statistical analysis script
└── Makefile
```
