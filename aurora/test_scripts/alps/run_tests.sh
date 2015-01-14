#!/bin/bash
# Script to run tests in alps director 
# and collect log from the failing tests
# these are designed to work with aurora  

CTEST_ST=1
CTEST_ED=25
itr=2
CTEST_OPT=' '
TESTID="ctest-$CTEST_ST-$CTEST_ED"
export EXPORT_FAILURES_DIR="/opt/pg/log/$TESTID"
export EXPORT_FAILURES_DIR_TMP="/tmp/log/$TESTID"
rm -rf "${EXPORT_FAILURES_DIR}"
rm -rf "${EXPORT_FAILURES_DIR}_TMP"
mkdir -p "$EXPORT_FAILURES_DIR"
mkdir -p "$EXPORT_FAILURES_DIR_TMP"
cd ~/work/alps/build
rm -rf logs
mkdir logs
export BUILD_GUI=1
export EXCLUDE_UI_NON_PITA=1
export EXCLUDE_UNSTABLE=1
cmake ..

# use a common, but hopefully unique prefix for the log destination
formatted_date=$(date '+%Y%m%d-%H%M%S')
for run in $(seq 1 $itr); do
  echo  "Running iteration number: ${run}"
  # need to recreate the directory every time, because we move it away at the end of the loop
  for testno in $(seq $CTEST_ST $CTEST_ED); do
    test_name=$(ctest -N  -L ^type:local$ | grep "Test.*#$testno:" | cut -d ':' -f 2 | tr -d ' ')
    echo "Running $test_name"
    rm -rf /opt/pg/log/*
    touch /opt/pg/log/${test_name}
    ctest --output-on-failure  -L ^type:local$ -R "^${test_name}$" >& "logs/ctestout_iter${run}_${test_name}.log"
    result="$?"
    if [[ "x$result" != "x0" ]] ; then 
      echo "                 FAILED"
     
      mv "logs/ctestout_iter${run}_${test_name}.log" "logs/ctestout_iter${run}_${test_name}.FAILED.log" 
      mkdir "logs/ctestout_iter${run}_${test_name}"
      cp -R /opt/pg/log/* "logs/ctestout_iter${run}_${test_name}/"
    fi
  done
  echo "Moving Logs to ${EXPORT_FAILURES_DIR_TMP}/logs.${formatted_date}.run${run}"
  mv logs ${EXPORT_FAILURES_DIR_TMP}/logs.${formatted_date}.run${run}
  mkdir logs
  # rename the logs directory
done
mv ${EXPORT_FAILURES_DIR_TMP} ${EXPORT_FAILURES_DIR}
echo " All Logs are in :: ${EXPORT_FAILURES_DIR}"
echo 'All done'
