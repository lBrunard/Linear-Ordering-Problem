# LOP Local Search — Implementation

C implementation of local search algorithms for the **Linear Ordering Problem (LOP)**.

## Compilation

```bash
cd code
make
```

Produces the `lop` binary in `code/`.

## Usage

```
./lop -i <instance_file> --<init> --<neighbourhood> --<pivot>
./lop -i <instance_file> --cw --<vnd_variant>
```

### Options

| Flag | Description |
|------|-------------|
| `-i <path>` | Path to instance file |
| `--random` | Random initialisation |
| `--cw` | Chenery-Watanabe (CW) initialisation |
| `--transpose` | Transpose neighbourhood |
| `--exchange` | Exchange neighbourhood |
| `--insert` | Insert neighbourhood |
| `--first` | First-improvement pivot rule |
| `--best` | Best-improvement pivot rule |
| `--vnd-tei` | VND with ordering Transpose→Exchange→Insert |
| `--vnd-tie` | VND with ordering Transpose→Insert→Exchange |

### Examples

```bash
# Insert neighbourhood, best-improvement, CW init
./lop -i instances/N-be75eec_150 --cw --insert --best

# VND-TEI with CW init
./lop -i instances/N-be75eec_150 --cw --vnd-tei
```

### Output format

One CSV line per run:

```
<instance>;<init>;<nh>;<pivot>;<initial_cost>;<final_cost>;<time_s>
```

Neighbourhood codes: `0`=Transpose, `1`=Exchange, `2`=Insert, `3`=VND-TEI, `4`=VND-TIE
Init codes: `0`=Random, `1`=CW
Pivot codes: `0`=First, `1`=Best

## Running all experiments

From the project root:

```bash
bash analysis/auto_run.sh
```

Results are written to `results/results_summary.csv`.
