#!/usr/bin/env python3
"""
Plot spatial and temporal convergence for RectsLR simulations.
Reads CSV outputs from run_convergence.sh and run_dt_convergence.sh.
Produces:
  1. Strain energy vs time (spatial refinement overlay)
  2. Strain energy vs time (dt refinement overlay)
  3. Log-log convergence plot: spatial (error vs h)
  4. Log-log convergence plot: temporal (error vs dt)
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
    "Artery_Research/data/artery_OED/RectsLR/exodus"
)
SAVE_DIR = DATA_DIR

# ---------- spatial convergence files ----------
spatial_levels = [
    {"h_mm": 5.00,  "file": "RectsLR_h5.00mm.csv"},
    {"h_mm": 2.50,  "file": "RectsLR_h2.50mm.csv"},
    {"h_mm": 1.25,  "file": "RectsLR_h1.25mm.csv"},
    {"h_mm": 0.625, "file": "RectsLR_h0.625mm.csv"},
]

# ---------- temporal convergence files ----------
dt_levels = [
    {"dt_ms": 0.500,  "file": "RectsLR_h1.25mm_dt0.500ms.csv"},
    {"dt_ms": 0.250,  "file": "RectsLR_h1.25mm_dt0.250ms.csv"},
    {"dt_ms": 0.125,  "file": "RectsLR_h1.25mm_dt0.125ms.csv"},
    {"dt_ms": 0.0625, "file": "RectsLR_h1.25mm_dt0.0625ms.csv"},
]

# Evaluation time for convergence metric
T_EVAL = 0.006  # 6 ms

# Convergence metric column
METRIC = "strain_energy"
METRIC_LABEL = "Strain Energy (J)"


def read_csv(filepath):
    return pd.read_csv(filepath)


def get_value_at(df, t_eval, col):
    idx = (df["time"] - t_eval).abs().idxmin()
    return df.loc[idx, col]


def richardson_rate(q1, q2, q3, r=2.0):
    num = abs(q1 - q2)
    den = abs(q2 - q3)
    if den == 0 or num == 0:
        return np.nan
    return np.log(num / den) / np.log(r)


# =====================================================================
# Load data
# =====================================================================
for lvl in spatial_levels:
    df = read_csv(DATA_DIR / lvl["file"])
    lvl["df"] = df
    lvl["SE"] = get_value_at(df, T_EVAL, METRIC)

for lvl in dt_levels:
    df = read_csv(DATA_DIR / lvl["file"])
    lvl["df"] = df
    lvl["SE"] = get_value_at(df, T_EVAL, METRIC)

# =====================================================================
# Figure 1: Strain energy vs time — spatial refinement
# =====================================================================
fig1, ax1 = plt.subplots(figsize=(8, 5))
for lvl in spatial_levels:
    df = lvl["df"]
    ax1.plot(df["time"] * 1e3, df[METRIC], label=f'h = {lvl["h_mm"]} mm')
ax1.axvline(T_EVAL * 1e3, color="gray", ls="--", lw=0.8, label=f"t_eval = {T_EVAL*1e3:.0f} ms")
ax1.set_xlabel("Time (ms)")
ax1.set_ylabel(METRIC_LABEL)
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
    ax2.plot(df["time"] * 1e3, df[METRIC], label=f'dt = {lvl["dt_ms"]} ms')
ax2.axvline(T_EVAL * 1e3, color="gray", ls="--", lw=0.8, label=f"t_eval = {T_EVAL*1e3:.0f} ms")
ax2.set_xlabel("Time (ms)")
ax2.set_ylabel(METRIC_LABEL)
ax2.set_title("Temporal Convergence — Strain Energy vs Time")
ax2.legend()
ax2.grid(True, alpha=0.3)
fig2.tight_layout()
fig2.savefig(SAVE_DIR / "convergence_temporal_time.png", dpi=200)
print(f"Saved: {SAVE_DIR / 'convergence_temporal_time.png'}")

# =====================================================================
# Figure 3: Log-log spatial convergence (error vs h)
# =====================================================================
h_vals = np.array([lvl["h_mm"] for lvl in spatial_levels])
se_vals = np.array([lvl["SE"] for lvl in spatial_levels])
se_ref = se_vals[-1]
errors_h = np.abs(se_vals[:-1] - se_ref)

print(f"\n=== Spatial Convergence (at t = {T_EVAL*1e3:.0f} ms) ===")
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
h_ref = h_vals[:-1]
slope2 = errors_h[0] * (h_ref / h_ref[0]) ** 2
ax3.loglog(h_ref, slope2, "--", color="gray", lw=1.2, label=r"$O(h^2)$ reference")
for i in range(1, len(errors_h)):
    rate = np.log(errors_h[i - 1] / errors_h[i]) / np.log(h_vals[i - 1] / h_vals[i])
    ax3.annotate(f"p = {rate:.2f}",
                 xy=(h_vals[i], errors_h[i]),
                 xytext=(12, 8), textcoords="offset points", fontsize=9)
ax3.set_xlabel("Element size h (mm)")
ax3.set_ylabel(f"|{METRIC} - ref| (J)")
ax3.set_title("Spatial Convergence Rate")
ax3.legend()
ax3.grid(True, which="both", alpha=0.3)
fig3.tight_layout()
fig3.savefig(SAVE_DIR / "convergence_spatial_rate.png", dpi=200)
print(f"Saved: {SAVE_DIR / 'convergence_spatial_rate.png'}")

# =====================================================================
# Figure 4: Log-log temporal convergence (error vs dt)
# =====================================================================
dt_vals = np.array([lvl["dt_ms"] for lvl in dt_levels])
se_dt_vals = np.array([lvl["SE"] for lvl in dt_levels])
se_dt_ref = se_dt_vals[-1]
errors_dt = np.abs(se_dt_vals[:-1] - se_dt_ref)

print(f"\n=== Temporal Convergence (at t = {T_EVAL*1e3:.0f} ms) ===")
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
dt_ref = dt_vals[:-1]
slope2_dt = errors_dt[0] * (dt_ref / dt_ref[0]) ** 2
ax4.loglog(dt_ref, slope2_dt, "--", color="gray", lw=1.2, label=r"$O(\Delta t^2)$ reference")
for i in range(1, len(errors_dt)):
    rate = np.log(errors_dt[i - 1] / errors_dt[i]) / np.log(dt_vals[i - 1] / dt_vals[i])
    ax4.annotate(f"p = {rate:.2f}",
                 xy=(dt_vals[i], errors_dt[i]),
                 xytext=(12, 8), textcoords="offset points", fontsize=9)
ax4.set_xlabel(r"Timestep $\Delta t$ (ms)")
ax4.set_ylabel(f"|{METRIC} - ref| (J)")
ax4.set_title("Temporal Convergence Rate")
ax4.legend()
ax4.grid(True, which="both", alpha=0.3)
fig4.tight_layout()
fig4.savefig(SAVE_DIR / "convergence_temporal_rate.png", dpi=200)
print(f"Saved: {SAVE_DIR / 'convergence_temporal_rate.png'}")

print("\nDone. All figures saved.")
