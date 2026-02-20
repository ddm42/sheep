#!/bin/bash
###############################################################################
# run_soft_convergence.sh -- Spatial convergence study for Lesion-Soft-ARFCenter
#
# Uses uniform_refine on Lesion_h2.50mm.e base mesh (halves h each level).
# Convergence metric: strain_energy (from CSV output).
#
# Usage:
#   ./run_soft_convergence.sh            # run all refinement levels
#   ./run_soft_convergence.sh 2          # run only refinement level 2
###############################################################################

# Initialize conda
source ~/miniforge/etc/profile.d/conda.sh && conda activate moose

# Paths
SHEEP_EXE="/Users/ddm42/projects/sheep/sheep-opt"
INPUT_FILE="/Users/ddm42/projects/sheep/problems/Lesion/Lesion-Soft-ARFCenter.i"
OUTPUT_DIR="/Users/ddm42/Google Drive/My Drive/1_Work-Duke-Research/Artery_Research/data/artery_OED/Lesion/exodus"
NUM_PROCS=6

# Create output directory if needed
mkdir -p "$OUTPUT_DIR"

# Base mesh file
BASE_MESH="Lesion_h2.50mm"

# Refinement levels: uniform_refine value | effective h label
REFINE_VALS=(   0          1          2          3          )
H_LABELS=(     "h2.50mm"  "h1.25mm"  "h0.625mm" "h0.3125mm")

# Fixed timestep for spatial convergence (small enough that temporal error is negligible)
DT="0.125e-3"
END_TIME="10e-3"

echo "================================================="
echo "Lesion-Soft Spatial Convergence Study"
echo "================================================="
echo "  Base mesh: ${BASE_MESH}"
echo "  Timestep (fixed): dt = ${DT} s"
echo "  End time: ${END_TIME} s"
echo "  Output dir: ${OUTPUT_DIR}"
echo ""

# Allow running a single level: ./run_soft_convergence.sh <level>
if [ -n "$1" ]; then
    START=$1; END=$1
else
    START=0; END=$(( ${#REFINE_VALS[@]} - 1 ))
fi

for i in $(seq $START $END); do
    ref=${REFINE_VALS[$i]}
    label=${H_LABELS[$i]}
    suffix="_soft_${label}"

    echo "-----------------------------------------"
    echo "Run $((i+1))/${#REFINE_VALS[@]}: refine=${ref}, h ~ ${label}"
    echo "Output suffix: ${suffix}"
    echo "-----------------------------------------"

    mpiexec -n $NUM_PROCS "$SHEEP_EXE" -i "$INPUT_FILE" \
        filename="$BASE_MESH" refine="$ref" my_dt="$DT" \
        end_time="$END_TIME" suffix="$suffix" -w

    if [ $? -eq 0 ]; then
        echo "SUCCESS: ${BASE_MESH}${suffix}"
    else
        echo "FAILED: ${BASE_MESH}${suffix}"
    fi
    echo ""
done

echo "================================================="
echo "All runs completed!"
echo "================================================="
echo ""
echo "To extract convergence data (strain_energy):"
echo "  Look in CSV files at: ${OUTPUT_DIR}/${BASE_MESH}_soft_h*.csv"
