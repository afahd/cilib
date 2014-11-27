#!/bin/bash -x

#scp -i ../gcloud-pg cn-setup.sh 146.148.53.60:/opt/pg/var/www/files/
sudo /bin/sed -i "s/^set \-x/#set \-x/g" /opt/pg/bin/ifc_ctl_pp
HN=$(hostname)
sudo /usr/bin/systemctl stop plumgrid
sudo /bin/sed -i s/label=c7-i1/label=$(hostname)/g /var/lib/libvirt/filesystems/plumgrid-data/conf/pg/plumgrid.conf
#DIR_IPS=`grep plumgrid_ip= /var/lib/libvirt/filesystems/plumgrid-data/conf/pg/plumgrid.conf | cut -d '=' -f 2 | sed 's/,/\n/g' | shuf | paste -sd "," -`
DIR_IPS=`echo "plumgrid_ip=10.11.10.11,10.11.10.12,10.11.10.13,10.11.10.14,10.11.10.15" | cut -d '=' -f 2 | sed 's/,/\n/g' | shuf | paste -sd "," -`
sudo /bin/sed -i s/plumgrid_ip=.*/plumgrid_ip=${DIR_IPS}/g /var/lib/libvirt/filesystems/plumgrid-data/conf/pg/plumgrid.conf
echo $HN | sudo tee /var/lib/libvirt/filesystems/plumgrid-data/conf/etc/hostname
sudo /usr/bin/systemctl start plumgrid
for i in `seq 1 60`;
do
  echo "Trying to wait for pgname on $NAME Iteration [$i]"
if [ -f  /var/run/libvirt/lxc/plumgrid.pid ];
then
  res=`sudo /opt/pg/bin/ifc_ctl gateway get_pgname`
  echo "       Received Response [$res]"
  [ $(echo "$res" | grep -E "PE_[0-9a-fA-F]*$") ] && break
else
 echo "      plumgrid not ready missing /var/run/libvirt/lxc/plumgrid.pid"
fi
  sleep 1
done



DOMAINS=`cat /opt/pg/domains`
for dom in $DOMAINS;
do
for ifc_cnt in `seq 1 10`;
do
DEV="$HN.$ifc_cnt"
DOMAIN=$dom

FOUND=0
/sbin/ip link show $DEV > /dev/null && FOUND=1
if [ "$FOUND" = 1 ] ; then
echo "Found ifc and deleted it"
sudo /opt/pg/bin/ifc_ctl gateway ifdown ${DEV}_ access_vm vm-$DEV || true
sudo /opt/pg/bin/ifc_ctl gateway del_port ${DEV}_ || true
sudo ip link del $DEV
fi

echo "Creating Device"
sudo /sbin/ip link add name $DEV type veth peer name ${DEV}_
echo "Adding Device $DEV to iovisor"
sudo /opt/pg/bin/ifc_ctl gateway add_port ${DEV}_
sudo /opt/pg/bin/ifc_ctl gateway ifup ${DEV}_ access_vm vm-$DEV $(cat /sys/class/net/${DEV}/address) pgtag1=${DOMAIN}
sudo ip netns add vm-$DEV
sudo ip link set ${DEV} netns vm-$DEV
sudo ip netns exec vm-${DEV} ip link set dev ${DEV} name eth0
sudo ip netns exec vm-${DEV} ifconfig eth0 up
nohup sudo ip netns exec vm-${DEV} bash -c "sleep $ifc_cnt;sleep $ifc_cnt;dhclient -pf /var/run/dhclient.${DEV} -lf /var/lib/dhclient/dc-${DEV}.leases eth0" &
done
done

echo "Setting up ETCD"
MYIP=`/sbin/ifconfig eth0 | grep "inet " | cut -d"i" -f2 | cut -d" " -f2`
cat >/tmp/etcd.conf <<EOF
# This configuration file is written in [TOML](https://github.com/mojombo/toml)

addr = "${MYIP}:4001"
bind_addr = "0.0.0.0:4001"
ca_file = ""
cert_file = ""
cors = []
cpu_profile_file = ""
data_dir = "."
# discovery = "http://etcd.local:4001/v2/keys/_etcd/registry/examplecluster"
http_read_timeout = 10.0
http_write_timeout = 10.0
key_file = ""
peers = ["10.11.10.11:7001","10.11.10.12:7001","10.11.10.13:7001"]
peers_file = ""
max_cluster_size = 3
max_result_buffer = 1024
max_retry_attempts = 3
name = "$HN"
snapshot = false
verbose = false
very_verbose = false

[peer]
addr = "${MYIP}:7001"
bind_addr = "0.0.0.0:7001"
ca_file = ""
cert_file = ""
key_file = ""

[cluster]
active_size = 3
remove_delay = 1800.0
sync_interval = 5.0
EOF
sudo mv /tmp/etcd.conf /etc/etcd/etcd.conf

sudo cat >./etcd_change_cmd.sh <<EOF
#!/bin/bash
CMD=\$1
#ETCD_WATCH_VALUE
echo "Running CMD:\$CMD" >> /tmp/etcdctl.log
\$CMD >& /tmp/1
etcdctl set hosts/`hostname`/gcmd "\`cat /tmp/1\`"  >> /tmp/etcdctl.log
etcdctl set hosts/`hostname`/gcmd_date "\`date\`"  >> /tmp/etcdctl.log
EOF
sudo chmod +x ./etcd_change_cmd.sh

sudo cat >./etcd_change_cmd_watch.sh <<EOF
#!/bin/bash
while true; do VAL=\`etcdctl watch /allhosts/cmd\` ; ./etcd_change_cmd.sh \$VAL; done
EOF
sudo chmod +x ./etcd_change_cmd_watch.sh

#sudo systemctl enable etcd
#sudo systemctl restart etcd
sudo systemctl disable etcd
sudo systemctl stop etcd

#for i in `seq 1 60`;
#do
#echo "Trying to check etdctl status [$i]"
#etcdctl ls && break
#sleep 1
#done


#etcdctl mkdir hosts/${HN}
#etcdctl set hosts/${HN}/myip "$MYIP"
#etcdctl set hosts/${HN}/date  "`date`"
#sudo nohup ./etcd_change_cmd_watch.sh > ./etcd_change_cmd_watch.log 2>&1  &
echo "DONE"
