
# Table of Contents

1.  [heat templates for ceph](#1)
    1.  [requirements](#11)
    2.  [instructions](#12)
    3.  [notes](#13)



<a id="1"></a>

# heat templates for ceph

easily set up ceph for testing upgrades etc

tested with hammer,jewel,luminous and mimic. mds nodes haven't been fully implemented yet

you will need to tune `ceph_environment.yaml` to suit your cloud and tweak
proxy/fastestmirror settings at the top of admin.sh and node.sh

luminous and mimic use bluestore for osds


<a id="11"></a>

## requirements

-   if you don't use `hw_disk_bus'scsi', hw_scsi_model='virtio-scsi'`
    in image properties you'll need to change admin.sh to use /dev/vd{bc}
-   designate should be set up to auto populate instance dns records
    if not you can inject hosts file into admin node with something like

        openstack server list -f value -c Networks -c Name | \
        grep ceph-lab1-network | sed -e 's/ceph1-lab-network=//' -e 's/,.*$//' | \
        ssh centos@login-ceph1-lab 'sudo tee -a /etc/hosts'


<a id="12"></a>

## instructions

assuming a stack_name of ceph1-lab:

1.  create stack

    `openstack stack create --wait -e ceph_environment.yaml -t ceph_template.yaml --parameter ceph_release=hammer ceph1-lab`

2.  get login node

    `openstack stack output show --all ceph1-lab`
    
    wait a bit for cloud-init to complete setup
    
3.  login and deploy

        ssh -A ceph-deploy@login-ceph1-lab
        cd ceph-deploy
        ./deploy.sh


<a id="13"></a>

## notes

rarely I've seen an issue where the stack can't be deleted because a
volume gets stuck in detaching. resolve with

    cinder reset-state --attach-status detached <vol_id>
    openstack volume delete <vol_id>
    openstack server delete <last_server_id>
    openstack stack delete --yes --wait <stack_name>

if you still can't delete the stack then you'll need

`openstack stack abandon <stack_name>`

(set `enable_stack_abandon = True` in heat.conf)

and a manual cleanup of the remaining resources
