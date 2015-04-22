#!/bin/bash

convertsecs() {
 ((h=${1}/3600))
 ((m=(${1}%3600)/60))
 ((s=${1}%60))
}

declare -A usages_N1Standard_2
declare -A usages_N1Standard_4
declare -A usages_G1Small
declare -A usages_F1Micro
declare -A usages_N1Highcpu_2
declare -A usages_N1Highmem_4
declare -A overall_cost
declare -A overall_usages

N1Standard_2_cost=0.126
N1Standard_4_cost=0.252
G1Small_cost=0.032
F1Micro_cost=0.012
N1Highcpu_2_cost=0.080
N1Highmem_4_cost=0.296
num_days=$1

echo "1. Download latest ci-report file"
latest_ci_report=( $(gsutil ls gs://ci-bucket/* | grep ci-report | tail -$num_days) )
i=0
for file in ${latest_ci_report[@]}; do
  latest_ci_report[i++]=${file##*/}
done
firstday=${latest_ci_report[0]##*_}
firstday=${firstday%.*}
if [[ num_days -eq 1 ]]; then
  gcloud_report="gcloud_report_$firstday"
else
  lastday=${latest_ci_report[$num_days-1]##*_}
  lastday=${lastday%.*}
  gcloud_report="gcloud_report_$firstday-$lastday"

fi
if [[ -e $gcloud_report.csv ]]; then
  rm "$gcloud_report.csv"
fi
j=1
for file in ${latest_ci_report[@]}; do
  gsutil cp gs://ci-bucket/${file} .
  echo "Concatinating file $((j++))"
  cat $file >> "$gcloud_report.csv"
done
latest_ci_report="$gcloud_report.csv"
echo "${latest_ci_report}"
#ci_report=${1:-$latest_ci_report}
ci_report=$latest_ci_report
echo "2. Extract VMs information from ci-report file"
timestamp=${ci_report##*_}
timestamp=${timestamp%.*}

grep Vmimage ${ci_report} > vminfo

echo "3. Calculate individual user's usage (will be in seconds)"
while read line
do
  instance_type=`echo $line | cut -d',' -f 2`
  instance_type=${instance_type##*/}
  instance_type=${instance_type:7}
  time_sec=`echo $line | cut -d',' -f 3`
  name_full=`echo $line  | cut -d',' -f 5 | cut -d '/' -f 11`
  name=`echo $name_full | cut -d '-' -f 1`

  if [ ${instance_type} == "N1Standard_2" ];then
    old_time="${usages_N1Standard_2[$name]}"
    new_time=$((old_time + time_sec))
    usages_N1Standard_2[$name]=$new_time
  elif [ ${instance_type} == "G1Small" ];then
    old_time="${usages_G1Small[$name]}"
    new_time=$((old_time + time_sec))
    usages_G1Small[$name]=$new_time
  elif [ ${instance_type} == "F1Micro" ];then
    old_time="${usages_F1Micro[$name]}"
    new_time=$((old_time + time_sec))
    usages_F1Micro[$name]=$new_time
  elif [ ${instance_type} == "N1Highcpu_2" ];then
    old_time="${usages_N1Highcpu_2[$name]}"
    new_time=$((old_time + time_sec))
    usages_N1Highcpu_2[$name]=$new_time
  elif [ ${instance_type} == "N1Highmem_4" ];then
    old_time="${usages_N1Highmem_4[$name]}"
    new_time=$((old_time + time_sec))
    usages_N1Highmem_4[$name]=$new_time
  else
    old_time="${usages_N1Standard_4[$name]}"
    new_time=$((old_time + time_sec))
    usages_N1Standard_4[$name]=$new_time
  fi
total_time="${overall_usages[$name]}"
total_time=$((total_time + time_sec))
overall_usages[$name]=$total_time
done < vminfo

echo "4. Print usage infromation in readable format hh:mm:ss to usage_report${timestamp}"
cat /dev/null > sorted_usage_report${timestamp}

printf "\n***********************************************************\n" >> sorted_usage_report${timestamp}
printf "N1Standard_2\n" >> sorted_usage_report${timestamp}
printf "***********************************************************\n" >> sorted_usage_report${timestamp}
cat /dev/null > tmp_report
for name  in "${!usages_N1Standard_2[@]}" ; do
  time_sec=${usages_N1Standard_2[$name]}
  convertsecs $time_sec
  readable_time="$h:$m:$s"
  cost=$(echo "$h*$N1Standard_2_cost" | bc -l)
  old_cost="${overall_cost[$name]}"
  if [ -z "$old_cost" ]; then
    old_cost=0
  fi
  new_total_cost=$(echo "${old_cost}+${cost}" | bc )
  overall_cost[$name]=${new_total_cost}
  printf "%-15s %-15s %-15s %-15s \n" ${usages_N1Standard_2[$name]} ${readable_time} ${name} ${cost} >> tmp_report
done
sort -n -r tmp_report >> sorted_usage_report${timestamp}

printf "\n***********************************************************\n" >> sorted_usage_report${timestamp}
printf "G1Small\n" >> sorted_usage_report${timestamp}
printf "***********************************************************\n" >> sorted_usage_report${timestamp}
cat /dev/null > tmp_report
for name  in "${!usages_G1Small[@]}" ; do
  time_sec=${usages_G1Small[$name]}
  convertsecs $time_sec
  readable_time="$h:$m:$s"
  cost=$(echo "$h*$G1Small_cost" | bc -l)
  old_cost="${overall_cost[$name]}"
  if [ -z "$old_cost" ]; then
    old_cost=0
  fi
  new_total_cost=$(echo "$old_cost+$cost" | bc -l)
  overall_cost[$name]=${new_total_cost}
  printf "%-15s %-15s %-15s %-15s \n" ${usages_G1Small[$name]} ${readable_time} ${name} ${cost} >> tmp_report
done
sort -n -r tmp_report >> sorted_usage_report${timestamp}

printf "\n***********************************************************\n" >> sorted_usage_report${timestamp}
printf "F1Micro \n" >> sorted_usage_report${timestamp}
printf "***********************************************************\n" >> sorted_usage_report${timestamp}
cat /dev/null > tmp_report
for name  in "${!usages_F1Micro[@]}" ; do
  time_sec=${usages_F1Micro[$name]}
  convertsecs $time_sec
  readable_time="$h:$m:$s"
  cost=$(echo "$h*$F1Micro_cost" | bc -l)
  old_cost="${overall_cost[$name]}"
  if [ -z "$old_cost" ]; then
    old_cost=0
  fi
  new_total_cost=$(echo "$old_cost+$cost" | bc -l)
  overall_cost[$name]=${new_total_cost}
  printf "%-15s %-15s %-15s %-15s \n" ${usages_F1Micro[$name]} ${readable_time} ${name} ${cost} >> tmp_report
done
sort -n -r tmp_report >> sorted_usage_report${timestamp}

printf "\n***********************************************************\n" >> sorted_usage_report${timestamp}
printf "N1Highmem_4\n" >> sorted_usage_report${timestamp}
printf "***********************************************************\n" >> sorted_usage_report${timestamp}
cat /dev/null > tmp_report
for name  in "${!usages_N1Highmem_4[@]}" ; do
  time_sec=${usages_N1Highmem_4[$name]}
  convertsecs $time_sec
  readable_time="$h:$m:$s"
  cost=$(echo "$h*$N1Highmem_4_cost" | bc -l)
  old_cost="${overall_cost[$name]}"
  if [ -z "$old_cost" ]; then
    old_cost=0
  fi
  new_total_cost=$(echo "$old_cost+$cost" | bc -l)
  overall_cost[$name]=${new_total_cost}
  printf "%-15s %-15s %-15s %-15s \n" ${usages_N1Highmem_4[$name]} ${readable_time} ${name} ${cost} >> tmp_report
done
sort -n -r tmp_report >> sorted_usage_report${timestamp}

printf "\n***********************************************************\n" >> sorted_usage_report${timestamp}
printf "N1Standard_4\n" >> sorted_usage_report${timestamp}
printf "***********************************************************\n" >> sorted_usage_report${timestamp}
cat /dev/null > tmp_report
for name  in "${!usages_N1Standard_4[@]}" ; do
  time_sec=${usages_N1Standard_4[$name]}
  convertsecs $time_sec
  readable_time="$h:$m:$s"
  cost=$(echo "$h*$N1Standard_4_cost" | bc -l)
  old_cost="${overall_cost[$name]}"
  if [ -z "$old_cost" ]; then
    old_cost=0
  fi
  new_total_cost=$(echo "$old_cost+$cost" | bc -l)
  overall_cost[$name]=${new_total_cost}
  printf "%-15s %-15s %-15s %-15s \n" ${usages_N1Standard_4[$name]} ${readable_time} ${name} ${cost} >> tmp_report
done
sort -n -r tmp_report >> sorted_usage_report${timestamp}

printf "\n-----------------------------------------------------------\n" >> sorted_usage_report${timestamp}
printf "Total Cost spent by each individual" >> sorted_usage_report${timestamp}
printf "\n-----------------------------------------------------------\n" >> sorted_usage_report${timestamp}
cat /dev/null > tmp_report
for name in "${!overall_cost[@]}"; do
  printf "%-15s %-15s \n" ${overall_cost[$name]} $name >> tmp_report
done
sort -n -r tmp_report >> sorted_usage_report${timestamp}

#sending out email
echo "5. Sending out email"
printf "\nHi All\n" >> email_body
if [[ num_days -eq 30 || num_days -eq 31 ]]; then
 printf "\nFollowing is the Aurora cloud resources cost report for last month.\n" >> email_body
 email_sub="Aurora monthly cloud resources cost report"
elif [[ num_days -eq 7 ]]; then
 printf "\nFollowing is the Aurora cloud resources cost report for last week.\n" >> email_body
 email_sub="Aurora weekly cloud resources cost report"
elif [[ num_days -eq 1 ]]; then
 printf "\nFollowing is the Aurora daily cloud resources cost report.\n" >> email_body
 email_sub="Aurora daily cloud resources cost report"
else
  printf "\nFollowing is the Aurora cloud resources cost report for last $num_days days.\n" >> email_body
 email_sub="Aurora cloud resources cost report for last $num_days days"
fi
printf "\n-----------------------------------------------------------\n" >> email_body
printf "Total cost spent by each individual" >> email_body
printf "\n-----------------------------------------------------------\n\n" >> email_body
printf "%-15s %-15s %-15s \n"  "Cost" "Name" "Total Time" >> email_body
printf "%-15s %-15s %-15s \n"  " " " " "(HHHH:MM:SS)" >> email_body
printf "\n--------------------------------------------\n" >> email_body
cat /dev/null > tmp_report
for name in "${!overall_cost[@]}"; do
  time_sec=${overall_usages[$name]}
  convertsecs $time_sec
  readable_time="$h:$m:$s"
  printf "%-15s %-15s %-15s \n"  "$"${overall_cost[$name]} $name $readable_time >> tmp_report
done
sort -k1.2 -g -r tmp_report >> email_body
for name in "${!overall_cost[@]}"; do
  email_recipients="$email_recipients $name@plumgrid.com"
done
cat email_body | mail -s $email_sub $email_recipients

echo "Cleanup"
rm tmp_report vminfo email_body
