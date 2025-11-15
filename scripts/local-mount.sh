#!/bin/bash

part=$(sudo fdisk -l | egrep sd[a-z]4 | awk '{ print $1 }')
echo $part, $HOME

sudo mkfs.ext4 $part
sudo mount $part $HOME/mnt
sudo chown -R ankushj:TableFS $HOME/mnt
