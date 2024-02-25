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
num_computes=$3
#--------------------

# $1-- adapter --- ens port
# $2-- password --- user password
# $3-- mac_c -- mac_file
# $4-- nfs 
loading_icon " ======================= CREATING ENS. PORT =======================   "

echo -e "TYPE=Ethernet\nPROXY_METHOD=none\nBROWSER_ONLY=no\nBOOTPROTO=none\nDEFROUTE=yes\nIPV4_FAILURE_FATAL=no\nIPV6INIT=yes\nIPV6_AUTOCONF=yes\nIPV6_DEFROUTE=yes\nIPV6_FAILURE_FATAL=no\nIPV6_ADDR_GEN_MODE=stable-privacy\nNAME=ens$1\nUUID=6925de50-efdc-4dd7-92eb-4683f2c649e4\nDEVICE=ens$1\nONBOOT=yes\nIPADDR=192.168.1.1\nPREFIX=24\nIPV6_PRIVACY=no" > /etc/sysconfig/network-scripts/ifcfg-ens$1
systemctl restart network

loading_icon " ========================= HOSTNAME ======================= "
hostnamectl set-hostname master.demo.lab
hostname

loading_icon " =================== FIREWALL ======================= "
systemctl stop firewalld
systemctl disable firewalld

loading_icon " =================== SELINUX  ======================= "
echo -e "SELINUX=disabled\nSELINUXTYPE=targeted" > /etc/selinux/config
setenforce 0

echo 0 > /sys/fs/selinux/enforce

#------------------

loading_icon " ======================= INSTALL FORM HTTP RMP FILE  ======================= "
yum -y install http://build.openhpc.community/OpenHPC:/1.3/CentOS_7/x86_64/ohpc-release-1.3-1.el7.x86_64.rpm

loading_icon " ======================= INSTALLING YUM-UTILS =======================  "
yum -y install yum-utils

loading_icon " ======================== CERTIFICATES ======================= "
wget -P /etc/yum.repos.d https://xcat.org/files/xcat/repos/yum/latest/xcat-core/xcat-core.repo --no-check-certificate
wget -P /etc/yum.repos.d https://xcat.org/files/xcat/repos/yum/xcat-dep/rh7/x86_64/xcat-dep.repo --no-check-certificate

loading_icon  " =================INSTALL OHPC=====================   "
yum -y install ohpc-base 
loading_icon  " ========================== INSTALL XCAT =======================  "
yum -y install xCAT
loading_icon " ====================== EXECUTE XCAT SCRIPT ===================== "
. /etc/profile.d/xcat.sh

loading_icon " ==================== RUNNING NTPD.SERVICE ======================= "
systemctl enable ntpd.service
echo "server 192.168.1.1 iburst" >> /etc/ntp.conf

echo "server 192.168.1.1 iburst" >> /etc/chrony.conf
echo "local stratum 10" >> /etc/chrony.conf
systemctl restart ntpd
systemctl start chronyd.service

loading_icon " ========================= COPY ISO IMAGE ===================  "
copycds osimage/CentOS-7-x86_64-DVD-2009.iso
#copycds osimage/$(ls osimage | cut -d " " -f 1 | head -$3 | tail -1 )

loading_icon " ==================== EXPORTING IMAGE ==================== "
export CHROOT=/install/netboot/centos7.9/x86_64/compute/rootimg

loading_icon " ===================== SET UP YOUR PASSWORD ====================== "
chtab key=system passwd.username=root passwd.password=$2

loading_icon "================= GENERTAE ISO IMAGE  ================= "
echo "osimages....."                                             #genimage
echo "$(lsdef -t osimage)" > osfile
osi=$(head -2 osfile | tail -1 | cut -d " " -f 1)
genimage $osi

echo "----------------------------------------------------------------------------------------------------------"
loading_icon "================= DOWNLOADINF BASE COMPONENTS  ================= "
# Adding OpenHPC Componentes
yum-config-manager --installroot=$CHROOT --enable base
cp /etc/yum.repos.d/OpenHPC.repo $CHROOT/etc/yum.repos.d
cp /etc/yum.repos.d/epel.repo $CHROOT/etc/yum.repos.d

