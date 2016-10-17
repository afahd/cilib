#!/bin/bash -e
sudo apt-get install ccache
export PATH="/usr/lib/ccache/:${PATH}"
mkdir -p /home/plumgrid/.ccache/
chown -R plumgrid:plumgrid /home/plumgrid/.ccache/
touch /home/plumgrid/.ccache/ccache.conf
ccache -M 5G
echo "base_dir = /home/plumgrid/work" >> /home/plumgrid/.ccache/ccache.conf
echo "compression = true" >> /home/plumgrid/.ccache/ccache.conf
#Adding to bashrc for aurora login
echo "export PATH=\"/usr/lib/ccache/:\${PATH}\"" >> /home/plumgrid/.bashrc