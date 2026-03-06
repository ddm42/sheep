#!/bin/bash
# Run a sheep script in the background via nohup.
# Usage: ./run_script.sh path/to/script.sh [args...]

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG="$REPO_DIR/config.sh"

if [ ! -f "$CONFIG" ]; then
    echo "Error: config.sh not found. Create it from the template:"
    echo "  cp config_temp.sh config.sh"
    exit 1
fi

export SHEEP_CONFIG="$CONFIG"

if [ -z "$1" ]; then
    echo "Usage: ./run_script.sh path/to/script.sh [args...]"
    exit 1
fi

SCRIPT_PATH="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
SCRIPT_NAME="$(basename "$1" .sh)"
shift
LOG_DIR="$(dirname "$SCRIPT_PATH")/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/out_${SCRIPT_NAME}.txt"

echo "Running: $SCRIPT_NAME"
echo "Log: $LOG_FILE"

nohup bash "$SCRIPT_PATH" "$@" > "$LOG_FILE" 2>&1 &

echo "Started PID: $!"
