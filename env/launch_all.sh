#!/bin/bash
DRY='echo DRYRUN +'
[[ $1 == --for-real ]] && DRY=
#for NEVT in 400 600 800; do
#  for NJOB in 2 5 10 15 18 20 25 40 60 75 90 100 150 200; do
for NEVT in 10; do
  for NPROC in 20; do
    $DRY sbatch -J simpythia8_testrun2 submit.sh --events $NEVT --processes $NPROC --jobs 10 --step sim
  done
done
