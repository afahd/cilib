#!/bin/bash -e

USER=plumgrid
export PATH=@CMAKE_BINARY_DIR@/:/opt/pg/scripts:/home/${USER}/google-cloud-sdk/bin:$PATH

TEMP=`getopt -o W:T:X: --long WORKSPACE:,duration:,extra-recp: -n 'get_daily_cost.sh' -- "$@"`
eval set -- "$TEMP"

EXTRA_RECP=""
while true ; do
  case "$1" in
    -W|--WORKSPACE) export WORKSPACE=$2 ; shift 2 ;;
    -T|--duration) export DURATION=$2 ; shift 2;;
    -X|--extra-recp) EXTRA_RECP=$2 ; shift 2 ;;
    --) shift ; break ;;
    *)
      echo "Unrecognized option $1"
       exit 1 ;;
  esac
done

if [[ ! -d $WORKSPACE ]]; then
  mkdir $WORKSPACE
else
  rm -rf ${WORKSPACE}*
fi
cat /dev/null > ${WORKSPACE}email_template

echo "running cost command"
aurora cost -U all -p all -T $DURATION -W $WORKSPACE
# send out email to aurora.internal
echo "Hi All," >> ${WORKSPACE}email_template
echo "The cost for aurora instances for the past $DURATION is as follows:" >> ${WORKSPACE}email_template
echo "" >> ${WORKSPACE}email_template
cat ${WORKSPACE}sorted_cost_final_report >> ${WORKSPACE}email_template

if [[ $DURATION == "day" ]];then
  subject="Aurora daily cloud resources cost report"
elif [[ $DURATION == "week" ]];then
  subject="Aurora weekly cloud resources cost report"
elif [[ $DURATION == "month" ]];then
  subject="Aurora monthly cloud resources cost report"
fi

cat ${WORKSPACE}email_template | mail -s "$subject" "aurora.internal@plumgrid.com" "$EXTRA_RECP"
