#!/bin/bash

function parallel()
{
total=$1
slot=$2
if [ "$operation" ==  "create" ]
then
for ((i=1; i<=total; i++)); do
for ((j=1; j<=slot; j++)); do
source $PWD/keystone_directory/keystone-mem$i
bash $PWD/parallel.sh  $3 $i
done
done
fi
if [ "$operation" !=  "create" ]
then 
python $PWD/thread.py $1 $2 $operation
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
for ((i=1; i<=upperlim; i++)); do
p="mem$i"

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
done

unset OS_USER_DOMAIN_NAME
unset OS_IDENTITY_API_VERSION
unset OS_DOMAIN_NAME
unset OS_USERNAME
unset OS_PASSWORD
unset OS_AUTH_URL
unset OS_REGION_NAME

parallel $n $slot $operation
fi
if [ "$operation" == "update" ]
then
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

tenant_create
