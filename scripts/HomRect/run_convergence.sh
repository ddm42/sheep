#!/bin/bash
###############################################################################
# run_convergence.sh -- Mesh refinement convergence study for HomRect
#
# Runs HomRect.i with progressively finer element sizes.
# Convergence metric: displacement L2-in-time error (from CSV output).
#
# Usage:
#   ./run_convergence.sh            # run all refinement levels
#   ./run_convergence.sh 2          # run only refinement level 2
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

INPUT_FILE="$REPO_DIR/problems/HomRect/HomRect.i"
OUTPUT_DIR="$DATA_DIR/HomRect/exodus"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"

mkdir -p "$OUTPUT_DIR" "$LOG_DIR"

timestamp() { date '+%Y-%m-%d %H:%M:%S'; }

# Refinement levels: nx | ny | h label (mm) for filename
# Domain: 0.08 m (x) x 0.05 m (y); each level halves h
NX_VALS=(   16       32       64       128      )
NY_VALS=(   10       20       40       80       )
LABELS=(    "5.00"   "2.50"   "1.25"   "0.625"  )
TOTAL=${#NX_VALS[@]}

# Fixed timestep for spatial convergence study
DT="0.03125e-3"
END_TIME="10e-3"

echo "[$(timestamp)] HomRect Mesh Refinement Convergence Study"
echo "  Timestep (fixed): dt = ${DT} s"
echo "  End time: ${END_TIME} s"
echo "  Output dir: ${OUTPUT_DIR}"
echo "  Log dir: ${LOG_DIR}"
echo "  Runs: ${TOTAL} refinement levels"

# Allow running a single level: ./run_convergence.sh <level>
if [ -n "$1" ]; then
    START=$1; END=$1
else
    START=0; END=$(( TOTAL - 1 ))
fi

SECONDS=0

for i in $(seq $START $END); do
    nx=${NX_VALS[$i]}
    ny=${NY_VALS[$i]}
    label=${LABELS[$i]}
    suffix="_h${label}mm"
    RUN_LOG="$LOG_DIR/HomRect${suffix}.log"

    echo ""
    echo "[$(timestamp)] === Run $((i+1))/${TOTAL}: h = ${label} mm (nx=${nx}, ny=${ny}, dt=${DT}) ==="
    echo "  MOOSE log: ${RUN_LOG}"

    RUN_SECONDS=$SECONDS

    mpiexec -n $NUM_PROCS "$SHEEP_EXE" -i "$INPUT_FILE" \
        nx="$nx" ny="$ny" my_dt="$DT" end_time="$END_TIME" \
        filename="HomRect" suffix="$suffix" \
        data_dir="$DATA_DIR" > "$RUN_LOG" 2>&1

    EXIT_CODE=$?
    ELAPSED=$(( SECONDS - RUN_SECONDS ))
    ELAPSED_MIN=$(awk "BEGIN {printf \"%.1f\", $ELAPSED/60}")

    if [ $EXIT_CODE -eq 0 ]; then
        echo "[$(timestamp)] PASS: HomRect${suffix} (${ELAPSED_MIN} min)"
    else
        echo "[$(timestamp)] FAIL: HomRect${suffix} (exit code ${EXIT_CODE}, ${ELAPSED_MIN} min)"
    fi
done

TOTAL_MIN=$(awk "BEGIN {printf \"%.1f\", $SECONDS/60}")
echo ""
echo "[$(timestamp)] All runs completed. Total walltime: ${TOTAL_MIN} min"
echo ""
echo "CSV files at: ${OUTPUT_DIR}/HomRect_h*.csv"
echo "MOOSE logs at: ${LOG_DIR}/HomRect_h*.log"
