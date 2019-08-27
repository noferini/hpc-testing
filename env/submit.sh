#!/bin/bash -e

#SBATCH --partition knl_usr_dbg
##SBATCH -J test_marconi
#SBATCH -A Pra18_4658
#SBATCH --time 2:00:00
#SBATCH --output /marconi_work/Pra18_4658/alice/jobs/%j_%N.out.log
#SBATCH --error  /marconi_work/Pra18_4658/alice/jobs/%j_%N.err.log

# Redirect all stderr to stdout
exec 2>&1

# Parse command-line options and export proper variables
ARGS=("$@")
N_EVENTS=0                                                      # Number of events
N_PROC=$SLURM_JOB_CPUS_PER_NODE                                 # Number of parallel processes per job
N_JOBS=1                                                        # Number of instances in same node
LOAD_PACKAGES="O2/nightly-$(TZ=Europe/Zurich date +%Y%m%d)-1"   # CVMFS packages, comma-separated
CVMFS_NAMESPACE='/cvmfs/alice-nightlies.cern.ch'                # CVMFS namespace
STEP=                                                           # Step: sim, digi, itsreco
while [[ $# -gt 0 ]]; do
  case "$1" in
    --events)
      N_EVENTS=$2
      shift
    ;;
    --jobs)
      N_JOBS=$2
      shift
    ;;
    --processes)
      N_PROC=$2
      shift
    ;;
    --packages)
      LOAD_PACKAGES=$2
      shift
    ;;
    --cvmfs-namespace)
      case "$2" in
        alice-nightlies) CVMFS_NAMESPACE='/cvmfs/alice-nightlies.cern.ch' ;;
        alice)           CVMFS_NAMESPACE='/cvmfs/alice.cern.ch' ;;
        gpfs)            CVMFS_NAMESPACE="$WORK/alice/software" ;;
        *)               CVMFS_NAMESPACE="$2"
      esac
      shift
    ;;
    --step)
      STEP=$2
      shift
    ;;
    *)
      echo "FATAL: option $1 not recognized"
      exit 1
    ;;
  esac
  shift
done

# Current executable
PROG=$(cd "$(dirname "$0")"; pwd)/$(basename "$0")

# Create a work directory (local) and work there
export MY_WORKING_DIRECTORY="$(mktemp -d)"
cd "$MY_WORKING_DIRECTORY"

# Create output directory (shared): output will be copied there at the end
if [[ ! $MY_OUTPUT_DIRECTORY ]]; then
  if [[ $STEP == sim || $STEP == digi || $STEP == itsreco ]]; then
    # Use fixed directory
    export MY_OUTPUT_DIRECTORY="$WORK/alice/jobs/$(TZ=Europe/Zurich date +%Y%m%d-%H%M%S)-${SLURM_JOB_NAME}-jid${SLURM_JOB_ID}-nevt${N_EVENTS}-njobs${N_PROC}-ninst${N_JOBS}"
  else
    # Use unique dir
    export MY_OUTPUT_DIRECTORY="$WORK/alice/jobs/$SLURM_JOB_ID"
  fi
  mkdir -p "$MY_OUTPUT_DIRECTORY"
fi

if [[ ! $SINGULARITY_CONTAINER ]]; then
  # Not in the Singularity container. Re-exec self in a container!
  exec singularity exec --contain --ipc --pid \
                        --bind /cvmfs,/scratch_local,$CINECA_SCRATCH,$WORK,$(dirname "$PROG") \
                        /cvmfs/alice-nightlies.cern.ch/singularity/alisw/slc7-builder \
                        "$PROG" "${ARGS[@]}"
fi

### From this point on: we are inside Singularity ###

# For debug, echo Slurm and Singularity envvars, plus sysinfo
env | grep -E 'SLURM|SINGULARITY' || true
lsb_release -a || true
ulimit -a || true
echo "My working directory: $(pwd)"

# Trick to bypass slow CVMFS modulecmd follows
: ${ARCH_DIR_CVMFS='el7-x86_64/Packages'}
: ${ARCH_DIR_ALIBUILD='slc7_x86-64'}
echo "Using CVMFS namespace ${CVMFS_NAMESPACE}"

# Creates a fake temporary work directory to load packages
PACKAGES_PREFIX="$CVMFS_NAMESPACE/$ARCH_DIR_CVMFS"
WORK_DIR="$(mktemp -d)"
ln -nfs "$PACKAGES_PREFIX" "$WORK_DIR/slc7_x86-64"

