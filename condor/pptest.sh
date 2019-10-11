#!/bin/bash 

# prepare list of command to be exected under singularity
echo "o2-sim -n 272 -g pythia8 -m PIPE ITS TPC TOF >sim.log" > run.sh
echo "pwd" >> run.sh

chmod a+x run.sh

USER=$(whoami)
id $USER

echo "---------------"

ls /tmp/

echo "---------------"

pwd

ls -la

#/cvmfs/alice-nightlies.cern.ch/bin/alienv setenv VO_ALICE@O2::nightly-20191010-1 -c \
#/cvmfs/alice-nightlies.cern.ch/bin/alienv setenv VO_ALICE@AliEn-ROOT-Legacy::0.1.1-3 -c \
#./runsim.sh

singularity exec --bind /cvmfs,/scratch_local /cvmfs/alice-nightlies.cern.ch/singularity/alisw/slc7-builder \
/cvmfs/alice-nightlies.cern.ch/bin/alienv setenv O2/nightly-20190710-1 -c \
./run.sh

#singularity exec --bind /cvmfs,/scratch_local,$CINECA_SCRATCH,$WORK /cvmfs/alice-nightlies.cern.ch/singularity/alisw/slc7-builder /cvmfs/alice-nightlies.cern.ch/bin/alienv setenv O2/nightly-20190710-1 -c o2-sim --help


ls -altr
