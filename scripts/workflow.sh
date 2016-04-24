#!/bin/bash
lb_prof=haproxy_lb
#fw_prof=vyos_fw
fw_prof=asav_fw

function parallel()
{
    total=$1
    slot=$2
    if [ "$operation" ==  "create" ]
    then
        if [ "$slot" == "1" ]
        then
            for ((i=1; i<=total; i++)); do
                for ((j=1; j<=slot; j++)); do
                    source $PWD/keystone_directory/keystone-mem$i
                    bash $PWD/operation.sh $3 $i
                done
            done
        else
            python $PWD/thread.py $1 $slot $operation
        fi
    fi
    if [ "$operation" !=  "create" ]
    then 
        python $PWD/thread.py $1 $2 $operation
    fi

}
function shared_validate()
{
    source $PWD/keystonerc_cloud_admin
    node_name=$(gbp servicechain-node-list |grep -w LB |awk '{print $4}')
    if [ "$node_name" == "LB" ]
    then
        echo -e "Create shared nodes , specs and nsp resource  in cloud_admin tenant ."
    else
        unset OS_USERNAME
        unset OS_TENANT_NAME
        unset OS_PASSWORD
        unset OS_AUTH_URL
        unset OS_REGION_NAME
        tenant_create

    fi
}

function tenant_create()
{
    echo -e "Enter number of tenant which u want at a  time in use"
    read slot

    echo -e "Enter number of tenant in multiple of " $slot
    read n
    echo $n
    echo -e "Enter create or delete or update "
    read operation
    if (( $n %  $slot == 0 ))
    then
        if [ "$operation" ==  "create" ]
        then
            rm -rf /tmp/floatingipid*
            mkdir $PWD/keystone_directory
            source ./keystone_identity_v3
            upperlim=$n
            ten_count=1000
            for ((i=1; i<=upperlim; i++)); do
                p="TENANT$ten_count"

                dom="default"
                openstack project create --domain $dom $p
                openstack user create --domain $dom --project $p --password $p $p
                openstack role add --domain $dom --user $p domain_member
                openstack role add --project $p --user $p _member_
                rm -rf $PWD/keystone_directory/keystone-mem$i
                echo -e "export OS_USERNAME=$p" >>$PWD/keystone_directory/keystone-mem$i
                echo -e "export OS_PROJECT_NAME=$p">>$PWD/keystone_directory/keystone-mem$i
                echo -e "export OS_TENANT_NAME=$p">>$PWD/keystone_directory/keystone-mem$i
                echo -e "export OS_PASSWORD=$p">>$PWD/keystone_directory/keystone-mem$i
                echo -e "export OS_AUTH_URL=http://10.251.1.20:5000/v3/">>$PWD/keystone_directory/keystone-mem$i

                echo -e "export PS1='[\u@\h \W($p)]\$ '">>$PWD/keystone_directory/keystone-mem$i

                echo -e "export OS_IDENTITY_API_VERSION=3">>$PWD/keystone_directory/keystone-mem$i
                echo -e "export OS_USER_DOMAIN_NAME=$dom">>$PWD/keystone_directory/keystone-mem$i
                echo -e "export OS_PROJECT_DOMAIN_NAME=$dom" >>$PWD/keystone_directory/keystone-mem$i
                ten_count=`expr $ten_count + 17`
            done

            unset OS_USER_DOMAIN_NAME
            unset OS_IDENTITY_API_VERSION
            unset OS_DOMAIN_NAME
            unset OS_USERNAME
            unset OS_PASSWORD
            unset OS_AUTH_URL
            unset OS_REGION_NAME
            sed -i "/dynamic=/c\dynamic=fw-lb" $PWD/gbp_resource.sh  
            #sed -i "/dynamic=/c\dynamic=fw" $PWD/gbp_resource.sh
            parallel $n $slot $operation
        fi
        if [ "$operation" == "update" ]
        then
            #sed -i "/dynamic=/c\dynamic=fw-lb" $PWD/gbp_resource.sh
            sed -i "/dynamic=/c\dynamic=fw" $PWD/gbp_resource.sh
            parallel $n $slot $operation 
        fi
        if [ "$operation" ==  "delete" ]
        then
            parallel $n $slot $operation
            : '
            unset OS_PROJECT_NAME
            unset OS_USER_DOMAIN_NAME
            unset OS_IDENTITY_API_VERSION
            unset OS_PROJECT_DOMAIN_NAME
            unset OS_USERNAME
            unset OS_TENANT_NAME
            source ./keystone_identity_v3
            sleep 120

            for (( i=1; i<=$n; i++ ))
            do
                openstack user delete mem$i
                openstack project delete mem$i
            done
            rm -rf $PWD/keystone_directory 
            '
        fi
    else
        echo -e $n " is not  multiple of " $slot
    fi


}

