#!/usr/bin/env python3
"""Plot x-location of peak |v_z| at center depth (z = 0.025 m) over time.

Loads the *_xpeak.npz files produced by extract_xpeak_velocity.py and overlays
the spatial and temporal refinement series. Also produces a v_z(x, t) heatmap
for the finest spatial level so the tracked peak can be sanity-checked
against the underlying wave field.

Usage (requires numpy + matplotlib — available in the moose conda env):
  conda activate moose
  python3 plot_xpeak_velocity.py                                # default dir
  python3 plot_xpeak_velocity.py /path/to/Lesion_25_9/exodus    # custom dir
"""

import re
import sys
import numpy as np
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from pathlib import Path

DEFAULT_DIR = Path(
    "/Users/ddm42/Google Drive/My Drive/1_Work-Duke-Research/"
    "Artery_Research/data/artery_OED/Lesion_25_9/exodus"
)
DATA_DIR = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_DIR
SAVE_DIR = DATA_DIR

# Regex for the convergence-suffix patterns embedded in MOOSE output filenames.
# Filenames often contain the Cubit mesh name AND the convergence suffix, e.g.
#   Lesion_h2.50mm_h0.625mm_<date>_xpeak.npz  -> spatial level: h = 0.625 mm
#   Lesion_h2.50mm_h0.625mm_dt0.125ms_<date>_xpeak.npz -> temporal: dt = 0.125 ms
# For spatial classification we want the LAST _hXmm_ token in the name.
RE_DT = re.compile(r"_dt(\d+(?:\.\d+)?)ms(?=[_.])")
RE_H = re.compile(r"_h(\d+(?:\.\d+)?)mm(?=[_.])")  # lookahead avoids consuming sep


def latest(files):
    """Return the alphabetically-last file (MOOSE timestamps sort correctly)."""
    return sorted(files, key=lambda p: p.name)[-1]


def classify(npz_files):
    """Bucket *_xpeak.npz files into spatial / temporal refinement series."""
    spatial = {}
    temporal = {}
    for f in npz_files:
        name = f.name
        m_dt = RE_DT.search(name)
        if m_dt:
            dt_ms = float(m_dt.group(1))
            temporal.setdefault(dt_ms, []).append(f)
            continue
        all_h = RE_H.findall(name)
        if all_h:
            h_mm = float(all_h[-1])  # last _hXmm_ wins (skip Cubit mesh prefix)
            spatial.setdefault(h_mm, []).append(f)
    spatial_lvls = [
        {"h_mm": h, "file": latest(files)}
        for h, files in sorted(spatial.items(), reverse=True)
    ]
    temporal_lvls = [
        {"dt_ms": dt, "file": latest(files)}
        for dt, files in sorted(temporal.items(), reverse=True)
    ]
    return spatial_lvls, temporal_lvls


def load(level):
    d = np.load(level["file"])
    level["ts"] = d["ts"]
    level["xs"] = d["xs"]
    level["x_peak"] = d["x_peak"]
    level["v_peak"] = d["v_peak"]
    level["v_peak_abs"] = d["v_peak_abs"]
    level["vel_xt"] = d["vel_xt"]
    level["used_field"] = str(d["used_field"])
    return level


npz_files = sorted(DATA_DIR.glob("*_xpeak.npz"))
if not npz_files:
    raise FileNotFoundError(
        f"No *_xpeak.npz in {DATA_DIR}. Run extract_xpeak_velocity.py first."
    )
print(f"Found {len(npz_files)} _xpeak.npz files in {DATA_DIR}")

spatial_levels, dt_levels = classify(npz_files)
print(f"Spatial levels: {[lvl['h_mm'] for lvl in spatial_levels]} mm")
print(f"Temporal levels: {[lvl['dt_ms'] for lvl in dt_levels]} ms")

for lvl in spatial_levels:
    print(f"  spatial h={lvl['h_mm']} mm -> {lvl['file'].name}")
    load(lvl)
for lvl in dt_levels:
    print(f"  temporal dt={lvl['dt_ms']} ms -> {lvl['file'].name}")
    load(lvl)

# Mask threshold: hide x_peak where the peak magnitude is too small to be meaningful
# (e.g. silent timesteps before the impulse, where argmax of ~zero noise picks a boundary)
MASK_FRAC = 0.05  # mask points below 5% of each run's global peak

