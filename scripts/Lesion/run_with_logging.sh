#!/bin/bash
# Wrapper script to run lesion batch processing with logging
# Usage: ./run_with_logging.sh

REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
LOG_DIR="$REPO_DIR/problems/progress_logs"

mkdir -p "$LOG_DIR"

log_date=$(date '+%Y%m%d_%H%M%S')
log_file="$LOG_DIR/progress_log_${log_date}.txt"

echo "Starting lesion batch processing..."
echo "Log file: $log_file"

"$REPO_DIR/problems/run_lesion_batch.sh" 2>&1 | tee "$log_file"

echo "Batch processing completed. Log saved to: $log_file"
