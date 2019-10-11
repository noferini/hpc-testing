#!/bin/bash

CE=
PORT=

JOBID=${1}

if [[ -z ${JOBID} ]]; then
  echo "Please pass JobID"
  exit
fi

echo "Retrieving output for JobID ${JOBID}"

condor_transfer_data -name $CE -pool $CE:$PORT ${JOBID}

JOBTARGETDIR="output/${JOBID}"

mkdir -v -p "${JOBTARGETDIR}"

TOMOVE="pptest.log pptest.out pptest.err"
for i in ${TOMOVE}; do
 mv -v $i "${JOBTARGETDIR}/"
done
ln -s ${JOBTARGETDIR} latest