def masked_xpeak(lvl):
    thresh = MASK_FRAC * lvl["v_peak_abs"].max()
    xp_mm = lvl["x_peak"] * 1e3
    return np.where(lvl["v_peak_abs"] >= thresh, xp_mm, np.nan)


# =====================================================================
# Figure 1: x_peak(t) — spatial refinement overlay
# =====================================================================
if spatial_levels:
    fig, ax = plt.subplots(figsize=(8, 5))
    for lvl in spatial_levels:
        ax.plot(lvl["ts"] * 1e3, masked_xpeak(lvl),
                label=f"h = {lvl['h_mm']} mm", lw=1.5)
    ax.axhline(-10, color="gray", ls=":", lw=0.8, label="source x = -10 mm")
    ax.set_xlabel("Time (ms)")
    ax.set_ylabel("x of peak |v_z| at z=25 mm (mm)")
    ax.set_title("Spatial refinement — x-location of peak shear-wave velocity")
    ax.legend(fontsize=9)
    ax.grid(True, alpha=0.3)
    fig.tight_layout()
    out = SAVE_DIR / "xpeak_spatial_time.png"
    fig.savefig(out, dpi=200)
    print(f"Saved: {out}")

# =====================================================================
# Figure 2: x_peak(t) — temporal refinement overlay
# =====================================================================
if dt_levels:
    fig, ax = plt.subplots(figsize=(8, 5))
    for lvl in dt_levels:
        ax.plot(lvl["ts"] * 1e3, masked_xpeak(lvl),
                label=f"dt = {lvl['dt_ms']} ms", lw=1.5)
    ax.axhline(-10, color="gray", ls=":", lw=0.8, label="source x = -10 mm")
    ax.set_xlabel("Time (ms)")
    ax.set_ylabel("x of peak |v_z| at z=25 mm (mm)")
    ax.set_title("Temporal refinement — x-location of peak shear-wave velocity")
    ax.legend(fontsize=9)
    ax.grid(True, alpha=0.3)
    fig.tight_layout()
    out = SAVE_DIR / "xpeak_temporal_time.png"
    fig.savefig(out, dpi=200)
    print(f"Saved: {out}")

# =====================================================================
# Figure 3: peak |v_z| magnitude vs time — spatial refinement
# =====================================================================
if spatial_levels:
    fig, ax = plt.subplots(figsize=(8, 5))
    for lvl in spatial_levels:
        ax.plot(lvl["ts"] * 1e3, lvl["v_peak_abs"],
                label=f"h = {lvl['h_mm']} mm", lw=1.5)
    ax.set_xlabel("Time (ms)")
    ax.set_ylabel("peak |v_z| at z=25 mm (m/s)")
    ax.set_title("Spatial refinement — peak shear-wave velocity magnitude")
    ax.set_yscale("log")
    ax.legend(fontsize=9)
    ax.grid(True, which="both", alpha=0.3)
    fig.tight_layout()
    out = SAVE_DIR / "xpeak_spatial_magnitude.png"
    fig.savefig(out, dpi=200)
    print(f"Saved: {out}")

# =====================================================================
# Figure 4: v_z(x, t) heatmap at center depth — finest spatial level
# =====================================================================
if spatial_levels:
    finest = spatial_levels[-1]
    vmax = np.percentile(np.abs(finest["vel_xt"]), 99.5)
    fig, ax = plt.subplots(figsize=(9, 5))
    im = ax.pcolormesh(
        finest["ts"] * 1e3,
        finest["xs"] * 1e3,
        finest["vel_xt"].T,
        shading="auto",
        cmap="RdBu_r",
        vmin=-vmax,
        vmax=vmax,
    )
    ax.plot(finest["ts"] * 1e3, finest["x_peak"] * 1e3,
            "k-", lw=0.8, label="x of peak |v_z|")
    ax.axhline(-10, color="black", ls=":", lw=0.6, label="source x = -10 mm")
    ax.set_xlabel("Time (ms)")
    ax.set_ylabel("x (mm)")
    ax.set_title(
        f"v_z(x, t) at z=25 mm — finest spatial (h = {finest['h_mm']} mm)"
    )
    fig.colorbar(im, ax=ax, label="v_z (m/s)")
    ax.legend(loc="upper right", fontsize=8)
    fig.tight_layout()
    out = SAVE_DIR / "xpeak_heatmap_finest_spatial.png"
    fig.savefig(out, dpi=200)
    print(f"Saved: {out}")

print("\nDone.")
