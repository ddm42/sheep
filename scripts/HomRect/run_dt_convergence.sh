#!/bin/bash
###############################################################################
# run_dt_convergence.sh -- Timestep convergence study for HomRect
#
# Runs HomRect.i with progressively smaller timesteps on a fixed mesh.
# Uses h=1.25mm (nx=64, ny=40) so spatial error is small relative to
# temporal error at the coarser timesteps.
#
# Usage:
#   ./run_dt_convergence.sh            # run all timestep levels
#   ./run_dt_convergence.sh 2          # run only level 2
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

# Fixed mesh: h=1.25mm
NX=64
NY=40

# End time (match spatial convergence study)
END_TIME="10e-3"

# Timestep levels (halving each time)
DT_VALS=(   "0.125e-3"    "0.0625e-3"    "0.03125e-3"    "0.015625e-3"  )
LABELS=(    "dt0.125ms"    "dt0.0625ms"   "dt0.03125ms"   "dt0.015625ms" )
TOTAL=${#DT_VALS[@]}

echo "[$(timestamp)] HomRect Timestep Convergence Study"
echo "  Fixed mesh: nx=${NX}, ny=${NY} (h=1.25mm)"
echo "  End time: ${END_TIME} s"
echo "  Output dir: ${OUTPUT_DIR}"
echo "  Log dir: ${LOG_DIR}"
echo "  Runs: ${TOTAL} timestep levels"

# Allow running a single level: ./run_dt_convergence.sh <level>
if [ -n "$1" ]; then
    START=$1; END=$1
else
    START=0; END=$(( TOTAL - 1 ))
fi

SECONDS=0

for i in $(seq $START $END); do
    dt=${DT_VALS[$i]}
    label=${LABELS[$i]}
    suffix="_h1.25mm_${label}"
    RUN_LOG="$LOG_DIR/HomRect${suffix}.log"

    echo ""
    echo "[$(timestamp)] === Run $((i+1))/${TOTAL}: dt = ${dt} s (nx=${NX}, ny=${NY}) ==="
    echo "  MOOSE log: ${RUN_LOG}"

    RUN_SECONDS=$SECONDS

    mpiexec -n $NUM_PROCS "$SHEEP_EXE" -i "$INPUT_FILE" \
        nx="$NX" ny="$NY" my_dt="$dt" end_time="$END_TIME" \
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
echo "CSV files at: ${OUTPUT_DIR}/HomRect_h1.25mm_dt*.csv"
echo "MOOSE logs at: ${LOG_DIR}/HomRect_h1.25mm_dt*.log"
