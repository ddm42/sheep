#!/bin/bash

source ~/miniforge/etc/profile.d/conda.sh && conda activate moose

mkdir -p /Users/ddm42/projects/sheep/problems/progress_logs

nohup mpiexec -n 30 /Users/ddm42/projects/sheep/sheep-opt \
  -i /Users/ddm42/projects/sheep/problems/HomRect/HomRect.i \
  nx=500 ny=312 my_dt=0.0125e-3 filename="HomRect_h0.16mm_dt0.0125ms" -w \
  > /Users/ddm42/projects/sheep/problems/progress_logs/HomRect_out.txt 2>&1 &
