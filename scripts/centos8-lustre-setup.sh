#!/bin/bash

SCRIPT=/users/ankushj/snips/scripts/centos8-lustre-setup-worker.sh
wget 'http://mirror.centos.org/centos/8-stream/BaseOS/x86_64/os/Packages/centos-gpg-keys-8-3.el8.noarch.rpm'
sudo rpm -i 'centos-gpg-keys-8-3.el8.noarch.rpm'
sudo dnf --disablerepo '*' --enablerepo=extras swap centos-linux-repos centos-stream-repos
module add mpi/mpich-x86_64
/share/testbed/bin/emulab-mpirunall sh -c "sudo /share/testbed/bin/localize-resolv"
/share/testbed/bin/emulab-mpirunall $SCRIPT
