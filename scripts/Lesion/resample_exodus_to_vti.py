# resample_exodus_to_vti.py
from paraview.simple import *
import os, sys

# USER SETTINGS — edit if needed
exodus_file = "mesh.exo"          # path to your Exodus file
out_dir = "resampled_vti"         # output directory
nx, ny, nz = 200, 200, 1          # sampling dims (make nz>1 for 3D)
field_name = "vel"                # name of your velocity field in Exodus
# end user settings

if not os.path.exists(out_dir):
    os.makedirs(out_dir)

# load exodus
reader = ExodusIIReader(FileName=[exodus_file])
reader.PointVariables = ["vel"]    # try point variables first; adjust if variable is named differently
reader.UpdatePipeline()

# get bounds of input
di = GetDataInformation(reader)
bounds = di.GetBounds()  # (xmin,xmax,ymin,ymax,zmin,zmax)
xmin,xmax,ymin,ymax,zmin,zmax = bounds

# prepare resampler (ResampleToImage)
resampler = ResampleToImage(Input=reader)
resampler.SamplingDimensions = [int(nx), int(ny), int(nz)]
resampler.SamplingBounds = [xmin, xmax, ymin, ymax, zmin, zmax]

# time steps
timesteps = GetTimeSteps()
print("Found time steps:", timesteps)

for i,t in enumerate(timesteps):
    print(f"Processing time {t} ({i+1}/{len(timesteps)})")
    # update reader/time
    reader.UpdatePipeline(time=t)
    # update resampler
    resampler.UpdatePipeline(time=t)
    # Save resampled grid to VTI (ImageData)
    outname = os.path.join(out_dir, f"resampled_t{int(round(t*1e9)):09d}.vti")
    # we use time in filename to sort; you can change naming
    SaveData(outname, proxy=resampler)
    print("Wrote", outname)

print("Done.")
