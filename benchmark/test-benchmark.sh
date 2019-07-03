#!/usr/bin/bash -e

export WORK_DIR=${WORK}/alice/alice/sw 
source ${WORK_DIR}/slc7_x86-64/O2/latest/etc/profile.d/init.sh
export PATH=$PATH:${WORK_DIR}/slc7_x86-64/O2/latest/bin
export VMCWORKDIR=${O2_ROOT}/share

time o2-sim-serial -n 0 -e TGeant4 2>&1 | tee benchmark.log
