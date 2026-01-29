# exodus_to_mat.py
# Convert MOOSE exodus output to uniformly sampled MAT file
# Run with: /Applications/ParaView-6.0.1.app/Contents/bin/pvpython exodus_to_mat.py

import sys
import os

# Add conda environment's site-packages to access scipy
conda_site_packages = os.path.expanduser("~/miniforge/envs/convertData/lib/python3.12/site-packages")
if os.path.exists(conda_site_packages):
    sys.path.insert(0, conda_site_packages)

from paraview.simple import *
import numpy as np
import scipy.io

# ==============================================================================
# USER SETTINGS — edit the exodus file path
# ==============================================================================
# NOTE: macOS Finder displays colons (:) as slashes (/) in filenames.
# If copying from Finder, replace any slashes in the filename with colons.
# e.g., "T13/53/18" in Finder should be "T13:53:18" in the path below.
exodus_file = "/Users/ddm42/Google Drive/My Drive/1_Work-Duke-Research/Artery_Research/data/artery_OED/Lesion/exodus/Lesion_h.625mm_2026-01-28T15:41:47-0500.e"

# Sampling parameters (edit if needed)
deltax = 0.0001  # m
deltaz = 0.0001  # m
# deltat = 0.00025  # s (not used for resampling - timesteps read from file)

# Field to extract
field_name = "disp_z"
# ==============================================================================

