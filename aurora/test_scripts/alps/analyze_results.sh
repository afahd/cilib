#!/bin/bash
DB="$HOME/.alps.test.db"
# Run this script in the directory where you have expanded all the results
# from aurora run's
# this script when run like "analyze_results.sh build" will create a new database
# then it can be run to create tests splits "analyze_results.sh 10" will generate the test splits for
# running in 10 VM's and display on the screen
# then it can be run to create tests splits "analyze_results.sh 10 run_tests.sh" will gerates the scripts
# run_tests.sh-1..10 with the splits to run the tests in 10 vm's

if [[ $1 == "build" ]] ; then
    if [ ! -e "$DB" ] ; then
        echo "DB Does not exist, creating it now"
        sqlite3 $DB "create table tests (Name STRING PRIMARY KEY, ID INTEGER, RunTime REAL, Status TEXT);"
    fi

    FAILING_TESTS=`find . | grep FAIL`
    ALL_TESTS=`find . | grep "\.log$" | grep -v trace_collector.12349.log | grep -v "/nginx/" | grep -v "/sal/" | grep -v "/test.log" | grep -v "/test_perf.log"`
    for TEST in $ALL_TESTS; do
        # echo $TEST
        TestTime=$(grep "Total Test time" $TEST | tr -s " " | cut -d ' ' -f 6)
        TestID=$(grep "Test *#[0-9]*" $TEST | tr -s " " | cut -d ' ' -f 3 | tr -d ':' | tr -d '#')
        TestName=$(echo $TEST | rev | cut -d'/' -f 1 | rev)

        # echo "[$TestName] RUNTIME : $TestTime"
        if [[ $TestTime == "" ]] ; then
            echo "Skipping $TEST"
        else
            TNAME=$(echo $TestName | cut -d '.' -f 1)
            TST=$(echo $TEST | grep -o "FAILED" || echo "PASSED")
            echo "Adding to DB :: [$TestID] $TNAME $TestTime $TST"
            sqlite3 $DB "insert into tests (Name, ID, RunTime, Status) values ('$TNAME', '$TestID', '$TestTime', '$TST');"
        fi
    done
    TotalTestRuntime=$(sqlite3 $DB "select sum(RunTime) from tests;")
    MaxTestID=$(sqlite3 $DB "select max(id) from tests;")
    TestCount=$(sqlite3 $DB "select count(id) from tests;")
    sqlite3 $DB "select id from tests order by id;" > /tmp/test_ids
    echo "No of Tests : $TestCount"
    echo "Last Test ID: $MaxTestID"
    echo "TotalRunTime: $TotalTestRuntime"
    echo "Missing test Results :"
    awk '$1!=p+1{print p+1"-"$1-1}{p=$1}' /tmp/test_ids
    #sqlite3 $DB "select ID, (select sum(RunTime) from tests t2 where t2.id <= t1.id) as accumulated from tests t1 order by ID;" > /tmp/cumulative

else
    let SPLIT=$1
    ScriptName=$2
    ITERATIONS=1
    TotalTestRuntime=$(sqlite3 $DB "select sum(RunTime) from tests;")
    MaxTestID=$(sqlite3 $DB "select max(id) from tests;")
    TestCount=$(sqlite3 $DB "select count(id) from tests;")
    sqlite3 $DB "select id from tests order by id;" > /tmp/test_ids
    echo "No of Tests : $TestCount"
    echo "Last Test ID: $MaxTestID"
    echo "TotalRunTime: $TotalTestRuntime"

    ITime=${TotalTestRuntime%.*}
    AVGTime=$(expr $ITime / $SPLIT)
    echo $AVGTime

    CURTIME="0"
    CurrentTest=1
    CurrentTime=0
    for ITR in `seq 1 $SPLIT` ; do
        let CURTIME=CURTIME+AVGTime
        TestInfo=$(sqlite3 $DB "select ID, (select sum(RunTime) from tests t2 where t2.id <= t1.id) as accumulated from tests t1 where accumulated < $CURTIME order by ID;" | tail -1)
        TestID=$(echo $TestInfo | cut -d "|" -f 1)
        TestTime=$(echo $TestInfo | cut -d "|" -f 2)
        TestTime=${TestTime%.*}
        let RunTime=TestTime-CurrentTime
        let NoTest=TestID-CurrentTest
        if [[ ! -z $ScriptName ]] ; then
            DScript="${ScriptName}-$ITR"
            echo "[$DScript]"$'\t'":: Test[$NoTest] "$'\t'" $CurrentTest - $TestID "$'\t'", RunTime : $RunTime"
            cp $ScriptName $DScript
            sed -i 's/CTEST_ST=[0-9]*/CTEST_ST='${CurrentTest}'/' $DScript
            sed -i 's/CTEST_ED=[0-9]*/CTEST_ED='${TestID}'/' $DScript
            sed -i 's/itr=[0-9]*/itr='${ITERATIONS}'/' $DScript
        else
            echo "Split [$ITR] :: Test[$NoTest] "$'\t'" $CurrentTest - $TestID "$'\t'", RunTime : $RunTime"
        fi

        let CurrentTest=TestID+1
        CurrentTime=$TestTime
    done

fi
