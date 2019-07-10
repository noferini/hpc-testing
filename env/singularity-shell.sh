#!/bin/bash
singularity shell --bind /cvmfs,/scratch_local,$CINECA_SCRATCH,$WORK /cvmfs/alice-nightlies.cern.ch/singularity/alisw/slc7-builder
