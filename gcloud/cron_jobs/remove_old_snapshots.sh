#!/bin/bash -e

export PATH=@CMAKE_BINARY_DIR@/:/opt/pg/scripts:$PATH
source aurora_infra_settings.conf

#only get build or run snapshots
snapshot_list=$(gcloud compute snapshots list --sort-by=creationTimestamp --regexp ".*$PRIM_INST_NAME.*")
#Extract Name
snapshot_names=$(echo "$snapshot_list" | grep $PRIM_INST_NAME)

#Delete all but the last 3 sets of snapshots
snapshot_names=$(echo "$snapshot_names" | cut -d ' ' -f 1 | head -n -6)

#Delete the snapshots
gcloud compute snapshots delete $snapshot_names -q