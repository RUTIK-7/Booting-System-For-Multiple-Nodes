
#!/bin/bash

function loading_icon(){
  count=0
  total=34
  #pstr="[=======================================================================]"
   pstr="[***********************************************************************]"
  com=$1
  echo "$1"
  while [ $count -lt $total ]; do
    sleep 0.3
    count=$(( $count + 1 ))
    pd=$(( $count * 73 / $total ))
    printf "\r%3d.%1d%% %.${pd}s" $(( $count * 100 / $total )) $(( ($count * 1000 / $total) % 10 )) $pstr
  done
}

#--------------------------------------------------------------------------------------------------
# $1 adapter-- ens number 
# $2 password --- user password
# $3 mac_c-- mac_file

num_computes=$3

#--------------------------------------------------------------------------------------------------
loading_icon "========================================= Creating Ens.port =============================================="
echo -e "TYPE=Ethernet\nPROXY_METHOD=none\nBROWSER_ONLY=no\nBOOTPROTO=none\nDEFROUTE=yes\nIPV4_FAILURE_FATAL=no\nIPV6INIT=yes\nIPV6_AUTOCONF=yes\nIPV6_DEFROUTE=yes\nIPV6_FAILURE_FATAL=no\nIPV6_ADDR_GEN_MODE=stable-privacy\nNAME=ens$1\nUUID=6925de50-efdc-4dd7-92eb-4683f2c649e4\nDEVICE=ens$1\nONBOOT=yes\nIPADDR=192.168.1.1\nPREFIX=24\nIPV6_PRIVACY=no" > /etc/sysconfig/network-scripts/ifcfg-ens$1
systemctl restart network

loading_icon "========================================= Hostname ========================================="
hostnamectl set-hostname master.demo.lab
hostname

loading_icon "========================================= Firewalld ========================================="
systemctl stop firewalld
systemctl disable firewalld

loading_icon "========================================= Selinux ========================================="
echo -e "SELINUX=disabled\nSELINUXTYPE=targeted" > /etc/selinux/config
setenforce 0

echo 0 > /sys/fs/selinux/enforce
#------------------
loading_icon "========================================= Install Utils ========================================="
yum -y install yum-utils

loading_icon "========================================= wget xcat repo ========================================="
wget -P /etc/yum.repos.d https://xcat.org/files/xcat/repos/yum/latest/xcat-core/xcat-core.repo --no-check-certificate
wget -P /etc/yum.repos.d https://xcat.org/files/xcat/repos/yum/xcat-dep/rh7/x86_64/xcat-dep.repo --no-check-certificate

loading_icon "========================================= Install xCAT ========================================="
yum -y install xCAT
. /etc/profile.d/xcat.sh

loading_icon "========================================= IP Config ========================================="
ifconfig ens$1 192.168.1.1 netmask 255.255.255.0 up
chdef -t site dhcpinterfaces="xcatmn|ens$1"
#read -p "Enter the Abosulute path of ISO image" iso_image
#copycds $iso_image
copycds osimage/CentOS-7-x86_64-DVD-2009.iso


loading_icon "========================================= Giving IPs ========================================="
for ((i=0 ; i < $num_computes ; i++));
do
  n=$(($i+1))
  mkdef -t node cn$i groups=compute,all ip=$(head -$n ip_file | tail -1) mac=$(head -$n mac_file | tail -1) netboot=xnba arch=x86_64
done

loading_icon "========================================= Creating user ========================================="
chtab key=system passwd.username=root passwd.password=$2
chdef-t site domain="master.demo.lab"

loading_icon "========================================= Making services ========================================="
makehosts
makenetworks
makedhcp -n
makedns -n

loading_icon "========================================= Nodeset ========================================="
echo "osimages....."
echo "$(lsdef -t osimage)" > osfile
osi=$(head -1 osfile | tail -1 | cut -d " " -f 1)
nodeset compute osimage=$osi
