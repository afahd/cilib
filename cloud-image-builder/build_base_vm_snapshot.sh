#! /bin/bash -e
PWD=`pwd`
source aurora_infra_settings.conf
export PATH=/opt/pg/scripts:$PATH
. gc_helpers.sh
. ~/.aurora.conf

_USER=plumgrid
declare -A MINOR_STEPS_ST
declare -A MINOR_STEPS_ED
BUILD_ENV_USER=${USER}

MAJOR_STEPS="build"
MINOR_STEPS_ST[build]=1
MINOR_STEPS_ED[build]=14

# forward to subshells
trap "kill 0" SIGINT
trap "kill 0" SIGTERM

function usage() {
cat <<EOF
usage: $0
-c | --cleanup : Test Cleanup
-Q | --major : Jump to specific major step in the install process
-R | --minor : Jump to specific minor step in the install process
-E | --minor_end : Stop at this step when in debug
-O | --stop : DONT Continue beyond the specifict step to end of the installation
-h | --help : help
EOF
exit 0
}
INSTANCE_IP=$(get_instance_ip ${PRIM_INST_NAME})

# Parsing arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -c|--cleanup ) CLEANUP=1;  ;;
    -Q| --major ) MAJOR_STEPS="$2"; TMP_MAJOR="$2"; shift ;;
    -R| --minor ) MINOR_STEPS_ST[$TMP_MAJOR]="$2"; shift ;;
    -E| --minor ) MINOR_STEPS_ED[$TMP_MAJOR]="$2"; shift ;;
    -O| --stop ) STOP=1; ;;
    -h | --help ) usage; ;;
    -- ) shift; break ;;
    * )
      log "Unknown parameter: $1";
      usage; break;;
  esac
  shift
done

