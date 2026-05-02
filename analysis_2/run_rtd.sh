#!/bin/bash
# =============================================================
#  Phase 2 only — RTD with intermediate logging
#  Usage:  bash analysis_2/run_rtd.sh   (from project root)
# =============================================================

set -e

BASE="$(cd "$(dirname "$0")/.." && pwd)"
CODE_DIR="$BASE/code"
EXE="$CODE_DIR/lop"
INSTANCE_DIR="$CODE_DIR/instances"
RESULTS_DIR="$BASE/results_2"
RTD_TRACES="$RESULTS_DIR/rtd_traces"

mkdir -p "$RTD_TRACES"

# Recompile
echo "Compiling..."
(cd "$CODE_DIR" && make clean && make)

# Measure VND time on this machine
echo ""
echo "Measuring VND time..."
VND_CSV=$(mktemp)
echo "Instance;Init;NH;Pivot;InitCost;FinalCost;Time" > "$VND_CSV"

INSTANCES_150=($(ls "$INSTANCE_DIR" | grep "_150$" | sort))
for inst in "${INSTANCES_150[@]}"; do
    "$EXE" -i "$INSTANCE_DIR/$inst" --cw --vnd-tie >> "$VND_CSV"
done

AVG_VND=$(awk -F';' 'NR>1 { sum += $7; n++ } END { printf "%.6f", sum/n }' "$VND_CSV")
TIME_LIMIT=$(awk "BEGIN { printf \"%.2f\", $AVG_VND * 500 }")
RTD_CUTOFF=$(awk "BEGIN { printf \"%.2f\", $AVG_VND * 5000 }")
rm -f "$VND_CSV"

echo "  Average VND time : ${AVG_VND}s"
echo "  Time limit (x500): ${TIME_LIMIT}s"
echo "  RTD cutoff (x5000): ${RTD_CUTOFF}s"

# Update config
cat > "$RESULTS_DIR/config.txt" <<EOF
AVG_VND=$AVG_VND
TIME_LIMIT=$TIME_LIMIT
RTD_CUTOFF=$RTD_CUTOFF
N_INSTANCES=${#INSTANCES_150[@]}
EOF

# RTD CSV (summary: one line per run with final cost)
RTD_CSV="$RESULTS_DIR/rtd_results.csv"
echo "Instance;Algo;Seed;FinalCost;Time" > "$RTD_CSV"

# First 2 instances
RTD_INSTANCES=("${INSTANCES_150[0]}" "${INSTANCES_150[1]}")

echo ""
echo "=========================================="
echo " RTD: 25 seeds x 2 algos x 2 instances"
echo " Cutoff: ${RTD_CUTOFF}s per run"
echo "=========================================="

TOTAL_RUNS=$((2 * 2 * 25))
RUN=0

for inst in "${RTD_INSTANCES[@]}"; do
    echo ""
    echo "  Instance: $inst"
    for seed in $(seq 1 25); do
        # SA
        RUN=$((RUN + 1))
        TRACE_FILE="$RTD_TRACES/${inst}_SA_seed${seed}.csv"
        echo "    [$RUN/$TOTAL_RUNS] SA  seed=$seed"
        "$EXE" -i "$INSTANCE_DIR/$inst" --cw --sa \
               --time "$RTD_CUTOFF" --seed "$seed" \
               --rtd-log "$TRACE_FILE" \
            | awk -F';' -v inst="$inst" -v algo="SA" -v seed="$seed" \
              '{ printf "%s;%s;%s;%s;%s\n", inst, algo, seed, $6, $7 }' \
            >> "$RTD_CSV"

        # ACO
        RUN=$((RUN + 1))
        TRACE_FILE="$RTD_TRACES/${inst}_ACO_seed${seed}.csv"
        echo "    [$RUN/$TOTAL_RUNS] ACO seed=$seed"
        "$EXE" -i "$INSTANCE_DIR/$inst" --aco \
               --time "$RTD_CUTOFF" --seed "$seed" \
               --rtd-log "$TRACE_FILE" \
            | awk -F';' -v inst="$inst" -v algo="ACO" -v seed="$seed" \
              '{ printf "%s;%s;%s;%s;%s\n", inst, algo, seed, $6, $7 }' \
            >> "$RTD_CSV"
    done
done

echo ""
echo "=========================================="
echo " RTD DONE"
echo "=========================================="
echo "Results:"
echo "  - $RTD_CSV (summary)"
echo "  - $RTD_TRACES/ (per-run traces)"
echo ""
echo "Total runs: $RUN"
