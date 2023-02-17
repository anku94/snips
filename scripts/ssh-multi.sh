#!/usr/bin/env bash
# ssh-multi
# D.Kovalov
# Based on http://linuxpixies.blogspot.jp/2011/06/tmux-copy-mode-and-how-to-control.html

# a script to ssh multiple servers over multiple tmux panes

shopt -s expand_aliases
source ~/.bashrc

get_numhosts() {
  count=$(/share/testbed/bin/emulab-listall | sed 's/,/\n/g' | wc -l)
  echo $count
}

deresolve_ip() {
  ip=$1
  last=$(echo $ip | cut -d. -f 4)
  hnum=$(( last - 2 ))
  echo h$hnum
}

starttmux() {
    if [ -z "$HOSTS" ]; then
       echo -n "Please provide of list of hosts separated by spaces [ENTER]: "
       read HOSTS
    fi

    local hosts=( $HOSTS )


    tmux new-window "ssh ${hosts[0]}"
    unset hosts[0];
    for i in "${hosts[@]}"; do
        tmux split-window -h  "ssh $i"
        tmux select-layout tiled > /dev/null
    done
    tmux select-pane -t 0
    tmux set-window-option synchronize-panes on > /dev/null

}

mystarttmux() {
  # FILE=~/hosts
  FILE=$1
  host0=$(deresolve_ip `head -1 $FILE`)
  # host0=$2
  echo $host0

  tmux new-window "ssh $host0"
  for i in `cat $FILE | tail -n +2`; do
    host=$(deresolve_ip $i)
    echo $i, $host
    tmux split-window -h "ssh $host"
    tmux select-layout tiled > /dev/null
  done

  tmux select-pane -t 0
  tmux set-window-option synchronize-panes on > /dev/null
}

sus_starttmux() {
  echo "Bootstrapping $1 nodes..."

  lastNode=$(($1 - 1))

  sudo /share/testbed/bin/localize-resolv

  tmux new-window "ssh h0"
  for i in `seq 1 $lastNode`; do
    echo $i
    tmux split-window -h "ssh h$i"
    tmux select-layout tiled > /dev/null
  done

  tmux select-pane -t 0
  tmux set-window-option synchronize-panes on > /dev/null
}

HOSTS=${HOSTS:=$*}

run_wcount() {
  count=$1
  echo $count
  read -p "Nodes found: $count. Continue? (Y/n): " confirm
  [[ -z "${confirm}" || $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1
  sus_starttmux $count
}

run_wocount() {
  count=$(get_numhosts)
  run_wcount $count
}

#mystarttmux
#sus_starttmux $1
while getopts "af:n:" opt; do
  case ${opt} in
    a )
      echo "sshing into all"
      run_wocount
      ;;
    f )
      hostfile=$OPTARG
      echo "host file: $hostfile"
      mystarttmux $hostfile
      ;;
    n )
      nhosts=$OPTARG
      echo "sshing into $nhosts"
      run_wcount $nhosts
      ;;
    : )
      echo "invalid opt"
      ;;
  esac
done
