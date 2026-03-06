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

# Source config
REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
CONFIG="${SHEEP_CONFIG:-$REPO_DIR/config.sh}"
if [ ! -f "$CONFIG" ]; then
    echo "Error: config.sh not found. Create it from the template:"
    echo "  cp config_temp.sh config.sh"
    exit 1
fi
source "$CONFIG"

INPUT_FILE="${1:-${REPO_DIR}/problems/Lesion/Lesion-DirBC.i}"

# Validate
if [ ! -f "$INPUT_FILE" ]; then
    echo "ERROR: Input file not found: $INPUT_FILE"
    exit 1
fi

PROBLEM_NAME=$(basename "$INPUT_FILE" .i)

# Derive output_dir from the .i file's output_dir variable (strip ${data_dir}/ prefix)
SUBDIR=$(grep '^output_dir' "$INPUT_FILE" | head -1 | sed "s/.*{data_dir}\///" | sed "s/'.*//")
OUTPUT_DIR="$DATA_DIR/$SUBDIR"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"

mkdir -p "$OUTPUT_DIR" "$LOG_DIR"

timestamp() { date '+%Y-%m-%d %H:%M:%S'; }

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
TOTAL=${#DT_VALS[@]}

echo "[$(timestamp)] ${PROBLEM_NAME} Timestep Convergence Study"
echo "  Input file: ${INPUT_FILE}"
echo "  Mesh type: ${MESH_TYPE}"
echo "  End time: ${END_TIME} s"
echo "  Output dir: ${OUTPUT_DIR}"
echo "  Log dir: ${LOG_DIR}"

# Build fixed-mesh CLI args based on mesh type
if [ "$MESH_TYPE" = "conformal" ]; then
    MESH_ARGS="desired_area=1.7e-7 n_ellipse=40"
    echo "  Fixed mesh: desired_area=1.7e-7, n_ellipse=40 (h~0.625mm)"
else
    REFINE=2
    MESH_ARGS="refine=$REFINE"
    echo "  Fixed mesh: ${BASE_MESH} + refine=${REFINE} (h~0.625mm)"
fi
echo "  Runs: ${TOTAL} timestep levels"

# Allow running a single level
if [ -n "$2" ]; then
    START=$2; END=$2
else
    START=0; END=$(( TOTAL - 1 ))
fi

SECONDS=0

for i in $(seq $START $END); do
    dt=${DT_VALS[$i]}
    label=${LABELS[$i]}
    suffix="_h0.625mm_${label}"
    RUN_LOG="$LOG_DIR/${BASE_MESH}${suffix}.log"

    echo ""
    echo "[$(timestamp)] === Run $((i+1))/${TOTAL}: dt = ${dt} s ==="
    echo "  MOOSE log: ${RUN_LOG}"

    RUN_SECONDS=$SECONDS

    mpiexec -n $NUM_PROCS "$SHEEP_EXE" -i "$INPUT_FILE" \
        filename="$BASE_MESH" $MESH_ARGS my_dt="$dt" \
        end_time="$END_TIME" suffix="$suffix" \
        data_dir="$DATA_DIR" > "$RUN_LOG" 2>&1

    EXIT_CODE=$?
    ELAPSED=$(( SECONDS - RUN_SECONDS ))
    ELAPSED_MIN=$(awk "BEGIN {printf \"%.1f\", $ELAPSED/60}")

    if [ $EXIT_CODE -eq 0 ]; then
        echo "[$(timestamp)] PASS: ${BASE_MESH}${suffix} (${ELAPSED_MIN} min)"
    else
        echo "[$(timestamp)] FAIL: ${BASE_MESH}${suffix} (exit code ${EXIT_CODE}, ${ELAPSED_MIN} min)"
    fi
done

TOTAL_MIN=$(awk "BEGIN {printf \"%.1f\", $SECONDS/60}")
echo ""
echo "[$(timestamp)] All runs completed. Total walltime: ${TOTAL_MIN} min"
