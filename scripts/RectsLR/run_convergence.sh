#!/bin/bash
###############################################################################
# run_convergence.sh -- Mesh refinement convergence study for RectsLR
#
# Runs RectsLR.i with progressively finer element sizes.
# Convergence metric: strain_energy at t = 6 ms (from CSV output).
#
# Usage:
#   ./run_convergence.sh            # run all refinement levels
#   ./run_convergence.sh 2          # run only refinement level 2
###############################################################################

# Initialize conda
source ~/miniforge/etc/profile.d/conda.sh && conda activate moose

# Paths
SHEEP_EXE="/Users/ddm42/projects/sheep/sheep-opt"
INPUT_FILE="/Users/ddm42/projects/sheep/problems/RectsLR/RectsLR.i"
OUTPUT_DIR="/Users/ddm42/Google Drive/My Drive/1_Work-Duke-Research/Artery_Research/data/artery_OED/RectsLR/exodus"
NUM_PROCS=6

# Create output directory if needed
mkdir -p "$OUTPUT_DIR"

# Refinement levels: nx | ny | h label (mm) for filename
# Domain: 0.08 m (x) x 0.05 m (y); each level halves h
NX_VALS=(   16       32       64       128      )
NY_VALS=(   10       20       40       80       )
LABELS=(    "5.00"   "2.50"   "1.25"   "0.625"  )

# Fixed timestep for spatial convergence study
DT="0.25e-3"

echo "========================================="
echo "RectsLR Mesh Refinement Convergence Study"
echo "========================================="
echo "  Timestep (fixed): dt = ${DT} s"
echo "  Output dir: ${OUTPUT_DIR}"
echo ""

# Allow running a single level: ./run_convergence.sh <level>
if [ -n "$1" ]; then
    START=$1; END=$1
else
    START=0; END=$(( ${#NX_VALS[@]} - 1 ))
fi

for i in $(seq $START $END); do
    nx=${NX_VALS[$i]}
    ny=${NY_VALS[$i]}
    label=${LABELS[$i]}
    filename="RectsLR_h${label}mm"

    echo "-----------------------------------------"
    echo "Run $((i+1))/${#NX_VALS[@]}: h = ${label} mm, nx = ${nx}, ny = ${ny}"
    echo "Filename: ${filename}"
    echo "-----------------------------------------"

    mpiexec -n $NUM_PROCS "$SHEEP_EXE" -i "$INPUT_FILE" \
        nx="$nx" ny="$ny" my_dt="$DT" filename="$filename" -w

    if [ $? -eq 0 ]; then
        echo "SUCCESS: ${filename}"
    else
        echo "FAILED: ${filename}"
    fi
    echo ""
done

echo "========================================="
echo "All runs completed!"
echo "========================================="
echo ""
echo "To extract convergence data (strain_energy at t = 6 ms):"
echo "  Look in CSV files at: ${OUTPUT_DIR}/RectsLR_h*.csv"
echo "  Find the row where 'time' = 0.006 and read the 'strain_energy' column."
