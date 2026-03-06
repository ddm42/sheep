#!/bin/bash
# One-off HomRect run (high-resolution). Uses config.sh for paths.
# Usage: ./HomRect.sh

source ~/miniforge/etc/profile.d/conda.sh && conda activate moose

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
LOG_DIR="$REPO_DIR/problems/progress_logs"

mkdir -p "$OUTPUT_DIR" "$LOG_DIR"

nohup mpiexec -n $NUM_PROCS "$SHEEP_EXE" \
  -i "$INPUT_FILE" \
  nx=500 ny=312 my_dt=0.0125e-3 filename="HomRect_h0.16mm_dt0.0125ms" \
  data_dir="$DATA_DIR" \
  > "$LOG_DIR/HomRect_out.txt" 2>&1 &

echo "Started PID: $!"
echo "Log: $LOG_DIR/HomRect_out.txt"
