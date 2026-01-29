#!/bin/bash

nohup mpiexec -n 32 /home/ddm42/projects/sheep/sheep-opt -i /home/ddm42/projects/sheep/problems/Lesion-DirBC.i > /home/ddm42/projects/sheep/problems/progress_logs/out.txt 2>&1 &
