#!/usr/bin/env python

import subprocess
import csv
import os
import pwd

SACCTCMD = "sacct -u %s --delimiter=, --format=JobID,JobName,State,Elapsed -P --noconvert -s R,PD" % pwd.getpwuid(os.getuid()).pw_name
FMT = "| % 10s | %-40s | %-12s |"

with open(os.devnull) as dn:
    po = subprocess.Popen(SACCTCMD.split(), stdout=subprocess.PIPE, stderr=dn)
    state_count = {}
    first = True
    with po.stdout:
        rd = csv.DictReader(po.stdout)
        for d in rd:
            if d["JobName"] == "extern":
                continue
            s = d["State"]
            state_count[s] = state_count.get(s, 0) + 1
            if s == "RUNNING":
                if first:
                    print(FMT % ("JobID", "JobName", "Elapsed"))
                    first = False
                print(FMT % (d["JobID"], d["JobName"],d["Elapsed"]))

for k in state_count:
    print("%10s: %d jobs" % (k, state_count[k]))
