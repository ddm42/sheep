#!/bin/bash
###############################################################################
# run_input.sh -- Run a single MOOSE input file with config.sh paths
#
# Runs in the background by default. Use --fg to run in foreground.
#
# Usage:
#   ./run_input.sh problems/Lesion/Lesion_TopRight.i
#   ./run_input.sh problems/Lesion/Lesion_TopCorners.i end_time=20e-3
#   ./run_input.sh --fg problems/HomRect/HomRect.i nx=200 ny=125
#
# Any extra arguments after the input file are passed directly to MOOSE as
# command-line parameter overrides (key=value pairs).
#
# Output goes to the data_dir defined in config.sh. MOOSE console output
# goes to a log file in logs/.
#
# Monitor progress:
#   tail -f <log file>
###############################################################################

source ~/miniforge/etc/profile.d/conda.sh && conda activate moose

# Source config
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
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

# First argument is the input file
INPUT_ARG="${1:?Usage: $0 [--fg] <input_file.i> [key=value ...]}"
shift

if [ ! -f "$INPUT_ARG" ]; then
    echo "Error: Input file not found: $INPUT_ARG"
    exit 1
fi
INPUT_FILE="$INPUT_ARG"

PROBLEM_NAME=$(basename "$INPUT_FILE" .i)

# Setup log directory
LOG_DIR="$REPO_DIR/logs"
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
    (
        START_TIME=$(date +%s)
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Started: $PROBLEM_NAME"
        mpiexec -n "$NUM_PROCS" "$SHEEP_EXE" -i "$INPUT_FILE" \
            data_dir="$DATA_DIR" "$@"
        RUN_EXIT=$?
        ELAPSED=$(( $(date +%s) - START_TIME ))
        printf '\n[%s] Finished: %s (exit code %d)\n' \
            "$(date '+%Y-%m-%d %H:%M:%S')" "$PROBLEM_NAME" "$RUN_EXIT"
        printf '  Walltime: %dh %dm %ds\n' \
            "$(( ELAPSED / 3600 ))" "$(( (ELAPSED % 3600) / 60 ))" "$(( ELAPSED % 60 ))"
        exit $RUN_EXIT
    ) > "$LOG_FILE" 2>&1

    EXIT_CODE=$?
    if [ $EXIT_CODE -eq 0 ]; then
        echo "SUCCESS ($PROBLEM_NAME)"
    else
        echo "FAILED ($PROBLEM_NAME, exit code $EXIT_CODE)"
        echo "  Check log: $LOG_FILE"
    fi
else
    nohup bash -c '
        START_TIME=$(date +%s)
        echo "[$(date "+%Y-%m-%d %H:%M:%S")] Started: $4"
        mpiexec -n "$1" "$2" -i "$3" data_dir="$5" "${@:6}" &
        MPI_PID=$!
        echo "  mpiexec PID: $MPI_PID"
        # Forward SIGTERM (not SIGINT: async children inherit SIGINT ignored) so
        # mpiexec tears down its ranks when the wrapper is killed.
        trap "kill -TERM $MPI_PID 2>/dev/null" INT TERM
        # wait returns 128+signum when interrupted by the trap; loop until the
        # child is actually reaped so RUN_EXIT and the walltime reflect the real exit
        wait $MPI_PID
        RUN_EXIT=$?
        while kill -0 $MPI_PID 2>/dev/null; do wait $MPI_PID; RUN_EXIT=$?; done
        ELAPSED=$(( $(date +%s) - START_TIME ))
        printf "\n[%s] Finished: %s (exit code %d)\n" \
            "$(date "+%Y-%m-%d %H:%M:%S")" "$4" "$RUN_EXIT"
        printf "  Walltime: %dh %dm %ds\n" \
            "$(( ELAPSED / 3600 ))" "$(( (ELAPSED % 3600) / 60 ))" "$(( ELAPSED % 60 ))"
    ' _ "$NUM_PROCS" "$SHEEP_EXE" "$INPUT_FILE" "$PROBLEM_NAME" "$DATA_DIR" "$@" \
        > "$LOG_FILE" 2>&1 &

    echo "Running in background (wrapper PID $!)"
    echo "  Monitor: tail -f $LOG_FILE"
    echo "  Cancel:  kill $!   (forwards SIGTERM to mpiexec; walltime still logged)"
fi
