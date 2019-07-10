#!/bin/bash -x

#SBATCH --partition knl_usr_dbg
#SBATCH -J test_marconi
#SBATCH -A Pra18_4658
#SBATCH --time 1:00:00
#SBATCH --output /marconi_work/Pra18_4658/alice/jobs/%j_%N.out.log
#SBATCH --error  /marconi_work/Pra18_4658/alice/jobs/%j_%N.err.log

# Packages to load (comma-separated)
export LOAD_PACKAGES='O2/nightly-20190710-1'

# Create a work directory (local) and work there
export MY_WORKING_DIRECTORY="$(mktemp -d)"
cd "$MY_WORKING_DIRECTORY"

# Create output directory (shared): output will be copied there at the end
export MY_OUTPUT_DIRECTORY="$WORK/alice/jobs/$SLURM_JOB_ID"
mkdir -p "$MY_OUTPUT_DIRECTORY"

if [[ ! $SINGULARITY_CONTAINER ]]; then
  # Not in the Singularity container. Re-exec self in a container!
  cp -v "$0" "$MY_WORKING_DIRECTORY"
  exec singularity exec --bind /cvmfs,/scratch_local,$CINECA_SCRATCH,$WORK \
                        /cvmfs/alice-nightlies.cern.ch/singularity/alisw/slc7-builder \
                        "$MY_WORKING_DIRECTORY"/"$(basename "$0")" "$@"
fi

### From this point on: we are in Singularity ###

# For debug, echo Slurm and Singularity envvars, plus sysinfo
env | grep -E 'SLURM|SINGULARITY'
lsb_release -a
echo "My working directory: `pwd`"

# Trick to bypass slow CVMFS modulecmd follows
: ${CVMFS_NAMESPACE='/cvmfs/alice-nightlies.cern.ch'}
: ${ARCH_DIR_CVMFS='el7-x86_64/Packages'}
: ${ARCH_DIR_ALIBUILD='slc7_x86-64'}

# Creates a fake temporary work directory to load packages
PACKAGES_PREFIX="$CVMFS_NAMESPACE/$ARCH_DIR_CVMFS"
WORK_DIR="$(mktemp -d)"
ln -nfs "$PACKAGES_PREFIX" "$WORK_DIR/slc7_x86-64"

for PKG in $(echo "$LOAD_PACKAGES" | sed -e 's/,/ /g'); do
  # Loading the environment is non-fatal
  source "$PACKAGES_PREFIX/$PKG/etc/profile.d/init.sh" > /dev/null 2>&1
done

# Cleanup of package loading
rm -rf "$WORK_DIR"
unset PKG PACKAGES_PREFIX WORK_DIR

### From this point on: we should be in the proper ALICE environment ###

# Check if environment is OK
type o2-sim

# VMCWORKDIR may not be correctly set
export VMCWORKDIR="$O2_ROOT/share"

# Run a test job
#o2-sim --help
echo "Number of jobs: $1"
echo "Number of events: $2"
time o2-sim -j $1 -n $2 -m PIPE TPC ITS -g pythia8

# Output
ls -l

# Copy all output to destination directory
rsync -av "$MY_WORKING_DIRECTORY/" "$MY_OUTPUT_DIRECTORY/"

# Cleanup
rm -rf "$MY_WORKING_DIRECTORY"