# Adding OpenHPC in nodes
cp /etc/yum.repos.d/OpenHPC.repo $CHROOT/etc/yum.repos.d
yum -y --installroot=$CHROOT install perl
yum -y --installroot=$CHROOT install ohpc-base-compute --skip-broken
yum -y --installroot=$CHROOT install ntp kernel lmod-ohpc

# Mounting /home and /opt/ohpc/pub to image om nodes
echo "192.168.1.1:/home /home nfs defaults 0 0" >> $CHROOT/etc/fstab
echo "192.168.1.1:/opt/ohpc/pub /opt/ohpc/pub nfs defaults 0 0" >> $CHROOT/etc/fstab

# Exporting /home and /opt/ohpc/pub to image
echo "/home *(rw,no_subtree_check,fsid=10,no_root_squash)" >> /etc/exports
echo "/opt/ohpc/pub *(ro,no_subtree_check,fsid=11)" >> /etc/exports

loading_icon " ========================= NFS CONFIGURE ========================= "
if [ $4 == 'y' ] || [ $4 == 'yes' ];
then
  # Common HardDisk using NFS '/nfs' mounted disk for all compute nodes
  echo "192.168.1.1:/nfs /nfs nfs defaults 0 0" >> $CHROOT/etc/fstab
  echo "/nfs *(rw,sync,no_root_squash,no_subtree_check)" >> /etc/exports
fi

exportfs -a
systemctl restart nfs-server && systemctl enable nfs-server && systemctl status nfs-server

# NTP time service on computes
chroot $CHROOT systemctl enable ntpd
echo "server 192.168.1.1" >> $CHROOT/etc/ntp.conf

loading_icon " ======================== Slurm_Installation_Process =========================== "
# Munge configureation
export MUNGEUSER=991
groupadd -g $MUNGEUSER munge
useradd  -m -c "MUNGE Uid 'N' Gid Emporium" -d /var/lib/munge -u $MUNGEUSER -g munge  -s /sbin/nologin munge
export SLURMUSER=992
groupadd -g $SLURMUSER slurm
useradd  -m -c "SLURM workload manager" -d /var/lib/slurm -u $SLURMUSER -g slurm  -s /bin/bash slurm

loading_icon " ============================ INSTALLING MUNGE SERVICE ============================ "
yum install epel-release munge munge-libs munge-devel -y
yum -y --installroot=$CHROOT install epel-release munge munge-libs munge-devel

yum install rng-tools -y
rngd -r /dev/urandom
/usr/sbin/create-munge-key -r
dd if=/dev/urandom bs=1 count=1024 > /etc/munge/munge.key
chown munge:munge /etc/munge/munge.key
chmod 400 /etc/munge/munge.key
touch /var/log/munge/munged.log
chown -R munge:munge /etc/munge/ /var/log/munge/
chmod 0700 /etc/munge/ /var/log/munge/

cp /etc/munge/munge.key $CHROOT/etc/munge
cp /var/log/munge/munged.log $CHROOT/var/log/munge/
chown -R munge:munge $CHROOT/etc/munge/ $CHROOT/var/log/munge/
chown -R munge:munge $CHROOT/var/log/munge
chown -R munge:munge $CHROOT/var/lib/munge
chown -R munge:munge $CHROOT/etc/munge/

systemctl enable munge && systemctl start munge
chroot $CHROOT systemctl enable munge
#Test munge.
munge -n
munge -n | munge

loading_icon " ======================== Slurm confirigation ======================== "

yum install openssl openssl-devel pam-devel numactl numactl-devel hwloc hwloc-devel lua lua-devel readline-devel rrdtool-devel ncurses-devel man2html libibmad libibumad gcc mariadb-server mariadb-devel -y

wget -P /opt https://download.schedmd.com/slurm/slurm-21.08.8.tar.bz2

