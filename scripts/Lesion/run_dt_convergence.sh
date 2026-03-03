#!/bin/bash
###############################################################################
# run_dt_convergence.sh -- Timestep convergence study for Lesion problems
#
# Fixed mesh: Lesion_h2.50mm.e with uniform_refine=2 (h ~ 0.625mm)
# Varies dt in halving steps.
# Convergence metrics: strain_energy, disp_z at 4 sample points (from CSV).
#
# Physics: c_s_B = 5.0 m/s, f_max = 1500 Hz
# dt levels chosen to span 5-43 samples/period at f_max.
#
# Usage:
#   ./run_dt_convergence.sh                          # Lesion-DirBC, all levels
#   ./run_dt_convergence.sh /path/to/Lesion_25_9.i   # different problem, all levels
#   ./run_dt_convergence.sh /path/to/Lesion_25_9.i 2 # different problem, level 2 only
###############################################################################

# Initialize conda
source ~/miniforge/etc/profile.d/conda.sh && conda activate moose

# Paths
SHEEP_DIR="/Users/ddm42/projects/sheep"
SHEEP_EXE="${SHEEP_DIR}/sheep-opt"
INPUT_FILE="${1:-${SHEEP_DIR}/problems/Lesion/Lesion-DirBC.i}"
NUM_PROCS=6

# Derive output dir from the .i file's file_base line
OUTPUT_DIR=$(grep 'file_base' "$INPUT_FILE" | head -1 | sed 's/.*"\(.*\)\/${.*/\1/')

# Validate
if [ ! -f "$INPUT_FILE" ]; then
    echo "ERROR: Input file not found: $INPUT_FILE"
    exit 1
fi

PROBLEM_NAME=$(basename "$INPUT_FILE" .i)

# Create output directory if needed
mkdir -p "$OUTPUT_DIR"

# Fixed mesh: base mesh + refine=2 (h ~ 0.625mm)
BASE_MESH="Lesion_h2.50mm"
REFINE=2

# End time
END_TIME="10e-3"

# Timestep levels (halving each time)
DT_VALS=(   "0.125e-3"    "0.0625e-3"    "0.03125e-3"    "0.015625e-3"  )
LABELS=(    "dt0.125ms"    "dt0.0625ms"   "dt0.03125ms"   "dt0.015625ms" )

echo "================================================="
echo "${PROBLEM_NAME} Timestep Convergence Study"
echo "================================================="
echo "  Input file: ${INPUT_FILE}"
echo "  Fixed mesh: ${BASE_MESH} + refine=${REFINE} (h~0.625mm)"
echo "  End time: ${END_TIME} s"
echo "  Output dir: ${OUTPUT_DIR}"
echo ""

# Allow running a single level: ./run_dt_convergence.sh <input_file> <level>
if [ -n "$2" ]; then
    START=$2; END=$2
else
    START=0; END=$(( ${#DT_VALS[@]} - 1 ))
fi

for i in $(seq $START $END); do
    dt=${DT_VALS[$i]}
    label=${LABELS[$i]}
    suffix="_h0.625mm_${label}"

    echo "-----------------------------------------"
    echo "Run $((i+1))/${#DT_VALS[@]}: dt = ${dt} s"
    echo "Output suffix: ${suffix}"
    echo "-----------------------------------------"

    mpiexec -n $NUM_PROCS "$SHEEP_EXE" -i "$INPUT_FILE" \
        filename="$BASE_MESH" refine="$REFINE" my_dt="$dt" \
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
