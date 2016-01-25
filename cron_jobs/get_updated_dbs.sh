#!/bin/bash -e
export USER=plumgrid
export PATH=@CMAKE_BINARY_DIR@/:/opt/pg/scripts:/opt/pg/scripts/gcloud/aurora/pipeline_scripts/:$PATH
source gc_helpers.sh
source pl_utils.sh
source pl_settings.conf
source aurora_infra_settings.conf
source pl_help.sh
source /home/${USER}/.aurora.conf

TEST_FAILURES_ACCEPTABLE=10
TEST_FAILURES_ACCEPTABLE_UNSTABLE=42

TEMP=`getopt -o W: --long WORKSPACE: -n 'get_updated_dbs.sh' -- "$@"`
eval set -- "$TEMP"

while true ; do
  case "$1" in
    -W|--WORKSPACE) export WORKSPACE=$2 ; shift 2 ;;
    --) shift ; break ;;
    *)
      echo "Unrecognized option $1"
       exit 1 ;;
  esac
done

function cleanup () {
  local build_id=$1
  echo "Running cleanup of alive instances related to $build_id..."

  cleanup.sh $build_id
}
# adding trap so that if at any point due to any issue the script exits, the instances would be cleaned up
trap "cleanup ${BUILD_ID}" EXIT

create_dir_or_remove_contents $WORKSPACE

declare -a branches=('master' 'stable_4_1');
declare -a pipelines=('smoke' 'extended' 'omni' 'unstable' 'pgui-smoke');

GCLOUD_PATH=${WORKSPACE}/gcloud
git clone ssh://${gerritid}@${GERRIT_IP}:${GERRIT_PORT}/gcloud.git ${GCLOUD_PATH}
scp -p -P ${GERRIT_PORT} ${gerritid}@${GERRIT_IP}:hooks/commit-msg ${GCLOUD_PATH}/.git/hooks/

mkdir ${WORKSPACE}/dbs

function check_db_existance() {
  local db=$1
  if [[ -e ${DB_PATH}${db} ]]; then
    echo ${DB_PATH}${db}
  else
    echo "error"
  fi
}


for BRANCH in ${branches[*]}; do
  echo "$BRANCH"
  initial_run=0
  for PIPELINE in ${pipelines[*]}; do
    tag="dbalps"
    project="alps"
    acceptable_test_failures=$TEST_FAILURES_ACCEPTABLE
    if [[ "$PIPELINE" == "unstable" ]]; then
      acceptable_test_failures=$TEST_FAILURES_ACCEPTABLE_UNSTABLE
    elif [[ "$PIPELINE" == "pgui-smoke" ]]; then
      project="pg_ui"
      tag="dbpgui"
    fi
    # this build id would be created, the variable BUILD_ID is for cleanup, since we do not have any information about the build.
    BUILD_ID=${tag}-bld-${BRANCH}
    if [[ $BRANCH == "stable_4_1" ]]; then
      BUILD_ID="${tag}-bld-stable-4-1"
    fi
    curr_db="${PIPELINE}-${BRANCH}.db"
    check_db=$(check_db_existance $curr_db)
    echo $check_db
    if [[ $check_db == "error" ]];then
      echo "${DB_PATH}${curr_db}"
      sqlite3 ${DB_PATH}${curr_db} "create table tests (Name STRING PRIMARY KEY, ID INTEGER, RunTime REAL, Status TEXT);"
      initial_run=1
    fi
    # echo $initial_run

    PIPELINE_WORKSPACE=${WORKSPACE}/pl-${PIPELINE}-${BRANCH}
    if [[ $initial_run == "1" ]]; then
      echo "aurora update_db -p ${project} -P ${PIPELINE} -b ${BRANCH} -W ${WORKSPACE} -u ${acceptable_test_failures} -t ${tag} -I"
      aurora update_db -p ${project} -P ${PIPELINE} -b ${BRANCH} -W ${WORKSPACE} -u ${acceptable_test_failures} -t ${tag} -I
    else
      echo "aurora update_db -p ${project} -P ${PIPELINE} -b ${BRANCH} -W ${WORKSPACE} -u ${acceptable_test_failures} -t ${tag}"
      aurora update_db -p ${project} -P ${PIPELINE} -b ${BRANCH} -W ${WORKSPACE} -u ${acceptable_test_failures} -t ${tag}
    fi
    # After the end of run pipelines, after the updation of db, the db is copied into the workspace of the pipelines in a dir dbs
    if [[ $? -eq 0 ]]; then
      # Get the path to the db that has been created
      path_to_created_db=$(get_db $PIPELINE $BRANCH)
      #copying db to central location to commit them together.
      cp $path_to_created_db ${WORKSPACE}/dbs/
    else
      continue
    fi
  done
  # cleaning up the instances that were used for the previous db update
  echo "cleaning up instances related to $BUILD_ID"
  cleanup $BUILD_ID
done

pushd ${GCLOUD_PATH}
git reset --hard origin/master
# Deleting the already present dbs in the newly cloned gcloud repository
rm -rf ${GCLOUD_PATH}/aurora/pipeline_scripts/alps/dbs/*.db
# Checking if the directory $WORKSPACE/dbs actually has any dbs or is empty, if empty we exit.
if [[ $(ls -A ${WORKSPACE}/dbs) ]]; then
  # Copying the newly created dbs to their location
  ls -a "${WORKSPACE}/dbs/"
  cp ${WORKSPACE}/dbs/* "${GCLOUD_PATH}/aurora/pipeline_scripts/alps/dbs/"
else
  exit 1
fi

cat /dev/null > commit_msg_file
echo "Updating dbs for Pipelines" >> commit_msg_file
echo >> commit_msg_file
cat commit_msg_file
for db in "${GCLOUD_PATH}/aurora/pipeline_scripts/alps/dbs"; do
  # Stage the file
  git add $db
done
# commit the file
git commit -s -F commit_msg_file
# Push the commit
git push origin HEAD:refs/for/master
rm commit_msg_file
