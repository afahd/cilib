#!/bin/bash -e
export PATH=/opt/pg/scripts:${PATH}
source gc_helpers.sh
export USER=plumgrid

timestamp=$(date +%Y_%m_%d_%H:%M:%S)
build_foster_vm_snapshot.sh > ~/foster_snapshot_${timestamp}  2>&1

tail ~/foster_snapshot_${timestamp} | mail -s "Foster Snapshot log ${timestamp}" aurora.internal@plumgrid.com
