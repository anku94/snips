#!/usr/bin/env bash

bash

EXP_NAME=amree
EXP_FULLNAME=TableFS,amree
# EXP_FULLNAME=TableFS,amr22wfok01
EXP_TGTSZ1=40
EXP_TGTSZ2=260

message() {
  echo "-INFO- $@"
}

die() {
  echo "-ERROR- $1"
  exit 1
}

modexp_to_target() {
  local exp_fullname=$1
  local -i tgtcnt=$2

  ssh ops -t "rm /tmp/ns.file"

  # first, generate nsfile
  py_cmd="python ~/scripts/modbed.py -e $exp_fullname -n $tgtcnt -g /tmp/ns.file -y"
  message "[CMD] $py_cmd"
  ssh ops -t "$py_cmd"

  # then, run modexp
  # flags: foreground + no email
  sh_cmd="/usr/testbed/bin/modexp -w -N -e $exp_fullname /tmp/ns.file"
  message "[CMD] $sh_cmd"
  ssh ops -t "$sh_cmd"

  # check nnodes
  message "Number of nodes in $exp_fullname: $nnodes"
  for check in $(seq 5); do
    sleep 5
    nnodes=$(ssh ops "/usr/testbed/bin/expinfo -e $exp_fullname -n" | grep pc | wc -l)
    message "Number of nodes in $exp_fullname: $nnodes"
    [ $nnodes -eq $tgtcnt ] && break
  done

  [ $nnodes -eq $tgtcnt ] || die "Failed to modexp to $tgtcnt nodes"
}

run_downsize_and_swapin() {
  local exp_fullname=$1
  local -i tgtcnt=$2

  # first get state, assert it is swapped
  message "Checking if $exp_fullname is swapped"

  ssh ops "/usr/testbed/bin/expinfo -e $exp_fullname -n" | \
    egrep -o "State: (.*)" | \
    grep -q "swapped" || die "Experiment not swapped"

  message "$exp_fullname is swapped"

  nnodes=$(ssh ops "/usr/testbed/bin/expinfo -e $exp_fullname -n" | grep pc | wc -l)
  message "Number of nodes in $exp_fullname: $nnodes"

  # then modexp to size exp to $EXP_TGTSZ1
  # get_nnodes $EXP_FULLNAME
  modexp_to_target $exp_fullname $tgtcnt

  nnodes=$(ssh ops "/usr/testbed/bin/expinfo -e $exp_fullname -n" | grep pc | wc -l)
  [ $nnodes -eq $tgtcnt ] || die "Failed to modexp to $tgtcnt nodes"

  # swap in exp
  local swapcmd="/usr/testbed/bin/swapexp -w -N -e $exp_fullname in"
  message "[CMD] $swapcmd"
  ssh ops -t "$swapcmd"
}

run_seq() {
  local exp_fullname=$EXP_FULLNAME

  # first get state, assert it is swapped
  message "Checking if $exp_fullname is swapped"

  ssh ops "/usr/testbed/bin/expinfo -e $exp_fullname -n" | \
    egrep -o "State: (.*)" | \
    grep -q "swapped" || die "Experiment not swapped"

  message "$exp_fullname is swapped"

  nnodes=$(ssh ops "/usr/testbed/bin/expinfo -e $exp_fullname -n" | grep pc | wc -l)
  message "Number of nodes in $exp_fullname: $nnodes"

  # then modexp to size exp to $EXP_TGTSZ1
  # get_nnodes $EXP_FULLNAME
  modexp_to_target $EXP_FULLNAME $EXP_TGTSZ1

  nnodes=$(ssh ops "/usr/testbed/bin/expinfo -e $exp_fullname -n" | grep pc | wc -l)
  [ $nnodes -eq $EXP_TGTSZ1 ] || die "Failed to modexp to $EXP_TGTSZ1 nodes"

  # swap in exp
  local swapcmd="/usr/testbed/bin/swapexp -w -N -e $exp_fullname in"
  message "[CMD] $swapcmd"
  ssh ops -t "$swapcmd"

  echo "Checking READYCOUNT: "
  ssh ops "/usr/testbed/bin/readycount -e $exp_fullname"

  modexp_to_target $EXP_FULLNAME $EXP_TGTSZ2
  [ $nnodes -eq $EXP_TGTSZ2 ] || die "Failed to modexp to $EXP_TGTSZ2 nodes"

  echo "Checking READYCOUNT: "
  ssh ops "/usr/testbed/bin/readycount -e $exp_fullname"
}

run_seq2() {
  local exp_fullname=$EXP_FULLNAME
  exp_fullname="TableFS,amree"
  state=$(ssh ops "/usr/testbed/bin/expinfo -e $exp_fullname -a" | grep "State: ")
  message "Experiment state: $state"

  if [[ "$state" == "State: swapped" ]]; then
    message "Experiment $exp_fullname swapped out; swapping in ..."
    run_downsize_and_swapin $exp_fullname $EXP_TGTSZ1
    sleep 10
  fi

  sleep 10
  echo "Experiment state: $state"

  # state == "State: active" or die
  [ "$state" == "State: active" ] || die "Experiment not active"

  nnodes=$(ssh ops "/usr/testbed/bin/expinfo -e $exp_fullname -n" | grep pc | wc -l)

  # if nnodes < EXP_TGTSZ1, modexp to EXP_TGTSZ1
  if [ $nnodes -lt $EXP_TGTSZ1 ]; then
    message "RESIZE1: Experiment $exp_fullname has $nnodes nodes; modexp to $EXP_TGTSZ1"
    modexp_to_target $exp_fullname $EXP_TGTSZ1
  fi

  exp_fullname="TableFS,amree"
  run_downsize_and_swapin "TableFS,amre" 3
  sleep 100
  modexp_to_target "TableFS,amree" 250
  sleep 100
  modexp_to_target "TableFS,amree" 256
  modexp_to_target $exp_fullname 240

  sleep 10

  nnodes=$(ssh ops "/usr/testbed/bin/expinfo -e $exp_fullname -n" | grep pc | wc -l)

  # mod exp to EXP_TGTSZ2
  message "RESIZE2: Experiment $exp_fullname has $nnodes nodes; modexp to $EXP_TGTSZ2"
  modexp_to_target $exp_fullname $EXP_TGTSZ2

  sleep 10
  # ssh "h0.$EXP_NAME.tablefs" "~/scripts/run-ansible.sh -a"
  # ~/scripts/run-ansible.sh -a
}

# sleep 500
run_seq2
