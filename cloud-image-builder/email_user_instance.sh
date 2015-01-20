#!/bin/bash
function get_instance_ip() {
  local INSTANCE_NAME=$1
  local internal_ip=$(gcloud compute instances list ${INSTANCE_NAME} --zones=us-central1-f | grep ${INSTANCE_NAME} | cut -d ' ' -f 4)
  echo $internal_ip
}
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
  if [[ $time_difference -gt 86400 ]]; then
    outdated_instances[$j]=${instance_names[$i]}
    name=$(echo ${instance_names[$i]} | awk -F'-' '{print $1}' )
    instance_ip=$(get_instance_ip ${instance_names[$i]})
    email=$(ssh ${instance_ip} "curl \"http://metadata.google.internal/computeMetadata/v1/instance/attributes/email\" -H \"Metadata-Flavor: Google\"")
    if [[ -z ${email_array[$name]} ]]; then
      email_array[${name}]=$email
    fi
    ((j++))
  fi
done

for K in "${!email_array[@]}"; do
  echo ${email_array[$K]}
  cat /dev/null > email_content
  echo "Hi $K, The following instances are outdated consider deleting them:" >> email_content
  for instance in "${outdated_instances[@]}"; do
    echo "$instance" | grep "$K" >> email_content
  done
  cat email_content | mail -s "Gcloud Running Instances" ${email_array[$K]}
done