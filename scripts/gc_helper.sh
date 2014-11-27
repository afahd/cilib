#!/bin/bash

HELPER_SH='topo_helper.sh'
PARALLEL=50
#DIR_INST_TYPE="n1-standard-8"
DIR_INST_TYPE="g1-small"
#DIR_INST_TYPE="n1-standard-2"
DIR_SNAP=director-11-23

#        parallel_run 10 bash -c "\"source cn_helper.sh;bar $i\""

function parallel_run() {
#    local TH=$1
#    shift
    sem -u -j $PARALLEL bash -c "\"source $HELPER_SH;$@\""
}

function parallel_wait() {
    sem --wait
}

function create_cn_multi() {
    local START=$1
    local END=$2
    echo "========= Will launch computer in range of [cn-$START and cn-$END] ============="
    for i in `seq $START $END`;
    do
        parallel_run create_inst_cn_andifup $i
    done
    echo "========== Waiting for the cn start jobs to complete ==========="
    parallel_wait
    echo "Done"
}

function create_inst_cn_andifup() {
    local CNT=$1
    echo "  Creating Compute Node instance cn-$CNT"
    create_inst_cn "cn-$CNT" cn-snap-11-20-2014

    DOM=`expr $CNT / 10 + 1`
    echo "  Bringing up interface on cn-$CNT for DOMAIN Demo-$DOM"
    cn_init "cn-$CNT" eth1.t1 Demo-${DOM}
}

function create_inst_cn() {
    local NAME=$1
    local IMAGE=$2
    local MACHINETYPE=${3:-"g1-small"}
    local FAIL=0
    gcloud -q --verbosity error compute --project "festive-courier-755" disks create "${NAME}" --zone "us-central1-f" --source-snapshot "$IMAGE" --type "pd-standard" >> /tmp/create_inst_cn.log 2>&1 || FAIL=1
    gcloud -q --verbosity error compute --project "festive-courier-755" instances  create "${NAME}" --zone "us-central1-f" --machine-type "$MACHINETYPE" --network "net-10-10" --maintenance-policy "MIGRATE" --scopes "https://www.googleapis.com/auth/devstorage.read_only" --disk "name=${NAME}" "mode=rw" "boot=yes" "auto-delete=yes" --no-address  >> /tmp/create_inst_cn.log 2>&1 || FAIL=1
    if [ $FAIL -eq 1 ]
    then
        date
        echo "ERROR:: occured when executing create_inst_cn with NAME=$NAME IMAGE=$IMAGE MACHINETYPE=$MACHINETYPE Please look at /tmp/create/instance_cn.log"
    fi
}

function cn_init() {
    local NAME=$1
    local DEV=$2
    local DOMAIN=$3
    #gcloud compute instances describe $NAME
    for i in `seq 1 60`;
    do
        echo "       Trying to ssh to $NAME Iteration [$i]"
        gcloud compute -q ssh work-node --ssh-flag='-t' --command "ssh -t -o StrictHostKeyChecking=no $NAME 'echo \"${DOMAIN}\" | sudo tee /opt/pg/domains'" >> /tmp/cn_init.log 2>&1  && break
        sleep 1
    done
    FAIL=0
    gcloud compute -q ssh work-node --ssh-flag='-t' --command "ssh -t -o StrictHostKeyChecking=no $NAME 'curl http://pg-lcm:81/files/cn-setup.sh | bash -e >& cn-setup.log'" >> /tmp/cn_init.log 2>&1 || FAIL=1
    if [ $FAIL -eq 1 ]
    then
        date
        echo "ERROR:: occured when executing cn_init with NAME=$NAME DEV=$DEV DOMIN=$DOMAIN Please look at /tmp/create/cn_init.log"
    fi
}

function delete_cn_multi() {
    local START=$1
    local END=$2
    for i in `seq $START $END`;
    do
        parallel_run delete_inst "cn-$i"
    done
    echo "Waiting for the jobs to complete"
    parallel_wait
    echo "Done"
}

function delete_inst() {
    local NAME=$1
    local FOUND=0
    echo "delete instance with name $1"
    gcloud compute -q instances describe $NAME > /dev/null && FOUND=1
    if [ $FOUND -eq  "1" ]; then
        echo "Found instance will delete it now"
        gcloud compute instances delete $NAME --zone us-central1-f --delete-disks all  -q
    else
        echo "Cant Delete, Instance not found"
    fi
}

function create_route() {
    local NAME=$1
    local IPRANGE=$2
    local INST=$3

    echo "create route with name $1"
    gcloud compute routes create $NAME --network "net-10-10" --next-hop-instance $INST --priority 100 --destination-range $IPRANGE
}

