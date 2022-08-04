#!/bin/sh

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
#/share/testbed/bin/wf-makebed -p TableFS -e carpib68 -n 68 -s /share/testbed/bin/generic-startup -i UBUNTU18-64-CARP -f ib -f ibok
/share/testbed/bin/wf-makebed -p TableFS -e ltib40 -n 40 -s /share/testbed/lustre/lustre-ibdirect-startup -i centos8-lustre -f ib -f ibok



# /share/testbed/bin/emulab-listall 
# /share/testbed/bin/emulab-mpirunall hostname
# host h0.ibtest.TableFS
