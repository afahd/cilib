#!/bin/bash

export LOC=${LOC:-localhost}
export PORT=8000
## license variables
PLUMGRID_LICENSE=${PLUMGRID_LICENSE:-"EuYaOnQHCTpli6BPg7KAOmO8GE8Q649RUzbFoc5oQ5c1koisjAdIDVXpDwTcMQXdN+JbOx41dPnsggifTcahnlHz5XRF7FnQo/bU5DOXy9zRbEPIlMsEk9o45xLJXWa0Uemyi6R+lz7C/zqn+LjpzWfoK4pACZSdrEbs/bTkGcmoOkkkwAwTCjYkqSq32pN8AdKFNv5F+nRlgogoi4f9gpMIqLTqqYtzNUAe/FSyNKrOpf6y0OsO4dH0ZJLc4nUYIKZbAh5s9DrukZN8gWVIEcKy1Q+clLx3aa8m/d3v1lfMh0X77PGhDq8Mr8S4qF5hj2EXqSBG88Dd5OAMtoiQMJCOvzNAP456NvjwPy/xo+RKZfCySgUc6CgUarzmfDOvM2Poe2y+RxLGUAvCOJxUFGsZ5ESq3SFv4yl4jhQjm3LCwubRyXcf005Ch4AVTi+oQPBV5D+CdwJW1WKnAgRsSpfp5CByeIyIm7GsMhv3shH0qtClggc0EOnKlzVs/danNKWmxVzrTrNketa/1kGnVl91UzImTUjZ0rSUNnmZLk9o1lfXRXPh1G0d9WoRHXBHfJnCTL/hhpa0r50ehC0CTB/ilvVxqaM+Qw4bUPoMoVuLQ6VaVx5wODOWquMbQ75Wu7oVfGz7RCLazWgTUs0NF9JZMAkVYfqYrEFdroEuLO0="}
LIC_FULL_JSON=' "license_key" : { "key1" : {
  "license" : "'$PLUMGRID_LICENSE'"
} } '

function log() {
  echo "[$(basename $0)-$(date '+%H:%M:%S.%N')] $@"
}

function assert_eq() {
  if [[ "$1" != "$2" ]] ; then
    log "assert_eq failed at line $3 ($1 != $2)"
    if [[ "x$4" != "x" ]] ; then
      log $4
    fi
    quit 1
  fi
}

function assert_neq() {
  if [[ "$1" == "$2" ]] ; then
    log "assert_neq failed at line $3 ($1 == $2)"
    if [[ "x$4" != "x" ]] ; then
      log $4
    fi
    quit 1
  fi
}

#us
# used to wait for TM to properly receive the license info from CDB
# $1: optional amount of $SLEEP_INTERVAL sec (default 0.2) increments to wait (default increments: 100)
function wait_license_propagation() {
  [[ -n "$LICENSE_DISABLED" || $license_enabled_first_pass -eq 1 ]] && return
  license_enabled_first_pass=1

  local lic_timeout=200
  if [[ $# -ge 1 ]]; then
    lic_timeout=$1
  fi
  log "Waiting for license propagation for ${lic_timeout} increments..."

  # wait for one of the license values to appear
  # (need a manual loop to handle both cURL failures and string mismatches)
  local lic_iter=$lic_timeout
  while true; do
    res=$(curl "$LOC:8080/0/tenant_manager/licenses/VNF.bridge/value" -f -s -H "Accept: application/json")
    status=$?
    if [[ $status -eq 0 && $res != "0" && $res != "null" ]]; then
      # if the request was successful, and the license value is nonzero
      break
    fi
    lic_iter=$[$lic_iter-1]
    assert_neq $lic_iter '0' 'N/A' 'Timed out waiting for license'
    sleep $SLEEP_INTERVAL
  done
  log 'DONE waiting for license!'
}

function post_license() {
    rest_put /0/tenant_manager $LIC_FULL_JSON
    echo "License Posted :$?"
    wait_license_propagation
}


# usage: rest_post '/path' '{ ... }'
function rest_post() {
  url="$1"
  x=$(curl "$LOC:8080$url" --write-out "%{http_code}" -o /tmp/last_rest_post -s \
    -H "Content-Type: application/json" -H "Accept: application/json" -d "$2")
  assert_eq "$x" 200 "n/a (POST $url)" "restgw returned: \"$(cat /tmp/last_rest_post)\""
}

# usage: rest_put '/path' '{ ... }'
function rest_put() {
  url="$1"
  x=$(curl -X PUT "$LOC:8080$url" --write-out "%{http_code}" -o /tmp/last_rest_post -s \
    -H "Content-Type: application/json" -H "Accept: application/json" -d "$2")
  assert_eq "$x" 200 "n/a (PUT $url)" "restgw returned: \"$(cat /tmp/last_rest_post)\""
}
# usage: rest_get '/path'
function rest_get() {
  url="$1"
  curl "$LOC:8080$url" -s -H "Accept: application/json"
  if [[ $DO_NO_ASSERT != 1 ]]; then
    assert_eq $? 0 "n/a (GET $url)"
  fi
}
# usage: rest_delete '/path'
function rest_delete() {
  url="$1"
  x=$(curl "$LOC:8080$url" -X DELETE --write-out "%{http_code}" -o /tmp/last_rest_post -s \
    -H "Accept: application/json")
  assert_eq $? 0 "n/a (DELETE $1)"
  assert_eq "$x" 200 "n/a (PUT $1)" "restgw returned: \"$(cat /tmp/last_rest_post)\""
}
