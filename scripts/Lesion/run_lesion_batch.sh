#!/bin/bash

# Bash script to run MOOSE lesion simulations with different mesh files
# Usage: ./run_lesion_batch.sh

# Initialize conda environment
source ~/miniforge/etc/profile.d/conda.sh && conda activate moose

# Define list of filenames to process
filenames=(
    "Lesion_h2.50mm"
    "Lesion_h1.25mm"
    "Lesion_h.625mm"
    "Lesion_h.250mm"
    "Lesion_h.125mm"
)

# MOOSE executable and input file paths
SHEEP_EXE="/Users/ddm42/projects/sheep/sheep-opt"
INPUT_FILE="/Users/ddm42/projects/sheep/problems/Lesion-DirBC.i"
NUM_PROCS=6

# Loop through each filename
for filename in "${filenames[@]}"; do
    echo "========================================="
    echo "Running simulation for: $filename"
    echo "========================================="
    
    # Run MOOSE with the current filename parameter
    mpiexec -n $NUM_PROCS $SHEEP_EXE -i $INPUT_FILE filename="$filename"
    
    # Check if the simulation completed successfully
    if [ $? -eq 0 ]; then
        echo "✓ Simulation completed successfully for $filename"
    else
        echo "✗ Simulation failed for $filename"
    fi
    
    echo ""
done

echo "All simulations completed!"