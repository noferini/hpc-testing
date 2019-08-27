#!/usr/bin/env python

"""Run this script on the Slurm login node.
   It is used to summarize benchmark information for each job.
   The produced file(s) can be used offline for processing.
"""

from __future__ import print_function
import csv
import re
import sys
import os
import os.path
import json
import subprocess
from glob import glob

JOBSDIR = "$WORK/alice/jobs"
REMASK = "jid([0-9]+)-nevt([0-9]+)-njobs([0-9]+)"
SACCTCMD = "sacct --format=JobID,CPUTimeRAW,ElapsedRAW,UserCPU,AveRSS,MaxRSS --delimiter=, -P --noconvert --jobs=%s"

def convtime(raw):
    """Converts format [DD-[HH:]]MM:SS to seconds.
    """
    m = re.search("^(([0-9]+)-)?(([0-9]+):)?([0-9]+):([0-9]+)", raw)
    sec = int(m.group(6), 10) + int(m.group(5), 10) * 60
    if m.group(4):
        sec += int(m.group(4), 10) * 3600
    if m.group(2):
        sec += int(m.group(2), 10) * 86400
    return sec

def main():
    globDir = os.path.join(os.path.expandvars(JOBSDIR), sys.argv[1])
    allJobs = {}
    jobFields = [ "jobId", "nEvt", "nJobs", "success", "shMem", "cpuTime", "wallTime", "userCpu", "aveRss", "maxRss" ]

    # Get information from the jobs directory
    for jobDirFull in sorted(glob(globDir)):
        jobDir = os.path.basename(jobDirFull)
        if not os.path.isdir(jobDirFull):
            continue
        m = re.search(REMASK, jobDir)
        if m:
            j = {}
            j["jobId"] = int(m.group(1))
            j["nEvt"] = int(m.group(2))
            j["nJobs"] = int(m.group(3))
            j["success"] = os.path.isfile(os.path.join(jobDirFull, "o2sim.root"))
            allJobs[j["jobId"]] = j

    # Append accounting information from `sacct`
    jids = ",".join([ str(allJobs[j]["jobId"]) for j in allJobs ])
    with open(os.devnull) as dn:
        po = subprocess.Popen((SACCTCMD % jids).split(), stdout=subprocess.PIPE, stderr=dn)
        with po.stdout:
            rd = csv.reader(po.stdout)
            for jid,cpu,wall,usercpu,averss,maxrss in rd:
                if jid.endswith(".batch"):
                    jid = int(jid.split(".", 1)[0])
                    allJobs[jid].update({ "cpuTime": int(cpu),
                                          "wallTime": int(wall),
                                          "userCpu": convtime(usercpu),
                                          "aveRss": int(averss),
                                          "maxRss": int(maxrss) })
        po.wait()

    # Retrieve information about the use of Shared Memory vs. ZeroMQ
    for jid in allJobs:
        jobLog = glob(os.path.join(os.path.expandvars(JOBSDIR), "%d*.out.log" % jid))[0]
        # Example of ZeroMQ fallback output:
        #   [INFO] CREATING SIM SHARED MEM SEGMENT FOR 200 WORKERS
        #   shmget: shmget failed: Cannot allocate memory
        #   [INFO] SHARED MEM INITIALIZED AT ID -1
        #   [WARN] COULD NOT CREATE SHARED MEMORY ... FALLING BACK TO SIMPLE MODE
        # Example of successful Shared Memory init:
        #   [INFO] CREATING SIM SHARED MEM SEGMENT FOR 20 WORKERS
        shmem = True
        with open(jobLog) as jl:
            for line in jl:
                if "COULD NOT CREATE SHARED MEMORY" in line:
                    shmem = False
                    break
        allJobs[jid]["shMem"] = shmem

    # Write table to CSV for later processing
    wr = csv.DictWriter(sys.stdout, fieldnames=jobFields)
    wr.writeheader()
    for jid in allJobs:
        wr.writerow(allJobs[jid])

    #print(json.dumps(allJobs, indent=4))

if __name__ == "__main__":
    main()
