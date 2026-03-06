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

# Paths
SHEEP_DIR="/Users/ddm42/projects/sheep"
SHEEP_EXE="${SHEEP_DIR}/sheep-opt"
INPUT_FILE="${1:-${SHEEP_DIR}/problems/Lesion/Lesion-DirBC.i}"
NUM_PROCS=6

# Derive output dir from the .i file's file_base line
OUTPUT_DIR=$(grep 'file_base' "$INPUT_FILE" | head -1 | sed 's/.*"\(.*\)\/${.*/\1/')

# Validate
if [ ! -f "$INPUT_FILE" ]; then
    echo "ERROR: Input file not found: $INPUT_FILE"
    exit 1
fi

PROBLEM_NAME=$(basename "$INPUT_FILE" .i)

# Create output directory if needed
mkdir -p "$OUTPUT_DIR"

# Derive base mesh name from the .i file's 'filename' default
BASE_MESH=$(grep '^filename' "$INPUT_FILE" | head -1 | sed 's/.*= *"\(.*\)".*/\1/')

# Detect mesh type: conformal (desired_area) vs structured (refine/nx/ny)
if grep -q '^desired_area' "$INPUT_FILE"; then
    MESH_TYPE="conformal"
else
    MESH_TYPE="structured"
fi

# Fixed timestep for spatial convergence (small enough that temporal error is
# negligible at f_max = 1500 Hz: dt = 0.03125 ms -> 21 samples/period)
DT="0.03125e-3"
END_TIME="10e-3"

echo "================================================="
echo "${PROBLEM_NAME} Spatial Convergence Study"
echo "================================================="
echo "  Input file: ${INPUT_FILE}"
echo "  Base mesh: ${BASE_MESH}"
echo "  Mesh type: ${MESH_TYPE}"
echo "  Timestep (fixed): dt = ${DT} s"
echo "  End time: ${END_TIME} s"
echo "  Output dir: ${OUTPUT_DIR}"
echo ""

if [ "$MESH_TYPE" = "conformal" ]; then
    # Conformal mesh: vary desired_area and n_ellipse
    # h halving => area quartering, n_ellipse doubling
    AREA_VALS=(    "2.7e-6"    "6.8e-7"    "1.7e-7"    "4.2e-8"    )
    NELLIPSE_VALS=( 10          20          40          80          )
    H_LABELS=(     "h2.50mm"  "h1.25mm"  "h0.625mm" "h0.3125mm")

    # Allow running a single level
    if [ -n "$2" ]; then
        START=$2; END=$2
    else
        START=0; END=$(( ${#AREA_VALS[@]} - 1 ))
    fi

    for i in $(seq $START $END); do
        area=${AREA_VALS[$i]}
        nellipse=${NELLIPSE_VALS[$i]}
        label=${H_LABELS[$i]}
        suffix="_${label}"

        echo "-----------------------------------------"
        echo "Run $((i+1))/${#AREA_VALS[@]}: desired_area=${area}, n_ellipse=${nellipse}, h ~ ${label}"
        echo "Output suffix: ${suffix}"
        echo "-----------------------------------------"

        mpiexec -n $NUM_PROCS "$SHEEP_EXE" -i "$INPUT_FILE" \
            filename="$BASE_MESH" desired_area="$area" n_ellipse="$nellipse" \
            my_dt="$DT" end_time="$END_TIME" suffix="$suffix" -w

        if [ $? -eq 0 ]; then
            echo "SUCCESS: ${BASE_MESH}${suffix}"
        else
            echo "FAILED: ${BASE_MESH}${suffix}"
        fi
        echo ""
    done
else
    # Structured mesh: vary uniform_refine
    REFINE_VALS=(   0          1          2          3          )
    H_LABELS=(     "h2.50mm"  "h1.25mm"  "h0.625mm" "h0.3125mm")

    # Allow running a single level
    if [ -n "$2" ]; then
        START=$2; END=$2
    else
        START=0; END=$(( ${#REFINE_VALS[@]} - 1 ))
    fi

    for i in $(seq $START $END); do
        ref=${REFINE_VALS[$i]}
        label=${H_LABELS[$i]}
        suffix="_${label}"

        echo "-----------------------------------------"
        echo "Run $((i+1))/${#REFINE_VALS[@]}: refine=${ref}, h ~ ${label}"
        echo "Output suffix: ${suffix}"
        echo "-----------------------------------------"

        mpiexec -n $NUM_PROCS "$SHEEP_EXE" -i "$INPUT_FILE" \
            filename="$BASE_MESH" refine="$ref" my_dt="$DT" \
            end_time="$END_TIME" suffix="$suffix" -w

        if [ $? -eq 0 ]; then
            echo "SUCCESS: ${BASE_MESH}${suffix}"
        else
            echo "FAILED: ${BASE_MESH}${suffix}"
        fi
        echo ""
    done
fi

echo "================================================="
echo "All runs completed!"
echo "================================================="
echo ""
echo "To extract convergence data:"
echo "  Look in CSV files at: ${OUTPUT_DIR}/${BASE_MESH}_h*.csv"