for PKG in $(echo "$LOAD_PACKAGES" | sed -e 's/,/ /g'); do
  # Loading the environment is non-fatal
  source "$PACKAGES_PREFIX/$PKG/etc/profile.d/init.sh" > /dev/null 2>&1 || true
done

# Cleanup of package loading
rm -rf "$WORK_DIR"
unset PKG PACKAGES_PREFIX WORK_DIR

### From this point on: we should be in the proper ALICE environment ###

# Check if environment is OK (die if not found!)
type o2-sim

# VMCWORKDIR may not be correctly set
export VMCWORKDIR="$O2_ROOT/share"

# Prepare input box in some cases
if [[ $STEP == sim || $STEP == digi || $STEP == itsreco ]]; then
  echo "Preparing input box from $MY_OUTPUT_DIRECTORY"
  rsync -av "$MY_OUTPUT_DIRECTORY/" "$MY_WORKING_DIRECTORY/"
fi

# Process monitoring
function psmon() {
  while [[ 1 ]]; do
    echo --- >> psmon.txt
    ps -u $USER -ww -o pid=,ppid=,etimes=,cputime=,vsz=,rsz=,drs=,trs=,cmd= >> psmon.txt
    sleep 60
  done
}

# What to run depends on the value of --step
case "$STEP" in

  sim)
    # Test job for simulation. We can run multiple instances of the job at the same time

    PROCESSES=()
    NEVT_PER_INST=$((N_EVENTS/N_JOBS))
    for ((I=0; I<$N_JOBS; I++)); do
        # Each test job has its own workdir
        mkdir job$I
        pushd job$I
            NEVT_THIS_INST=$NEVT_PER_INST
            if [[ $I == 0 ]]; then
                NEVT_THIS_INST=$(( N_EVENTS - (NEVT_PER_INST * (N_JOBS-1)) ))
            fi
            echo "Running simulation with $N_PROC jobs and $NEVT_THIS_INST events, job $I"
            set -x
            o2-sim ${N_PROC:+-j $N_PROC} -n $NEVT_THIS_INST --skipModules ZDC CPV MID -g pythia8 &> output.log &
            PROCESSES+=($!)
            set +x
        popd
    done

    # Launch process monitoring too
    psmon &
    PSMON_PID=$!

    # Wait upon all PIDs to finish
    echo "PIDs of all processes spawned: ${PROCESSES[*]}"
    for ((I=0; I<${#PROCESSES[*]}; I++)); do
      echo Waiting for PID ${PROCESSES[$I]}
      wait ${PROCESSES[$I]} || echo "WARNING: exited with $?"
    done
    kill -9 $PSMON_PID &> /dev/null
    echo "Job done"
  ;;

  digi)
    # Digitization
    echo "Running digitization"
    set -x
    time o2-sim-digitizer-workflow
  ;;

  itsreco)
    # ITS reconstruction
    echo "Running ITS reconstruction"
    set -x
    time o2-its-reco-workflow
  ;;

  speedtest)
    # Run test copy plus o2-sim
    SRC="$GEANT4_ROOT"
    if [[ $DATA_SOURCE == cvmfs ]]; then
      DEST=$(mktemp -d)
      echo === Warming up CVMFS cache: $SRC to $DEST ===
      time rsync -a "$SRC/" "$DEST"
      rm -rf "$DEST"
    fi
    DEST=$(mktemp -d)
    echo === Copying data from $SRC to $DEST ===
    time rsync -a "$SRC/" "$DEST"
    rm -rf "$DEST"
    for TGEANT in TGeant3 TGeant4; do
      echo === Running o2-sim -n 0 -e $TGEANT ===
      O2SIMDIR=$(mktemp -d)
      pushd "$O2SIMDIR"
        time o2-sim -n 0 -e "$TGEANT"
      popd
      rm -rf "$O2SIMDIR"
    done
  ;;

  *)
    # No step
    echo "No valid step specified (you used \"$STEP\")"
  ;;

esac


# Output
ls -l

# Copy all output to destination directory
rsync -av "$MY_WORKING_DIRECTORY/" "$MY_OUTPUT_DIRECTORY/"

# Cleanup
rm -rf "$MY_WORKING_DIRECTORY"
