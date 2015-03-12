#!/bin/bash -e
export PATH=/opt/pg/scripts:$PATH
source gc_helpers.sh

timestamp=$(date +%Y_%m_%d_%H:%M:%S)
aurora_build_primary_vm_snapshot.sh > ~/primary_snapshot_${timestamp}
