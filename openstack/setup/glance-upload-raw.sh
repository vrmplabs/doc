#!/bin/bash

# Import Settings
. settings

if [ ! -f $1 ] ; then
	echo "can not find the image"
	exit 1
fi


export OS_TENANT_NAME=$SERVICE_TENANT_NAME
export OS_USERNAME=glance
export OS_PASSWORD=$SERVICE_PASSWORD
export OS_AUTH_URL='http://'$KEYSTONE_IP':5000/v2.0/'
export OS_REGION_NAME=RegionOne
#export | grep OS_

echo "Uploading raw image"
glance add name="CentOS6.2-64" is_public=true container_format=bare disk_format=raw < $1 


#TOKEN=`./obtain-token.sh`
#echo "Uploading kernel"
#RVAL=`glance add name="ttylinux-kernel" is_public=true container_format=aki disk_format=aki < ttylinux-uec-amd64-12.1_2.6.35-22_1-vmlinuz`
#KERNEL_ID=`echo $RVAL | cut -d":" -f2 | tr -d " "`
#
#echo "Uploading ramdisk"
#RVAL=`glance add name="ttylinux-ramdisk" is_public=true container_format=ari disk_format=ari < ttylinux-uec-amd64-12.1_2.6.35-22_1-initrd`
#RAMDISK_ID=`echo $RVAL | cut -d":" -f2 | tr -d " "`
#
#echo "Uploading image"
#glance add name="ttylinux" is_public=true container_format=ami disk_format=ami kernel_id=$KERNEL_ID ramdisk_id=$RAMDISK_ID < ttylinux-uec-amd64-12.1_2.6.35-22_1.img
