#!/bin/bash

####################################################################################################
# Parses the gcloud qouta information, extracts the entity to check, compares against the threshold
# limit set calculates the percentage usage and if exceeding the threshold, adds the information to
# the email file.
#
# Parameters: gcloud qouta information using gcloud cli, the name of the entity to check, the
# threshold set, and email file.
####################################################################################################

function generate_percentage_report () {
  local qouta_data_file=$1
  local metric_name=$2
  local threshold_limit=$3
  local email_file=$4

  ret_val=0
  # Extracting the line above and below the metric provided as argument, e.g CPUS, SNAPSHOTS.
  # These lines contain the actual current usage and the qouta limit assigned.
  local metric=$(cat $qouta_data_file | grep "$metric_name" -A1 -B1 | tr "-" " " )
  eval line=($metric)
  # Breaking down the entity, qouta and the limit and assigning to defined variables.
  local qouta_metric=${line[3]}
  local qouta_usage=${line[5]}
  local qouta_limit=${line[1]}
  # Providing info on the console.
  echo "- The usage of ${qouta_metric} is : ${qouta_usage}/${qouta_limit}"
  # Calculating the percentage usage.
  local percentage=$(echo "scale=4; (${qouta_usage} / ${qouta_limit} * 100)" | bc -l)
  # Removing trailing zeros
  local percentage=$(echo $percentage | awk ' sub("\\.*0+$","") ')
  # Comparing the real time usage with the threshold values.
  local comparison=`echo "${qouta_usage} >= ${threshold_limit}" | bc`
  if [[ $comparison -eq 1 ]]; then
    ret_val=222
    echo "- ${qouta_metric} has exceeded ${threshold_limit} ${qouta_metric}, , Usage = ${qouta_usage} (${percentage}%). Limit is ${qouta_limit}" >> $email_file
  fi
  return $ret_val
}

# Preparing the email content for the dreaded email.
echo "Hi Guys," > ${WORKSPACE}/email_content.txt
echo "Gcloud qouta issue detected, please take evasive actions to remedy the situation." >> ${WORKSPACE}/email_content.txt
echo "The following is the breakdown of the issues related to qoutas:" >> ${WORKSPACE}/email_content.txt

# Threshold limits to notify the CI Team.
declare -A limits=(
["CPUS"]=3500.0
["DISKS_TOTAL_GB"]=380000.0
["SNAPSHOTS"]=850.0
)

send_email=0
# Iterating over the keys from the array.
for key in ${!limits[@]}; do
  if [[ $key == "SNAPSHOTS" ]]; then
    # since we use different command to extract the usage of SNAPSHOTS.
    gcloud compute project-info describe > ${WORKSPACE}/output_raw.txt
  else
    # command to extract the usage of CPUS and DISKS_TOTAL_GB.
    gcloud compute regions describe us-central1 > ${WORKSPACE}/output_raw.txt
  fi
  generate_percentage_report ${WORKSPACE}/output_raw.txt $key ${limits[${key}]} ${WORKSPACE}/email_content.txt
  send_email=$(($send_email+$?))
done

# Checking if return values for all the entities is zero, if not send email informing CI Team.
if [[ $send_email -ne 0 ]]; then
  echo "sending email to the saviors"
  cat ${WORKSPACE}/email_content.txt
  cat ${WORKSPACE}/email_content.txt | mail -s "[ALERT]: QOUTA ABOUT TO REACH LIMIT" "alir@plumgrid.com,irfans@plumgrid.com,afahd@plumgrid.com,muaazs@plumgrid.com"
fi
