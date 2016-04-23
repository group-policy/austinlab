#!/bin/bash
source gbp_resource.sh
function usage(){
    echo "[Usage <arguments>: #1.create/update/delete#2. Source_file]"
    echo -e "Arg 1 : create or update or delete\nArg 2 : source file for your tenant "
}


#source source-mem14-delete
#source $PWD/keystone_directory/$2

if [ $# -lt 2 ] 
then
    usage
    exit
fi
# change the variable for north-south/east-west chain
if [ "$1" != "create" -a "$1" != "delete" -a "$1" != "update" ]
then
    echo -e "Invalid argument : $1\n"
    usage
    exit
fi
if [ $1 == "create" ]; then
    source $PWD/keystone_directory/$2
    pre_create $3
fi

if [ $1 == "delete" ]; then
    source $PWD/keystone_directory/$2
    cleanup $3
fi
if [ $1 == "update" ]; then
    source $PWD/keystone_directory/$2
    update $3
fi

