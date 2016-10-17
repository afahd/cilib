#!/bin/bash -e
export PATH=/opt/pg/scripts:$PATH
source gc_helpers.sh
source aurora_infra_settings.conf
export USER=plumgrid

function delete_instance() {
    gcloud compute instances delete $PRIM_INST_NAME --delete-disks all  -q
}

timestamp=$(date +%Y_%m_%d_%H:%M:%S)
trap 'delete_instance' EXIT
aurora_build_primary_vm_snapshot.sh > ~/primary_snapshot_${timestamp}  2>&1

tail ~/primary_snapshot_${timestamp} | mail -s "Aurora Snapshot log $timestamp" aurora.internal@plumgrid.com

