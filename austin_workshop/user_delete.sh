#!/bin/bash
echo -e "Tenant and user delete"
echo -e "Make sure you  deleted all non shared gbp resources from all tenants , which are you going to delete.Press Y for Yes and N  for NO "
read flag
if [ "$flag" != "Y" -a "$flag" != "N"  ]
then
    echo -e "Invalid argument : $1\n"
    exit
fi
if [ "$flag" == "Y" ]
then
    echo -e "Enter number of tenant which u created last time "
    read n
    echo -e "Tenant deletion started"
    unset OS_PROJECT_NAME
    unset OS_USER_DOMAIN_NAME
    unset OS_IDENTITY_API_VERSION
    unset OS_PROJECT_DOMAIN_NAME
    unset OS_USERNAME
    unset OS_TENANT_NAME
    source $PWD/keystone_identity_v3
    ten_count=1000

    for (( i=1; i<=$n; i++ ))
    do
        openstack user delete TENANT$ten_count
        openstack project delete TENANT$ten_count
        ten_count=`expr $ten_count + 17`
    done
    rm -rf $PWD/keystone_directory
fi
if [ "$flag" == "N" ]
then
    echo -e "ok"
fi

