# exodus_to_mat.py
# Convert MOOSE 2D exodus output to uniformly sampled MAT file.
#
# Auto-detects plane orientation (x-y or x-z) from mesh bounds and saves both
# in-plane displacement components (disp_x + disp_y/disp_z) to a single .mat.
#
# Usage:
#   /Applications/ParaView-6.0.1.app/Contents/bin/pvpython exodus_to_mat.py <exodus_file>
#       [--x x0,x1,n] [--yz y0,y1,n] [--t t0,t1,n]
#
# Defaults:
#   --x  -0.02,0.02,401
#   --yz 0.015,0.035,201
#   --t  0.0,0.035,561         (dt = 62.5 us, 16 kHz)
#
# NOTE: macOS Finder displays colons as slashes. If copying from Finder, replace
# slashes in the filename with colons.

import sys
import os

# Add conda environment's site-packages to access scipy
conda_site_packages = os.path.expanduser("~/miniforge/envs/convertData/lib/python3.12/site-packages")
if os.path.exists(conda_site_packages):
    sys.path.insert(0, conda_site_packages)

from paraview.simple import *
import numpy as np
import scipy.io


DEFAULT_X_SAMPLE = [-0.02, 0.02, 401]
DEFAULT_YZ_SAMPLE = [0.015, 0.035, 201]
DEFAULT_T_SAMPLE = [0.0, 0.035, 561]


def parse_sample_arg(s):
    parts = s.split(",")
    if len(parts) != 3:
        raise ValueError(f"Expected 'start,end,n', got '{s}'")
    return [float(parts[0]), float(parts[1]), int(parts[2])]


def parse_args(argv):
    if len(argv) < 2:
        print("Usage: pvpython exodus_to_mat.py <exodus_file> [--x x0,x1,n] [--yz y0,y1,n] [--t t0,t1,n]")
        sys.exit(1)

    exodus_file = argv[1]
    x_sample = list(DEFAULT_X_SAMPLE)
    yz_sample = list(DEFAULT_YZ_SAMPLE)
    t_sample = list(DEFAULT_T_SAMPLE)

    i = 2
    while i < len(argv):
        flag = argv[i]
        val = argv[i + 1] if i + 1 < len(argv) else None
        if flag == "--x":
            x_sample = parse_sample_arg(val); i += 2
        elif flag == "--yz":
            yz_sample = parse_sample_arg(val); i += 2
        elif flag == "--t":
            t_sample = parse_sample_arg(val); i += 2
        else:
            print(f"Unknown argument: {flag}")
            sys.exit(1)

    return exodus_file, x_sample, yz_sample, t_sample


def resolve_field(point_vars, target_field):
    if target_field in point_vars:
        return {"target_field": target_field, "reader_var": target_field, "component_idx": 0}

    parts = target_field.rsplit("_", 1)
    if len(parts) == 2:
        base_candidate = parts[0] + "_"
        component_map = {"x": 0, "y": 1, "z": 2}
        if base_candidate in point_vars:
            return {
                "target_field": target_field,
                "reader_var": base_candidate,
                "component_idx": component_map.get(parts[1], 0),
            }

    return {"target_field": target_field, "reader_var": target_field, "component_idx": 0}


def get_resampled_array(point_data, field_info):
    arr = point_data.GetArray(field_info["reader_var"])
    if arr is None:
        arr = point_data.GetArray(field_info["target_field"])
    if arr is None and "_" in field_info["target_field"]:
        arr = point_data.GetArray(field_info["target_field"].rsplit("_", 1)[0])
    if arr is None and "_" in field_info["reader_var"]:
        arr = point_data.GetArray(field_info["reader_var"].rsplit("_", 1)[0])
    return arr


def extract_component_to_numpy(arr, component_idx):
    n_points = arr.GetNumberOfTuples()
    n_components = arr.GetNumberOfComponents()
    out = np.zeros(n_points, dtype=np.float64)
    if n_components == 1:
        for p in range(n_points):
            out[p] = arr.GetValue(p)
    else:
        for p in range(n_points):
            out[p] = arr.GetComponent(p, component_idx)
    return out


