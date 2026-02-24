#!/bin/bash
###############################################################################
# run_dt_convergence.sh -- Timestep convergence study for RectsLR
#
# Runs RectsLR.i with progressively smaller timesteps on a fixed mesh.
# Uses h=1.25mm (nx=64, ny=40) so spatial error is small relative to
# temporal error at the coarser timesteps.
#
# Usage:
#   ./run_dt_convergence.sh            # run all timestep levels
#   ./run_dt_convergence.sh 2          # run only level 2
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

# Fixed mesh: h=1.25mm
NX=64
NY=40

# Timestep levels (halving each time)
DT_VALS=(   "0.50e-3"   "0.25e-3"   "0.125e-3"   "0.0625e-3"  )
LABELS=(    "dt0.500ms"  "dt0.250ms"  "dt0.125ms"   "dt0.0625ms" )

echo "========================================="
echo "RectsLR Timestep Convergence Study"
echo "========================================="
echo "  Fixed mesh: nx=${NX}, ny=${NY} (h=1.25mm)"
echo "  Output dir: ${OUTPUT_DIR}"
echo ""

# Allow running a single level: ./run_dt_convergence.sh <level>
if [ -n "$1" ]; then
    START=$1; END=$1
else
    START=0; END=$(( ${#DT_VALS[@]} - 1 ))
fi

for i in $(seq $START $END); do
    dt=${DT_VALS[$i]}
    label=${LABELS[$i]}
    filename="RectsLR_h1.25mm_${label}"

    echo "-----------------------------------------"
    echo "Run $((i+1))/${#DT_VALS[@]}: dt = ${dt} s"
    echo "Filename: ${filename}"
    echo "-----------------------------------------"

    mpiexec -n $NUM_PROCS "$SHEEP_EXE" -i "$INPUT_FILE" \
        nx="$NX" ny="$NY" my_dt="$dt" filename="$filename" -w

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
