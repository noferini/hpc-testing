#!/usr/bin/bash -e

export WORK_DIR=${WORK}/alice/alice/sw 
source ${WORK_DIR}/slc7_x86-64/O2/latest/etc/profile.d/init.sh
export PATH=$PATH:${WORK_DIR}/slc7_x86-64/O2/latest/bin
export VMCWORKDIR=${O2_ROOT}/share

o2-sim -j 4 -n 20 -m PIPE TPC ITS -g pythia8 2>&1 | tee o2sim.log
