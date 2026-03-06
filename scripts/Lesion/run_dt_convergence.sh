#!/bin/bash
###############################################################################
# run_dt_convergence.sh -- Timestep convergence study for Lesion problems
#
# Supports two mesh types:
#   - Conformal (XYDelaunayGenerator): uses desired_area + n_ellipse
#   - Structured (GeneratedMeshGenerator): uses refine level
# Auto-detected from the input file. Fixed mesh at production resolution.
#
# Varies dt in halving steps.
# Convergence metrics: strain_energy, avg_disp_y (from CSV postprocessors).
#
# Usage:
#   ./run_dt_convergence.sh                              # Lesion-DirBC, all levels
#   ./run_dt_convergence.sh /path/to/Lesion_TopRight.i   # conformal mesh problem
#   ./run_dt_convergence.sh /path/to/problem.i 2         # single level only
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

# Derive base mesh name from the .i file's 'filename' default
BASE_MESH=$(grep '^filename' "$INPUT_FILE" | head -1 | sed 's/.*= *"\(.*\)".*/\1/')

# Detect mesh type: conformal (desired_area) vs structured (refine/nx/ny)
if grep -q '^desired_area' "$INPUT_FILE"; then
    MESH_TYPE="conformal"
else
    MESH_TYPE="structured"
fi

# End time
END_TIME="10e-3"

# Timestep levels (halving each time)
DT_VALS=(   "0.125e-3"    "0.0625e-3"    "0.03125e-3"    "0.015625e-3"  )
LABELS=(    "dt0.125ms"    "dt0.0625ms"   "dt0.03125ms"   "dt0.015625ms" )

echo "================================================="
echo "${PROBLEM_NAME} Timestep Convergence Study"
echo "================================================="
echo "  Input file: ${INPUT_FILE}"
echo "  Mesh type: ${MESH_TYPE}"
echo "  End time: ${END_TIME} s"
echo "  Output dir: ${OUTPUT_DIR}"

# Build the fixed-mesh CLI args based on mesh type
if [ "$MESH_TYPE" = "conformal" ]; then
    # Production resolution for conformal mesh: h ~ 0.625mm
    MESH_ARGS="desired_area=1.7e-7 n_ellipse=40"
    echo "  Fixed mesh: desired_area=1.7e-7, n_ellipse=40 (h~0.625mm)"
else
    # Production resolution for structured mesh: refine=2
    REFINE=2
    MESH_ARGS="refine=$REFINE"
    echo "  Fixed mesh: ${BASE_MESH} + refine=${REFINE} (h~0.625mm)"
fi
echo ""

# Allow running a single level
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
        filename="$BASE_MESH" $MESH_ARGS my_dt="$dt" \
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
