#!/bin/bash
# $1--mac_c ---mac_file
echo "##################################### Slurm installtion ##########################################"
# Munge configureation
export MUNGEUSER=991
groupadd -g $MUNGEUSER munge
useradd  -m -c "MUNGE Uid 'N' Gid Emporium" -d /var/lib/munge -u $MUNGEUSER -g munge  -s /sbin/nologin munge
export SLURMUSER=992
groupadd -g $SLURMUSER slurm
useradd  -m -c "SLURM workload manager" -d /var/lib/slurm -u $SLURMUSER -g slurm  -s /bin/bash slurm

yum install epel-release munge munge-libs munge-devel -y
yum install rng-tools -y
rngd -r /dev/urandom
/usr/sbin/create-munge-key -r
dd if=/dev/urandom bs=1 count=1024 > /etc/munge/munge.key
chown munge:munge /etc/munge/munge.key
chmod 400 /etc/munge/munge.key
touch /var/log/munge/munged.log
chown -R munge:munge /etc/munge/ /var/log/munge/
chmod 0700 /etc/munge/ /var/log/munge/
systemctl enable munge && systemctl start munge

#Nodes
for ((i=0 ; i < $1 ; i++));
do
    a=$(($i+1))
    echo "Configuring munge in compute c$a"
    n=$(head -$a ip_file | tail -1)
    ssh $n '''yum -y install epel-release munge munge-libs munge-devel'''
    scp /etc/munge/munge.key root@$n:/etc/munge
    scp /var/log/munge/munged.log root@$n:/var/log/munge/
    ssh $n '''chown -R munge:munge /etc/munge/ /var/log/munge/'''
    ssh $n '''chown -R munge:munge /var/log/munge/'''
    ssh $n '''chown -R munge:munge /var/lib/munge/'''
    ssh $n '''chown -R munge:munge /etc/munge/'''
    ssh $n '''systemctl start munge && systemctl enable munge'''
done

echo "###################################### Slurm confirigation ############################"
yum -y install openssl openssl-devel pam-devel numactl numactl-devel hwloc hwloc-devel lua lua-devel readline-devel rrdtool-devel ncurses-devel man2html libibmad libibumad gcc mariadb-server mariadb-devel 
wget -P /opt https://download.schedmd.com/slurm/slurm-21.08.8.tar.bz2
yum -y install rpm-build
rpmbuild -ta /opt/slurm-21.08.8.tar.bz2

# For Master
yum -y install rpm-build
cd /root/rpmbuild/RPMS/x86_64/ && yum -y --nogpgcheck localinstall * && cd -

# For Nodes
for ((i=0 ; i < $1 ; i++));
do
    a=$(($i+1))
    echo "Configuring rebuild in compute c$a"
    n=$(head -$a ip_file | tail -1)
    ssh $n '''yum -y install rpm-build'''
    scp -r /root/rpmbuild root@$n:/
    ssh $n '''cd $CHROOT/rpmbuild/RPMS/x86_64/ && yum -y --nogpgcheck localinstall * && cd -'''
done

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
for ((i=0 ; i < $1 ; i++));
do
    a=$(($i+1))
    echo "Configuring slurm in compute c$a"
    n=$(head -$a ip_file | tail -1)
    scp /etc/slurm/slurm.conf root@$n:/etc/slurm/
    scp /etc/slurm/cgroup.conf root@$n:/etc/slurm/
    ssh $n '''systemctl enable slurmd.service'''
done

echo "/etc/slurm/slurm.conf -> /etc/slurm/slurm.conf " >> /install/custom/netboot/compute.synclist
echo "/etc/munge/munge.key -> /etc/munge/munge.key " >> /install/custom/netboot/compute.synclist

#master
mkdir /var/spool/slurm
chown root: /var/spool/slurm/
chmod 755 /var/spool/slurm/
touch /var/log/slurmctld.log
chown root: /var/log/slurmctld.log
touch /var/log/slurm_jobacct.log
chown root: /var/log/slurm_jobacct.log

echo "$(date | cut -d " " -f 4)" > date
current_date=$(date | cut -d " " -f 4)
#nodes
for ((i=0 ; i < $1 ; i++));
do
    a=$(($i+1))
    echo "Changing ownership in compute c$a"
    n=$(head -$a ip_file | tail -1)
    scp date root@$n:/root/
    ssh $n '''mkdir /var/spool/slurm'''
    ssh $n '''chown root: /var/spool/slurm'''
    ssh $n '''chmod 755 /var/spool/slurm'''
    ssh $n '''mkdir /var/log/slurm'''
    ssh $n '''touch /var/log/slurm/slurmd.log'''
    ssh $n '''chown root: /var/log/slurm/slurmd.log'''
    ssh $n '''systemctl start slurmd.service'''
    ssh $n '''date -s “$(cat date)”'''
done

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

#--------------------------------------------------------------------------------------------------------
