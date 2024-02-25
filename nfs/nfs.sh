#!/bin/bash
printf 'n\np\n\n\n\nw' | fdisk /dev/sdb
mkfs.ext4 /dev/sdb1
mkdir /nfs
mount /dev/sdb1 /nfs && echo $?
df -Th