function shared_resource()
{
    source $PWD/keystonerc_cloud_admin
    echo -e "create for create or delete for delete operation"
    read sop
    if [ "$sop" != "create" -a "$sop" != "delete" ]
    then
        echo -e "Invalid argument : $1\n"
        exit
    fi
    if [ "$sop" == "create" ]
    then
        node_name=$(gbp servicechain-node-list |grep -w LB |awk '{print $4}')
        if [ "$node_name" == "LB" ]
        then
            echo -e "Delete previous shared node and spec and nsp resources which u created in cloud_admin tenant ."
        else

            : '
            gbp service-profile-create --shared True --servicetype FIREWALL --insertion-mode l3 --service-flavor asav --vendor oneconvergence FW
            gbp service-profile-create --shared True --servicetype LOADBALANCER --insertion-mode l3 --service-flavor haproxy --vendor oneconvergence LB
            gbp external-segment-create --ip-version 4 --cidr 1.102.1.254/24 --external-route destination=0.0.0.0/0,nexthop= --shared True Management-Out
            gbp external-segment-create --ip-version 4 --cidr 1.102.2.254/24 --external-route destination=0.0.0.0/0,nexthop= --shared True default
            gbp nat-pool-create --ip-version 4 --ip-pool 1.103.2.0/24 --shared True --external-segment default default-nat-pool
            '
            gbp servicechain-node-create --service-profile $fw_prof --shared True --template-file $PWD/fw.template1 FW-1
            gbp servicechain-node-create --service-profile $fw_prof --shared True --template-file $PWD/fw.template2 FW-2
            gbp servicechain-node-create --service-profile $lb_prof --shared True --template-file $PWD/lb.template  LB
            gbp servicechain-spec-create LB --nodes  "LB"  --shared True
            gbp servicechain-spec-create FW-2 --nodes  "FW-2"  --shared True
            gbp servicechain-spec-create FW-1-LB --nodes  "FW-1 LB" --shared True
            gbp network-service-policy-create LB-VIP-FIP-NSP --network-service-params "type=ip_single,name=vip_ip,value=self_subnet" --shared True
            gbp policy-action-create LB-REDIRECT --action-type redirect --action-value LB --shared True
            gbp policy-action-create FW-REDIRECT --action-type redirect --action-value FW-2 --shared True
            gbp policy-action-create FW-LB-REDIRECT --action-type redirect --action-value FW-1-LB --shared True
            gbp policy-action-create ALLOW --action-type allow --shared True
            gbp policy-classifier-create ICMP-CLASSIFIER --protocol icmp --direction bi --shared True
            gbp policy-classifier-create HTTP-CLASSIFIER --protocol tcp --port-range 80 --direction bi --shared True
            gbp policy-classifier-create TCP-CLASSIFIER --protocol tcp  --direction bi --shared True
            gbp policy-classifier-create ICMP-CLASSIFIER --protocol icmp  --direction bi --shared True
            gbp policy-rule-create  ICMP-ALLOW-PR --classifier ICMP-CLASSIFIER --actions ALLOW--shared True
            gbp policy-rule-create TCP-ALLOW-PR --classifier TCP-CLASSIFIER  --actions  ALLOW --shared True
            gbp policy-rule-create FW-LB-PR --classifier HTTP-CLASSIFIER --actions FW-LB-REDIRECT --shared True
            gbp policy-rule-create  LB-PR --classifier HTTP-CLASSIFIER --actions LB-REDIRECT --shared True
            gbp policy-rule-create  FW-PR --classifier TCP-CLASSIFIER --actions FW-REDIRECT --shared True
            gbp policy-rule-set-create HTTP-LB-REDIRECT-PRS --policy-rules "ICMP-ALLOW-PR TCP-ALLOW-PR LB-PR"  --shared True
            gbp policy-rule-set-create TCP-FW-REDIRECT-PRS --policy-rules "ICMP-ALLOW-PR TCP-ALLOW-PR FW-PR"  --shared True
            gbp policy-rule-set-create WEB-FW-LB-REDIRECT-PRS --policy-rules "ICMP-ALLOW-PR TCP-ALLOW-PR FW-LB-PR"  --shared True
            gbp policy-rule-set-create WEB-PRS --policy-rules "ICMP-ALLOW-PR TCP-ALLOW-PR"  --shared True
        fi
    fi
    if [ "$sop" == "delete" ]
    then
        echo -e "These resources are shared resources before deleting make sure you deleted all resourecs from other tenants which used these shared resources.Press Y for Yes  or press N for No ."
        read flag
        if [ "$flag" != "Y" -a "$flag" != "N" ]
        then
            echo -e "Invalid argument : $1\n"
            exit
        fi
        if [ "$flag" == "Y" ]
        then
            : '
            gbp external-segment-create --ip-version 4 --cidr 1.102.1.254/24 --external-route destination=0.0.0.0/0,nexthop= --shared True Management-Out
            gbp external-segment-create --ip-version 4 --cidr 1.102.2.254/24 --external-route destination=0.0.0.0/0,nexthop= --shared True default
            gbp nat-pool-create --ip-version 4 --ip-pool 1.103.2.0/24 --shared True --external-segment default default-nat-pool
            '
            gbp policy-rule-set-delete WEB-PRS
            gbp policy-rule-set-delete WEB-FW-LB-REDIRECT-PRS
            gbp policy-rule-set-delete TCP-FW-REDIRECT-PRS
            gbp policy-rule-set-delete HTTP-LB-REDIRECT-PRS
            gbp policy-rule-delete FW-PR
            gbp policy-rule-delete LB-PR
            gbp policy-rule-delete FW-LB-PR
            gbp policy-rule-delete TCP-ALLOW-PR
            gbp policy-rule-delete ICMP-ALLOW-PR
            gbp policy-classifier-delete ICMP-CLASSIFIER
            gbp policy-classifier-delete TCP-CLASSIFIER
            gbp policy-classifier-delete HTTP-CLASSIFIER
            gbp policy-classifier-delete ICMP-CLASSIFIER
            gbp policy-action-delete FW-LB-REDIRECT
            gbp policy-action-delete FW-REDIRECT
            gbp policy-action-delete LB-REDIRECT
            gbp policy-action-delete ALLOW
            gbp network-service-policy-delete LB-VIP-FIP-NSP
            gbp servicechain-spec-delete FW-1-LB
            gbp servicechain-spec-delete FW-2 
            gbp servicechain-spec-delete  LB 
            gbp servicechain-node-delete FW-1
            gbp servicechain-node-delete FW-2
            gbp servicechain-node-delete LB 


        fi
        if [ "$flag" == "N" ]
        then
            echo -e " ok "
        fi
    fi

}

function start()
{
    echo -e "Enter operator or tenant ."
    read op
    if [ "$op" != "operator" -a "$op" != "tenant" ]
    then
        echo -e "Invalid argument : $1\n"
        exit
    fi

    if [ "$op" == "operator" ]
    then 
        shared_resource
    fi
    if [ "$op" == "tenant" ]
    then 
        shared_validate
    fi
}

start



