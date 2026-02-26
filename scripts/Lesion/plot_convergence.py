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

# ---------- spatial convergence files ----------
spatial_levels = [
    {"h_mm": 2.50,   "refine": 0, "file": "Lesion_h2.50mm_h2.50mm.csv"},
    {"h_mm": 1.25,   "refine": 1, "file": "Lesion_h2.50mm_h1.25mm.csv"},
    {"h_mm": 0.625,  "refine": 2, "file": "Lesion_h2.50mm_h0.625mm.csv"},
    {"h_mm": 0.3125, "refine": 3, "file": "Lesion_h2.50mm_h0.3125mm.csv"},
]

# ---------- temporal convergence files ----------
dt_levels = [
    {"dt_ms": 0.125,    "file": "Lesion_h2.50mm_h0.625mm_dt0.125ms.csv"},
    {"dt_ms": 0.0625,   "file": "Lesion_h2.50mm_h0.625mm_dt0.0625ms.csv"},
    {"dt_ms": 0.03125,  "file": "Lesion_h2.50mm_h0.625mm_dt0.03125ms.csv"},
    {"dt_ms": 0.015625, "file": "Lesion_h2.50mm_h0.625mm_dt0.015625ms.csv"},
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


def read_csv(filepath):
    """Read MOOSE CSV output."""
    return pd.read_csv(filepath)


def get_value_at(df, t_eval, col):
    """Get column value at the time closest to t_eval."""
    idx = (df["time"] - t_eval).abs().idxmin()
    return df.loc[idx, col]


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
    df = read_csv(DATA_DIR / lvl["file"])
    lvl["df"] = df
    lvl["SE"] = get_value_at(df, T_EVAL, "strain_energy")
    for col in DISP_COLS:
        lvl[col] = get_value_at(df, T_EVAL, col)

print("Loading temporal convergence data...")
for lvl in dt_levels:
    df = read_csv(DATA_DIR / lvl["file"])
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
# Figure 3: Log-log spatial convergence — strain energy error vs h
# =====================================================================
h_vals = np.array([lvl["h_mm"] for lvl in spatial_levels])
se_vals = np.array([lvl["SE"] for lvl in spatial_levels])

# Use finest solution as reference
se_ref = se_vals[-1]
errors_h = np.abs(se_vals[:-1] - se_ref)

# Print table
print("\n=== Spatial Convergence: Strain Energy (at t = {:.0f} ms) ===".format(T_EVAL * 1e3))
print(f"{'h (mm)':>10s}  {'SE':>16s}  {'|SE - SE_ref|':>16s}  {'rate':>6s}")
for i, lvl in enumerate(spatial_levels):
    err_str = f"{errors_h[i]:.4e}" if i < len(errors_h) else "(ref)"
    rate_str = ""
    if 1 <= i < len(errors_h):
        rate = richardson_rate(se_vals[i - 1], se_vals[i], se_vals[i + 1])
        rate_str = f"{rate:.2f}"
    print(f"{lvl['h_mm']:10.4f}  {lvl['SE']:16.6e}  {err_str:>16s}  {rate_str:>6s}")
print(f"{spatial_levels[-1]['h_mm']:10.4f}  {spatial_levels[-1]['SE']:16.6e}  {'(ref)':>16s}")

fig3, ax3 = plt.subplots(figsize=(6, 5))
ax3.loglog(h_vals[:-1], errors_h, "o-", color="C0", lw=2, ms=8, label="Measured error")

# Reference slope O(h^2)
h_ref = h_vals[:-1]
slope2 = errors_h[0] * (h_ref / h_ref[0]) ** 2
ax3.loglog(h_ref, slope2, "--", color="gray", lw=1.2, label=r"$O(h^2)$ reference")

# Annotate rates
for i in range(1, len(errors_h)):
    rate = np.log(errors_h[i - 1] / errors_h[i]) / np.log(h_vals[i - 1] / h_vals[i])
    ax3.annotate(f"p = {rate:.2f}",
                 xy=(h_vals[i], errors_h[i]),
                 xytext=(12, 8), textcoords="offset points", fontsize=9)

ax3.set_xlabel("Element size h (mm)")
ax3.set_ylabel("|SE - SE$_{ref}$| (J)")
ax3.set_title("Spatial Convergence Rate — Strain Energy")
ax3.legend()
ax3.grid(True, which="both", alpha=0.3)
fig3.tight_layout()
fig3.savefig(SAVE_DIR / "convergence_spatial_rate.png", dpi=200)
print(f"Saved: {SAVE_DIR / 'convergence_spatial_rate.png'}")

# =====================================================================
# Figure 4: Log-log temporal convergence — strain energy error vs dt
# =====================================================================
dt_vals = np.array([lvl["dt_ms"] for lvl in dt_levels])
se_dt_vals = np.array([lvl["SE"] for lvl in dt_levels])

se_dt_ref = se_dt_vals[-1]
errors_dt = np.abs(se_dt_vals[:-1] - se_dt_ref)

print("\n=== Temporal Convergence: Strain Energy (at t = {:.0f} ms) ===".format(T_EVAL * 1e3))
print(f"{'dt (ms)':>10s}  {'SE':>16s}  {'|SE - SE_ref|':>16s}  {'rate':>6s}")
for i, lvl in enumerate(dt_levels):
    err_str = f"{errors_dt[i]:.4e}" if i < len(errors_dt) else "(ref)"
    rate_str = ""
    if 1 <= i < len(errors_dt):
        rate = richardson_rate(se_dt_vals[i - 1], se_dt_vals[i], se_dt_vals[i + 1])
        rate_str = f"{rate:.2f}"
    print(f"{lvl['dt_ms']:10.4f}  {lvl['SE']:16.6e}  {err_str:>16s}  {rate_str:>6s}")
print(f"{dt_levels[-1]['dt_ms']:10.4f}  {dt_levels[-1]['SE']:16.6e}  {'(ref)':>16s}")

fig4, ax4 = plt.subplots(figsize=(6, 5))
ax4.loglog(dt_vals[:-1], errors_dt, "s-", color="C1", lw=2, ms=8, label="Measured error")

# Reference slope O(dt^2)
dt_ref = dt_vals[:-1]
slope2_dt = errors_dt[0] * (dt_ref / dt_ref[0]) ** 2
ax4.loglog(dt_ref, slope2_dt, "--", color="gray", lw=1.2, label=r"$O(\Delta t^2)$ reference")

# Annotate rates
for i in range(1, len(errors_dt)):
    rate = np.log(errors_dt[i - 1] / errors_dt[i]) / np.log(dt_vals[i - 1] / dt_vals[i])
    ax4.annotate(f"p = {rate:.2f}",
                 xy=(dt_vals[i], errors_dt[i]),
                 xytext=(12, 8), textcoords="offset points", fontsize=9)

ax4.set_xlabel(r"Timestep $\Delta t$ (ms)")
ax4.set_ylabel("|SE - SE$_{ref}$| (J)")
ax4.set_title("Temporal Convergence Rate — Strain Energy")
ax4.legend()
ax4.grid(True, which="both", alpha=0.3)
fig4.tight_layout()
fig4.savefig(SAVE_DIR / "convergence_temporal_rate.png", dpi=200)
print(f"Saved: {SAVE_DIR / 'convergence_temporal_rate.png'}")

# =====================================================================
# Figure 5: Log-log spatial convergence — displacement error at 4 points
# =====================================================================
fig5, ax5 = plt.subplots(figsize=(7, 5))

print("\n=== Spatial Convergence: Displacement at Sample Points (at t = {:.0f} ms) ===".format(T_EVAL * 1e3))
colors = ["C0", "C1", "C2", "C3"]
for j, (col, lbl) in enumerate(zip(DISP_COLS, DISP_LABELS)):
    vals = np.array([lvl[col] for lvl in spatial_levels])
    ref_val = vals[-1]
    errs = np.abs(vals[:-1] - ref_val)

    print(f"\n  {lbl}: ref = {ref_val:.6e}")
    for i in range(len(errs)):
        print(f"    h = {h_vals[i]:.4f} mm  err = {errs[i]:.4e}")

    # Skip points with zero error (can happen if point is at boundary)
    if np.any(errs > 0):
        ax5.loglog(h_vals[:-1], errs, "o-", color=colors[j], lw=1.5, ms=6, label=lbl)

        # Annotate rate for last pair
        if len(errs) >= 2 and errs[-1] > 0 and errs[-2] > 0:
            rate = np.log(errs[-2] / errs[-1]) / np.log(h_vals[-3] / h_vals[-2])
            ax5.annotate(f"p={rate:.1f}", xy=(h_vals[-2], errs[-1]),
                         xytext=(10, -12), textcoords="offset points",
                         fontsize=8, color=colors[j])

# Reference slope O(h^2)
h_plot = h_vals[:-1]
# Use median of the first errors for reference line placement
first_errs = []
for col in DISP_COLS:
    vals = np.array([lvl[col] for lvl in spatial_levels])
    e = abs(vals[0] - vals[-1])
    if e > 0:
        first_errs.append(e)
if first_errs:
    ref_e0 = np.median(first_errs)
    slope2_disp = ref_e0 * (h_plot / h_plot[0]) ** 2
    ax5.loglog(h_plot, slope2_disp, "--", color="gray", lw=1.2, label=r"$O(h^2)$ reference")

ax5.set_xlabel("Element size h (mm)")
ax5.set_ylabel(r"|$u_z$ - $u_{z,ref}$| (m)")
ax5.set_title("Spatial Convergence — Displacement at Sample Points")
ax5.legend(fontsize=8)
ax5.grid(True, which="both", alpha=0.3)
fig5.tight_layout()
fig5.savefig(SAVE_DIR / "convergence_spatial_disp.png", dpi=200)
print(f"\nSaved: {SAVE_DIR / 'convergence_spatial_disp.png'}")

# =====================================================================
# Figure 6: Log-log temporal convergence — displacement error at 4 points
# =====================================================================
fig6, ax6 = plt.subplots(figsize=(7, 5))

print("\n=== Temporal Convergence: Displacement at Sample Points (at t = {:.0f} ms) ===".format(T_EVAL * 1e3))
for j, (col, lbl) in enumerate(zip(DISP_COLS, DISP_LABELS)):
    vals = np.array([lvl[col] for lvl in dt_levels])
    ref_val = vals[-1]
    errs = np.abs(vals[:-1] - ref_val)

    print(f"\n  {lbl}: ref = {ref_val:.6e}")
    for i in range(len(errs)):
        print(f"    dt = {dt_vals[i]:.4f} ms  err = {errs[i]:.4e}")

    if np.any(errs > 0):
        ax6.loglog(dt_vals[:-1], errs, "s-", color=colors[j], lw=1.5, ms=6, label=lbl)

        # Annotate rate for last pair
        if len(errs) >= 2 and errs[-1] > 0 and errs[-2] > 0:
            rate = np.log(errs[-2] / errs[-1]) / np.log(dt_vals[-3] / dt_vals[-2])
            ax6.annotate(f"p={rate:.1f}", xy=(dt_vals[-2], errs[-1]),
                         xytext=(10, -12), textcoords="offset points",
                         fontsize=8, color=colors[j])

# Reference slope O(dt^2)
dt_plot = dt_vals[:-1]
first_errs_dt = []
for col in DISP_COLS:
    vals = np.array([lvl[col] for lvl in dt_levels])
    e = abs(vals[0] - vals[-1])
    if e > 0:
        first_errs_dt.append(e)
if first_errs_dt:
    ref_e0_dt = np.median(first_errs_dt)
    slope2_disp_dt = ref_e0_dt * (dt_plot / dt_plot[0]) ** 2
    ax6.loglog(dt_plot, slope2_disp_dt, "--", color="gray", lw=1.2, label=r"$O(\Delta t^2)$ reference")

ax6.set_xlabel(r"Timestep $\Delta t$ (ms)")
ax6.set_ylabel(r"|$u_z$ - $u_{z,ref}$| (m)")
ax6.set_title("Temporal Convergence — Displacement at Sample Points")
ax6.legend(fontsize=8)
ax6.grid(True, which="both", alpha=0.3)
fig6.tight_layout()
fig6.savefig(SAVE_DIR / "convergence_temporal_disp.png", dpi=200)
print(f"\nSaved: {SAVE_DIR / 'convergence_temporal_disp.png'}")

print("\nDone. All 6 figures saved.")