function delete_rotue() {
    local NAME=$1
    local FOUND=0
    echo "delete route with name $1"
    gcloud compute routes describe $NAME > /dev/null && FOUND=1
    if [ $FOUND -eq  "1" ]; then
        echo "Found route. Deleting it now."
        gcloud compute routes delete $NAME -q
    else
        echo "Cant Delete, route [$NAME] not found"
    fi
}

function reset_cn_multi() {
    local START=$1
    local END=$2
    for i in `seq $START $END`;
    do
        parallel reset_inst "cn-$i" &
    done
    echo "Waiting for the RESET jobs to complete"
    parallel_wait
    echo "Done"

}

function reset_inst() {
    local NAME=$1
    echo "reseting instance with name $1"
    gcloud compute instances reset $NAME --zone us-central1-f
}


function create_inst_director() {
    local NAME=$1
    local IMAGE=$2
    local MACHINETYPE=${3:-"g1-small"}
    local DIR_IP=$4
    echo "create an inst name $1"

    gcloud compute --project "festive-courier-755" disks create "${NAME}" --zone "us-central1-f" --source-snapshot "$IMAGE" --type "pd-standard"

    gcloud compute --project "festive-courier-755" instances create "${NAME}" --zone "us-central1-f" --machine-type "$MACHINETYPE" --network "net-10-10"  --can-ip-forward  --maintenance-policy "MIGRATE" --scopes "https://www.googleapis.com/auth/devstorage.read_only" --disk "name=${NAME}" "mode=rw" "boot=yes" "auto-delete=yes"
    echo "Logging into running inst $NAME and apply config"
    for i in `seq 1 60`;
    do
        echo "Trying to ssh to $NAME Iteration [$i]"
        gcloud compute ssh $NAME --ssh-flag='-t' --command 'sudo /usr/bin/systemctl stop plumgrid;sudo /usr/bin/systemctl stop puppet' && break
        sleep 1
    done

    gcloud compute ssh $NAME --ssh-flag='-t' --command "sudo sed -i 's/director-1/${NAME}/g' /var/lib/libvirt/filesystems/plumgrid-data/conf/etc/hostname"
    gcloud compute ssh $NAME --ssh-flag='-t' --command "sudo sed -i 's/director-1/${NAME}/g' /var/lib/libvirt/filesystems/plumgrid-data/conf/etc/hosts"
    gcloud compute ssh $NAME --ssh-flag='-t' --command "sudo sed -i 's/init_servers = {/init_servesr = {\n  [\"10.11.10.14\"] = true,\n  [\"10.11.10.15\"] = true,/g' /var/lib/libvirt/filesystems/plumgrid-data/conf/pg/nginx.conf"
    gcloud compute ssh $NAME --ssh-flag='-t' --command "sudo sed -i 's/10.11.10.11/${DIR_IP}/g'  /etc/sysconfig/network-scripts/ifcfg-eth0:0"
    gcloud compute ssh $NAME --ssh-flag='-t' --command 'sudo /usr/sbin/ifup eth0:0;sudo /usr/bin/systemctl start plumgrid'
}

function login_inst() {
    gcloud compute ssh work-node --ssh-flag=-t --command "ssh -o StrictHostKeyChecking=no $1"
}

function startup_directors() {
#set -e
parallel_run create_inst_director director-1 $DIR_SNAP $DIR_INST_TYPE 10.11.10.11
parallel_run create_inst_director director-2 $DIR_SNAP $DIR_INST_TYPE 10.11.10.12
parallel_run create_inst_director director-3 $DIR_SNAP $DIR_INST_TYPE 10.11.10.13
parallel_run create_inst_director director-4 $DIR_SNAP $DIR_INST_TYPE 10.11.10.14
parallel_run create_inst_director director-5 $DIR_SNAP $DIR_INST_TYPE 10.11.10.15
#./create_route.sh ip-10-11-10-11 10.11.10.11 director-1
#./create_route.sh ip-10-11-10-12 10.11.10.12 director-2
#./create_route.sh ip-10-11-10-13 10.11.10.13 director-3
#./create_route.sh ip-10-11-10-14 10.11.10.14 director-4
#./create_route.sh ip-10-11-10-15 10.11.10.15 director-5

echo "Waiting for the jobs to complete"
parallel_wait
echo "Done"
}

function shutdown_directors() {
    parallel_run delete_inst director-1
    parallel_run delete_inst director-2
    parallel_run delete_inst director-3
    parallel_run delete_inst director-4
    parallel_run delete_inst director-5
#./delete_inst.sh director-b4
#./delete_inst.sh director-b5
#./delete_route.sh ip-10-11-10-11
#./delete_route.sh ip-10-11-10-12
#./delete_route.sh ip-10-11-10-13

echo "Waiting for the jobs to complete"
parallel_wait
echo "Done"
}
