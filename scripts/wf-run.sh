#!/bin/bash

# /share/testbed/bin/rr-makebed -e exp -p plfs -i ubuntu-12-64-plfs -n 64

getnodestrs() {
  prefix=wf0
  count=4
  start=73

  nodestr=""

  for idx in `seq 1 $count`;
  do
    nodeid=$(( start + idx - 1 ))
    nodestr="$nodestr -m $prefix$nodeid"
  done

  nodestr=$(echo $nodestr | sed 's/,$//g')
  echo $nodestr
  #echo " wf071 wf073 wf074 wf075 wf076 wf078 wf080 wf081 wf084 wf085 wf091 wf092 wf093 wf095 wf097 wf098 wf099" | sed 's/\ /\ -m /g'
}

#getnodestrs
#/share/testbed/bin/wf+ib-makebed -e stdwfib4 -p TableFS -i UBUNTU18-64-PDLSTD -I 2 -d 72 $(getnodestrs)
#/share/testbed/bin/wf+ib-makebed -e wfib33 -p TableFS -i UBUNTU18-64-PDLSTD -I 2 -d 72 -n 33
#/share/testbed/bin/wf+ib-makebed -e wfib6ccp -p TableFS -i CENTOS7-64-CARP -I 2 -d 72 -n 6

#/share/testbed/bin/wf-makebed -p TableFS -e ltib12 -n 12 -s /share/testbed/lustre/lustre-ipoib-startup -i centos7-lustre -f ib
#/share/testbed/bin/wf-makebed -p TableFS -e mpi34 -n 34 -s /share/testbed/bin/generic-startup -i UBUNTU18-64-MPICH33 -f ib -f ibok
#/share/testbed/bin/wf-makebed -p TableFS -e ts34 -n 34 -s /share/testbed/bin/generic-startup -i UBUNTU18-64-TRITON -f ib -f ibok
#/share/testbed/bin/wf-makebed -p TableFS -e amrib08 -n 8 -s /share/testbed/bin/generic-startup -i UBUNTU20-64-AMR -f ib -f ibok
#/share/testbed/bin/wf-makebed -p TableFS -e amrib34v2 -n 34 -s /share/testbed/bin/generic-startup -i UBUNTU20-64-AMR -f ib -f ibok
#/share/testbed/bin/wf-makebed -p TableFS -e carpib60 -n 60 -s /share/testbed/bin/generic-startup -i UBUNTU18-64-CARP -f ib -f ibok
#/share/testbed/bin/wf-makebed -p TableFS -e carpib30 -n 30 -s /share/testbed/bin/generic-startup -i UBUNTU18-64-CARP -f ib
#/share/testbed/bin/wf-makebed -p TableFS -e carpib06nok -n 6 -s /share/testbed/bin/generic-startup -i UBUNTU18-64-CARP -f ib
#/share/testbed/bin/wf-makebed -p TableFS -e ltib40 -n 40 -s /share/testbed/lustre/lustre-ibdirect-startup -i centos8-lustre -f ib -f ibok
#/share/testbed/bin/wf-makebed -p TableFS -e carp40 -n 40 -s /share/testbed/bin/generic-startup -i UBUNTU18-64-CARP -f ibok
#/share/testbed/bin/wf-makebed -p TableFS -e carp100 -n 100 -s /share/testbed/bin/generic-startup -i UBUNTU18-64-CARP -f ibok
#/share/testbed/bin/wf-makebed -p TableFS -e carp20 -n 20 -s /share/testbed/bin/generic-startup -i UBUNTU18-64-CARP -f ibok

#/share/testbed/bin/wf-makebed -p TableFS -e ltibdir20-tmp -n 23 -s /share/testbed/lustre/lustre-ibdirect-startup -i centos8-lustre -f ibok
#/share/testbed/bin/wf-makebed -p TableFS -e amrib40 -n 40 -s /share/testbed/bin/generic-startup -i UBUNTU20-64-AMR -f ib -f ibok
#/share/testbed/bin/wf-makebed -p TableFS -e amrib03 -n 3 -s /share/testbed/bin/generic-startup -i UBUNTU20-64-AMR -f ib -f ibok
#/share/testbed/bin/orca-makebed -p TableFS -e orca02 -n 2 -s /share/testbed/bin/generic-startup -i UBUNTU18-64-ORCA -M
#/share/testbed/bin/wf-makebed -p TableFS -e 746vm02 -n 2 -s /share/testbed/bin/generic-startup -i UBUNTU22-64-PDLSTD
#/share/testbed/bin/wf-makebed -p TableFS -e amrib100 -n 100 -s /share/testbed/bin/generic-startup -i UBUNTU20-64-AMR -f ib -f ibok
#/share/testbed/bin/wf-makebed -p TableFS -e amrib128 -n 128 -s /share/testbed/bin/generic-startup -i UBUNTU20-64-AMR
# /share/testbed/bin/wf-makebed -p TableFS -e amrwfok140 -n 140 -s /share/testbed/bin/generic-startup -i UBUNTU20-64-AMR -f wfok
#/share/testbed/bin/wf-makebed -p TableFS -e amrwfok01 -n 1 -s /share/testbed/bin/generic-startup -i UBUNTU20-64-AMR -f wfok

NUM_NODES=""
EXP_NAME="amrwfok"
IMAGE="UBUNTU20-64-AMR"
FLAGS="-f wfok"
STARTUP_SCRIPT="/share/testbed/bin/generic-startup"

check_var() {
    local var_name="$1"
    local current_value="${!var_name}"
    
    echo -n "$var_name = $current_value. Enter new value or press ENTER. "
    read -r new_value
    
    if [ -n "$new_value" ]; then
        eval "$var_name=\"$new_value\""
        echo "$var_name is now set to $new_value"
    fi
}

execute() {
  CMD="/share/testbed/bin/wf-makebed -p TableFS -e $EXP_NAME -n $NUM_NODES -s $STARTUP_SCRIPT -i $IMAGE $FLAGS"
  echo -en "[CMD] $CMD \n Continue? [y/N] "
  read -r response

  # unless response is n or N, continue
  if [ "$response" != "n" ] && [ "$response" != "N" ]; then
    echo "Executing command..."
    eval $CMD
  fi
}

check_var NUM_NODES
EXP_NAME="$EXP_NAME$NUM_NODES"
check_var EXP_NAME
execute



# /share/testbed/bin/emulab-listall 
# /share/testbed/bin/emulab-mpirunall hostname
# host h0.ibtest.TableFS
