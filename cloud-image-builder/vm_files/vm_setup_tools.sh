#!/bin/bash -e
set -e
#cd;tr -cd '\11\12\15\40-\176' < work/tools/packages/vijava/com/vmware/vim25/ws/WSClient.java > work/tools/packages/vijava/com/vmware/vim25/ws/WSClient.java2
#cd;mv work/tools/packages/vijava/com/vmware/vim25/ws/WSClient.java2 work/tools/packages/vijava/com/vmware/vim25/ws/WSClient.java
sudo /etc/init.d/cgroup-lite stop || true
sudo apt-get purge -y cgroup-lite || true
echo "golang-go golang-go/dashboard boolean false" | sudo debconf-set-selections
mkdir -p ~/work/tools/build
cd ~/work/tools/build && cmake ..
cd ~/work/tools/build && sudo make packages
bash -c "sudo chown -R plumgrid.plumgrid /opt/local"
cd ~/work/tools/build && make
cd ~/work/tools/build && make -C packages install
bash -c "cd ~/work/tools/build && . ../env/alps.bashrc && make install"
cd ~/work/tools/build && sudo chown -R plumgrid.plumgrid /opt/pg
