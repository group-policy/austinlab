#!/usr/bin/python
import thread
import os
import sys
import time
# Define a function for the thread
def update_prs( operation, keystone, index):
    path=os.getenv("PWD")
    os.environ["keyenv"] = keystone
    key=os.getenv("keyenv")
    command1="source  " + path +"/keystone_directory/" +keystone 
    command="bash  " + path + "/parallel.sh  " + operation + " " + keystone + " " +str(index)
    print command
    os.system(command)


def insert_servicefwlb( operation, flag, prefix, index, keystone ):
    name = prefix+str(index)+"fwlb"
    command = "bash $PWD/parallel.sh "+ operation + " " +  flag + " " +"fw-lb " + name + " " + keystone
    print command
    os.system(command)


def threadcall( n, slot, operation ):
    count = 1
    index = 1
    while ( count <= int(n) ):
	slot_count = 1
	while ( slot_count <= int(slot) ):
	   key = "keystone-mem"+str(index)
           thread.start_new_thread( update_prs, (operation, key, index ) )
           #thread.start_new_thread( insert_servicefwlb, (operation, flag, prefix, index, key, ) )
	   index = index + 1
	   slot_count = slot_count + 1
        print (time.strftime("%H:%M:%S"))
        time.sleep(3)
        print (time.strftime("%H:%M:%S"))
	count = count + int(slot)
threadcall(sys.argv[1], sys.argv[2], sys.argv[3] )
