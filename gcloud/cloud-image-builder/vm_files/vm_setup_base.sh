#!/bin/bash -e
set -e
useradd plumgrid -p plumgrid || true
usermod -a -G adm plumgrid
usermod -a -G sudo plumgrid
#apt-get install sudo
cp 90-cloudimg-plumgrid /etc/sudoers.d/
chmod 0440 /etc/sudoers.d/90-cloudimg-plumgrid
rm -rf /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y ssh git sudo vim tzdata-java rsyslog
#ADD run_bash /home/plumgrid/
#chmod +x /home/plumgrid/run_bash
chown -R plumgrid.plumgrid /home/plumgrid
su plumgrid -c 'rm -rf ~/.ssh/id_rsa*'
su plumgrid -c 'ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa'
apt-get install -y gcc-multilib libmagic-dev libcurl4-openssl-dev
mv /etc/apt/sources.list /etc/apt/sources.list.bak
cp sources.list /etc/apt/
cp ubuntu-lxc-stable-precise.list /etc/apt/sources.list.d/
apt-get update || true
apt-get install -y --force-yes apache2 openssh-server cmake make git g++ iovisor-dkms openjdk-7-jdk plumgrid-install-tools unzip lxc curl isc-dhcp-client
apt-get install -y reprepro apt-cacher-ng apt-mirror
apt-get install -y --force-yes linux-headers-`uname -r` linux-image-`uname -r`
/usr/bin/git config --global user.name sushilks
/usr/bin/git config --global user.email sushilks@plumgrid.com
/usr/bin/git config --global push.default upstream
cp ssh_config /home/plumgrid/.ssh/config
/bin/chown plumgrid.plumgrid /home/plumgrid/.ssh/config
#/bin/mkdir /var/run/sshd
#ADD authorized_keys /home/plumgrid/.ssh/authorized_keys
sudo sed -i 's/ \/var\/www/ \/opt\/pg\/var\/www/g'  /etc/apache2/sites-available/default
/bin/chown plumgrid.plumgrid /opt
/bin/chmod 777 /opt
su plumgrid -c 'bash -c "sudo mkdir -p /opt/local/bin"'
su plumgrid -c 'bash -c "sudo mkdir -p /opt/pg/{bin,core,debug,lib,log,share,test,tmp,web,env}"'
su plumgrid -c 'bash -c "sudo chmod 777 /opt/pg/{bin,core,debug,lib,log,share,test,tmp,web}"'
bash -c 'chown -R plumgrid.plumgrid /opt/pg'
su plumgrid -c 'bash -c "echo \". /opt/pg/env/alps.bashrc\" >> ~/.bashrc"'
#cp --remove-destination git_update.sh /home/plumgrid/
bash -c 'chown plumgrid.plumgrid /home/plumgrid/git_update.sh'
