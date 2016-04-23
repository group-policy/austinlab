#!/bin/bash
echo -e "Enter number of tenant which u created last time "
read n

unset OS_PROJECT_NAME
unset OS_USER_DOMAIN_NAME
unset OS_IDENTITY_API_VERSION
unset OS_PROJECT_DOMAIN_NAME
unset OS_USERNAME
unset OS_TENANT_NAME
source $PWD/keystone_identity_v3

for (( i=1; i<=$n; i++ ))
do
openstack user delete mem$i
openstack project delete mem$i
done
rm -rf $PWD/keystone_directory

