ls#!/bin/bash

. ./rest_helper.sh

post_license
echo "License is ready"
DT=$(rest_get /0/tenant_manager/licenses)
echo "Current LICENSE=$DT"