yum -y install rpm-build
rpmbuild -ta /opt/slurm-21.08.8.tar.bz2

# For Master
cd /root/rpmbuild/RPMS/x86_64/ && yum -y --nogpgcheck localinstall * && cd -

# For Nodes
yum -y --installroot=$CHROOT install rpm-build
cp -r /root/rpmbuild $CHROOT/
cd $CHROOT/rpmbuild/RPMS/x86_64/ && yum -y --installroot=$CHROOT --nogpgcheck localinstall * && cd -

#Edit the slurm.conf file
cp /etc/slurm/slurm.conf.example /etc/slurm/slurm.conf
perl -pi -e "s/SlurmctldHost=\S+/SlurmctldHost=master.demo.lab/" /etc/slurm/slurm.conf
perl -pi -e "s/SlurmUser=\S+/SlurmUser=root/" /etc/slurm/slurm.conf
perl -pi -e "s/#SlurmdUser=root/SlurmdUser=root/" /etc/slurm/slurm.conf
perl -pi -e "s/NodeName=linux\[1-32\] CPUs=1 State=UNKNOWN/NodeName=c\[1-2\] CPUs=1 State=UNKNOWN/" /etc/slurm/slurm.conf

cp /etc/slurm/cgroup.conf.example /etc/slurm/cgroup.conf

# Database conf.
cp /etc/slurm/slurmdbd.conf.example /etc/slurm/slurmdbd.conf
perl -pi -e "s/StoragePass=\S+/#StoragePass=/" /etc/slurm/slurmdbd.conf
perl -pi -e "s/StorageUser=\S+/StorageUser=root/" /etc/slurm/slurmdbd.conf
perl -pi -e "s/#StorageLoc=\S+/StorageLoc=slurm_acct_db/" /etc/slurm/slurmdbd.conf
perl -pi -e "s/SlurmUser=\S+/SlurmUser=root/" /etc/slurm/slurmdbd.conf

#node
cp /etc/slurm/slurm.conf $CHROOT/etc/slurm/
cp /etc/slurm/cgroup.conf $CHROOT/etc/slurm/
echo "/etc/slurm/slurm.conf -> /etc/slurm/slurm.conf " >> /install/custom/netboot/compute.synclist
echo "/etc/munge/munge.key -> /etc/munge/munge.key " >> /install/custom/netboot/compute.synclist
chroot $CHROOT systemctl enable slurmd.service

#master
mkdir /var/spool/slurm
chown root: /var/spool/slurm/
chmod 755 /var/spool/slurm/
touch /var/log/slurmctld.log
chown root: /var/log/slurmctld.log
touch /var/log/slurm_jobacct.log
chown root: /var/log/slurm_jobacct.log

#nodes
mkdir $CHROOT/var/spool/slurm
chown root: $CHROOT/var/spool/slurm
chmod 755 $CHROOT/var/spool/slurm
mkdir $CHROOT/var/log/slurm
touch $CHROOT/var/log/slurm/slurmd.log
chown root: $CHROOT/var/log/slurm/slurmd.log

chroot $CHROOT systemctl start slurmd.service

# mysql database
systemctl enable mariadb
systemctl start mariadb
systemctl status mariadb

mysql -e "CREATE DATABASE slurm_acct_db"

# Changinf ownership
chown root: /etc/slurm/slurmdbd.conf
chmod 600 /etc/slurm/slurmdbd.conf
touch /var/log/slurmdbd.log
chown root: /var/log/slurmdbd.log

#Slurmdbd service
systemctl enable slurmdbd
systemctl start slurmdbd
systemctl status slurmdbd

# Slurmctld service
systemctl enable slurmctld.service
systemctl start slurmctld.service
systemctl status slurmctld.service

#----------------------------------------------------------------------------------------------------------------------------------------------

loading_icon " ======================= Nagios installtion ============================= "
yum -y install ohpc-nagios
yum -y --installroot=$CHROOT install nagios-plugins-all-ohpc nrpe-ohpc --skip-broken

