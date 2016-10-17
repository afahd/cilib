#!/bin/bash -e
set -e
branch=$1
export PATH="/usr/lib/ccache/:${PATH}"
cd ~/work/iovisor/bld && make
cd ~/work/iovisor/bld && sudo make install
mkdir -p ~/work/pg_ui/build && mkdir -p ~/work/sal/build && mkdir -p ~/work/pkg/build && mkdir -p ~/work/pg_cli/build

# Adding special condition for master on pgui due to grunt changes
if [[ $branch != "master" ]]; then
  bash -c "cd ~/work/pg_ui/build && . /opt/pg/env/alps.bashrc && cmake .."
  cd ~/work/pg_ui/build && make -j 4 -k
  cd ~/work/pg_ui/build && make install
fi
bash -c "cd ~/work/sal/build && . /opt/pg/env/alps.bashrc && cmake .."
cd ~/work/sal/build && make -j 4 -k
cd ~/work/sal/build && make install
bash -c "cd ~/work/pkg/build && . /opt/pg/env/alps.bashrc && cmake .."
cd ~/work/pkg/build && make -j 4 -k
cd ~/work/pkg/build && make install
bash -c "cd ~/work/pg_cli/build && . /opt/pg/env/alps.bashrc && cmake .."
cd ~/work/pg_cli/build && make -j 4 -k
cd ~/work/pg_cli/build && make install
mkdir -p ~/work/corelib/build
bash -c "cd ~/work/corelib/build && . /opt/pg/env/alps.bashrc && cmake .."
cd ~/work/corelib/build && make -j 4 -k
cd ~/work/corelib/build && make install
mkdir -p ~/work/alps/build
bash -c "cd ~/work/alps/build && . /opt/pg/env/alps.bashrc && cmake .."
cd ~/work/alps/build && make -j 4 -k
cd ~/work/alps/build && make install
mkdir -p ~/work/python-plumgridlib/build
bash -c "cd ~/work/python-plumgridlib/build && . /opt/pg/env/alps.bashrc && cmake .."
cd ~/work/python-plumgridlib/build && make -j 4 install
