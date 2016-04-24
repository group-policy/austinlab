#!/bash/bin

dynamic="fw-lb"
#dynamic="fw"
lb_prof=haproxy_lb
fw_prof=vyos_fw
#fw_prof=asav_fw
image_name=cirros
ext_segment=Datacenter-Out
flav=m1.tiny

function add_mem()
{
    #$1 will be the ptg name
    #$2 will be no of member to launch
    image_id=$(openstack image list |grep  "$image_name" |awk '{print $2}'|head -n 1)
    sleep 2
    cptgid=$(gbp policy-target-group-list |grep -w $1  |awk '{print $2}')
    i=1
    while [ $i -le $2 ]
    do
        pt_id=$( gbp  pt-create --policy-target-group $cptgid $1"cpt"$i | grep  port_id | awk '{print $4 }' )
        openstack server create --image $image_id --flavor $flav --nic port-id=$pt_id  $1"-mem"$i
        i=`expr $i + 1`
    done
}

function del_mem()
{

    i=1
    while [ $i -le $2 ]
    do
        sleep 2
        gbp pt-delete $1"cpt"$i
        i=`expr $i + 1`
    done


    i=1
    while [ $i -le $2 ]
    do
        sleep 2
        openstack server delete $1"-mem"$i
        i=`expr $i + 1`
    done

}

function floatingipasso()
{
    a=$2
    datacenter_name=$(neutron net-external-list  |grep Datacenter |awk '{print $4}')
    floatingip_id=$( neutron  floatingip-create $datacenter_name |grep  id  |head -n 2 |tail -n 1  |awk '{print $4}')
    echo $floatingip_id >>/tmp/floatingipid$a
    sleep 5
    floating_ip=$(neutron floatingip-show $floatingip_id |grep  floating_ip_address |awk '{print $4}')
    neutron  floatingip-associate $floatingip_id  $1

}

function floatingipdisasso()
{
    a=$1
    filename=/tmp/floatingipid$a
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
        gbp policy-rule-set-update update-prs --policy-rules "icmpallow-pr tcpallow-pr update-pr"
        vipid1=$(neutron port-list |grep vip|grep -v $vipid |awk '{print $2}')
        echo -e $vipid1
        floatingipasso $vipid1 $1
    fi
    if [ "$dynamic" == "fw" ]
    then
        gbp policy-target-group-update db --provided-policy-rule-sets=tcp-prs
    fi

    #gbp policy-rule-set-update update-prs --policy-rules "tcp-pr"
    #gbp policy-rule-set-update update-prs --policy-rules "icmpallow-pr tcpallow-pr"
}





function dynamicinsertion()
{
    if [ "$dynamic" == "fw-lb" ]
    then
        echo -e "PRS update for fw-lb sequentially"
        update
    fi

    if [ "$dynamic" == "fw" ]
    then
        echo -e "PRS update for fw sequentially"
        gbp policy-target-group-update db --provided-policy-rule-sets=tcp-prs
    fi
}


function pre_create()
{
    node_name=$(gbp servicechain-node-list |grep -w lb-node |awk '{print $4}')
    if [ "$node_name" == "lb-node" ]
    then
        echo -e "Delete previos resources which you created last time in this tenant ."
    else
        gbp servicechain-node-create --service-profile $fw_prof --template-file $PWD/fw.template fw-node
        gbp servicechain-node-create --service-profile $lb_prof --template-file $PWD/lb.template lb-node
        gbp servicechain-spec-create lb-spec --nodes  "lb-node"
        gbp servicechain-spec-create fw-spec --nodes  "fw-node"
        gbp servicechain-spec-create fw-lb-spec --nodes  "fw-node lb-node"
        gbp policy-action-create lb-redirect --action-type redirect --action-value lb-spec
        gbp policy-action-create fw-redirect --action-type redirect --action-value fw-spec
        gbp policy-action-create fw-lb-redirect --action-type redirect --action-value fw-lb-spec
        gbp policy-action-create allow --action-type allow
        gbp policy-classifier-create http-classifier --protocol tcp --port-range 80 --direction bi
        gbp policy-classifier-create tcp-classifier --protocol tcp  --direction bi
        gbp policy-classifier-create icmp-classifier --protocol icmp  --direction bi
        gbp policy-rule-create http-pr --classifier http-classifier --actions lb-redirect 
        gbp policy-rule-create tcp-pr --classifier tcp-classifier --actions fw-redirect
        gbp policy-rule-create update-pr --classifier http-classifier --actions fw-lb-redirect
        gbp policy-rule-create icmpallow-pr --classifier icmp-classifier --actions allow
        gbp policy-rule-create tcpallow-pr --classifier tcp-classifier --actions allow
        gbp policy-rule-set-create http-prs --policy-rules "http-pr"
        gbp policy-rule-set-create tcp-prs --policy-rules "tcp-pr"
        gbp policy-rule-set-create update-prs --policy-rules "icmpallow-pr tcpallow-pr"
        gbp network-service-policy-create lb-nsp --network-service-params "type=ip_single,name=vip_ip,value=self_subnet"
        gbp ptg-create db
        gbp ptg-create app --network-service-policy lb-nsp
        gbp ptg-create web   --network-service-policy lb-nsp
        #gbp policy-target-group-update db --provided-policy-rule-sets=tcp-prs
        gbp policy-target-group-update app --provided-policy-rule-sets=http-prs  --consumed-policy-rule-sets tcp-prs=None  #--network-service-policy lb-nsp
        gbp policy-target-group-update web --provided-policy-rule-sets=update-prs --consumed-policy-rule-sets http-prs=None #--network-service-policy lb-nsp
        gbp external-policy-create --external-segments $ext_segment  --consumed-policy-rule-sets update-prs=None  internet
        dynamicinsertion

        add_mem db 1
        add_mem app 2
        add_mem web 2
    fi
}

function cleanup()
{
    floatingipdisasso $1
    del_mem db 1
    del_mem app 2
    del_mem web 2
    gbp policy-target-group-delete db 
    gbp policy-target-group-delete app 
    gbp policy-target-group-delete web
    gbp external-policy-delete internet
    gbp policy-rule-set-delete http-prs
    gbp policy-rule-set-delete tcp-prs 
    gbp policy-rule-set-delete update-prs
    gbp policy-rule-delete http-pr 
    gbp policy-rule-delete tcp-pr
    gbp policy-rule-delete update-pr  
    gbp policy-rule-delete icmpallow-pr
    gbp policy-rule-delete tcpallow-pr 
    gbp policy-classifier-delete http-classifier
    gbp policy-classifier-delete tcp-classifier
    gbp policy-classifier-delete icmp-classifier 
    gbp policy-action-delete lb-redirect
    gbp policy-action-delete fw-redirect
    gbp policy-action-delete fw-lb-redirect
    gbp policy-action-delete allow 
    gbp servicechain-spec-delete lb-spec 
    gbp servicechain-spec-delete fw-spec
    gbp servicechain-spec-delete fw-lb-spec
    gbp servicechain-node-delete fw-node
    gbp servicechain-node-delete lb-node
}

