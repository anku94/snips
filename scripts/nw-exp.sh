#!/bin/bash

#set -euxo pipefail

host=""

if [ "$#" -ge 1 ];
then
  host=$1
fi

# sudo fi_msg_bw -p verbs -e msg -S 65536 -w 5000 -I 5000 $host
# [ -z $host ] || sleep 2
# sudo fi_msg_bw -p verbs -e dgram -S 65536 -w 5000 -I 5000 $host
# [ -z $host ] || sleep 2
# sudo fi_msg_bw -p verbs -e rdm -S 65536 -w 5000 -I 5000 $host
# [ -z $host ] || sleep 2

prov_opts=( verbs )
ep_opts=( msg rdm dgram )
ct_opts=( queue counter )
ct_opts=( queue )
cm_opts=( spin sread fd )

for prov in "${prov_opts[@]}"; do
  for ep in "${ep_opts[@]}"; do
    for ct in "${ct_opts[@]}"; do
      for cm in "${cm_opts[@]}"; do
        echo $prov, $ep, $ct, $cm
        echo "sudo fi_msg_bw -p $prov -e $ep -S 65536 -w 5000 -I 5000 -t $ct -c $cm $host"
        sudo fi_msg_bw -p $prov -e $ep -S 65536 -w 5000 -I 5000 -t $ct -c $cm $host
        [ -z $host ] || sleep 1
      done
    done
  done
done
