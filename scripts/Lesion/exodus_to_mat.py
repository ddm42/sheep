# exodus_to_mat.py
# Convert MOOSE exodus output to uniformly sampled MAT file
#
# Usage:
#   /Applications/ParaView-6.0.1.app/Contents/bin/pvpython exodus_to_mat.py <exodus_file>
#
# Example:
#   /Applications/ParaView-6.0.1.app/Contents/bin/pvpython exodus_to_mat.py "/path/to/file.e"
#
# NOTE: macOS Finder displays colons (:) as slashes (/) in filenames.
#       If copying from Finder, replace slashes in the filename with colons.
#       e.g., "T13/53/18" in Finder should be "T13:53:18" in the path.

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
x_sample = [-0.02, 0.02, 401]       # x range and number of points
yz_sample = [0.015, 0.035, 201]     # y/z range and number of points (auto-detected)
t_sample = [0.0, 0.035, 141]        # time range and number of points

# Field to extract — auto-detected from mesh orientation (disp_y for x-y, disp_z for x-z)
field_name = None
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

    # Generate coordinate vectors
    xs = np.linspace(x_sample[0], x_sample[1], x_sample[2])
    zs = np.linspace(yz_sample[0], yz_sample[1], yz_sample[2])
    ts_requested = np.linspace(t_sample[0], t_sample[1], t_sample[2])

    nx, nz, nt_requested = len(xs), len(zs), len(ts_requested)

    dx = (x_sample[1] - x_sample[0]) / (x_sample[2] - 1) if x_sample[2] > 1 else 0
    dz = (yz_sample[1] - yz_sample[0]) / (yz_sample[2] - 1) if yz_sample[2] > 1 else 0
    dt = (t_sample[1] - t_sample[0]) / (t_sample[2] - 1) if t_sample[2] > 1 else 0

    # Load exodus file and detect mesh orientation
    reader = ExodusIIReader(FileName=[exodus_file])
    reader.UpdatePipeline()

    # Get mesh bounds to auto-detect 2D plane orientation
    di = servermanager.Fetch(reader)
    bounds = [0.0] * 6
    di.GetBounds(bounds)
    mesh_xmin, mesh_xmax, ymin, ymax, mesh_zmin, mesh_zmax = bounds
    print(f"Mesh bounds: x=[{mesh_xmin}, {mesh_xmax}], y=[{ymin}, {ymax}], z=[{mesh_zmin}, {mesh_zmax}]")

    # Auto-detect plane orientation: flat dimension is the out-of-plane direction
    y_extent = abs(ymax - ymin)
    z_extent = abs(mesh_zmax - mesh_zmin)

    global field_name
    if z_extent < 1e-10:
        # x-y plane mesh (GeneratedMeshGenerator 2D) — flat in z
        plane_mode = "xy"
        if field_name is None:
            field_name = "disp_y"
        print(f"Detected x-y plane mesh (flat in z). Field: {field_name}")
    else:
        # x-z plane mesh (Cubit 2D) — flat in y
        plane_mode = "xz"
        if field_name is None:
            field_name = "disp_z"
        print(f"Detected x-z plane mesh (flat in y). Field: {field_name}")

    print(f"Requested sampling: nx={nx}, nz={nz}, nt={nt_requested}")
    print(f"Increments: dx={dx:.6f}, dz={dz:.6f}, dt={dt:.6f}")

    # Get available point variables
    point_vars = reader.PointVariables
    print(f"Available point variables: {point_vars}")

    # Determine how the field is stored in the exodus file.
    # MOOSE may store displacements as scalar arrays (disp_x, disp_z) or as
    # vector arrays (disp_ with components x,y,z).  Detect which convention
    # this file uses and set reader_var (what to enable in the reader) and
    # component_idx (which component to extract from the array).
    reader_var = field_name          # default: scalar field
    component_idx = 0                # default: first (or only) component

    if field_name in point_vars:
        # Scalar variable present directly — use it
        reader.PointVariables = [field_name]
    else:
        # Try to find a vector base: 'disp_y' -> base 'disp_'
        parts = field_name.rsplit('_', 1)
        if len(parts) == 2:
            base_candidate = parts[0] + '_'
            comp_name = parts[1]
            if base_candidate in point_vars:
                reader_var = base_candidate
                component_map = {'x': 0, 'y': 1, 'z': 2}
                component_idx = component_map.get(comp_name, 0)
                print(f"Field '{field_name}' maps to vector '{reader_var}' component {component_idx}")
                reader.PointVariables = [reader_var]
            else:
                # Last resort: enable as-is and hope for the best
                reader.PointVariables = [field_name]
        else:
            reader.PointVariables = [field_name]

    reader.UpdatePipeline()

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

    # Create a sampling Plane matching the mesh's 2D orientation
    plane = Plane()
    if plane_mode == "xz":
        # x-z plane at y=0: Point1 along x, Point2 along z
        plane.Origin = [x_sample[0], 0.0, yz_sample[0]]
        plane.Point1 = [x_sample[1], 0.0, yz_sample[0]]
        plane.Point2 = [x_sample[0], 0.0, yz_sample[1]]
    else:
        # x-y plane at z=0: Point1 along x, Point2 along y
        plane.Origin = [x_sample[0], yz_sample[0], 0.0]
        plane.Point1 = [x_sample[1], yz_sample[0], 0.0]
        plane.Point2 = [x_sample[0], yz_sample[1], 0.0]
    plane.XResolution = nx - 1
    plane.YResolution = nz - 1
    plane.UpdatePipeline()

    # Merge all element blocks so the probe can find cells in every block
    merged = MergeBlocks(Input=reader)

    # Flatten the out-of-plane coordinate to exactly 0 — the 2D mesh has tiny
    # floating-point offsets (~1e-19) on some blocks that cause cell locator misses
    flattened = Transform(Input=merged)
    flattened.Transform = "Transform"
    if plane_mode == "xz":
        flattened.Transform.Scale = [1.0, 0.0, 1.0]  # flatten y
    else:
        flattened.Transform.Scale = [1.0, 1.0, 0.0]  # flatten z

    # Resample merged data onto the plane
    resampler = ResampleWithDataset(SourceDataArrays=flattened, DestinationMesh=plane)

    # Prepare storage: shape (nz, nx, nt)
    data = np.zeros((nz, nx, nt), dtype=np.float64)

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

        # Get the field array — try reader_var first (vector), then field_name (scalar)
        point_data = resampled_data.GetPointData()
        arr = point_data.GetArray(reader_var)
        if arr is None:
            arr = point_data.GetArray(field_name)
        if arr is None:
            # ParaView sometimes drops the trailing underscore after resampling
            arr = point_data.GetArray(field_name.rsplit('_', 1)[0] if '_' in field_name else field_name)

        if arr is None:
            print(f"  WARNING: Field '{field_name}' not found at timestep {t}")
            for j in range(point_data.GetNumberOfArrays()):
                print(f"    Available: {point_data.GetArrayName(j)}")
            continue

        # Convert to numpy array, extracting the correct component
        n_points = arr.GetNumberOfTuples()
        n_components = arr.GetNumberOfComponents()

        field_data = np.zeros(n_points)
        if n_components == 1:
            for p in range(n_points):
                field_data[p] = arr.GetValue(p)
        else:
            for p in range(n_points):
                field_data[p] = arr.GetComponent(p, component_idx)

        # Plane points are ordered: x varies fastest (XResolution), then z (YResolution)
        field_2d = field_data.reshape((nz, nx), order='C')

        data[:, :, i] = field_2d

    # Prepare output filename (same directory as exodus file)
    exodus_dir = os.path.dirname(exodus_file)
    exodus_basename = os.path.splitext(os.path.basename(exodus_file))[0]
    output_file = os.path.join(exodus_dir, f"{exodus_basename}_{field_name}.mat")

    # Save to MAT file
    # Use 'ys' or 'zs' depending on orientation, but always include both names
    ts_array = np.array(ts)
    yz_label = "ys" if plane_mode == "xy" else "zs"
    mat_dict = {
        field_name: data,
        'xs': xs,
        yz_label: zs,
        'ts': ts_array,
        'dx': dx,
        'dz': dz,
        'dt': dt,
    }
    scipy.io.savemat(output_file, mat_dict)

    print(f"\n=== Summary ===")
    print(f"Output file: {output_file}")
    print(f"Array '{field_name}' shape: {data.shape} (n{yz_label[0]}, nx, nt)")
    print(f"xs: {len(xs)} points, range [{xs[0]:.6f}, {xs[-1]:.6f}], dx={dx:.6f}")
    print(f"{yz_label}: {len(zs)} points, range [{zs[0]:.6f}, {zs[-1]:.6f}], dz={dz:.6f}")
    print(f"ts: {len(ts_array)} points, range [{ts_array[0]:.6f}, {ts_array[-1]:.6f}], dt={dt:.6f}")
    print(f"\nMATLAB usage:")
    print(f"  data = load('{os.path.basename(output_file)}');")
    print(f"  {field_name} = data.{field_name};  % ({nz}, {nx}, {nt})")
    print(f"  xs = data.xs;  % ({nx},)")
    print(f"  {yz_label} = data.{yz_label};  % ({nz},)")
    print(f"  ts = data.ts;  % ({nt},)")


if __name__ == "__main__":
    main()
