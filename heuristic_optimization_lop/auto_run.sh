#!/bin/bash

EXE="./lop"
INSTANCE_DIR="instances"
OUTPUT_FILE="results_summary.csv"

if [ ! -f "$EXE" ]; then
    echo "Erreur : L'exécutable $EXE est introuvable. Compile avec 'make' d'abord."
    exit 1
fi

echo "Instance;Init;Neighborhood;Pivot;InitialCost;FinalCost;Time" > $OUTPUT_FILE

echo "Démarrage des tests..."

instances=$(ls $INSTANCE_DIR | grep -E "150|250")

# --- 1.1 ---
pivots=("first" "best")
neighborhoods=("transpose" "exchange" "insert")
inits=("random" "cw")

for inst in $instances; do
    echo "Processing Instance: $inst"
    for init in "${inits[@]}"; do
        for nh in "${neighborhoods[@]}"; do
            for pivot in "${pivots[@]}"; do
                $EXE -i "$INSTANCE_DIR/$inst" --$init --$nh --$pivot >> $OUTPUT_FILE
            done
        done
    done
done

# --- EXERCICE 1.2 : VND ---
# Utilise uniquement l'initialisation CW (comme demandé dans l'énoncé)
vnd_variants=("vnd-tei" "vnd-tie")

echo "Processing VND tests..."
for inst in $instances; do
    echo "  VND - Instance: $inst"
    for vnd in "${vnd_variants[@]}"; do
        $EXE -i "$INSTANCE_DIR/$inst" --cw --$vnd >> $OUTPUT_FILE
    done
done

echo "Terminé ! Les résultats sont dans $OUTPUT_FILE"