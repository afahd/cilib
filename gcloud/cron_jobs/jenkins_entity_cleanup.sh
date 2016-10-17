#!/bin/bash

#Script to cleanup running entities for jenkins. Deletes all the instances/disks/snapshots
#running for longer than the specified time.
if [[ -z $2 ]]; then
  user_name="jenkins"
else
  user_name="$2"
fi

time_diff=$1
instance_list=$(gcloud compute instances list --format=text --sort-by=creationTimestamp --regexp "${user_name}.*")
#Extract Name and creation time stamp
instance_names=($(echo "$instance_list" | grep '^name'))
instance_creationtime=($(echo "$instance_list" | grep creationTimestamp))

for (( i = 1 ; i < ${#instance_names[@]} ; i=i+2 )) do
  current_date=$(date +"%s")
  creation_date=$(date -d ${instance_creationtime[$i]} +"%s" )
  time_difference=$(($current_date - $creation_date))
  #Modify time as needed
  if [[ $time_difference -gt $time_diff ]]; then
    outdated_instances="$outdated_instances ${instance_names[$i]}"
  fi
done
gcloud compute instances delete $outdated_instances --delete-disks all -q

#only get build or run snapshots
snapshot_list=$(gcloud compute snapshots list --format=text --sort-by=creationTimestamp --regexp "${user_name}.*")
#Extract Name and creation time stamp
snapshot_names=($(echo "$snapshot_list" | grep '^name'))
snapshot_creationtime=($(echo "$snapshot_list" | grep creationTimestamp))

for (( i = 1 ; i < ${#snapshot_names[@]} ; i=i+2 )) do
  current_date=$(date +"%s")
  creation_date=$(date -d ${snapshot_creationtime[$i]} +"%s" )
  time_difference=$(($current_date - $creation_date))
  #Modify time as needed
  if [[ $time_difference -gt $time_diff ]]; then
    outdated_snapshots="$outdated_snapshots ${snapshot_names[$i]}"
  fi
done
gcloud compute snapshots delete $outdated_snapshots -q

#Disks containg name of instances have to excluded from the search in order to find dangling disks
disk_exclude_list=$(echo "${instance_names[@]} NAME" | sed -e 's/name\: //g' | tr ' ' \| )
dangling_disks=$(gcloud compute disks list --regexp "${user_name}.*" --sort-by=creationTimestamp | grep -E -v "${disk_exclude_list}" | cut -d ' ' -f 1 )
dangling_disks=$(echo "$dangling_disks" | tr '\r\n' '|')
dangling_disks=$(gcloud compute disks list --format text --regexp "(${dangling_disks})")
dangling_disks_names=($(echo "${dangling_disks}" | grep '^name:'))
dangling_disks_creationtime=($(echo "${dangling_disks}" | grep creationTimestamp))

for (( i = 1 ; i < ${#dangling_disks_names[@]} ; i=i+2 )) do
  current_date=$(date +"%s")
  creation_date=$(date -d ${dangling_disks_creationtime[$i]} +"%s" )
  time_difference=$(($current_date - $creation_date))
  #Modify time as needed
  if [[ $time_difference -gt $time_diff ]]; then
    outdated_disks="$outdated_disks ${dangling_disks_names[$i]}"
  fi
done
gcloud compute disks delete $outdated_disks -q
