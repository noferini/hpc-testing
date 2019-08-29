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
REMASK = "jid([0-9]+)-nevt([0-9]+)-njobs([0-9]+)-ninst([0-9]+)"
SACCTCMD = "sacct --format=JobID,UserCPU,ElapsedRAW,AveRSS,MaxRSS --delimiter=, -P --noconvert --jobs=%s"

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

def slurmStats():
    globDir = os.path.join(os.path.expandvars(JOBSDIR), sys.argv[1])
    allJobs = {}
    jobFields = [ "jobId", "nEvt", "nProc", "nInst", "nInstOk", "nShMem", "slurmUserCpu",
                  "slurmWallTime", "slurmAveRss", "slurmMaxRss" ]

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
            j["nProc"] = int(m.group(3))
            j["nInst"] = int(m.group(4))
            # Now inspect subdirs
            success = 0
            nShMem = 0
            for i in range(j["nInst"]):
                subJobDir = os.path.join(jobDirFull, "job%d" % i)
                if os.path.isfile(os.path.join(subJobDir, "o2sim.root")):
                    success += 1
                else:
                    continue
                shMem = True
                with open(os.path.join(subJobDir, "output.log")) as jl:
                    for line in jl:
                        if "COULD NOT CREATE SHARED MEMORY" in line:
                            shMem = False
                            break
                if shMem:
                    nShMem += 1

            j["nInstOk"] = success
            j["nShMem"] = nShMem
            allJobs[j["jobId"]] = j

    # Append accounting information from `sacct`
    jids = ",".join([ str(allJobs[j]["jobId"]) for j in allJobs ])
    with open(os.devnull) as dn:
        po = subprocess.Popen((SACCTCMD % jids).split(), stdout=subprocess.PIPE, stderr=dn)
        with po.stdout:
            rd = csv.reader(po.stdout)
            for jid,usercpu,wall,averss,maxrss in rd:
                if jid.endswith(".batch"):
                    jid = int(jid.split(".", 1)[0])
                    allJobs[jid].update({ "slurmWallTime": int(wall),
                                          "slurmUserCpu": convtime(usercpu),
                                          "slurmAveRss": int(averss),
                                          "slurmMaxRss": int(maxrss) })
        po.wait()

    # Write Slurm stats to a file
    with open("slurm_stats.csv", "w") as js:
        wr = csv.DictWriter(js, fieldnames=jobFields)
        wr.writeheader()
        for jid in allJobs:
            wr.writerow(allJobs[jid])
    print("Jobs stats written to slurm_stats.csv")

def parsePsmon():
    globDir = os.path.join(os.path.expandvars(JOBSDIR), sys.argv[1])
    fields = [ "pid", "ppid", "etimes", "cputime", "vsz", "rsz", "drs", "trs", "cmd" ]

    with open("psmon.csv", "w") as csvfp:
        csvout = csv.writer(csvfp)
        csvout.writerow(["jobId", "nEvt", "nProc", "nInst", "elapsed", "cpuEff", "vsz", "rsz"])

        for jobDirFull in sorted(glob(globDir)):
            psMon = os.path.join(jobDirFull, "psmon.txt")
            if not os.path.isfile(psMon):
                continue
            m = re.search(REMASK, os.path.basename(jobDirFull))
            if not m:
                continue
            jobId = int(m.group(1))
            nEvt = int(m.group(2))
            nProc = int(m.group(3))
            nInst = int(m.group(4))
            print("Parsing %s" % psMon)

            cpuEffSample = 0.
            elapsed = -1
            vszSample = 0
            rszSample = 0
            with open(psMon) as pm:
                # pid=,ppid=,etimes=,cputime=,vsz=,rsz=,drs=,trs=,cmd=
                for line in pm:
                    if line.startswith("---"):
                        if elapsed > -1:
                            # Dump data
                            csvout.writerow([jobId, nEvt, nProc, nInst, elapsed, cpuEffSample, vszSample, rszSample])
                        cpuEffSample = 0.
                        elapsed = -1
                        vszSample = 0
                        rszSample = 0
                        continue
                    rec = dict(zip(fields, line.split(None, len(fields)-1)))
                    rec["cputime"] = convtime(rec["cputime"])
                    for f in fields:
                        rec[f] = int(rec[f]) if f != "cmd" else rec[f].strip()
                    if rec["etimes"] > 0:
                        cpuEffSample += float(rec["cputime"]) / float(rec["etimes"])
                    vszSample += int(rec["vsz"])
                    rszSample += int(rec["rsz"])
                    if "slurm_script" in rec["cmd"] and rec["etimes"] > elapsed:
                        # Job running time == Slurm script elapsed time
                        # TODO this is quite weak, works with Slurm and a single dedicated node...
                        elapsed = rec["etimes"]
                        
            # Dump data
            csvout.writerow([jobId, nEvt, nProc, nInst, elapsed, cpuEffSample, vszSample, rszSample])

    print("Process monitoring stats written to psmon.csv")

if __name__ == "__main__":
    slurmStats()
    parsePsmon()
