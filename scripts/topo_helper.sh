#!/bin/bash -e
. ./gc_helper.sh
. ./rest_helper.sh

function topo_del() {
    local domain=$1
    rest_delete /v0/VND/$domain
    rest_delete /0/pem_master/log_rule/${domain}
    rest_delete /0/tunnel_service/vnd_config/${domain}
}

function topo_del_multi() {
    local START=$1
    local END=$2
    for i in `seq $START $END`;
    do
        echo "Deleting Demo-$i"
        parallel_run topo_del Demo-$i
    done
    echo "Waiting for the Delete jobs to complete"
    parallel_wait
    echo "Done"
}

function topo_multi() {
    local START=$1
    local END=$2
    for i in `seq $START $END`;
    do
        echo "Launching Demo-$i"
        parallel_run post_br_dhcp "Demo-$i"
    done
    echo "Waiting for the cn start jobs to complete"
    parallel_wait
    echo "Done"
}

function post_br_dhcp() {
    local domain=$1
    local subnet=${2:-"10.90.1"}

    # create a toplology "Demo1"

    rest_put /v0/VND/$domain '{
   "container_group" : "'$domain'",
   "topology_name" : "default-topo",
   "link" : {
     "link1" : {
            "link_type" : "static",
            "attachment1" : "bridge/Bridge1/ifc/B1toR",
            "attachment2" : "dhcp/dhcp1/ifc/DtoB1"
     },
     "vm_rule1" : {
            "link_type" : "rule",
            "attachment1" : "cnf-vmgroup/Cluster1",
            "attachment2" : "bridge/Bridge1"
     }
   },
   "ne_type" : {
         "bridge" : {
            "Bridge1" : {
              "ifc" : {
                 "B1toR" : { "ifc_type" : "static" }
               },
              "action":{"DefaultAction":{"action_text":"create_and_link_ifc(DYN_)"}}

             }
         },
         "dhcp" : {
             "dhcp1" : {
                "ifc" : {
                  "DtoB1" : { "ifc_type" : "static",
                              "dhcp_server_ip" : "'$subnet'.251",
                              "dhcp_server_mask" : "255.255.255.0",
                              "ip_range_start" : "'$subnet'.10",
                              "ip_range_end"   : "'$subnet'.100",
                              "no_ping" : true
                   }
                }
             }
         },

         "cnf-vmgroup" : {
             "Cluster1" : {
                "rules" : {"1" : {"criteria" : "ifc_type", "match" : "ACCESS_VM" } }
              }
         }
   }
}'

    # Create the PEM Rules.
    res=$(rest_get /0/pem_master/log_rule/${domain}/rule)
    if [[ "${res}" == "{}" ]]; then
        rest_put /0/pem_master/log_rule/${domain} '{ "rule":null }'
    fi
    rest_put /0/pem_master/log_rule/${domain}/rule/catch_all_rule '{
       "pgtag1" : "'$domain'",
       "log_ifc_type" : "ACCESS_VM"
    }'

    #enable Tunnel Liveness
    rest_put /0/tunnel_service/vnd_config/${domain} '{
      "add_security":false,
      "add_tos":false,
      "add_vlan":false,
      "dot1q_vlan":0,
      "profile_name":"VXLAN",
      "sec_keylife":3600,
      "tos":0
     }'
}
