#!/bin/bash
###############################################################################
# run_convergence.sh -- Spatial convergence study for Lesion problems
#
# Supports two mesh types:
#   - Conformal (XYDelaunayGenerator): varies desired_area and n_ellipse
#   - Structured (GeneratedMeshGenerator): varies refine level
# Auto-detected from the input file.
#
# Convergence metrics: strain_energy, avg_disp_y (from CSV postprocessors).
#
# Physics: c_s_B = 5.0 m/s, f_max = 1500 Hz
# First reflection enters imaging domain at ~10 ms; T_EVAL uses end_time=10ms.
#
# Usage:
#   ./run_convergence.sh                          # Lesion-DirBC, all levels
#   ./run_convergence.sh /path/to/Lesion_TopRight.i   # conformal mesh problem
#   ./run_convergence.sh /path/to/problem.i 2     # single level only
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

# Fixed timestep for spatial convergence
DT="0.03125e-3"
END_TIME="10e-3"

echo "[$(timestamp)] ${PROBLEM_NAME} Spatial Convergence Study"
echo "  Input file: ${INPUT_FILE}"
echo "  Base mesh: ${BASE_MESH}"
echo "  Mesh type: ${MESH_TYPE}"
echo "  Timestep (fixed): dt = ${DT} s"
echo "  End time: ${END_TIME} s"
echo "  Output dir: ${OUTPUT_DIR}"
echo "  Log dir: ${LOG_DIR}"

SECONDS=0

if [ "$MESH_TYPE" = "conformal" ]; then
    AREA_VALS=(    "2.7e-6"    "6.8e-7"    "1.7e-7"    "4.2e-8"    )
    NELLIPSE_VALS=( 10          20          40          80          )
    H_LABELS=(     "h2.50mm"  "h1.25mm"  "h0.625mm" "h0.3125mm")
    TOTAL=${#AREA_VALS[@]}
    echo "  Runs: ${TOTAL} refinement levels"

    if [ -n "$2" ]; then
        START=$2; END=$2
    else
        START=0; END=$(( TOTAL - 1 ))
    fi

    for i in $(seq $START $END); do
        area=${AREA_VALS[$i]}
        nellipse=${NELLIPSE_VALS[$i]}
        label=${H_LABELS[$i]}
        suffix="_${label}"
        RUN_LOG="$LOG_DIR/${BASE_MESH}${suffix}.log"

        echo ""
        echo "[$(timestamp)] === Run $((i+1))/${TOTAL}: desired_area=${area}, n_ellipse=${nellipse}, h ~ ${label} ==="
        echo "  MOOSE log: ${RUN_LOG}"

        RUN_SECONDS=$SECONDS

        mpiexec -n $NUM_PROCS "$SHEEP_EXE" -i "$INPUT_FILE" \
            filename="$BASE_MESH" desired_area="$area" n_ellipse="$nellipse" \
            my_dt="$DT" end_time="$END_TIME" suffix="$suffix" \
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
else
    REFINE_VALS=(   0          1          2          3          )
    H_LABELS=(     "h2.50mm"  "h1.25mm"  "h0.625mm" "h0.3125mm")
    TOTAL=${#REFINE_VALS[@]}
    echo "  Runs: ${TOTAL} refinement levels"

    if [ -n "$2" ]; then
        START=$2; END=$2
    else
        START=0; END=$(( TOTAL - 1 ))
    fi

    for i in $(seq $START $END); do
        ref=${REFINE_VALS[$i]}
        label=${H_LABELS[$i]}
        suffix="_${label}"
        RUN_LOG="$LOG_DIR/${BASE_MESH}${suffix}.log"

        echo ""
        echo "[$(timestamp)] === Run $((i+1))/${TOTAL}: refine=${ref}, h ~ ${label} ==="
        echo "  MOOSE log: ${RUN_LOG}"

        RUN_SECONDS=$SECONDS

        mpiexec -n $NUM_PROCS "$SHEEP_EXE" -i "$INPUT_FILE" \
            filename="$BASE_MESH" refine="$ref" my_dt="$DT" \
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
fi

TOTAL_MIN=$(awk "BEGIN {printf \"%.1f\", $SECONDS/60}")
echo ""
echo "[$(timestamp)] All runs completed. Total walltime: ${TOTAL_MIN} min"
echo ""
echo "CSV files at: ${OUTPUT_DIR}/${BASE_MESH}_h*.csv"
echo "MOOSE logs at: ${LOG_DIR}/${BASE_MESH}_h*.log"
