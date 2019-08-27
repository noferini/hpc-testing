#!/bin/bash
CMD=${1:-shell}
shift
set -x
exec singularity ${CMD} --bind /cvmfs,/scratch_local,$CINECA_SCRATCH,$WORK /cvmfs/alice-nightlies.cern.ch/singularity/alisw/slc7-builder "$@"
