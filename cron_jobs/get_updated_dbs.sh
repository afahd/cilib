#!/bin/bash -e

export PATH=@CMAKE_BINARY_DIR@/:/opt/pg/scripts:/opt/pg/scripts/gcloud/aurora/pipeline_scripts/:$PATH
source gc_helpers.sh
source pl_utils.sh
source pl_settings.conf
source aurora_infra_settings.conf
source pl_help.sh

TEMP=`getopt -o W: --long WORKSPACE: -n 'update_db.sh' -- "$@"`
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

declare -a branches=('master' 'stable_4_0' 'stable_4_1');
declare -a pipelines=('smoke' 'extended' 'unstable' 'omni' 'pgui-smoke');

GCLOUD_PATH=${WORKSPACE}/gcloud

git clone ssh://${GERRIT_ID}@${GERRIT_IP}:${GERRIT_PORT}/gcloud.git ${GCLOUD_PATH}
scp -p -P ${GERRIT_PORT} ${GERRIT_ID}@${GERRIT_IP}:hooks/commit-msg ${GCLOUD_PATH}/.git/hooks/


for BRANCH in ${branches[*]}; do
  echo "$BRANCH"
  for PIPELINE in ${pipelines[*]}; do
    tag="dbalps"
    project="alps"
    acceptable_test_failures=10
    if [[ "$PIPELINE" == "unstable" ]]; then
      acceptable_test_failures=38
    elif [[ "$PIPELINE" == "pgui-smoke" ]]; then
      project="pg_ui"
      tag="dbpgui"
    fi
    # this build id would be created, the variable BUILD_ID is for cleanup, since we do not have any information about the build.
    BUILD_ID=${tag}-bld-${BRANCH}
    PIPELINE_WORKSPACE=${WORKSPACE}/pl-${PIPELINE}-${BRANCH}
    aurora update_db -p ${project} -P ${PIPELINE} -b ${BRANCH} -W ${WORKSPACE} -u ${acceptable_test_failures} -t ${tag}
    # After the end of run pipelines, after the updation of db, the db is copied into the workspace of the pipelines in a dir dbs
    if [[ $? -eq 0 ]]; then
      # Get the path to the db that has been created
      path_to_created_db=$(get_db $PIPELINE $BRANCH)
      pushd ${GCLOUD_PATH}
      git reset --hard origin/master
      echo ${WORKSPACE}/${PIPELINE_WORKSPACE}/dbs
      echo ${GCLOUD_PATH}/aurora/pipeline_scripts/alps/dbs
      # Remove the previous db in the newly pulled repo.
      rm ${GCLOUD_PATH}/aurora/pipeline_scripts/alps/dbs/${PIPELINE}-${BRANCH}.db
      # Copy new db to the dbs directory in the newly pulled gcloud repo to commit.
      cp ${path_to_created_db} ${GCLOUD_PATH}/aurora/pipeline_scripts/alps/dbs/
      git status
      cat /dev/null > commit_msg_file

      echo "Updating db for $PIPELINE Pipeline on Branch $BRANCH" >> commit_msg_file
      echo >> commit_msg_file

      cat commit_msg_file

      # Commit the file
      git commit -s -o -F commit_msg_file aurora/pipeline_scripts/alps/${PIPELINE}-${BRANCH}.db
      # Push the commit
      git push origin HEAD:refs/for/master
      rm commit_msg_file
    else
      continue
    fi
  done
  # cleaning up the instances that were used for the previous db update
  echo "cleaning up instances related to $BUILD_ID"
  cleanup $BUILD_ID
done
