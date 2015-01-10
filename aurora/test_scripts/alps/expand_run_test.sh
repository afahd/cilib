#!/bin/bash
# Script expander which will take the base run_tests.sh script and expand it into multiple scripts 
# so that parallel aurora run's can be executed. 

if [[ "$#" != 5 ]] ; then 
echo "Usages : Expand_run_test <Name of Script> <Iternation Count> <First Test No> <Step Size> <No of Tests>"
exit
fi 

Script=$1
Iter=$2
FirstTest=$3
StepSz=$4
StepCnt=$5

echo "Copying run_test.sh with the following parameters"
echo "    ITERATIONS               : $Iter"
echo "    Start [StepSz * StepCnt] : $StartTest [ $StepSz * $StepCnt]"
for stp in `seq 1 $StepCnt`; do 
   let StartTest=FirstTest+stp*StepSz-StepSz
   let EndTest=FirstTest+stp*StepSz-1
   echo "Step = $stp Test = $StartTest - $EndTest"
   cp $Script $Script-$StartTest
   sed -i 's/CTEST_ST=[0-9]*/CTEST_ST='${StartTest}'/' $Script-$StartTest
   sed -i 's/CTEST_ED=[0-9]*/CTEST_ED='${EndTest}'/' $Script-$StartTest
   sed -i 's/itr=[0-9]*/itr='${Iter}'/' $Script-$StartTest
done
 
