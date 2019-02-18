#!/bin/bash

# optionally set yumproxy and disable fastestmirror
echo "proxy = http://192.168.1.1:8123/" >>/etc/yum.conf
sed -i 's/^enabled=1/enabled=0/' /etc/yum/pluginconf.d/fastestmirror.conf

# required setup
setenforce 0
sed -i 's/^SELINUX=enabled/SELINUX=disabled/' /etc/selinux/config

yum -y install $EXTRA_PACKAGES
systemctl enable ntpd
systemctl start ntpd

useradd -m -d /home/ceph-deploy ceph-deploy
mkdir /home/ceph-deploy/ceph-deploy
chown ceph-deploy:ceph-deploy /home/ceph-deploy/ceph-deploy
echo 'ceph-deploy ALL = (root) NOPASSWD:ALL' >/etc/sudoers.d/ceph-deploy
chmod 0440 /etc/sudoers.d/ceph-deploy
mkdir ~ceph-deploy/.ssh
chmod 0700 ~ceph-deploy/.ssh
cp ~centos/.ssh/authorized_keys ~ceph-deploy/.ssh/
chown -R ceph-deploy:ceph-deploy ~ceph-deploy/.ssh
