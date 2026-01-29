#!/bin/bash

# Wrapper script to run lesion batch processing with logging
# Usage: ./run_with_logging.sh

# Create progress_logs directory if it doesn't exist
mkdir -p /Users/ddm42/projects/sheep/problems/progress_logs

# Generate date string for log file
log_date=$(date '+%Y%m%d_%H%M%S')
log_file="/Users/ddm42/projects/sheep/problems/progress_logs/progress_log_${log_date}.txt"

echo "Starting lesion batch processing..."
echo "Log file: $log_file"

# Run the batch script and redirect all output to log file
/Users/ddm42/projects/sheep/problems/run_lesion_batch.sh 2>&1 | tee "$log_file"

echo "Batch processing completed. Log saved to: $log_file"