function build_image() {
  local step=$1
  # It should give the version number as an argument.

  case "$step" in
      1)
        echo "Creating the disk[${PRIM_INST_NAME}-d1] for the instance in the cloud"
        exec_gcloud_cmd disks create "${PRIM_INST_NAME}-d1" \
            --source-snapshot  "$BASE_LINUX" --type "$DISK_TYPE" --size="$DISK1_SIZE" -q
        exec_gcloud_cmd disks create "${PRIM_INST_NAME}-d2" \
            --type "$DISK_TYPE" --size="$DISK2_SIZE" -q
        ;;
      2)
        echo "Creating the instance[$PRIM_INST_NAME] in the cloud"
        echo plumgrid:$(cat /home/${USER}/.ssh/id_rsa.pub) > /tmp/keys
        echo plumgrid:$(echo ${COMMON_KEY}) >> /tmp/keys
        exec_gcloud_cmd instances create "${PRIM_INST_NAME}"  \
            --machine-type "$MACHINE_TYPE" --network "$NETWORK" --maintenance-policy \
            "MIGRATE" --scopes "$SCOPES" -q \
            --disk "name=${PRIM_INST_NAME}-d1" "mode=rw" "boot=yes" "auto-delete=yes" \
            --disk "name=${PRIM_INST_NAME}-d2" "mode=rw" "boot=no" "auto-delete=yes" \
            --metadata-from-file sshKeys=/tmp/keys --metadata email="$emailid"
        ;;
      3)
          echo "Waiting for the machine to boot up and allow ssh access"
          INSTANCE_IP=$(get_instance_ip ${PRIM_INST_NAME})
          wait_for_instance ${INSTANCE_IP}
          ;;
      4)
          echo "Copying setup file over"
          tryexec scp -o StrictHostKeyChecking=no ~/.ssh/id_rsa.pub ${_USER}@$INSTANCE_IP:./auth-key.pub
          tryexec ssh -t ${_USER}@${INSTANCE_IP} -o StrictHostKeyChecking=no "cat ./auth-key.pub >> ~/.ssh/authorized_keys && sudo ifconfig eth0 mtu 1400"
          tryexec scp -o StrictHostKeyChecking=no vm_files/* ${_USER}@${INSTANCE_IP}:.
          tryexec scp -o StrictHostKeyChecking=no ~/.ssh/id_rsa.pub ${_USER}@${INSTANCE_IP}:authorized_keys
          ;;
      5)
          echo "Running base init script on the Instance"
          tryexec run_cmd_gci ${INSTANCE_IP} "sudo bash -x ./vm_setup_preinit.sh" "t"
          ;;
      6)
          echo "Running base setup script on the Instance"
          #tryexec scp -o StrictHostKeyChecking=no vm_files/vm_setup_base.sh ${_USER}@${INSTANCE_IP}:.
          tryexec run_cmd_gci ${INSTANCE_IP} "sudo bash -x ./vm_setup_base.sh" "t"
          ;;
      7)
          echo "git clone of tools"
          tryexec run_cmd_gci_sshforwarding ${INSTANCE_IP} "git clone ssh://${gerritid}@gerrit:29418/tools.git ~/work/tools" "plumgrid"
          ;;
      8)
          projs="pg_ui iovisor sal pkg pg_cli python-plumgridlib alps"
          echo "git clone of $projs"
          for pr in $projs ; do
              echo "   ==> Extracting $pr on the instance[$INSTANCE_IP]"
              tryexec run_cmd_gci_sshforwarding ${INSTANCE_IP} "git clone ssh://${gerritid}@gerrit:29418/${pr}.git ~/work/${pr}" "plumgrid"
          done
          ;;
      9)
          echo "Building tools"
          retryexec run_cmd_gci ${INSTANCE_IP} "sudo su plumgrid -c 'bash -x ./vm_setup_tools.sh'"
          ;;
      10)
          echo "Building the rest"
          tryexec scp -o StrictHostKeyChecking=no vm_files/vm_setup_all.sh ${_USER}@${INSTANCE_IP}:.
          retryexec run_cmd_gci ${INSTANCE_IP} "sudo su plumgrid -c 'bash -x ./vm_setup_all.sh'"
          ;;


      11)
          #TODO: During aurora-build, we remove all contents of build directories of all projects.
          #      We also nuke /opt/pg/var/www directory. We need to think about that whether
          #      we really need following during primary snapshot build?
          echo "Starting build-all.sh"
          retryexec run_cmd_gci ${INSTANCE_IP} "sudo chown plumgrid.plumgrid /home/plumgrid/run_build_all.sh"
          tryexec run_build_all ${INSTANCE_IP} "unstable" "/tmp/build_all.log"
          ;;
      12)
          echo "Polling for build-all (tailing \"/tmp/build_all.log\" for complete logs)"
          tryexec run_poll_cmd ${INSTANCE_IP} "run_build_all.sh" "/tmp/build_all.log" "1"
          download_from_docker ${INSTANCE_IP} "/tmp/build_all.log" "${WORKSPACE}/logs/"
          ;;
      13)
          echo "Making a snapshot of the VM"
          SN_ID=`date +%s`
          SNAP_D1="$PRIM_INST_NAME-d1-${SN_ID}"
          SNAP_D2="$PRIM_INST_NAME-d2-${SN_ID}"
          echo "SNAP_D1 = [$SNAP_D1]"
          echo gcloud compute disks snapshot $PRIM_INST_NAME-d1 --snapshot-names $SNAP_D1
          gcloud compute disks snapshot $PRIM_INST_NAME-d1 --snapshot-names "$SNAP_D1"
          gcloud compute disks snapshot $PRIM_INST_NAME-d2 --snapshot-names "$SNAP_D2"
	  ;;
      14)
          echo "Shutting down the Instance $PRIM_INST_NAME"
          gcloud compute instances delete $PRIM_INST_NAME --delete-disks all  -q
          ;;
      *)
          echo "NOP - $step"
          ;;
esac
}

for MAJOR_STEP in $MAJOR_STEPS; do
echo " ====== Starting STEP [$MAJOR_STEP] Number of Steps ::${MINOR_STEPS_ST[$MAJOR_STEP]} -> ${MINOR_STEPS_ED[$MAJOR_STEP]}  ======"
for MINOR_STEP in `seq ${MINOR_STEPS_ST[$MAJOR_STEP]} ${MINOR_STEPS_ED[$MAJOR_STEP]}`; do
    printf "\n  === Starting STEP [$MAJOR_STEP][$MINOR_STEP] === \n"
    case "$MAJOR_STEP" in
        build)
            build_image $MINOR_STEP
            ;;
        *)
            echo "UNKNOWN STEP $MAJOR_STEP.$MINOR_STEP"
            ;;
    esac
    if [ -n "$STOP" ] ; then
        exit

   fi
done
done

exit 0
