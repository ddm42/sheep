# extract_xpeak_velocity.py
# Probe vel_z along a horizontal line at center depth (z = 0.025 m), find the
# x-location of |vel_z| peak at each timestep, and save to a .npz file alongside
# the exodus file.
#
# Uses vel_z directly when present (NewmarkVelAux output); otherwise falls back
# to numerical d/dt of disp_z. Auto-detects x-z vs x-y mesh orientation.
#
# Usage:
#   /Applications/ParaView-6.0.1.app/Contents/bin/pvpython extract_xpeak_velocity.py <exodus_file>
#   /Applications/ParaView-6.0.1.app/Contents/bin/pvpython extract_xpeak_velocity.py <directory>
#
# When a directory is given, all *.e files in it are processed sequentially.

import sys
import os
from pathlib import Path

from paraview.simple import *
import numpy as np

# ----- sampling parameters -----
X_RANGE = (-0.02, 0.02)   # x bounds (m) of the imaging window
NX = 401                  # samples along x (dx = 0.1 mm)
Z_CENTER = 0.025          # center-depth coordinate (m)

# ----- field name preferences -----
PLANE_FIELDS = {
    "xz": {"vel": "vel_z", "disp": "disp_z"},
    "xy": {"vel": "vel_y", "disp": "disp_y"},
}


def detect_plane_and_fields(reader):
    """Inspect mesh bounds to decide x-z vs x-y plane orientation."""
    di = servermanager.Fetch(reader)
    bounds = [0.0] * 6
    di.GetBounds(bounds)
    _, _, ymin, ymax, zmin, zmax = bounds
    if abs(zmax - zmin) < 1e-10:
        return "xy"
    return "xz"


