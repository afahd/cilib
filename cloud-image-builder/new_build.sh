#! /bin/bash -e
PWD=`pwd`

BASE_LINUX="ubuntu-1204-3-10-39-v2"
MACHINETYPE="n1-standard-4"
DISK_SIZE="10GB"

declare -A MINOR_STEPS_ST
declare -A MINOR_STEPS_ED
BUILD_ENV_USER=${USER}

MAJOR_STEPS="build"
#MAJOR_STEPS="init build"
MINOR_STEPS_ED[init]=23
MINOR_STEPS_ED[build]=21
MINOR_STEPS_ST[init]=1
MINOR_STEPS_ST[build]=1

# forward to subshells
trap "kill 0" SIGINT
trap "kill 0" SIGTERM

function tryexec() {
  "$@"
  retval=$?
  [[ $retval -eq 0 ]] && return 0

  log 'A command has failed:'
  log "  $@"
  log "Value returned: ${retval}"
  exit $retval
}


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
  local NAME=plumgrid-builder-v1

  case "$step" in
      1)
        echo "Creating the disk[${NAME}-d1] for the instance in the cloud"
            gcloud -q --verbosity error compute disks create "${NAME}-d1"  --source-snapshot "$BASE_LINUX" --type "pd-standard"  --size="$DISK_SIZE"
          gcloud compute disks create "${NAME}-d2" --size "200" --type "pd-standard"
        ;;
      2)
        echo "Creating the instance[$NAME] in the cloud"
        gcloud -q --verbosity error compute instances  create "${NAME}" --machine-type "$MACHINETYPE" --network "net-10-10" --maintenance-policy "MIGRATE" --scopes "https://www.googleapis.com/auth/devstorage.read_only" --disk "name=${NAME}-d1" "mode=rw" "boot=yes" "auto-delete=yes" --disk "name=${NAME}-d2" "mode=rw" "boot=no" "auto-delete=yes"
        ;;
      3)
          echo "Waiting for the machine to boot up and allow ssh access"
          for i in `seq 1 60`;
          do
              echo "       Trying to ssh to $NAME Iteration [$i]"
