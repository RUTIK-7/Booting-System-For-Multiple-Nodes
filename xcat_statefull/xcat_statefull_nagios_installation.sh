#!/bin/bash

# $1---mac_file
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


yum -y install http://build.openhpc.community/OpenHPC:/1.3/CentOS_7/x86_64/ohpc-release-1.3-1.el7.x86_64.rpm

for ((i=0 ; i < $1 ; i++));
do
    a=$(($i+1))
    echo "Installing OpenHPC in c$a"
    n=$(head -$a ip_file | tail -1)
    ssh $n '''yum -y install http://build.openhpc.community/OpenHPC:/1.3/CentOS_7/x86_64/ohpc-release-1.3-1.el7.x86_64.rpm'''
done

yum -y install epel-release
yum -y install ohpc-base

systemctl enable ntpd.service
echo "server 192.168.1.1 iburst" >> /etc/ntp.conf
systemctl restart ntpd && systemctl status ntpd

echo "server 192.168.1.1 iburst" >> /etc/chrony.conf
echo "local stratum 10" >> /etc/chrony.conf
systemctl start chronyd.service && systemctl status chronyd.service


echo "##################################### Nagios installtion ##########################################"
yum -y install ohpc-nagios

# Nodes
for ((i=0 ; i < $1 ; i++));
do
    a=$(($i+1))
    echo "Configuring Nagios in compute c$a"
    n=$(head -$a ip_file | tail -1)
    ssh $n '''yum -y install nagios-plugins-all-ohpc nrpe-ohpc --skip-broken'''

    # Configure NRPE in compute image
    ssh $n '''systemctl enable nrpe'''
    ssh $n '''systemctl start nrpe'''
    ssh $n '''perl -pi -e "s/^allowed_hosts=/# allowed_hosts=/"  /etc/nagios/nrpe.cfg '''

    ssh $n '''perl -pi -e "s/pid_file=\S+/pid_file=\/var\/run\/nrpe\/nrpe.pid/" /etc/nagios/nrpe.cfg'''

    ssh $n '''echo "nrpe 5666/tcp #NRPE" >> /etc/services'''
    ssh $n '''echo "nrpe: 192.168.1.1 : ALLOW" >> /etc/hosts.allow'''
    ssh $n '''echo "nrpe : ALL : DENY" >> /etc/hosts.allow'''

    # check-ssh for hosts
    ssh $n '''echo command[check_ssh]=/usr/lib64/nagios/plugins/check_ssh localhost >> /etc/nagios/nrpe.cfg'''
done

# Remote services
mv /etc/nagios/conf.d/services.cfg.example /etc/nagios/conf.d/services.cfg

# Adding nodes name and ip-address in /etc/nagios/conf.d/hosts.cfg(path)
echo '''## Linux Host Template ##
define host{
        name linux-box ; Name of this template
        use generic-host ; Inherit default values
        check_period 24x7
        check_interval 5
        retry_interval 1
        max_check_attempts 10
        check_command check-host-alive
        notification_period 24x7
        notification_interval 30
        notification_options d,r
        contact_groups admins
        register 0 ; DONT REGISTER THIS - ITS A TEMPLATE
}

define hostgroup {
        hostgroup_name compute
        alias compute nodes
        members 
} 
# example configuration of 4 remote linux systems
''' > /etc/nagios/conf.d/hosts.cfg

for ((i=0 ; i < $1 ; i++));
do
  n=$(($i+1))
  echo -n "c$n," >> nodenames
done

perl -pi -e "s/members /members $(cat nodenames)/" /etc/nagios/conf.d/hosts.cfg

for ((i=0 ; i < $1 ; i++));
do
  n=$(($i+1))
  echo -e "\ndefine host {\n use linux-box\n host_name c$n\n alias c$n\n address $(head -$n ip_file | tail -1)   ; IP address of Remote Linux host\n}"  >> /etc/nagios/conf.d/hosts.cfg
done

# location of mail for alert 
perl -pi -e "s/ \/bin\/mail/ \/usr\/bin\/mailx/g" /etc/nagios/objects/commands.cfg

#update email address
perl -pi -e "s/nagios\@localhost/root\hpcsa887@gmail.com/" /etc/nagios/objects/contacts.cfg

# Setting Passwords
htpasswd -bc /etc/nagios/passwd nagiosadmin "root"

# Configureing nagios on master
chkconfig nagios on
systemctl start nagios
systemctl status nagios
chmod u+s `which ping`

for ((i=0 ; i < $1 ; i++));
do
    a=$(($i+1))
    echo "Configuring Nagios in compute c$a"
    n=$(head -$a ip_file | tail -1)
    ssh $n systemctl restart nrpe
# UserName = nagiosadmin 
#password = root
# ---------------------------------------------------------------------------------------------------------

