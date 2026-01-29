# vti_to_mat.py
import pyvista as pv
import numpy as np
import scipy.io
import glob, os

vti_files = sorted(glob.glob("resampled_vti/*.vti"))
if len(vti_files) == 0:
    raise SystemExit("No .vti files found in resampled_vti/")

# read first to get dims and field names
sample = pv.read(vti_files[0])
dims = sample.dimensions  # (nx+1, ny+1, nz+1) for cell-centered vs point?
# For ImageData point arrays: sample.dimensions yields number of nodes in each direction
nx, ny, nz = dims
print("Grid dimensions (points):", nx, ny, nz)

# field name guess
field_names = list(sample.array_names)
print("Available arrays:", field_names)
# choose the right name (maybe 'vel' or 'velocity'); adjust if needed
vec_name = [n for n in field_names if 'vel' in n.lower() or 'velocity' in n.lower()]
if not vec_name:
    raise SystemExit("Couldn't find velocity array; arrays: " + str(field_names))
vec_name = vec_name[0]
print("Using vector field:", vec_name)

# Prepare storage: shape (nt, nz, ny, nx, 3) or (nx,ny,nz,nt,3)
nt = len(vti_files)
data = np.zeros((nt, nx, ny, nz, 3), dtype=np.float32)

for i,fn in enumerate(vti_files):
    print("Reading", fn)
    grid = pv.read(fn)
    arr = grid[vec_name]   # shape (n_points, 3) for vector
    # reshape depends on ordering; ImageData stores point ordering as z fastest? check dims.
    # PyVista returns points in node order; easiest is to reshape by known dims:
    arr3 = arr.reshape((nx, ny, nz, 3), order='F')  # try Fortran-order; may need 'C'
    # store transposed to (nx,ny,nz,3)
    data[i] = arr3  # adjust if needed

# Save to .mat: choose layout MATLAB-friendly
# e.g., velocity(x,y,z,t,component) -> rearrange axes to (nx,ny,nz,nt,3)
data_mat = np.transpose(data, (1,2,3,0,4))  # (nx,ny,nz,nt,3)
scipy.io.savemat("velocity_resampled.mat", {'velocity': data_mat})
print("Saved velocity_resampled.mat")