def main():
    exodus_file, x_sample, yz_sample, t_sample = parse_args(sys.argv)

    if not os.path.exists(exodus_file):
        print(f"ERROR: Exodus file not found: {exodus_file}")
        sys.exit(1)

    print(f"Reading exodus file: {exodus_file}")

    xs = np.linspace(x_sample[0], x_sample[1], x_sample[2])
    zs = np.linspace(yz_sample[0], yz_sample[1], yz_sample[2])
    ts_requested = np.linspace(t_sample[0], t_sample[1], t_sample[2])
    nx, nz, nt_requested = len(xs), len(zs), len(ts_requested)

    dx = (x_sample[1] - x_sample[0]) / (x_sample[2] - 1) if x_sample[2] > 1 else 0
    dz = (yz_sample[1] - yz_sample[0]) / (yz_sample[2] - 1) if yz_sample[2] > 1 else 0
    dt = (t_sample[1] - t_sample[0]) / (t_sample[2] - 1) if t_sample[2] > 1 else 0

    reader = ExodusIIReader(FileName=[exodus_file])
    reader.UpdatePipeline()

    di = servermanager.Fetch(reader)
    bounds = [0.0] * 6
    di.GetBounds(bounds)
    mesh_xmin, mesh_xmax, ymin, ymax, mesh_zmin, mesh_zmax = bounds
    print(f"Mesh bounds: x=[{mesh_xmin}, {mesh_xmax}], y=[{ymin}, {ymax}], z=[{mesh_zmin}, {mesh_zmax}]")

    z_extent = abs(mesh_zmax - mesh_zmin)
    if z_extent < 1e-10:
        plane_mode = "xy"
        vert_field_name = "disp_y"
    else:
        plane_mode = "xz"
        vert_field_name = "disp_z"
    print(f"Detected {plane_mode} plane mesh. Vertical field: {vert_field_name}")

    horz_field_name = "disp_x"

    print(f"Requested sampling: nx={nx}, nz={nz}, nt={nt_requested}")
    print(f"Increments: dx={dx:.6f}, dz={dz:.6f}, dt={dt:.6f}")

    point_vars = list(reader.PointVariables)
    print(f"Available point variables: {point_vars}")

    horz_field_info = resolve_field(point_vars, horz_field_name)
    vert_field_info = resolve_field(point_vars, vert_field_name)
    reader.PointVariables = sorted(set([horz_field_info["reader_var"], vert_field_info["reader_var"]]))
    reader.UpdatePipeline()

    all_timesteps = reader.TimestepValues
    if all_timesteps is None or len(all_timesteps) == 0:
        all_timesteps = GetAnimationScene().TimeKeeper.TimestepValues
    all_timesteps = list(all_timesteps)
    print(f"File contains {len(all_timesteps)} timesteps: {all_timesteps[0]} to {all_timesteps[-1]}")

    tol = dt / 10 if dt > 0 else 1e-9
    ts = []
    for t_req in ts_requested:
        for t_file in all_timesteps:
            if abs(t_file - t_req) < tol:
                ts.append(t_file)
                break
        else:
            nearest = min(all_timesteps, key=lambda t: abs(t - t_req))
            if nearest not in ts:
                ts.append(nearest)
                print(f"  Warning: No exact match for t={t_req:.6f}, using nearest t={nearest:.6f}")

    nt = len(ts)
    print(f"Using {nt} timesteps")

    plane = Plane()
    if plane_mode == "xz":
        plane.Origin = [x_sample[0], 0.0, yz_sample[0]]
        plane.Point1 = [x_sample[1], 0.0, yz_sample[0]]
        plane.Point2 = [x_sample[0], 0.0, yz_sample[1]]
    else:
        plane.Origin = [x_sample[0], yz_sample[0], 0.0]
        plane.Point1 = [x_sample[1], yz_sample[0], 0.0]
        plane.Point2 = [x_sample[0], yz_sample[1], 0.0]
    plane.XResolution = nx - 1
    plane.YResolution = nz - 1
    plane.UpdatePipeline()

    merged = MergeBlocks(Input=reader)
    flattened = Transform(Input=merged)
    flattened.Transform = "Transform"
    flattened.Transform.Scale = [1.0, 0.0, 1.0] if plane_mode == "xz" else [1.0, 1.0, 0.0]

    resampler = ResampleWithDataset(SourceDataArrays=flattened, DestinationMesh=plane)

    data_horz = np.zeros((nz, nx, nt), dtype=np.float64)
    data_vert = np.zeros((nz, nx, nt), dtype=np.float64)

    for i, t in enumerate(ts):
        print(f"Processing timestep {i+1}/{nt}: t={t}")
        reader.UpdatePipeline(time=t)
        merged.UpdatePipeline(time=t)
        flattened.UpdatePipeline(time=t)
        resampler.UpdatePipeline(time=t)

        resampled_data = servermanager.Fetch(resampler)
        point_data = resampled_data.GetPointData()

        arr_h = get_resampled_array(point_data, horz_field_info)
        if arr_h is None:
            print(f"  WARNING: Field '{horz_field_name}' not found at timestep {t}")
        else:
            data_horz[:, :, i] = extract_component_to_numpy(arr_h, horz_field_info["component_idx"]).reshape((nz, nx), order="C")

        arr_v = get_resampled_array(point_data, vert_field_info)
        if arr_v is None:
            print(f"  WARNING: Field '{vert_field_name}' not found at timestep {t}")
        else:
            data_vert[:, :, i] = extract_component_to_numpy(arr_v, vert_field_info["component_idx"]).reshape((nz, nx), order="C")

    exodus_dir = os.path.dirname(exodus_file)
    exodus_basename = os.path.splitext(os.path.basename(exodus_file))[0]
    output_file = os.path.join(exodus_dir, f"{exodus_basename}_{plane_mode}.mat")

    ts_array = np.array(ts)
    yz_label = "ys" if plane_mode == "xy" else "zs"

    mat_dict = {
        "disp_x": data_horz,
        vert_field_name: data_vert,
        "disp_z": data_vert,  # always provide disp_z alias for MATLAB convenience
        "xs": xs,
        yz_label: zs,
        "zs": zs if plane_mode == "xz" else zs,
        "ts": ts_array,
        "dx": dx,
        "dz": dz,
        "dt": dt,
    }
    if plane_mode == "xy":
        mat_dict["ys"] = zs

    scipy.io.savemat(output_file, mat_dict)

    print(f"\n=== Summary ===")
    print(f"Output file: {output_file}")
    print(f"Array 'disp_x' shape: {data_horz.shape} (n{yz_label[0]}, nx, nt)")
    print(f"Array '{vert_field_name}' shape: {data_vert.shape} (n{yz_label[0]}, nx, nt)")
    print(f"xs: {len(xs)} points, range [{xs[0]:.6f}, {xs[-1]:.6f}], dx={dx:.6f}")
    print(f"{yz_label}: {len(zs)} points, range [{zs[0]:.6f}, {zs[-1]:.6f}], dz={dz:.6f}")
    print(f"ts: {len(ts_array)} points, range [{ts_array[0]:.6f}, {ts_array[-1]:.6f}], dt={dt:.6f}")


if __name__ == "__main__":
    main()