#              gcloud compute -q ssh work-nod --ssh-flag='-t' --command "ssh -t -o StrictHostKeyChecking=no $NAME 'echo \"${DOMAIN}\" | sudo tee /opt/pg/domains'" >> /tmp/cn_init.log 2>&1  && break
              gcloud compute -q ssh ${NAME} --ssh-flag='-t' --command "ls" >> /tmp/build_image.2.log 2>&1  && break
              sleep 1
          done
          ;;
      4) 
          echo "copy my public key into the servers authorized keys"
          gcloud compute copy-files ~/.ssh/id_rsa.pub $NAME:./auth-key.pub
          gcloud compute -q ssh $NAME  --ssh-flag='-t' --command "cat ./auth-key.pub >> ~/.ssh/authorized_keys"
          gcloud compute -q ssh ${NAME} --ssh-flag='-t' --command "sudo apt-get install -y btrfs-tools haveged"
          gcloud compute -q ssh ${NAME} --ssh-flag='-t' --command 'sudo mkfs.btrfs /dev/sdb -L DDISK && echo "LABEL=\"DDISK\" /opt btrfs defaults 0 0" > /tmp/b1 && sudo bash -c "cat /tmp/b1 >> /etc/fstab"'
          gcloud compute -q ssh ${NAME} --ssh-flag='-t' --command "sudo mount /opt &&  sudo mkdir -p /opt/var/lib"
          gcloud compute -q ssh ${NAME} --ssh-flag='-t' --command "sudo service docker stop && sudo mv /var/lib/docker /opt/var/lib"
          gcloud compute -q ssh ${NAME} --ssh-flag='-t' --command "sudo ln -s /opt/var/lib/docker /var/lib/ && sudo service docker start"
	;;
      5)
          echo "updating the local dev-bootstrap repository"
          cd ~/dev-bootstrap && git pull
          cp ~/.ssh/id_rsa.pub  ~/dev-bootstrap/pgdev-docker-base/authorized_keys
          cd ~ && tar cfz dev-bootstrap.tar.gz dev-bootstrap
          ;;
      6)
          echo "Copying the dev-bootstrap directory to the build machine $NAME"
          gcloud compute copy-files ~/dev-bootstrap.tar.gz ${NAME}:./
          ;;
      7)
          echo "Untaring the script on the remote machine"
          gcloud compute -q ssh ${NAME} --ssh-flag='-t' --command "tar xf ./dev-bootstrap.tar.gz"
          ;;
      8)
          echo "Starting the build for pgdev-base container"
          gcloud compute -q ssh ${NAME} --ssh-flag='-t' --command "cd dev-bootstrap/pgdev-docker-base && sudo docker build -t plumgrid-pgdev-base ."
          ;;
      9)
          #echo "collecting the IP address for the docker container"
          #BUILD_DOCKER_IP=$(gcloud compute -q ssh ${NAME} --ssh-flag='-t' --command "cat local_docker_ip")
	  #echo "BUILD_DOCKER_IP=$BUILD_DOCKER_IP"
          echo "setting up forward on ${NAME} Machine "
          gcloud compute -q ssh ${NAME} --ssh-flag='-t' --command "echo 'host *' > ~/.ssh/config; echo '    ForwardAgent yes'>>~/.ssh/config"
          echo "Setting docker mtu and restarting docker services"
          gcloud compute -q ssh ${NAME} --ssh-flag='-t' --command "echo 'DOCKER_OPTS=\"--mtu 1400 --insecure-registry pg-docker-repo:5000\"' | sudo tee /etc/default/docker; sudo service docker restart"
         ;;
      10)
          echo "starting the pgdev-base container"
          gcloud compute -q ssh ${NAME} --ssh-flag='-t' --command "DID=\$(sudo docker run -d plumgrid-pgdev-base /usr/sbin/sshd -D); echo \$DID > ./local_docker_id; sudo docker inspect --format '{{ .NetworkSettings.IPAddress }}' \$DID > ./local_docker_ip"
          ;;
      11) 
          echo "starting ssh agent and exporting keys"
          if [ -z "$SSH_AUTH_SOCK" ] ; then 
             eval `ssh-agent -s`
             ssh-add
          fi
          ;;
      12) 
 	  echo "Updating the repositories"
  	  #gcloud compute -q ssh  plumgrid-builder-v1 --ssh-flag='-tA' --command "eval \`ssh-agent -s\`; ssh-add; ssh -t  -o StrictHostKeyChecking=no plumgrid@\`cat local_docker_ip\` /bin/bash"
  	  gcloud compute -q ssh  plumgrid-builder-v1 --ssh-flag='-tA' --command "ssh -t  -o StrictHostKeyChecking=no plumgrid@\`cat local_docker_ip\` /bin/bash ./git_update.sh"
	;;
      13) 
         echo "Creating a snapshot with the repo installed in the docker"
         gcloud compute -q ssh ${NAME} --ssh-flag='-t' --command "sudo docker commit \`cat local_docker_id\` plumgrid-pgdev-gitbase"
        ;;
      14) 
         echo "Stopping the container"
         gcloud compute -q ssh ${NAME} --ssh-flag='-t' --command "sudo docker stop \`cat local_docker_id\`"
        ;;
      15)
          echo "Starting the build for pgdev container"
          gcloud compute -q ssh ${NAME} --ssh-flag='-t' --command "cd dev-bootstrap/pgdev-docker && sudo docker build -t plumgrid-pgdev ."
          ;;
      16)
          echo "Starting prepration for build-all.sh(Starting the ssh server)" 
          gcloud compute -q ssh ${NAME} --ssh-flag='-t' --command "DID=\$(sudo docker run  --cap-add=all  --cap-add=SYS_ADMIN --lxc-conf='lxc.aa_profile=unconfined' --privileged -d plumgrid-pgdev /home/plumgrid/startup.sh); echo \$DID > ./local_pgdev_docker_id; sudo docker inspect --format '{{ .NetworkSettings.IPAddress }}' \$DID > ./local_pgdev_docker_ip"
          ;;
      17) 
          echo "check if ssh server is up and running"
          if [ -z "$SSH_AUTH_SOCK" ] ; then
             eval `ssh-agent -s`
             ssh-add
          fi
          for i in `seq 1 60`;
          do
              echo "       Trying to ssh to plumgrid-builder-v1 Iteration [$i]"
              gcloud compute -q ssh  plumgrid-builder-v1 --ssh-flag='-tA' --command "ssh -t  -o StrictHostKeyChecking=no plumgrid@\`cat local_pgdev_docker_ip\` ls" >> /tmp/build_image.3.log  2>&1 && break 
              sleep 1
          done
          echo "Starting build-all.sh"
          gcloud compute -q ssh  plumgrid-builder-v1 --ssh-flag='-tA' --command "ssh -t  -o StrictHostKeyChecking=no plumgrid@\`cat local_pgdev_docker_ip\` /bin/bash /home/plumgrid/run_build_all.sh"
          ;;
      18)
          echo "Making a snapshot for the container"
          gcloud compute -q ssh ${NAME} --ssh-flag='-t' --command "sudo docker commit \`cat ./local_pgdev_docker_id\` pg_dev:latest"
         ;;
      19)
          echo "Pushing the container to the repo"
          SN_ID=`date +%s`
          gcloud compute -q ssh ${NAME} --ssh-flag='-t' --command "sudo docker tag pg_dev:latest pg-docker-repo:5000/pg_dev:${SN_ID}"
          gcloud compute -q ssh ${NAME} --ssh-flag='-t' --command "sudo docker push pg-docker-repo:5000/pg_dev:${SN_ID}"
          gcloud compute -q ssh ${NAME} --ssh-flag='-t' --command "echo pg_dev:${SN_ID} > ~/pgdev_latest_docker_image"
          gcloud compute -q ssh ${NAME} --ssh-flag='-t' --command "echo plumgrid-builder-v1-d1-${SN_ID} > ~/pgtest_latest_d1_snapshot"
          gcloud compute -q ssh ${NAME} --ssh-flag='-t' --command "echo plumgrid-builder-v1-d2-${SN_ID} > ~/pgtest_latest_d2_snapshot"
          gcloud compute -q ssh ${NAME} --ssh-flag='-t' --command "echo ${BASE_LINUX} > ~/base_linux_vm_snapshot_name"
          ;;
      20) 
          echo "Making a snapshot of the VM"a
          SNAP_D1_=$(gcloud compute -q ssh ${NAME} --ssh-flag='-t' --command "cat ~/pgtest_latest_d1_snapshot")
          SNAP_D2_=$(gcloud compute -q ssh ${NAME} --ssh-flag='-t' --command "cat ~/pgtest_latest_d2_snapshot")
          SNAP_D1=$(echo $SNAP_D1_ | tr -d '\n'| tr -d '\r')
          SNAP_D2=$(echo $SNAP_D2_ | tr -d '\n'| tr -d '\r')
          echo "SNAP_D1 = [$SNAP_D1]"
          echo gcloud compute disks snapshot plumgrid-builder-v1-d1 --snapshot-names $SNAP_D1
          gcloud compute disks snapshot plumgrid-builder-v1-d1 --snapshot-names "$SNAP_D1"
          gcloud compute disks snapshot plumgrid-builder-v1-d2 --snapshot-names "$SNAP_D2"
	  ;;
      21)
          echo "Shutting down the Instance $NAME"
          gcloud compute instances delete $NAME --delete-disks all  -q
          ;;
      *)
          echo "NOP - $step"
          ;;
esac
}

for MAJOR_STEP in $MAJOR_STEPS; do
echo " ====== Starting STEP [$MAJOR_STEP] Number of Steps ::${MINOR_STEPS_ST[$MAJOR_STEP]} -> ${MINOR_STEPS_ED[$MAJOR_STEP]}  ======"
for MINOR_STEP in `seq ${MINOR_STEPS_ST[$MAJOR_STEP]} ${MINOR_STEPS_ED[$MAJOR_STEP]}`; do
    echo "    === Starting STEP [$MAJOR_STEP][$MINOR_STEP] ==="
    case "$MAJOR_STEP" in
#        init)
#            build_image $MINOR_STEP
#            ;;
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
