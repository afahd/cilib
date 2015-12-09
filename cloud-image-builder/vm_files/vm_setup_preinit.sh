#!/bin/bash -e
set -e
echo 'Acquire::http { Proxy \"http://10.10.163.162:3142\"; };' > /tmp/02proxy
sudo mv /tmp/02proxy /etc/apt/apt.conf.d/02proxy
sudo apt-get update || true
sudo apt-get install -y btrfs-tools haveged libxml2-dev
sudo mkfs.btrfs /dev/sdb -L DDISK && echo "LABEL=\"DDISK\" /opt btrfs defaults 0 0" > /tmp/b1 && sudo bash -c "cat /tmp/b1 >> /etc/fstab"
sudo mount /opt
sudo mkdir -p /opt/var/lib
sudo service docker stop
sudo mv /var/lib/docker /opt/var/lib
sudo ln -s /opt/var/lib/docker /var/lib/ && sudo service docker start
sudo mv /home/plumgrid /opt/
sudo chown plumgrid.plumgrid /opt/plumgrid
sudo ln -s /opt/plumgrid /home/plumgrid
sudo rm -rf /var/lib/lxc
sudo mkdir /opt/lxc
sudo ln -s /opt/lxc /var/lib/lxc
sudo sed -i '/gerrit/d' /etc/hosts
sudo bash -c "echo '192.168.10.77 gerrit' >> /etc/hosts"
