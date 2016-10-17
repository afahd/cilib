#!/bin/bash -e
branch=$1
PROJECT_LIST=(pkg pg_cli pg_ui sal alps python-plumgridlib)

for p in ${PROJECT_LIST[@]}; do
	cd ~/work/$p
	git reset --hard origin/${branch}
	git checkout ${branch}
	git reset --hard origin/${branch}
	git clean -fdx
done