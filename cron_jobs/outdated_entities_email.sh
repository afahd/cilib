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
instance_state=($(echo "$instance_list" | grep status))
j=0
for (( i = 1 ; i < ${#instance_names[@]} ; i=i+2 )) do
  current_date=$(date +"%s")
  creation_date=$(date -d ${instance_creationtime[$i]} +"%s" )
  time_difference=$(($current_date - $creation_date))
  #Modify time as needed
  if [[ $time_difference -gt $time_diff && ${instance_state[$i]} == "RUNNING" ]]; then
    outdated_instances[$j]="${instance_names[$i]} ${instance_creationtime[$i]:0:10}"
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
    outdated_snapshots[$j]="${snapshot_names[$i]} ${snapshot_creationtime[$i]:0:10}"
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
    outdated_disks[$j]="${dangling_disks_names[$i]} ${dangling_disks_creationtime[$i]:0:10}"
    #Delete outdated dangling disks
    gcloud compute disks delete ${dangling_disks_names[$i]} -q
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
  send_mail=0
  cat /dev/null > email_content
  echo "Hi $email," >> email_content

  user_instances=$(printf '%s\n' "${outdated_instances[@]}" | grep "$email")
  if [[ -n $user_instances ]]; then
    echo >> email_content
    echo "The following instances are outdated consider deleting them:" >> email_content
    echo -e "Name: CreationDate:\n $user_instances" | column -t >> email_content
    echo >> email_content
    echo "Use 'aurora rm instances <regex>' to delete the instances." >> email_content
    send_mail=1
  fi

  user_disks=$(printf '%s\n' "${outdated_disks[@]}" | grep "$email")
  if [[ -n $user_disks ]]; then
    echo >> email_content
    echo "The following disks were not attached to any instance and have been deleted:" >> email_content
    echo -e "Name: CreationDate:\n $user_disks" | column -t >> email_content
    echo >> email_content
    send_mail=1
  fi

  user_snapshots=$(printf '%s\n' "${outdated_snapshots[@]}" | grep "$email")
  number_user_snapshots=$(printf '%s\n' "${outdated_snapshots[@]}" | grep "$email" | wc -l)
  #Trigger email only if more than 2 sets of snapshots present
  if [[ $number_user_snapshots -gt 4 ]]; then
    echo >> email_content
    echo "The following snapshots are outdated consider deleting them:" >> email_content
    echo -e "Name: CreationDate:\n $user_snapshots" | column -t  >> email_content
    echo >> email_content
    echo "Use 'aurora rm snapshots <regex>' to delete the instances." >> email_content
    send_mail=1
  fi
  if [[ $send_mail == 1 ]]; then
    current_date=$(date +"%d %b %Y")
    #cat email_content | mail -s "Aurora Cloud Resources Usage Report ${current_date}" -c "aurora.internal@plumgrid.com" $email@plumgrid.com
  fi
done
