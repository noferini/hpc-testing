HPC testing
===========

Scripts for testing O2 simulations on HPC resources.


Prerequisites
-------------
* [Singularity](https://sylabs.io/docs/)
* [CVMFS](https://cernvm.cern.ch/portal/filesystem)

The submission script works both standalone, and submitted via Slurm.


Launch a simulation
-------------------
Standalone:

```
env/submit.sh -J JOBNAME \
              --events NEVENTS \
              --processes NPROCESSES \
              --jobs NJOBS \
              --step sim \
              [--packages O2/nightly-XXXXYYZZ-1]
```

Submit via Slurm:

```
sbatch -J JOBNAME env/submit.sh --events NEVENTS \
                                --processes NPROCESSES \
                                --jobs NJOBS \
                                --step sim \
                                [--packages O2/nightly-XXXXYYZZ-1]
```

The commands are very similar: `-J` is used as a parameter to `sbatch` instead of `submit.sh`.

Parameters:

* `--events NEVENTS`: total number of events to generate. If the submission has multiple instances
  (_i.e._ `--jobs` has a value greater than 1), each instance will generate its fraction of events.
* `--processes NPROCESSES`: number of FairMQ parallel devices to be launched for each instance
* `--jobs NJOBS`: number of instances of `o2-sim` to launch
* `--packages O2/nightly-XXXXYYZZ-1`: specify the O2 package to pick from CVMFS (if unspecified use
  today's date in Geneva timezone to pick one)
