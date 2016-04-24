#!/bash/bin

dynamic=fw-lb
image_name=cirros
ext_segment=Datacenter-Out
flav=m1.tiny

function add_mem()
{
    image_id=$(openstack image list |grep  "$image_name" |awk '{print $2}'|head -n 1)
    sleep 2
    cptgid=$(gbp policy-target-group-list |grep -w $1  |awk '{print $2}')
    i=1
    while [ $i -le $2 ]
    do
        pt_id=$( gbp  pt-create --policy-target-group $cptgid $1"CPT"$i | grep  port_id | awk '{print $4 }' )
        openstack server create --image $image_id --flavor $flav --nic port-id=$pt_id  $1"-MEM"$i
        i=`expr $i + 1`
    done
}

function del_mem()
{

    i=1
    while [ $i -le $2 ]
    do
        sleep 2
        gbp pt-delete $1"CPT"$i
        i=`expr $i + 1`
    done


    i=1
    while [ $i -le $2 ]
    do
        sleep 2
        openstack server delete $1"-MEM"$i
        i=`expr $i + 1`
    done

}

function floatingipasso()
{
    a=$2
    datacenter_name=$(neutron net-external-list  |grep Datacenter |awk '{print $4}')
    floatingip_id=$( neutron  floatingip-create $datacenter_name |grep  id  |head -n 2 |tail -n 1  |awk '{print $4}')
    echo $floatingip_id >>/tmp/floatingipidin$a
    sleep 5
    floating_ip=$(neutron floatingip-show $floatingip_id |grep  floating_ip_address |awk '{print $4}')
    neutron  floatingip-associate $floatingip_id  $1

}

function floatingipdisasso()
{
    a=$1
    filename=/tmp/floatingipidin$a
    while read -r line
    do
        neutron floatingip-disassociate $line
        sleep 5
        neutron floatingip-delete $line
        sleep 3

    done < "$filename"
}

function  update()
{

    if [ "$dynamic" == "fw-lb" ]
    then
        vipid=$(neutron port-list |grep vip |awk '{print $2}')
        echo -e $vipid
        gbp policy-rule-set-update WEB-PRS --policy-rules "ICMPALLOW-PR TCPALLOW-PR WEB-PR "
        vipid1=$(neutron port-list |grep vip|grep -v $vipid |awk '{print $2}')
        echo -e $vipid1
        floatingipasso $vipid1 $1
    fi
    if [ "$dynamic" == "fw" ]
    then
        gbp policy-target-group-update DB --provided-policy-rule-sets=TCP-PRS
        #add_mem DB 1
    fi
}






function dynamicinsertion()
{
    if [ "$dynamic" == "fw-lb" ]
    then
        echo -e "PRS update for fw-lb"
        update $1 
    fi

    if [ "$dynamic" == "fw" ]
    then
        echo -e "PRS update for fw "
        gbp policy-target-group-update DB --provided-policy-rule-sets=TCP-PRS
    fi
}


function pre_create()
{
    action_name=$(gbp policy-action-list  |grep -w  FW-LB-REDIRECT |awk '{print $4}')
    if [ "$action_name" == "FW-LB-REDIRECT" ]
    then
        echo -e "Delete previous gbp unshared resources which u created in tenant ."
    else
        gbp policy-action-create LB-REDIRECT --action-type redirect --action-value LB
        gbp policy-action-create FW-REDIRECT --action-type redirect --action-value FW-2
        gbp policy-action-create FW-LB-REDIRECT --action-type redirect --action-value FW-1-LB
        gbp policy-action-create ALLOW --action-type allow
        gbp policy-classifier-create HTTP-CLASSIFIER --protocol tcp --port-range 80 --direction bi
        gbp policy-classifier-create TCP-CLASSIFIER --protocol tcp  --direction bi
        gbp policy-classifier-create ICMP-CLASSIFIER --protocol icmp  --direction bi
        gbp policy-rule-create HTTP-PR --classifier HTTP-CLASSIFIER --actions LB-REDIRECT
        gbp policy-rule-create TCP-PR --classifier TCP-CLASSIFIER  --actions FW-REDIRECT
        gbp policy-rule-create WEB-PR --classifier HTTP-CLASSIFIER --actions FW-LB-REDIRECT
        gbp policy-rule-create  ICMPALLOW-PR --classifier ICMP-CLASSIFIER --actions ALLOW
        gbp policy-rule-create TCPALLOW-PR --classifier TCP-CLASSIFIER --actions ALLOW
        gbp policy-rule-set-create HTTP-PRS --policy-rules "ICMPALLOW-PR TCPALLOW-PR HTTP-PR"
        gbp policy-rule-set-create TCP-PRS --policy-rules "ICMPALLOW-PR TCPALLOW-PR TCP-PR"
        gbp policy-rule-set-create WEB-PRS --policy-rules "ICMPALLOW-PR TCPALLOW-PR"
        gbp ptg-create DB
        gbp ptg-create APP --network-service-policy LB-VIP-FIP-NSP
        gbp ptg-create WEB  --network-service-policy  LB-VIP-FIP-NSP
        gbp policy-target-group-update APP --provided-policy-rule-sets=HTTP-PRS  --consumed-policy-rule-sets TCP-PRS=None  
        gbp policy-target-group-update WEB --provided-policy-rule-sets=WEB-PRS --consumed-policy-rule-sets HTTP-PRS=None 
        gbp external-policy-create --external-segments $ext_segment  --consumed-policy-rule-sets WEB-PRS=None  EXTERNAL-WORLD
        dynamicinsertion $1 

        add_mem DB 1
        add_mem APP 2
        add_mem WEB 2

    fi
}

function cleanup()
{
    floatingipdisasso $1
    del_mem DB 1
    del_mem APP 2
    del_mem WEB 2
    gbp policy-target-group-delete DB
    gbp policy-target-group-delete APP 
    gbp policy-target-group-delete WEB
    gbp external-policy-delete EXTERNAL-WORLD
    gbp policy-rule-set-delete HTTP-PRS
    gbp policy-rule-set-delete TCP-PRS
    gbp policy-rule-set-delete WEB-PRS
    gbp policy-rule-delete HTTP-PR
    gbp policy-rule-delete TCP-PR
    gbp policy-rule-delete WEB-PR  
    gbp policy-rule-delete ICMPALLOW-PR
    gbp policy-rule-delete TCPALLOW-PR
    gbp policy-classifier-delete HTTP-CLASSIFIER
    gbp policy-classifier-delete TCP-CLASSIFIER
    gbp policy-classifier-delete ICMP-CLASSIFIER 
    gbp policy-action-delete LB-REDIRECT
    gbp policy-action-delete FW-REDIRECT
    gbp policy-action-delete FW-LB-REDIRECT
    gbp policy-action-delete ALLOW
}


