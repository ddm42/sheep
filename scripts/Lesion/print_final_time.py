#!/usr/bin/env python3
"""Print timestep information from an exodus file.

Usage:
    conda activate moose
    python print_final_time.py <exodus_file.e>
"""

import sys
from scipy.io import netcdf_file

def main():
    if len(sys.argv) < 2:
        print("Usage: python print_final_time.py <exodus_file.e>")
        sys.exit(1)

    filepath = sys.argv[1]

    with netcdf_file(filepath, 'r', mmap=False) as f:
        times = f.variables['time_whole'].data
        print(f"Number of timesteps: {len(times)}")
        print(f"First time: {times[0]}")
        print(f"Final time: {times[-1]}")

if __name__ == "__main__":
    main()
