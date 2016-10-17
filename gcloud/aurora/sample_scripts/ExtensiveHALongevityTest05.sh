#!/bin/bash
export EXPORT_FAILURES_DIR=/opt/pg/log/
cd /home/plumgrid/work/alps/build
ctest -R UNSTABLE_ExtensiveHALongevityTest05 --output-on-failure -V
