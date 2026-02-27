#!/usr/bin/env python3
"""
Plot spatial and temporal convergence for Lesion-DirBC simulations.
Reads CSV outputs from convergence studies and produces 6 figures:
  1. Strain energy vs time (spatial refinement overlay)
  2. Strain energy vs time (dt refinement overlay)
  3. Log-log convergence plot: spatial strain energy error vs h
  4. Log-log convergence plot: temporal strain energy error vs dt
  5. Log-log convergence plot: spatial displacement error vs h (4 sample points)
  6. Log-log convergence plot: temporal displacement error vs dt (4 sample points)
"""

import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from pathlib import Path

# ---------- paths ----------
DATA_DIR = Path(
    "/Users/ddm42/Google Drive/My Drive/1_Work-Duke-Research/"
    "Artery_Research/data/artery_OED/Lesion/exodus"
)
SAVE_DIR = DATA_DIR  # save figures alongside the data

# ---------- spatial convergence files (glob handles MOOSE append_date timestamps) ----------
spatial_levels = [
    {"h_mm": 2.50,   "refine": 0, "pattern": "Lesion_h2.50mm_h2.50mm*.csv"},
    {"h_mm": 1.25,   "refine": 1, "pattern": "Lesion_h2.50mm_h1.25mm*.csv"},
    {"h_mm": 0.625,  "refine": 2, "pattern": "Lesion_h2.50mm_h0.625mm*.csv"},
    {"h_mm": 0.3125, "refine": 3, "pattern": "Lesion_h2.50mm_h0.3125mm*.csv"},
]

# ---------- temporal convergence files ----------
dt_levels = [
    {"dt_ms": 0.125,    "pattern": "Lesion_h2.50mm_h0.625mm_dt0.125ms*.csv"},
    {"dt_ms": 0.0625,   "pattern": "Lesion_h2.50mm_h0.625mm_dt0.0625ms*.csv"},
    {"dt_ms": 0.03125,  "pattern": "Lesion_h2.50mm_h0.625mm_dt0.03125ms*.csv"},
    {"dt_ms": 0.015625, "pattern": "Lesion_h2.50mm_h0.625mm_dt0.015625ms*.csv"},
]

# Evaluation time for convergence metric
# First shear wave reflection enters imaging domain at ~10 ms; evaluate before that
T_EVAL = 0.008  # 8 ms

# Displacement sample point columns in CSV
DISP_COLS = ["disp_z_pt1", "disp_z_pt2", "disp_z_pt3", "disp_z_pt4"]
DISP_LABELS = [
    "pt1 (-5, 25) mm",
    "pt2 (5, 25) mm",
    "pt3 (10, 20) mm",
    "pt4 (10, 30) mm",
]


def find_latest_csv(directory, pattern, exclude=None):
    """Find the most recent CSV matching a glob pattern (handles MOOSE append_date).

    Parameters
    ----------
    exclude : str, optional
        Substring to exclude from matches (e.g. "_dt" to avoid temporal files).
    """
    matches = list(directory.glob(pattern))
    if exclude:
        matches = [m for m in matches if exclude not in m.name]
    matches.sort(key=lambda p: p.stat().st_mtime)
    if not matches:
        raise FileNotFoundError(f"No file matching '{pattern}' in {directory}")
    return matches[-1]


def read_csv(filepath):
    """Read MOOSE CSV output."""
    return pd.read_csv(filepath)


def get_value_at(df, t_eval, col):
    """Get column value at the time closest to t_eval."""
    idx = (df["time"] - t_eval).abs().idxmin()
    return df.loc[idx, col]


def l2_error_in_time(df_test, df_ref, col, t_max):
    """Compute relative L2 error of a time signal over [0, t_max].

    Interpolates both signals onto the finer time grid, then computes:
        e_rel = sqrt( integral( (u - u_ref)^2 dt ) ) / sqrt( integral( u_ref^2 dt ) )

    This captures amplitude, phase, and waveform shape differences — critical
    for wave propagation problems where a single-time snapshot is misleading.
    """
    # Trim to [0, t_max]
    mask_t = df_test["time"] <= t_max + 1e-12
    mask_r = df_ref["time"] <= t_max + 1e-12
    t_test = df_test.loc[mask_t, "time"].values
    u_test = df_test.loc[mask_t, col].values
    t_ref = df_ref.loc[mask_r, "time"].values
    u_ref = df_ref.loc[mask_r, col].values

    # Use the finer (more points) time grid as the common grid
    if len(t_ref) >= len(t_test):
        t_common = t_ref
        u_ref_i = u_ref
        u_test_i = np.interp(t_common, t_test, u_test)
    else:
        t_common = t_test
        u_test_i = u_test
        u_ref_i = np.interp(t_common, t_ref, u_ref)

    diff = u_test_i - u_ref_i
    # Trapezoidal integration
    l2_err = np.sqrt(np.trapezoid(diff ** 2, t_common))
    l2_ref = np.sqrt(np.trapezoid(u_ref_i ** 2, t_common))

    if l2_ref == 0:
        return l2_err, 0.0, l2_err  # absolute only
    return l2_err, l2_ref, l2_err / l2_ref


