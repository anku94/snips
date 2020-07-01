#!/bin/bash

dir=`ls -d /tmp/vpic* 2> /dev/null | sort -k1n`

files=`find $dir -type f -iname "*perfstats*"`

byte_sum=0
for file in $files; do
  byte_cur=`tail -1 $file | cut -d, -f 2`
  byte_sum=$(( byte_sum + byte_cur ))
done

host_name=`hostname | cut -d. -f1`
echo $byte_sum > ~/count/$host_name

echo `du -sb ~/mnt | cut -f 1` > ~/count/$host_name.du
