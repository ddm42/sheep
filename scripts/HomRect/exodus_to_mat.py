# exodus_to_mat.py (HomRect version)
# Convert MOOSE exodus output to uniformly sampled MAT file
# Adapted for HomRect x-y plane meshes (z=0)
#
# Usage:
#   /Applications/ParaView-6.0.1.app/Contents/bin/pvpython exodus_to_mat.py <exodus_file>
#
# Example:
#   /Applications/ParaView-6.0.1.app/Contents/bin/pvpython exodus_to_mat.py "/path/to/file.e"

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
# SAMPLING PARAMETERS — define the subregion and number of samples
# ==============================================================================
# Format: [start, end, num_samples]
x_sample = [-0.02, 0.02, 401]    # x range and number of points
y_sample = [0.015, 0.035, 201]    # y range and number of points
t_sample = [0.0, 0.006, 49]       # time range and number of points

# Field to extract — ParaView may store as vector "disp_" or scalar "disp_y"
field_name = "disp_y"
vector_name = "disp_"       # fallback: vector name if scalar not available
component_index = 1         # 0=x, 1=y component of the vector
# ==============================================================================


def main():
    # Get exodus file from command line
    if len(sys.argv) < 2:
        print("Usage: pvpython exodus_to_mat.py <exodus_file>")
        print("Example: pvpython exodus_to_mat.py \"/path/to/file.e\"")
        sys.exit(1)

    exodus_file = sys.argv[1]

    if not os.path.exists(exodus_file):
        print(f"ERROR: Exodus file not found: {exodus_file}")
        sys.exit(1)

    print(f"Reading exodus file: {exodus_file}")

    # Generate coordinate vectors using linspace
    xs = np.linspace(x_sample[0], x_sample[1], x_sample[2])
    ys = np.linspace(y_sample[0], y_sample[1], y_sample[2])
    ts_requested = np.linspace(t_sample[0], t_sample[1], t_sample[2])

    nx, ny, nt_requested = len(xs), len(ys), len(ts_requested)

    # Compute and print increments
    dx = (x_sample[1] - x_sample[0]) / (x_sample[2] - 1) if x_sample[2] > 1 else 0
    dy = (y_sample[1] - y_sample[0]) / (y_sample[2] - 1) if y_sample[2] > 1 else 0
    dt = (t_sample[1] - t_sample[0]) / (t_sample[2] - 1) if t_sample[2] > 1 else 0

    print(f"Requested sampling: nx={nx}, ny={ny}, nt={nt_requested}")
    print(f"Increments: dx={dx:.6f}, dy={dy:.6f}, dt={dt:.6f}")

    # Load exodus file
    reader = ExodusIIReader(FileName=[exodus_file])

    # Get available point variables
    reader.UpdatePipeline()
    point_vars = reader.PointVariables
    print(f"Available point variables: {point_vars}")

    # Enable the field we want — handle both scalar and vector cases
    use_vector = False
    if field_name in point_vars:
        reader.PointVariables = [field_name]
    elif vector_name in point_vars:
        print(f"  '{field_name}' not found as scalar; using vector '{vector_name}' component {component_index}")
        reader.PointVariables = [vector_name]
        use_vector = True
    else:
        reader.PointVariables = [field_name]

    reader.UpdatePipeline()

    # Get bounds of the mesh
    di = servermanager.Fetch(reader)
    bounds = [0.0] * 6
    di.GetBounds(bounds)
    mesh_xmin, mesh_xmax, mesh_ymin, mesh_ymax, zmin, zmax = bounds
    print(f"Mesh bounds: x=[{mesh_xmin}, {mesh_xmax}], y=[{mesh_ymin}, {mesh_ymax}], z=[{zmin}, {zmax}]")

    # Get available timesteps from file
    all_timesteps = reader.TimestepValues
    if all_timesteps is None or len(all_timesteps) == 0:
        all_timesteps = GetAnimationScene().TimeKeeper.TimestepValues
    all_timesteps = list(all_timesteps)
    print(f"File contains {len(all_timesteps)} timesteps: {all_timesteps[0]} to {all_timesteps[-1]}")

    # Find timesteps that match our requested times (within tolerance)
    tol = dt / 10 if dt > 0 else 1e-9
    ts = []
    for t_req in ts_requested:
        for t_file in all_timesteps:
            if abs(t_file - t_req) < tol:
                ts.append(t_file)
                break
        else:
            # No matching timestep found - use nearest
            nearest = min(all_timesteps, key=lambda t: abs(t - t_req))
            if nearest not in ts:  # Avoid duplicates
                ts.append(nearest)
                print(f"  Warning: No exact match for t={t_req:.6f}, using nearest t={nearest:.6f}")

    nt = len(ts)
    print(f"Using {nt} timesteps")

    # Create a Plane at z=0 as the sampling mesh (HomRect is in x-y plane)
    # Plane spans x_sample range (Point1) and y_sample range (Point2)
    plane = Plane()
    plane.Origin = [x_sample[0], y_sample[0], 0.0]
    plane.Point1 = [x_sample[1], y_sample[0], 0.0]
    plane.Point2 = [x_sample[0], y_sample[1], 0.0]
    plane.XResolution = nx - 1
    plane.YResolution = ny - 1
    plane.UpdatePipeline()

    # Merge all element blocks so the probe can find cells in every block
    merged = MergeBlocks(Input=reader)

    # Flatten z-coordinates to exactly 0 — the 2D mesh may have tiny floating-point
    # z-offsets that cause the cell locator to miss cells
    flattened = Transform(Input=merged)
    flattened.Transform = "Transform"
    flattened.Transform.Scale = [1.0, 1.0, 0.0]

    # Resample merged data onto the plane
    resampler = ResampleWithDataset(SourceDataArrays=flattened, DestinationMesh=plane)

    # Prepare storage: shape (ny, nx, nt)
    data = np.zeros((ny, nx, nt), dtype=np.float64)

    # Process each timestep
    for i, t in enumerate(ts):
        print(f"Processing timestep {i+1}/{nt}: t={t}")

        # Update pipeline to this time
        reader.UpdatePipeline(time=t)
        merged.UpdatePipeline(time=t)
        flattened.UpdatePipeline(time=t)
        resampler.UpdatePipeline(time=t)

        # Fetch the data
        resampled_data = servermanager.Fetch(resampler)

        # Get the field array
        point_data = resampled_data.GetPointData()
        arr_name = vector_name if use_vector else field_name
        arr = point_data.GetArray(arr_name)

        if arr is None:
            print(f"  WARNING: Field '{arr_name}' not found at timestep {t}")
            for j in range(point_data.GetNumberOfArrays()):
                print(f"    Available: {point_data.GetArrayName(j)}")
            continue

        # Convert to numpy array
        n_points = arr.GetNumberOfTuples()
        n_components = arr.GetNumberOfComponents()

        field_data = np.zeros(n_points)
        if use_vector and n_components > 1:
            for p in range(n_points):
                field_data[p] = arr.GetComponent(p, component_index)
        else:
            for p in range(n_points):
                field_data[p] = arr.GetValue(p) if n_components == 1 else arr.GetComponent(p, 0)

        # Plane points are ordered: x varies fastest (XResolution), then y (YResolution)
        field_2d = field_data.reshape((ny, nx), order='C')

        data[:, :, i] = field_2d

    # Prepare output filename (same directory as exodus file)
    exodus_dir = os.path.dirname(exodus_file)
    exodus_basename = os.path.splitext(os.path.basename(exodus_file))[0]
    output_file = os.path.join(exodus_dir, f"{exodus_basename}_{field_name}.mat")

    # Save to MAT file
    ts_array = np.array(ts)
    scipy.io.savemat(output_file, {
        field_name: data,
        'xs': xs,
        'ys': ys,
        'ts': ts_array,
        'dx': dx,
        'dy': dy,
        'dt': dt,
    })

    print(f"\n=== Summary ===")
    print(f"Output file: {output_file}")
    print(f"Array '{field_name}' shape: {data.shape} (ny, nx, nt)")
    print(f"xs: {len(xs)} points, range [{xs[0]:.6f}, {xs[-1]:.6f}], dx={dx:.6f}")
    print(f"ys: {len(ys)} points, range [{ys[0]:.6f}, {ys[-1]:.6f}], dy={dy:.6f}")
    print(f"ts: {len(ts_array)} points, range [{ts_array[0]:.6f}, {ts_array[-1]:.6f}], dt={dt:.6f}")
    print(f"\nMATLAB usage:")
    print(f"  data = load('{os.path.basename(output_file)}');")
    print(f"  {field_name} = data.{field_name};  % ({ny}, {nx}, {nt})")
    print(f"  xs = data.xs;  % ({nx},)")
    print(f"  ys = data.ys;  % ({ny},)")
    print(f"  ts = data.ts;  % ({nt},)")


if __name__ == "__main__":
    main()
