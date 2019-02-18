#!/bin/bash -v

# optionally set yumproxy and disable fastestmirror
echo "proxy = http://192.168.1.1:8123/" >>/etc/yum.conf
sed -i 's/^enabled=1/enabled=0/' /etc/yum/pluginconf.d/fastestmirror.conf

# required setup
setenforce 0
sed -i 's/^SELINUX=enabled/SELINUX=disabled/' /etc/selinux/config

yum -y install $EXTRA_PACKAGES
systemctl enable ntpd
systemctl start ntpd

yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
yum -y install https://download.ceph.com/rpm-$CEPH_VERSION/el7/noarch/ceph-release-1-1.el7.noarch.rpm
yum -y install ceph-deploy
useradd -m -d /home/ceph-deploy ceph-deploy
mkdir /home/ceph-deploy/ceph-deploy
chown ceph-deploy:ceph-deploy /home/ceph-deploy/ceph-deploy
echo 'ceph-deploy ALL = (root) NOPASSWD:ALL' >/etc/sudoers.d/ceph-deploy
chmod 0440 /etc/sudoers.d/ceph-deploy
mkdir ~ceph-deploy/.ssh
chmod 0700 ~ceph-deploy/.ssh
cp ~centos/.ssh/authorized_keys ~ceph-deploy/.ssh/
chown -R ceph-deploy:ceph-deploy ~ceph-deploy/.ssh
cat <<EOF >/home/ceph-deploy/ceph-deploy/deploy.sh
#!/bin/bash

set -xe

RELEASE=$CEPH_VERSION

# install/setup
ceph-deploy new --public-network $NETWORK mon0-$STACK_TAG mon1-$STACK_TAG mon2-$STACK_TAG
ceph-deploy install --release \$RELEASE admin-$STACK_TAG mon0-$STACK_TAG mon1-$STACK_TAG mon2-$STACK_TAG stg0-$STACK_TAG stg1-$STACK_TAG stg2-$STACK_TAG
ceph-deploy --overwrite-conf mon create-initial

# copy keys
ceph-deploy admin admin-$STACK_TAG mon0-$STACK_TAG mon1-$STACK_TAG mon2-$STACK_TAG stg0-$STACK_TAG stg1-$STACK_TAG stg2-$STACK_TAG

if [ "\$RELEASE" == "luminous" -o "\$RELEASE" == "mimic" ]
then
  ceph-deploy mgr create mon0-$STACK_TAG mon1-$STACK_TAG mon2-$STACK_TAG
fi

# check quorum
sleep 3 && ceph --id admin --keyring ceph.client.admin.keyring status && sleep 3


# create osds
if [ "\$RELEASE" == "luminous" -o "\$RELEASE" == "mimic" ]
then
  ceph-deploy osd create --data /dev/sdb stg0-$STACK_TAG
  ceph-deploy osd create --data /dev/sdc stg0-$STACK_TAG
  ceph-deploy osd create --data /dev/sdb stg1-$STACK_TAG
  ceph-deploy osd create --data /dev/sdc stg1-$STACK_TAG
  ceph-deploy osd create --data /dev/sdb stg2-$STACK_TAG
  ceph-deploy osd create --data /dev/sdc stg2-$STACK_TAG
else
  ceph-deploy osd prepare stg0-$STACK_TAG:sdb stg0-$STACK_TAG:sdc stg1-$STACK_TAG:sdb stg1-$STACK_TAG:sdc stg2-$STACK_TAG:sdb stg2-$STACK_TAG:sdc
  ceph-deploy osd activate stg0-$STACK_TAG:/dev/sdb1 stg0-$STACK_TAG:/dev/sdc1 stg1-$STACK_TAG:/dev/sdb1 stg1-$STACK_TAG:/dev/sdc1 stg2-$STACK_TAG:/dev/sdb1 stg2-$STACK_TAG:/dev/sdc1
fi

# show final status
echo -e "Done\n"
sleep 3
sudo ceph status
sudo ceph tell mon.* version
sudo ceph tell osd.* version
EOF

# set owner/mode & scan for ssh keys
chown ceph-deploy:ceph-deploy /home/ceph-deploy/ceph-deploy/deploy.sh
chmod 750 /home/ceph-deploy/ceph-deploy/deploy.sh

su -c 'ssh-keyscan admin-$STACK_TAG mon0-$STACK_TAG mon1-$STACK_TAG mon2-$STACK_TAG stg0-$STACK_TAG stg1-$STACK_TAG stg2-$STACK_TAG >>~ceph-deploy/.ssh/known_hosts' ceph-deploy
