#!/bin/bash
DRY='echo DRYRUN +'
[[ $1 == --for-real ]] && DRY=

for NINST in 1 2 4 6 8 10 11 12 13; do
  for NEVT in 1200 1600; do
    for NPROC in 20; do
      $DRY sbatch -J simpythia8_multijobs2 submit.sh --events $NEVT --processes $NPROC --jobs $NINST --step sim
      #                                              ^^^^^^^^^^^^^^ ^^^^^^^^^^^^^^^^^^ ^^^^^^^^^^^^^
      #                                              total num evt  parallel fmq proc  n o2-sim inst
    done
  done
done
