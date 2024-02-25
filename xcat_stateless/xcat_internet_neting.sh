#!/bin/bash

# $1 --mac_c --mac_file
# $2 -- comnpute node adapter 

for ((i=0 ; i < $1 ; i++));
do
    a=$(($i+1))
    echo "Configuring network port in c$a"
    n=$(head -$a ip_file | tail -1)
    ssh $n '''echo -e "TYPE=Ethernet\nPROXY_METHOD=none\nBROWSER_ONLY=no\nIPADDR=$n\nPREFIX=24\nGATEWAY=192.168.1.1\nDNS1=192.168.1.1\nDEFROUTE=yes\nIPV4_FAILURE_FATAL=no\nIPV6_AUTOCONF=yes\nIPV6_DEFROUTE=yes\nIPV6_FAILURE_FATAL=no\nNAME="System ens$2"" >> /etc/sysconfig/network-scripts/ifcfg-ens$2'''
    ssh $n "systemctl restart NetworkManager"
    ssh $n "systemctl restart network"
done

yum -y install iptables-services
iptables -A INPUT -s 192.168.1.0/24 -p tcp --dport=80 -j ACCEPT
iptables -P INPUT ACCEPT
iptables -t nat -A POSTROUTING -s 192.168.1.0/24 -o ens$2 -j MASQUERADE