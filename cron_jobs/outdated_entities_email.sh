#!/bin/bash

#Usage outdated_entities_email.sh <Instance/snapshot time elapsed> <Disks time elapsed>
#Script to send emails to user about outdated instances, disks and snapshots.
#If the time difference between the creation time and the current time is greater than the specified duration
#and email is sent to the user notifying about the outdated entities.
#Email is extracted from the name of the entity.

#Time elapsed since creation (seconds) for generating email for instances and snapshots
time_diff=$1
#Time elapsed since creation (seconds) for generating email for disks
time_diff_disks=$2
#array for mapping emails and gerritids
declare -A email_array
#only get build or run instances
instance_list=$(gcloud compute instances list --format=text --sort-by=creationTimestamp --regexp ".*(run|bld).*")
#Extract Name and creation time stamp
instance_names=($(echo "$instance_list" | grep '^name'))
instance_creationtime=($(echo "$instance_list" | grep creationTimestamp))
j=0
for (( i = 1 ; i < ${#instance_names[@]} ; i=i+2 )) do
  current_date=$(date +"%s")
  creation_date=$(date -d ${instance_creationtime[$i]} +"%s" )
  time_difference=$(($current_date - $creation_date))
  #Modify time as needed
  if [[ $time_difference -gt $time_diff ]]; then
    outdated_instances[$j]=${instance_names[$i]}
    name=$(echo ${instance_names[$i]} | awk -F'-' '{print $1}' )
    #Add to the email array if not already present
    if [[ -z ${email_array[$name]} ]]; then
      email_array[${name}]=1
    fi
    ((j++))
  fi
done

#only get build or run snapshots
snapshot_list=$(gcloud compute snapshots list --format=text --sort-by=creationTimestamp --regexp ".*(run|bld).*")
#Extract Name and creation time stamp
snapshot_names=($(echo "$snapshot_list" | grep '^name'))
snapshot_creationtime=($(echo "$snapshot_list" | grep creationTimestamp))
j=0
for (( i = 1 ; i < ${#snapshot_names[@]} ; i=i+2 )) do
  current_date=$(date +"%s")
  creation_date=$(date -d ${snapshot_creationtime[$i]} +"%s" )
  time_difference=$(($current_date - $creation_date))
  #Modify time as needed
  if [[ $time_difference -gt $time_diff ]]; then
    outdated_snapshots[$j]=${snapshot_names[$i]}
    name=$(echo ${snapshot_names[$i]} | awk -F'-' '{print $1}' )
    #Add to the email array if not already present
    if [[ -z ${email_array[$name]} ]]; then
      email_array[${name}]=1
    fi
    ((j++))
  fi
done

#Disks containg name of instances have to excluded from the search in order to find dangling disks\
disk_exclude_list=$(echo "${instance_names[@]} NAME" | sed -e 's/name\: //g' | tr ' ' \| )
dangling_disks=$(gcloud compute disks list --regexp ".*(run|bld).*" --sort-by=creationTimestamp | grep -E -v "${disk_exclude_list}" | cut -d ' ' -f 1 )
dangling_disks=$(echo "$dangling_disks" | tr '\r\n' '|')
dangling_disks=$(gcloud compute disks list --format text --regexp "(${dangling_disks})")
dangling_disks_names=($(echo "${dangling_disks}" | grep '^name:'))
dangling_disks_creationtime=($(echo "${dangling_disks}" | grep creationTimestamp))

j=0
for (( i = 1 ; i < ${#dangling_disks_names[@]} ; i=i+2 )) do
  current_date=$(date +"%s")
  creation_date=$(date -d ${dangling_disks_creationtime[$i]} +"%s" )
  time_difference=$(($current_date - $creation_date))
  #Modify time as needed
  if [[ $time_difference -gt $time_diff_disks ]]; then
    outdated_disks[$j]=${dangling_disks_names[$i]}
    name=$(echo ${dangling_disks_names[$i]} | awk -F'-' '{print $1}' )
    #Add to the email array if not already present
    if [[ -z ${email_array[$name]} ]]; then
      email_array[${name}]=1
    fi
    ((j++))
  fi
done

#Send out the email for every unique email address
for email in "${!email_array[@]}"; do
  cat /dev/null > email_content
  echo "Hi $email, The following instances are outdated consider deleting them:" >> email_content
  for instance in "${outdated_instances[@]}"; do
    echo "$instance" | grep "$email" >> email_content
  done

  echo "The following disks are not attached to any instances:" >> email_content
  for disk in "${outdated_disks[@]}"; do
    echo "$disk" | grep "$email" >> email_content
  done

  echo "The following snapshots are outdated consider deleting them:" >> email_content
  for snapshot in "${outdated_snapshots[@]}"; do
    echo "$snapshot" | grep "$email" >> email_content
  done
  echo "$email@plumgrid.com"
  cat email_content | mail -s "Gcloud Running Entities" $email@plumgrid.com
done