#!/bin/bash
export EXPORT_FAILURES_DIR=/opt/pg/log/
sudo /home/plumgrid/work/alps/build/scripts/jenkins/lxc-automaton-longevity-jenkins-init.sh
cd /home/plumgrid/work/alps/build
ctest -R UNSTABLE_ExtensiveHALongevityTest05 --output-on-failure -V