def richardson_rate(q1, q2, q3, r=2.0):
    """Compute convergence rate from three successive refinements (ratio r)."""
    num = abs(q1 - q2)
    den = abs(q2 - q3)
    if den == 0 or num == 0:
        return np.nan
    return np.log(num / den) / np.log(r)


# =====================================================================
# Load data
# =====================================================================
print("Loading spatial convergence data...")
for lvl in spatial_levels:
    csv_path = find_latest_csv(DATA_DIR, lvl["pattern"], exclude="_dt")
    print(f"  {lvl['pattern']} -> {csv_path.name}")
    df = read_csv(csv_path)
    lvl["df"] = df
    lvl["SE"] = get_value_at(df, T_EVAL, "strain_energy")
    for col in DISP_COLS:
        lvl[col] = get_value_at(df, T_EVAL, col)

print("Loading temporal convergence data...")
for lvl in dt_levels:
    csv_path = find_latest_csv(DATA_DIR, lvl["pattern"])
    print(f"  {lvl['pattern']} -> {csv_path.name}")
    df = read_csv(csv_path)
    lvl["df"] = df
    lvl["SE"] = get_value_at(df, T_EVAL, "strain_energy")
    for col in DISP_COLS:
        lvl[col] = get_value_at(df, T_EVAL, col)

# =====================================================================
# Figure 1: Strain energy vs time — spatial refinement
# =====================================================================
fig1, ax1 = plt.subplots(figsize=(8, 5))
for lvl in spatial_levels:
    df = lvl["df"]
    ax1.plot(df["time"] * 1e3, df["strain_energy"], label=f'h = {lvl["h_mm"]} mm')
ax1.axvline(T_EVAL * 1e3, color="gray", ls="--", lw=0.8, label=f"t_eval = {T_EVAL*1e3:.0f} ms")
ax1.set_xlabel("Time (ms)")
ax1.set_ylabel("Strain Energy (J)")
ax1.set_title("Spatial Convergence — Strain Energy vs Time")
ax1.legend()
ax1.grid(True, alpha=0.3)
fig1.tight_layout()
fig1.savefig(SAVE_DIR / "convergence_spatial_time.png", dpi=200)
print(f"Saved: {SAVE_DIR / 'convergence_spatial_time.png'}")

# =====================================================================
# Figure 2: Strain energy vs time — temporal refinement
# =====================================================================
fig2, ax2 = plt.subplots(figsize=(8, 5))
for lvl in dt_levels:
    df = lvl["df"]
    ax2.plot(df["time"] * 1e3, df["strain_energy"], label=f'dt = {lvl["dt_ms"]} ms')
ax2.axvline(T_EVAL * 1e3, color="gray", ls="--", lw=0.8, label=f"t_eval = {T_EVAL*1e3:.0f} ms")
ax2.set_xlabel("Time (ms)")
ax2.set_ylabel("Strain Energy (J)")
ax2.set_title("Temporal Convergence — Strain Energy vs Time")
ax2.legend()
ax2.grid(True, alpha=0.3)
fig2.tight_layout()
fig2.savefig(SAVE_DIR / "convergence_temporal_time.png", dpi=200)
print(f"Saved: {SAVE_DIR / 'convergence_temporal_time.png'}")

# =====================================================================
# Figure 3: Log-log spatial convergence — strain energy L2-in-time error
# =====================================================================
h_vals = np.array([lvl["h_mm"] for lvl in spatial_levels])

print("\n=== Spatial Convergence: Strain Energy L2-in-Time Error (0 to {:.0f} ms) ===".format(T_EVAL * 1e3))
se_rel_errs_h = []
for lvl in spatial_levels[:-1]:
    l2_abs, l2_ref_norm, l2_rel = l2_error_in_time(
        lvl["df"], spatial_levels[-1]["df"], "strain_energy", T_EVAL
    )
    se_rel_errs_h.append(l2_rel)
    print(f"  h = {lvl['h_mm']:.4f} mm  L2 rel err = {l2_rel*100:.3f}%")
se_rel_errs_h = np.array(se_rel_errs_h)

fig3, ax3 = plt.subplots(figsize=(6, 5))
ax3.loglog(h_vals[:-1], se_rel_errs_h * 100, "o-", color="C0", lw=2, ms=8, label="Measured error")

