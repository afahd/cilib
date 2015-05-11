#!/bin/bash

# Purpose of the script is to calculate cost with respect to pipelines.
# One can see that how much are we spending on individual pipelines like
# smoke, extended, unstable etc
convertsecs() {
 ((h=${1}/3600))
 ((m=(${1}%3600)/60))
 ((s=${1}%60))
}

# "usages" array will hold the time in seconds for which cloud instances remain
# up, for running some particular pipeline.
declare -A usages
# Right now all pipelines are using same type of instances.
N1Standard_4_cost=0.252
# Instance name have pipeline infromation embedded in it at end. 1 represents smoke,
# 2 represents extended and so on.
declare -A pl_code
pl_code[1]="smoke"
pl_code[2]="extended"
pl_code[3]="unstable"
pl_code[4]="pgui-smoke"
pl_code[5]="omni"
pl_code[6]="automaton"
pl_code[7]="automaton-longevity"
pl_code[8]="longevity"
pl_code[9]="coral"
pl_code[10]="DEBUG-TEST"
pl_code['x']="MISCELLANEOUS"

# Download latest daily usage report file or one supplied through arguments.
echo "1. Download latest ci-report file"
latest_ci_report=$(gsutil ls gs://ci-bucket/* | grep ci-report | tail -1)
latest_ci_report=${latest_ci_report##*/}
ci_report=${1:-$latest_ci_report}
echo "${latest_ci_report}"
gsutil cp gs://ci-bucket/${ci_report} .

# Extract only the information of those instances which were part of pipeline run.
# All such instances have ccod (cost code) embedded in their name.
echo "2. Extract VMs information from ci-report file"
grep ccod ${ci_report} > vminfo

# Extract time taken by instances of some particular pipeline. Time will be in seconds.
echo "3. Calculate individual pipeline usage (will be in seconds)"
while read line
do
  name_full=`echo $line  | cut -d',' -f 5 | cut -d '/' -f 11` # jenkins-build-run-24-13924-2-p-1-658ab20b7e97
  cost_pipeline_code=${name_full#*"-p-"} # 1-658ab20b7e97
  cost_pipeline_code=${cost_pipeline_code%%"-"*} # 1
  pipeline=${pl_code[$cost_pipeline_code]} # smoke
  echo "**** name_full=$name_full , cost_pipeline_code=$cost_pipeline_code, pipeline=$pipeline ****"
  time_sec=`echo $line | cut -d',' -f 3`
  old_time="${usages[$pipeline]}"
  new_time=$((old_time + time_sec))
  usages[$pipeline]=$new_time
done < vminfo

# Print usage information in readable format.
# Get total time taken by all pipelines and calculate cost spent.
echo "4. Print usage infromation in readable format hh:mm:ss to usage_report"
timestamp=${ci_report##*_}
timestamp=${timestamp%.*}
cat /dev/null > pipeline_usage_report_${timestamp}
for pipeline in "${!usages[@]}" ; do
  time_sec=${usages[$pipeline]}
  convertsecs $time_sec
  readable_time="$h:$m:$s"
  cost=$(echo "$h*$N1Standard_4_cost" | bc -l)
  printf "%-15s %-15s %-15s %-15s \n" ${pipeline} ${readable_time} ${cost} >> pipeline_usage_report_${timestamp}
done
cat pipeline_usage_report_${timestamp}

echo "Happy :)"
