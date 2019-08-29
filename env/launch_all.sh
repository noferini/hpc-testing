#!/bin/bash -e

cd "$(dirname "$0")"

DRY='echo DRYRUN +'
[[ $1 == --for-real ]] && DRY=

for NINST in 1 2 3 4 5 6 7 8; do
  for NEVT in 1600; do
    for NPROC in 6 10 14 17 19 20 21 22 23 24 25 27 30 35 40; do
      # Use a cutoff to avoid wasting time
      NPROCTOT=$((NINST * NPROC))
      if [[ $NPROCTOT -ge 40 && $NPROCTOT -le 272 ]]; then
        echo "Launching for ninst=$NINST nproc=$NPROC (total=$NPROCTOT)" >&2
        $DRY sbatch -J simpythia8_multijobs4     \
                    submit.sh --events $NEVT     \
                              --processes $NPROC \
                              --jobs $NINST      \
                              --step sim         \
                              --packages O2/nightly-20190829-1
      else
        echo "Not launching for ninst=$NINST nproc=$NPROC: not worth it" >&2
      fi
    done
  done
done
