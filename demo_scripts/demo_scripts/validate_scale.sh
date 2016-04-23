#!/bin/bash
source $PWD/keystone_identity_v3
rm -rf /tmp/projectid.txt
openstack project list |grep mem |awk '{print $2}' >>/tmp/projectid.txt
function usage(){
echo "[Usage <arguments>: #1.create/update/delete #2. fw for firewall chain or lb for haproxy service chain #3. lb for  haproxy service chain]"
echo -e "Arg 1 : create or delete\nArg 2 : fw/lb \nArg 3: lb "


}

if [ $# -lt 2 ]
then
usage
exit
fi


if [ "$1" != "create" -a "$1" != "delete" -a "$1" != "update" ]
then
    echo -e "Invalid argument : $1\n"
    usage
    exit
fi


function fwpolicy()
{
rm -rf /tmp/fwpolicyid.txt
tenantfile=/tmp/projectid.txt
while read -r tenant_id
do
mysql --database neutron -e "select id from firewall_policies where tenant_id='$tenant_id';" |grep -v id |wc -l >>/tmp/fwpolicyid.txt
done < "$tenantfile"
#cat /tmp/fwpolicyid.txt
}

function lbvip()
{
rm -rf /tmp/lbvip.txt
tenantfile=/tmp/projectid.txt
while read -r tenant_id
do
mysql --database neutron -e "select id from vips where tenant_id='$tenant_id';" |grep -v id |wc -l >>/tmp/lbvip.txt
done < "$tenantfile"
#cat /tmp/lbvip.txt
}

function scalevalidate()
{
fwcount=/tmp/fwpolicyid.txt

if [ "$1" == "fw" ]
then
count=1
while read -r fwp
do
if [ "$fwp" != "$3" ]
then
id=$(sed -n "$count p" /tmp/projectid.txt)
name=$(openstack project show $id |grep name |awk '{print $4}')

echo -e "fw service not  got inserted during group  or prs update in " $name " tenant id is " $id
fi
count=$[$count +1]
done < "$fwcount"

fi
if [ "$2" == "lb" ]
then
echo -e "first" $1 "second" $2 "third" $3
vipcount=/tmp/lbvip.txt
count=1
while read -r vip
do
if [ "$vip" != "$3" ]
then
id=$(sed -n "$count p" /tmp/projectid.txt)

name=$(openstack project show $id |grep name |awk '{print $4}')

echo -e  "lb service not  got inserted during   group or prs update in " $name " tenant id is " $id
fi
count=$[$count +1]
done < "$vipcount"
fi

}
fwpolicy
lbvip

if [ "$#" ==  "3" ]
then
if [ "$1" == "create" ]
then
scalevalidate $2 $3 1
fi
if [ "$1" == "update" ]
then
scalevalidate $2 $3 2
fi
if [ "$1" == "delete" ]
then
scalevalidate $2 $3 0
fi
fi

if [ "$#" ==  "2" ]
then
if [ "$2" == "fw" ]
then
a="oc "
if [ "$1" == "create" ]
then
echo -e "create"
scalevalidate $2 $a 1
fi 
if [ "$1" == "update" ]
then
echo -e "update"
scalevalidate $2 $a 2
fi 
if [ "$1" == "delete" ]
then
echo -e "delete"
scalevalidate $2 $a 0
fi
fi
fi
if [ "$#" ==  "2" ]
then
if [ "$2" == "lb" ]
then
a=$2
b="oc"
if [ "$1" == "create" ]
then
echo -e "create"
scalevalidate $b $a  1
fi 
if [ "$1" == "update" ]
then
echo-e "update"
scalevalidate $b $a 2
fi 
if [ "$1" == "delete" ]
then
echo -e "delete"
scalevalidate $b $a 0
fi
fi
fi
