#!/bin/bash
# Script expander which will take the base run_tests.sh script and expand it into multiple scripts 
# so that parallel aurora run's can be executed. 

show_help() {
     cat << EXPANDHELP
Generate scripts to run on cloud.
  -b, --base_script   Base seed script from which rest of scripsts will get generated
  -i, --iterations    Number of time script needs to run
  -f, --first_test    Starting ctest number
  -t, --step_size     Number of tests to run as part of one script.
  -c, --num_sets      Number of cloud instances among which you want to distribute these tests

EXPANDHELP
}

# read the options
TEMP=`getopt -o b:i:f:t:c:h --long base_script:,iterations:,first_test:,step_size:,num_sets:,help -n 'expand_test.sh' -- "$@"`
eval set -- "$TEMP"

# extract options and their arguments into variables.
while true ; do
  case "$1" in
    -b|--base_script)
      BASE_SCRIPT=$2 ; shift 2 ;;
    -i|--iteratons)
      ITERATIONS=$2 ; shift 2 ;;
    -f|--first_test)
      FIRST_TEST=$2 ; shift 2 ;;
    -t|--step_size)
      STEP_SIZE=$2 ; shift 2 ;;
    -c|--num_sets)
      NUM_SETS=$2 ; shift 2 ;;
    -h|--help)
      show_help
      exit 0 ;;
    --) shift ; break ;;
    *) exit 1 ;;
  esac
done

echo "Copying run_test.sh with the following parameters"
echo "    ITERATIONS               : $ITERATIONS"
echo "    Start [STEP_SIZE * NUM_SETS] : ${FIRST_TEST} [ ${STEP_SIZE} * ${NUM_SETS}]"
for stp in `seq 1 $NUM_SETS`; do 
   let StartTest=FIRST_TEST+stp*STEP_SIZE-STEP_SIZE
   let EndTest=FIRST_TEST+stp*STEP_SIZE-1
   echo "Step = $stp Test = $StartTest - $EndTest"
   cp $BASE_SCRIPT ${BASE_SCRIPT}-$StartTest
   sed -i 's/CTEST_ST=[0-9]*/CTEST_ST='${StartTest}'/' ${BASE_SCRIPT}-$StartTest
   sed -i 's/CTEST_ED=[0-9]*/CTEST_ED='${EndTest}'/' ${BASE_SCRIPT}-$StartTest
   sed -i 's/itr=[0-9]*/itr='${ITERATIONS}'/' ${BASE_SCRIPT}-$StartTest
done
 
