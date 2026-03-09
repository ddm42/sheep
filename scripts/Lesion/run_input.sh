#!/bin/bash
###############################################################################
# run_input.sh -- Run a single MOOSE input file with config.sh paths
#
# Runs in the background by default. Use --fg to run in foreground.
#
# Usage:
#   ./run_input.sh Lesion_TopRight.i                   # run in background
#   ./run_input.sh Lesion_TopCorners.i end_time=20e-3  # override parameters
#   ./run_input.sh --fg Lesion_TopRight.i              # run in foreground
#
# Any extra arguments after the input file are passed directly to MOOSE as
# command-line parameter overrides (key=value pairs).
#
# Output goes to the data_dir defined in config.sh. MOOSE console output
# goes to a log file in scripts/Lesion/logs/.
#
# Monitor progress:
#   tail -f <log file>
###############################################################################

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

# Check for --fg flag
FOREGROUND=false
if [ "$1" = "--fg" ]; then
    FOREGROUND=true
    shift
fi

# First argument is the input file (can be just a name or a full path)
INPUT_ARG="${1:?Usage: $0 [--fg] <input_file.i> [key=value ...]}"
shift

# Resolve input file path: check as-is, then in problems/Lesion/
if [ -f "$INPUT_ARG" ]; then
    INPUT_FILE="$INPUT_ARG"
elif [ -f "$REPO_DIR/problems/Lesion/$INPUT_ARG" ]; then
    INPUT_FILE="$REPO_DIR/problems/Lesion/$INPUT_ARG"
else
    echo "Error: Input file not found: $INPUT_ARG"
    echo "  Looked in: ./ and $REPO_DIR/problems/Lesion/"
    exit 1
fi

PROBLEM_NAME=$(basename "$INPUT_FILE" .i)

# Setup log directory
LOG_DIR="$(cd "$(dirname "$0")" && pwd)/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/${PROBLEM_NAME}_$(date '+%Y%m%d_%H%M%S').log"

echo "=== run_input.sh ==="
echo "  Input:    $INPUT_FILE"
echo "  Procs:    $NUM_PROCS"
echo "  Data dir: $DATA_DIR"
echo "  Log:      $LOG_FILE"
echo "  Overrides: $*"
echo ""

if [ "$FOREGROUND" = true ]; then
    mpiexec -n "$NUM_PROCS" "$SHEEP_EXE" -i "$INPUT_FILE" \
        data_dir="$DATA_DIR" "$@" \
        > "$LOG_FILE" 2>&1

    EXIT_CODE=$?
    if [ $EXIT_CODE -eq 0 ]; then
        echo "SUCCESS ($PROBLEM_NAME)"
    else
        echo "FAILED ($PROBLEM_NAME, exit code $EXIT_CODE)"
        echo "  Check log: $LOG_FILE"
    fi
else
    nohup mpiexec -n "$NUM_PROCS" "$SHEEP_EXE" -i "$INPUT_FILE" \
        data_dir="$DATA_DIR" "$@" \
        > "$LOG_FILE" 2>&1 &

    echo "Running in background (PID $!)"
    echo "  Monitor: tail -f $LOG_FILE"
fi
