#!/bin/bash -e
apt_component=$1
export APT_COMPONENT=${apt_component}
source /opt/pg/env/alps.bashrc

cd /home/plumgrid/work/pkg/build
../scripts/build-all.sh
#find /home/plumgrid -name "*.o" -not -name 'setcontext.o' | xargs rm -f
#find /home/plumgrid -name "*.a" | xargs rm -f
#find /home/plumgrid -name "*_pre" | xargs rm -f
#sudo su plumgrid -c /bin/bash

