#!/bin/bash

sudo dpkg -i /share/testbed/misc/panfs-4.15.0-88-generic-8.0.3.b-1564293.3.ul_1804_x86_64.deb

lsmod | grep pan

sleep 3

sudo /share/testbed/bin/linux-panfs -f
