#!/bin/bash -e
export PATH=/opt/pg/scripts:$PATH
source gc_helpers.sh
export USER=plumgrid

timestamp=$(date +%Y_%m_%d_%H:%M:%S)
aurora_build_primary_vm_snapshot.sh > ~/primary_snapshot_${timestamp}  2>&1

tail ~/primary_snapshot_${timestamp} | mail -s "Aurora Snapshot log $timestamp" aurora.internal@plumgrid.com

