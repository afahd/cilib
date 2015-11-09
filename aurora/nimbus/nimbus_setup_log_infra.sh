#!/bin/bash -e
source /home/$USER/.aurora.conf
. /opt/pg/scripts/gc_helpers.sh

function setup_log_infra_on_dir() {
  local INSTANCE_IP=$1
  local LOG_FILE=$2
  local WORKLOAD_IP=$3
  local WORKLOAD_PORT=$4

  local local_file=$(mktemp /tmp/setup_log_infra_on_dir.sh-XXXXX)
  cat /dev/null > ${local_file}
  cat >> ${local_file} <<DELIM__
set -e
pushd /home/plumgrid/work/nirvana/setup
./fwd_tclogs_to_wl.sh -i $WORKLOAD_IP -p $WORKLOAD_PORT
popd
DELIM__
  #File name needs to be constant for continue functionality, thus renaming.
  local instance_file=/tmp/$(basename ${local_file})
  local renamed_file=/tmp/setup_log_infra_on_dir.sh
  retryexec upload ${INSTANCE_IP}  ${local_file} ${instance_file}
  tryexec run_cmd_gci ${INSTANCE_IP} "mv ${instance_file} ${renamed_file}"
  rm ${local_file}
  tryexec run_bg_cmd ${INSTANCE_IP} "${renamed_file}" "/bin/bash ${renamed_file}" "$LOG_FILE"
}

function setup_log_infra_on_wl() {
  local INSTANCE_IP=$1
  local LOG_FILE=$2
  local local_file=$(mktemp /tmp/setup_log_infra_on_wl.sh-XXXXX)
  cat /dev/null > ${local_file}
  cat >> ${local_file} <<DELIM__
set -e
pushd /home/plumgrid/work/nirvana/setup
./setup_riemann_infra.sh
popd
DELIM__
  #File name needs to be constant for continue functionality, thus renaming.
  local instance_file=/tmp/$(basename ${local_file})
  local renamed_file=/tmp/setup_log_infra_on_wl.sh
  retryexec upload ${INSTANCE_IP}  ${local_file} ${instance_file}
  tryexec run_cmd_gci ${INSTANCE_IP} "mv ${instance_file} ${renamed_file}"
  rm ${local_file}
  tryexec run_bg_cmd ${INSTANCE_IP} "${renamed_file}" "/bin/bash ${renamed_file}" "$LOG_FILE"
}

function get_instance_ips_using_regex() {
  local regex=$1
  instance_ip=$(gcloud compute instances list -r ${regex} | grep ${regex})
  instance_ip=$(echo "${instance_ip}" | awk '{ print $4}')
  echo $instance_ip
}

function show_nimbus_setup_log_infra_help() {
  cat << HELP

  USAGE: nimbus_setup_log_infra -l <build-id> -p <workload vm port>

  Required Arguments:
  -l, --build-id      Build id for which nimbus was deployed.

  Optional Arguments:
  -p, --wl-port       UDP Port where workload VM is listening to incoming logs.
                      Default is 33333.

HELP
}

WL_PORT=33333
STEP_ST=1
STEP_ED=5

# read the options
TEMP=`getopt -o l:R:E:h --long build-id:,step_st:,step_ed:,\help -n 'nimbus_setup_log_infra.sh' -- "$@"`
eval set -- "$TEMP"
while true ; do
  case "$1" in
     -l| --build-id ) BUILD_ID="$2"; shift 2 ;;
     -p| --wl-port ) WL_PORT="$2"; shift 2 ;;
     -R| --step_st ) STEP_ST="$2"; shift 2 ;;
     -E| --step_ed ) STEP_ED="$2"; shift 2 ;;
     -h| --help ) show_nimbus_setup_log_infra_help; exit 0; shift ;;
     --) shift ; break ;;
     *) exit 1 ;;
  esac
done

# TODO: Build_ID is required parameter
MOD_BUILD_ID=$(echo ${BUILD_ID} | sed 's/bld/run/')
wl_instance_name=${emailid}-${MOD_BUILD_ID}-falworkload
dir_instance_name=${emailid}-${MOD_BUILD_ID}-faldirector

function build_image() {
  local step=$1
  case "$step" in

  1)
    echo "Clone nirvana on workload VM"
    wl_instance_ip=$(get_instance_ips_using_regex ${wl_instance_name}.*)
    echo "*** $wl_instance_ip ***"
    run_cmd_gci_sshforwarding $wl_instance_ip "git clone ssh://$gerritid@${GERRIT_IP}:${GERRIT_PORT}/nirvana /home/plumgrid/work/nirvana"
    ;;

  2)
    echo "Clone nirvana on directors"
    dir_instance_ips=$(get_instance_ips_using_regex ${dir_instance_name}.*)
    for x in ${dir_instance_ips[@]}; do
      echo " $x"
      run_cmd_gci_sshforwarding $x "git clone ssh://$gerritid@${GERRIT_IP}:${GERRIT_PORT}/nirvana /home/plumgrid/work/nirvana"
    done
    ;;

  3)
    echo "Run setup_riemenn_server.sh on workload VM"
    wl_instance_ip=$(get_instance_ips_using_regex ${wl_instance_name}.*)
    tryexec setup_log_infra_on_wl ${wl_instance_ip} "/tmp/setup_log_infra_on_wl.log"
    ;;

  4)
    echo "Polling for setting up log infra on workload VMs"
    wl_instance_ip=$(get_instance_ips_using_regex ${wl_instance_name}.*)
    tryexec run_poll_cmd ${wl_instance_ip} "setup_log_infra_on_wl.sh" "/tmp/setup_log_infra_on_wl.log" "1"
    ;;

  5)
    echo "Run fwd_to_wl.sh script to watch trace_collector file and forward it to workload VM."
    wl_instance_ip=$(get_instance_ips_using_regex ${wl_instance_name}.*)
    dir_instance_ips=$(get_instance_ips_using_regex ${dir_instance_name}.*)
    for x in ${dir_instance_ips[@]}; do
      tryexec setup_log_infra_on_dir ${x} "/tmp/setup_log_infra_on_dir.log" ${wl_instance_ip} ${WL_PORT}
    done
    ;;

    *)
      echo "NOP - $step"
      ;;
   esac
}

for STEP in `seq ${STEP_ST} ${STEP_ED}`; do
  printf "\n    === Starting STEP $STEP === \n"
  start_time=$(date +%s)
  build_image $STEP
  end_time=$(date +%s)
  print_time_taken $start_time $end_time "[$STEP]"
done
