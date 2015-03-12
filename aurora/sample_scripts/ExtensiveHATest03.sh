#!/bin/bash
export EXPORT_FAILURES_DIR=/opt/pg/log/
/home/plumgrid/work/alps/build/scripts/jenkins/lxc-automaton-jenkins-init.sh
cd /home/plumgrid/work/alps/build
ctest -R ExtensiveHATest03 --output-on-failure -V
