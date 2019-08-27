#!/usr/bin/bash -e

export WORK_DIR=${WORK}/alice/alice/sw 
source ${WORK_DIR}/slc7_x86-64/O2/latest/etc/profile.d/init.sh
export PATH=$PATH:${WORK_DIR}/slc7_x86-64/O2/latest/bin
export VMCWORKDIR=${O2_ROOT}/share

which o2-sim
o2-sim-serial -n 1 -m TPC 2>&1 | tee o2sim.log