# Reference slope O(h^2)
h_ref = h_vals[:-1]
slope2 = se_rel_errs_h[0] * 100 * (h_ref / h_ref[0]) ** 2
ax3.loglog(h_ref, slope2, "--", color="gray", lw=1.2, label=r"$O(h^2)$ reference")

# 1% line
ax3.axhline(1.0, color="red", ls=":", lw=1, alpha=0.6, label="1% error")

# Annotate rates
for i in range(1, len(se_rel_errs_h)):
    rate = np.log(se_rel_errs_h[i - 1] / se_rel_errs_h[i]) / np.log(h_vals[i - 1] / h_vals[i])
    ax3.annotate(f"p = {rate:.2f}",
                 xy=(h_vals[i], se_rel_errs_h[i] * 100),
                 xytext=(12, 8), textcoords="offset points", fontsize=9)

ax3.set_xlabel("Element size h (mm)")
ax3.set_ylabel("Relative L2-in-time error (%)")
ax3.set_title(r"Spatial Convergence — $\|SE - SE_{ref}\|_{L^2(t)}$ / $\|SE_{ref}\|_{L^2(t)}$")
ax3.legend()
ax3.grid(True, which="both", alpha=0.3)
fig3.tight_layout()
fig3.savefig(SAVE_DIR / "convergence_spatial_rate.png", dpi=200)
print(f"Saved: {SAVE_DIR / 'convergence_spatial_rate.png'}")

# =====================================================================
# Figure 4: Log-log temporal convergence — strain energy L2-in-time error
# =====================================================================
dt_vals = np.array([lvl["dt_ms"] for lvl in dt_levels])

print("\n=== Temporal Convergence: Strain Energy L2-in-Time Error (0 to {:.0f} ms) ===".format(T_EVAL * 1e3))
se_rel_errs_dt = []
for lvl in dt_levels[:-1]:
    l2_abs, l2_ref_norm, l2_rel = l2_error_in_time(
        lvl["df"], dt_levels[-1]["df"], "strain_energy", T_EVAL
    )
    se_rel_errs_dt.append(l2_rel)
    print(f"  dt = {lvl['dt_ms']:.4f} ms  L2 rel err = {l2_rel*100:.3f}%")
se_rel_errs_dt = np.array(se_rel_errs_dt)

fig4, ax4 = plt.subplots(figsize=(6, 5))
ax4.loglog(dt_vals[:-1], se_rel_errs_dt * 100, "s-", color="C1", lw=2, ms=8, label="Measured error")

# Reference slope O(dt^2)
dt_ref = dt_vals[:-1]
slope2_dt = se_rel_errs_dt[0] * 100 * (dt_ref / dt_ref[0]) ** 2
ax4.loglog(dt_ref, slope2_dt, "--", color="gray", lw=1.2, label=r"$O(\Delta t^2)$ reference")

# 1% line
ax4.axhline(1.0, color="red", ls=":", lw=1, alpha=0.6, label="1% error")

# Annotate rates
for i in range(1, len(se_rel_errs_dt)):
    rate = np.log(se_rel_errs_dt[i - 1] / se_rel_errs_dt[i]) / np.log(dt_vals[i - 1] / dt_vals[i])
    ax4.annotate(f"p = {rate:.2f}",
                 xy=(dt_vals[i], se_rel_errs_dt[i] * 100),
                 xytext=(12, 8), textcoords="offset points", fontsize=9)

ax4.set_xlabel(r"Timestep $\Delta t$ (ms)")
ax4.set_ylabel("Relative L2-in-time error (%)")
ax4.set_title(r"Temporal Convergence — $\|SE - SE_{ref}\|_{L^2(t)}$ / $\|SE_{ref}\|_{L^2(t)}$")
ax4.legend()
ax4.grid(True, which="both", alpha=0.3)
fig4.tight_layout()
fig4.savefig(SAVE_DIR / "convergence_temporal_rate.png", dpi=200)
print(f"Saved: {SAVE_DIR / 'convergence_temporal_rate.png'}")

# =====================================================================
# Figure 5: Log-log spatial convergence — L2-in-time displacement error
# =====================================================================
fig5, ax5 = plt.subplots(figsize=(7, 5))

print("\n=== Spatial Convergence: Displacement L2-in-Time Error (0 to {:.0f} ms) ===".format(T_EVAL * 1e3))
colors = ["C0", "C1", "C2", "C3"]
df_ref_spatial = spatial_levels[-1]["df"]