def main():
    if not os.path.exists(exodus_file):
        print(f"ERROR: Exodus file not found: {exodus_file}")
        sys.exit(1)

    print(f"Reading exodus file: {exodus_file}")

    # Load exodus file
    reader = ExodusIIReader(FileName=[exodus_file])

    # Get available point variables
    reader.UpdatePipeline()
    point_vars = reader.PointVariables
    print(f"Available point variables: {point_vars}")

    # Enable the field we want
    if field_name in point_vars:
        reader.PointVariables = [field_name]
    else:
        # Try to find disp_z in nodal variables
        reader.NodeSetArrayStatus = []
        reader.ElementVariables = []
        reader.PointVariables = [field_name]

    reader.UpdatePipeline()

    # Get bounds of the mesh
    di = servermanager.Fetch(reader)
    bounds = [0.0] * 6
    di.GetBounds(bounds)  # (xmin, xmax, ymin, ymax, zmin, zmax)
    xmin, xmax, ymin, ymax, zmin, zmax = bounds
    print(f"Mesh bounds: x=[{xmin}, {xmax}], y=[{ymin}, {ymax}], z=[{zmin}, {zmax}]")

    # For 2D simulation in x-z plane, the "z" in 3D VTK is actually our z coordinate
    # and "y" is typically 0 or small for a 2D mesh
    # Determine which plane the mesh is in
    x_range = xmax - xmin
    y_range = ymax - ymin
    z_range = zmax - zmin

    print(f"Ranges: x={x_range}, y={y_range}, z={z_range}")

    # Compute number of samples from bounds and deltas
    nx = int(round(x_range / deltax)) + 1

    # Determine if this is a 2D mesh in x-z plane (y is thin) or x-y plane (z is thin)
    if z_range > y_range:
        # Mesh is in x-z plane (y is thin)
        nz = int(round(z_range / deltaz)) + 1
        ny = 1
        sample_z_range = (zmin, zmax)
        sample_y_range = (ymin, ymax) if y_range > 0 else (0, 0)
        z_coord_min, z_coord_max = zmin, zmax
    else:
        # Mesh might be in x-y plane (z is thin) - treat y as our "z"
        nz = int(round(y_range / deltaz)) + 1
        ny = 1
        sample_z_range = (zmin, zmax) if z_range > 0 else (0, 0)
        sample_y_range = (ymin, ymax)
        z_coord_min, z_coord_max = ymin, ymax
        print("Note: Mesh appears to be in x-y plane, treating y as z coordinate")

    print(f"Sampling dimensions: nx={nx}, ny={ny}, nz={nz}")

    # Get timesteps from file
    timesteps = reader.TimestepValues
    if timesteps is None or len(timesteps) == 0:
        # Try alternative method
        timesteps = GetAnimationScene().TimeKeeper.TimestepValues

    timesteps = list(timesteps)
    nt = len(timesteps)
    print(f"Found {nt} timesteps: {timesteps[0]} to {timesteps[-1]}")

    # Create resampler (ResampleToImage)
    resampler = ResampleToImage(Input=reader)
    resampler.SamplingDimensions = [nx, nz, ny]  # VTK ordering
    resampler.SamplingBounds = [xmin, xmax, zmin, zmax, ymin, ymax]

    # Prepare storage: shape (nz, nx, nt)
    data = np.zeros((nz, nx, nt), dtype=np.float64)

    # Process each timestep
    for i, t in enumerate(timesteps):
        print(f"Processing timestep {i+1}/{nt}: t={t}")

        # Update pipeline to this time
        reader.UpdatePipeline(time=t)
        resampler.UpdatePipeline(time=t)

        # Fetch the data
        resampled_data = servermanager.Fetch(resampler)

        # Get the field array
        point_data = resampled_data.GetPointData()
        arr = point_data.GetArray(field_name)

        if arr is None:
            print(f"  WARNING: Field '{field_name}' not found at timestep {t}")
            # List available arrays
            for j in range(point_data.GetNumberOfArrays()):
                print(f"    Available: {point_data.GetArrayName(j)}")
            continue

        # Convert to numpy array
        n_points = arr.GetNumberOfTuples()
        n_components = arr.GetNumberOfComponents()

        field_data = np.zeros(n_points)
        for p in range(n_points):
            field_data[p] = arr.GetValue(p) if n_components == 1 else arr.GetComponent(p, 0)

        # Reshape to grid dimensions
        # VTK ImageData stores points in x-fastest order (x varies fastest, then y, then z)
        # Our resampler dimensions are [nx, nz, ny]
        # So the point order is: x varies fastest, then z, then y
        field_grid = field_data.reshape((ny, nz, nx), order='C')

        # Extract the 2D slice (ny=1, so just squeeze)
        field_2d = field_grid[0, :, :]  # shape (nz, nx)

        data[:, :, i] = field_2d

    # Generate coordinate vectors
    xs = np.linspace(xmin, xmax, nx)
    zs = np.linspace(z_coord_min, z_coord_max, nz)
    ts = np.array(timesteps)

    # Prepare output filename (same directory as exodus file)
    exodus_dir = os.path.dirname(exodus_file)
    exodus_basename = os.path.splitext(os.path.basename(exodus_file))[0]
    output_file = os.path.join(exodus_dir, f"{exodus_basename}_{field_name}.mat")

    # Save to MAT file
    scipy.io.savemat(output_file, {
        field_name: data,
        'xs': xs,
        'zs': zs,
        'ts': ts,
        'deltax': deltax,
        'deltaz': deltaz,
    })

    print(f"\n=== Summary ===")
    print(f"Output file: {output_file}")
    print(f"Array '{field_name}' shape: {data.shape} (nz, nx, nt)")
    print(f"xs: {len(xs)} points, range [{xs[0]:.6f}, {xs[-1]:.6f}], delta={deltax}")
    print(f"zs: {len(zs)} points, range [{zs[0]:.6f}, {zs[-1]:.6f}], delta={deltaz}")
    print(f"ts: {len(ts)} points, range [{ts[0]:.6f}, {ts[-1]:.6f}]")
    print(f"\nMATLAB usage:")
    print(f"  data = load('{os.path.basename(output_file)}');")
    print(f"  {field_name} = data.{field_name};  % ({nz}, {nx}, {nt})")
    print(f"  xs = data.xs;  % ({nx},)")
    print(f"  zs = data.zs;  % ({nz},)")
    print(f"  ts = data.ts;  % ({nt},)")

if __name__ == "__main__":
    main()