def process_file(exodus_file):
    print(f"\n=== Processing: {exodus_file}")

    out_path = os.path.splitext(exodus_file)[0] + "_xpeak.npz"
    if os.path.exists(out_path):
        print(f"  Skipping (output exists): {out_path}")
        return

    reader = ExodusIIReader(FileName=[exodus_file])
    reader.UpdatePipeline()

    plane_mode = detect_plane_and_fields(reader)
    vel_name = PLANE_FIELDS[plane_mode]["vel"]
    disp_name = PLANE_FIELDS[plane_mode]["disp"]
    print(f"  Plane: {plane_mode}, preferred field: {vel_name}")

    available = list(reader.PointVariables)
    print(f"  Available PointVariables: {available}")

    # MOOSE may store velocity/displacement as a scalar (vel_z, disp_z) or as a
    # vector base (vel_, disp_) with x/y/z components.
    vel_base = vel_name.rsplit("_", 1)[0] + "_"     # "vel_"
    disp_base = disp_name.rsplit("_", 1)[0] + "_"   # "disp_"
    comp_letter = vel_name.rsplit("_", 1)[1]        # "z" or "y"
    comp_idx_default = {"x": 0, "y": 1, "z": 2}[comp_letter]

    field_name = None
    component_idx = 0
    is_velocity = False  # True if field is already a velocity (no d/dt needed)

    if vel_name in available:
        field_name = vel_name
        is_velocity = True
    elif vel_base in available:
        field_name = vel_base
        component_idx = comp_idx_default
        is_velocity = True
        print(f"  Using vector array '{vel_base}' component {comp_letter} (idx {component_idx})")
    elif disp_name in available:
        field_name = disp_name
        print(f"  vel field absent — falling back to numerical d/dt of {disp_name}")
    elif disp_base in available:
        field_name = disp_base
        component_idx = comp_idx_default
        print(f"  vel field absent — falling back to numerical d/dt of '{disp_base}' component {comp_letter}")
    else:
        print(f"  ERROR: no usable velocity or displacement field; skipping")
        Delete(reader)
        return

    reader.PointVariables = [field_name]
    reader.UpdatePipeline()

    all_times = list(reader.TimestepValues or [])
    nt = len(all_times)
    if nt == 0:
        print("  ERROR: no timesteps; skipping")
        Delete(reader)
        return
    print(f"  Timesteps: {nt}, range [{all_times[0]:.6f}, {all_times[-1]:.6f}]")

    xs = np.linspace(X_RANGE[0], X_RANGE[1], NX)

    # Line probe at center depth
    line = Line()
    if plane_mode == "xz":
        line.Point1 = [X_RANGE[0], 0.0, Z_CENTER]
        line.Point2 = [X_RANGE[1], 0.0, Z_CENTER]
    else:
        line.Point1 = [X_RANGE[0], Z_CENTER, 0.0]
        line.Point2 = [X_RANGE[1], Z_CENTER, 0.0]
    line.Resolution = NX - 1
    line.UpdatePipeline()

    # Merge multi-block mesh and flatten the out-of-plane coordinate to 0
    # (otherwise tiny ~1e-19 offsets cause cell locator misses).
    merged = MergeBlocks(Input=reader)
    flat = Transform(Input=merged)
    flat.Transform = "Transform"
    if plane_mode == "xz":
        flat.Transform.Scale = [1.0, 0.0, 1.0]
    else:
        flat.Transform.Scale = [1.0, 1.0, 0.0]

    resampler = ResampleWithDataset(SourceDataArrays=flat, DestinationMesh=line)

    field_xt = np.zeros((nt, NX), dtype=np.float64)

    for i, t in enumerate(all_times):
        if i == 0 or (i + 1) % 50 == 0 or i == nt - 1:
            print(f"    timestep {i + 1}/{nt}  t = {t:.6f}")
        reader.UpdatePipeline(time=t)
        merged.UpdatePipeline(time=t)
        flat.UpdatePipeline(time=t)
        resampler.UpdatePipeline(time=t)

        data = servermanager.Fetch(resampler)
        pd = data.GetPointData()
        arr = pd.GetArray(field_name)
        if arr is None and field_name.endswith("_"):
            # ParaView occasionally drops the trailing underscore on vector arrays
            arr = pd.GetArray(field_name.rstrip("_"))
        if arr is None:
            print(f"    WARNING: field '{field_name}' missing at t={t}")
            continue

        n_points = arr.GetNumberOfTuples()
        n_components = arr.GetNumberOfComponents()
        vals = np.empty(n_points, dtype=np.float64)
        if n_components == 1:
            for p in range(n_points):
                vals[p] = arr.GetValue(p)
        else:
            for p in range(n_points):
                vals[p] = arr.GetComponent(p, component_idx)

        if n_points == NX:
            field_xt[i, :] = vals
        else:
            # Resample produced a different layout — interpolate onto xs
            line_coords = np.linspace(X_RANGE[0], X_RANGE[1], n_points)
            field_xt[i, :] = np.interp(xs, line_coords, vals)

    ts_arr = np.array(all_times)

    if is_velocity:
        vel_xt = field_xt
    else:
        # Central-difference time derivative of displacement -> velocity
        vel_xt = np.gradient(field_xt, ts_arr, axis=0)

    abs_vel = np.abs(vel_xt)
    peak_idx = np.argmax(abs_vel, axis=1)
    x_peak = xs[peak_idx]
    v_peak = vel_xt[np.arange(nt), peak_idx]
    v_peak_abs = abs_vel[np.arange(nt), peak_idx]

    np.savez(
        out_path,
        ts=ts_arr,
        xs=xs,
        vel_xt=vel_xt,
        x_peak=x_peak,
        v_peak=v_peak,
        v_peak_abs=v_peak_abs,
        used_field=field_name,
        plane_mode=plane_mode,
        z_center=Z_CENTER,
    )
    print(f"  Saved: {out_path}")
    print(f"    vel_xt shape: {vel_xt.shape}")
    print(f"    x_peak range: [{x_peak.min() * 1e3:.2f}, {x_peak.max() * 1e3:.2f}] mm")
    print(f"    |v|_peak max: {v_peak_abs.max():.4e} m/s")

    # Tear down the pipeline so the next file starts fresh
    for src in (resampler, flat, merged, line, reader):
        Delete(src)


def main():
    if len(sys.argv) < 2:
        print("Usage: pvpython extract_xpeak_velocity.py <exodus_file_or_directory>")
        sys.exit(1)

    target = sys.argv[1]
    if os.path.isdir(target):
        files = sorted(Path(target).glob("*.e"))
        print(f"Found {len(files)} .e files in {target}")
        for f in files:
            try:
                process_file(str(f))
            except Exception as e:
                print(f"  FAILED on {f.name}: {e}")
    else:
        process_file(target)


if __name__ == "__main__":
    main()