for j, (col, lbl) in enumerate(zip(DISP_COLS, DISP_LABELS)):
    rel_errs = []
    for lvl in spatial_levels[:-1]:
        l2_abs, l2_ref_norm, l2_rel = l2_error_in_time(
            lvl["df"], df_ref_spatial, col, T_EVAL
        )
        rel_errs.append(l2_rel)

    rel_errs = np.array(rel_errs)

    print(f"\n  {lbl}:")
    for i in range(len(rel_errs)):
        print(f"    h = {h_vals[i]:.4f} mm  L2 rel err = {rel_errs[i]*100:.3f}%")

    if np.any(rel_errs > 0):
        ax5.loglog(h_vals[:-1], rel_errs * 100, "o-", color=colors[j],
                   lw=1.5, ms=6, label=lbl)

        # Annotate rate for last pair
        if len(rel_errs) >= 2 and rel_errs[-1] > 0 and rel_errs[-2] > 0:
            rate = np.log(rel_errs[-2] / rel_errs[-1]) / np.log(h_vals[-3] / h_vals[-2])
            ax5.annotate(f"p={rate:.1f}", xy=(h_vals[-2], rel_errs[-1] * 100),
                         xytext=(10, -12), textcoords="offset points",
                         fontsize=8, color=colors[j])

# Reference slope O(h^2)
h_plot = h_vals[:-1]
ax5.loglog(h_plot, 1.0 * (h_plot / h_plot[0]) ** 2, "--", color="gray",
           lw=1.2, label=r"$O(h^2)$ reference")

# 1% line
ax5.axhline(1.0, color="red", ls=":", lw=1, alpha=0.6, label="1% error")

ax5.set_xlabel("Element size h (mm)")
ax5.set_ylabel("Relative L2-in-time error (%)")
ax5.set_title(r"Spatial Convergence — $\|u_z - u_{z,ref}\|_{L^2(t)}$ / $\|u_{ref}\|_{L^2(t)}$")
ax5.legend(fontsize=8)
ax5.grid(True, which="both", alpha=0.3)
fig5.tight_layout()
fig5.savefig(SAVE_DIR / "convergence_spatial_disp.png", dpi=200)
print(f"\nSaved: {SAVE_DIR / 'convergence_spatial_disp.png'}")

# =====================================================================
# Figure 6: Log-log temporal convergence — L2-in-time displacement error
# =====================================================================
fig6, ax6 = plt.subplots(figsize=(7, 5))

print("\n=== Temporal Convergence: Displacement L2-in-Time Error (0 to {:.0f} ms) ===".format(T_EVAL * 1e3))
df_ref_temporal = dt_levels[-1]["df"]

for j, (col, lbl) in enumerate(zip(DISP_COLS, DISP_LABELS)):
    rel_errs = []
    for lvl in dt_levels[:-1]:
        l2_abs, l2_ref_norm, l2_rel = l2_error_in_time(
            lvl["df"], df_ref_temporal, col, T_EVAL
        )
        rel_errs.append(l2_rel)

    rel_errs = np.array(rel_errs)

    print(f"\n  {lbl}:")
    for i in range(len(rel_errs)):
        print(f"    dt = {dt_vals[i]:.4f} ms  L2 rel err = {rel_errs[i]*100:.3f}%")

    if np.any(rel_errs > 0):
        ax6.loglog(dt_vals[:-1], rel_errs * 100, "s-", color=colors[j],
                   lw=1.5, ms=6, label=lbl)

        # Annotate rate for last pair
        if len(rel_errs) >= 2 and rel_errs[-1] > 0 and rel_errs[-2] > 0:
            rate = np.log(rel_errs[-2] / rel_errs[-1]) / np.log(dt_vals[-3] / dt_vals[-2])
            ax6.annotate(f"p={rate:.1f}", xy=(dt_vals[-2], rel_errs[-1] * 100),
                         xytext=(10, -12), textcoords="offset points",
                         fontsize=8, color=colors[j])

# Reference slope O(dt^2)
dt_plot = dt_vals[:-1]
ax6.loglog(dt_plot, 1.0 * (dt_plot / dt_plot[0]) ** 2, "--", color="gray",
           lw=1.2, label=r"$O(\Delta t^2)$ reference")

# 1% line
ax6.axhline(1.0, color="red", ls=":", lw=1, alpha=0.6, label="1% error")

ax6.set_xlabel(r"Timestep $\Delta t$ (ms)")
ax6.set_ylabel("Relative L2-in-time error (%)")
ax6.set_title(r"Temporal Convergence — $\|u_z - u_{z,ref}\|_{L^2(t)}$ / $\|u_{ref}\|_{L^2(t)}$")
ax6.legend(fontsize=8)
ax6.grid(True, which="both", alpha=0.3)
fig6.tight_layout()
fig6.savefig(SAVE_DIR / "convergence_temporal_disp.png", dpi=200)
print(f"\nSaved: {SAVE_DIR / 'convergence_temporal_disp.png'}")

print("\nDone. All 6 figures saved.")