# Configure NRPE in compute image
chroot $CHROOT systemctl enable nrpe
perl -pi -e "s/^allowed_hosts=/# allowed_hosts=/" $CHROOT/etc/nagios/nrpe.cfg

perl -pi -e "s/pid_file=\S+/pid_file=\/var\/run\/nrpe\/nrpe.pid/ " $CHROOT/etc/nagios/nrpe.cfg

echo "nrpe 5666/tcp #NRPE" >> $CHROOT/etc/services
echo "nrpe: 192.168.1.1 : ALLOW" >> $CHROOT/etc/hosts.allow
echo "nrpe : ALL : DENY" >> $CHROOT/etc/hosts.allow
chroot $CHROOT /usr/sbin/useradd -c "NRPEuserfortheNRPEservice" -d /var/run/nrpe -r -g nrpe -s /sbin/nologin nrpe
chroot $CHROOT /usr/sbin/groupadd -r nrpe

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

for ((i=0 ; i < $num_computes ; i++));
do
  n=$(($i+1))
  echo -n "c$n," >> nodenames
done

perl -pi -e "s/members /members $(cat nodenames)/" /etc/nagios/conf.d/hosts.cfg

for ((i=0 ; i < $num_computes ; i++));
do
  n=$(($i+1))
  echo -e "\ndefine host {\n use linux-box\n host_name c$n\n alias c$n\n address $(head -$n ip_file | tail -1)   ; IP address of Remote Linux host\n}"  >> /etc/nagios/conf.d/hosts.cfg
done

# location of mail for alert 
perl -pi -e "s/ \/bin\/mail/ \/usr\/bin\/mailx/g" /etc/nagios/objects/commands.cfg

#update email address
perl -pi -e "s/nagios\@localhost/root\@master.demo.lab/" /etc/nagios/objects/contacts.cfg

# check-ssh for hosts
echo command[check_ssh]=/usr/lib64/nagios/plugins/check_ssh localhost  >> $CHROOT/etc/nagios/nrpe.cfg

# Setting Passwords
htpasswd -bc /etc/nagios/passwd nagiosadmin "root"

# Configureing nagios on master
chkconfig nagios on
systemctl start nagios
systemctl status nagios
chmod u+s `which ping`
# UserName = nagiosadmin 
# ---------------------------------------------------------------------------------------------------------

# Path for xCAT synclist 
mkdir -p /install/custom/netboot
chdef -t osimage -o centos7.9-x86_64-netboot-compute synclists="/install/custom/netboot/compute.synclist"

# credential files
echo "/etc/passwd -> /etc/passwd" > /install/custom/netboot/compute.synclist
echo "/etc/group -> /etc/group" >> /install/custom/netboot/compute.synclist
echo "/etc/shadow -> /etc/shadow" >> /install/custom/netboot/compute.synclist

loading_icon "================================== Createing node ====================================="

for ((i=0 ; i < $num_computes ; i++));
do
  n=$(($i+1))
  mkdef -t node c$n groups=compute,all ip=$(head -$n ip_file | tail -1) mac=$(head -$n mac_file | tail -1) netboot=xnba arch=x86_64
done

chdef -t site domain="master.demo.lab"
chdef -t site master="192.168.1.1"
chdef -t site forwarders="192.168.1.1"
chdef -t site nameservces="192.168.1.1"
chtab key=system passwd.username=root passwd.password=root

loading_icon " ======== PACK-IMAGE =============== "
packimage $osi

loading_icon "================== RUNNING MAKE COMMAND ===============  "
makehosts
makenetworks
makedhcp -n
makedhcp -a
makedns -n
makedns -a

xcatprobe xcatmn -i ens$1
sleep 5

loading_icon "============ NODESET ============"
nodeset compute osimage=$osi

echo "----- FOR NAGIOS MONITORING TOOL ------"
echo " OPEN BROWSER SEARCH "
echo " USERNAME --- nagiosadmin "
echo "PASSWORD --- root "
echo "http://loaclhost/nagios"