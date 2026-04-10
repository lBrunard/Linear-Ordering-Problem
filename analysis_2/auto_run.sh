#!/bin/bash
# =============================================================
#  INFO-H-413 — Implementation Exercise 2
#  Run all SLS experiments (SA + ACO) on size-150 instances
#  Usage:  bash analysis_2/auto_run.sh   (from project root)
# =============================================================

set -e

BASE="$(cd "$(dirname "$0")/.." && pwd)"
CODE_DIR="$BASE/code"
EXE="$CODE_DIR/lop"
INSTANCE_DIR="$CODE_DIR/instances"
BK_FILE="$CODE_DIR/best_known/best_known.txt"
RESULTS_DIR="$BASE/results_2"

mkdir -p "$RESULTS_DIR"

if [ ! -f "$EXE" ]; then
    echo "Binary not found. Compiling..."
    (cd "$CODE_DIR" && make clean && make)
fi

# ---- collect size-150 instances (sorted) ----
INSTANCES_150=($(ls "$INSTANCE_DIR" | grep "_150$" | sort))
N_INST=${#INSTANCES_150[@]}
echo "Found $N_INST instances of size 150."

# =============================================================
#  PHASE 0 — Measure average VND time on size-150 instances
# =============================================================
echo ""
echo "=========================================="
echo " PHASE 0: Measuring VND-TIE time (CW)"
echo "=========================================="

VND_CSV="$RESULTS_DIR/vnd_times.csv"
echo "Instance;Init;NH;Pivot;InitCost;FinalCost;Time" > "$VND_CSV"

for inst in "${INSTANCES_150[@]}"; do
    echo "  VND: $inst"
    "$EXE" -i "$INSTANCE_DIR/$inst" --cw --vnd-tie >> "$VND_CSV"
done

# compute average VND time
AVG_VND=$(awk -F';' 'NR>1 { sum += $7; n++ } END { printf "%.6f", sum/n }' "$VND_CSV")
TIME_LIMIT=$(awk "BEGIN { printf \"%.2f\", $AVG_VND * 500 }")
RTD_CUTOFF=$(awk "BEGIN { printf \"%.2f\", $AVG_VND * 5000 }")

echo ""
echo "  Average VND time : ${AVG_VND}s"
echo "  Time limit (x500): ${TIME_LIMIT}s"
echo "  RTD cutoff (x5000): ${RTD_CUTOFF}s"
echo ""

# save config for R scripts
cat > "$RESULTS_DIR/config.txt" <<EOF
AVG_VND=$AVG_VND
TIME_LIMIT=$TIME_LIMIT
RTD_CUTOFF=$RTD_CUTOFF
N_INSTANCES=$N_INST
EOF

# =============================================================
#  PHASE 1 — Run SA and ACO once on each size-150 instance
# =============================================================
echo "=========================================="
echo " PHASE 1: SLS runs (SA + ACO)"
echo "=========================================="

SLS_CSV="$RESULTS_DIR/sls_results.csv"
echo "Instance;Init;Algo;Pivot;InitCost;FinalCost;Time" > "$SLS_CSV"

for inst in "${INSTANCES_150[@]}"; do
    echo "  SA  : $inst"
    "$EXE" -i "$INSTANCE_DIR/$inst" --cw --sa --time "$TIME_LIMIT" >> "$SLS_CSV"

    echo "  ACO : $inst"
    "$EXE" -i "$INSTANCE_DIR/$inst" --aco --time "$TIME_LIMIT" >> "$SLS_CSV"
done

echo ""
echo "Phase 1 done. Results in $SLS_CSV"
echo ""

# =============================================================
#  PHASE 2 — Run-Time Distributions (first 2 instances, 25 runs)
# =============================================================
echo "=========================================="
echo " PHASE 2: RTD (25 runs, 2 instances)"
echo "=========================================="

RTD_CSV="$RESULTS_DIR/rtd_results.csv"
echo "Instance;Algo;Seed;FinalCost;Time" > "$RTD_CSV"

# first 2 instances of size 150
RTD_INSTANCES=("${INSTANCES_150[0]}" "${INSTANCES_150[1]}")

for inst in "${RTD_INSTANCES[@]}"; do
    echo "  RTD instance: $inst"
    for seed in $(seq 1 25); do
        # SA
        echo "    SA  seed=$seed"
        "$EXE" -i "$INSTANCE_DIR/$inst" --cw --sa \
               --time "$RTD_CUTOFF" --seed "$seed" \
            | awk -F';' -v inst="$inst" -v algo="SA" -v seed="$seed" \
              '{ printf "%s;%s;%s;%s;%s\n", inst, algo, seed, $6, $7 }' \
            >> "$RTD_CSV"

        # ACO
        echo "    ACO seed=$seed"
        "$EXE" -i "$INSTANCE_DIR/$inst" --aco \
               --time "$RTD_CUTOFF" --seed "$seed" \
            | awk -F';' -v inst="$inst" -v algo="ACO" -v seed="$seed" \
              '{ printf "%s;%s;%s;%s;%s\n", inst, algo, seed, $6, $7 }' \
            >> "$RTD_CSV"
    done
done

echo ""
echo "Phase 2 done. Results in $RTD_CSV"
echo ""
echo "=========================================="
echo " ALL DONE"
echo "=========================================="
echo "Results saved in: $RESULTS_DIR/"
echo "  - vnd_times.csv     (VND timing)"
echo "  - sls_results.csv   (SA + ACO main runs)"
echo "  - rtd_results.csv   (RTD data)"
echo "  - config.txt        (time parameters)"
echo ""
echo "Next: run the R analysis scripts:"
echo "  Rscript analysis_2/statistical_tests.R"
echo "  Rscript analysis_2/generate_plots.R"
