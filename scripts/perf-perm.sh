#!/usr/bin/env bash

sudo addgroup tracing
sudo usermod -aG tracing ankushj
# newgrp tracing
sudo mount -o remount,mode=755 /sys/kernel/debug
sudo mount -o remount,mode=755 /sys/kernel/debug/tracing
echo 0 | sudo tee /proc/sys/kernel/kptr_restrict
echo -1 | sudo tee /proc/sys/kernel/perf_event_paranoid
sudo chown root:tracing /sys/kernel/debug/tracing/uprobe_events
sudo chmod g+rw /sys/kernel/debug/tracing/uprobe_events

PSM=/users/ankushj/repos/parthenon-vibe/amr-install/lib/libpsm_infinipath.so.1.16

perf probe -x $PSM --funcs

newgrp tracing
perf probe -x $PSM -a 'psm:nobj=psmi_mpool_get mp->mp_num_obj'
perf probe -x $PSM -a 'psm:nused=psmi_mpool_get mp->mp_num_obj_inuse'
perf probe -l
