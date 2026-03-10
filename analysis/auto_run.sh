#!/bin/bash
# Run all LOP experiments and save results to results/
# Usage: bash analysis/auto_run.sh  (from project root)

BASE="$(cd "$(dirname "$0")/.." && pwd)"
CODE_DIR="$BASE/code"
EXE="$CODE_DIR/lop"
INSTANCE_DIR="$CODE_DIR/instances"
OUTPUT_FILE="$BASE/results/results_summary.csv"

if [ ! -f "$EXE" ]; then
    echo "Error: binary not found. Compile first: cd code && make"
    exit 1
fi

echo "Instance;Init;Neighborhood;Pivot;InitialCost;FinalCost;Time" > "$OUTPUT_FILE"
echo "Starting experiments..."

instances=$(ls "$INSTANCE_DIR" | grep -E "150|250")

# --- Exercise 1.1 : 12 configurations ---
pivots=("first" "best")
neighborhoods=("transpose" "exchange" "insert")
inits=("random" "cw")

for inst in $instances; do
    echo "Processing: $inst"
    for init in "${inits[@]}"; do
        for nh in "${neighborhoods[@]}"; do
            for pivot in "${pivots[@]}"; do
                "$EXE" -i "$INSTANCE_DIR/$inst" --$init --$nh --$pivot >> "$OUTPUT_FILE"
            done
        done
    done
done

# --- Exercise 1.2 : VND (CW init only) ---
vnd_variants=("vnd-tei" "vnd-tie")

echo "Processing VND..."
for inst in $instances; do
    echo "  VND: $inst"
    for vnd in "${vnd_variants[@]}"; do
        "$EXE" -i "$INSTANCE_DIR/$inst" --cw --$vnd >> "$OUTPUT_FILE"
    done
done

echo "Done. Results saved to $OUTPUT_FILE"