#!/usr/bin/env bash

setup() {
  sudo mount -o remount,mode=755 /sys/kernel/debug
  sudo mount -o remount,mode=755 /sys/kernel/debug/tracing
  echo 0 | sudo tee /proc/sys/kernel/kptr_restrict
  echo -1 | sudo tee /proc/sys/kernel/perf_event_paranoid
  sudo chown root:TableFS /sys/kernel/debug/tracing/uprobe_events
  sudo chmod g+rw /sys/kernel/debug/tracing/uprobe_events

  sudo apt install -y libpython2-dev
}

run() {
  gcc -g -o code code.c
  ./code

  alias perf=~/.local/bin/perf

  # -g enables call graph
  perf record -g ./code

  # DWARF enables better stack unwinding
  perf record -g --call-graph=dwarf ./code
  perf report --stdio

  # Show probe-able functions in binary
  perf probe -x ./code -F

  # Show probe-able function lines in binary
  perf probe -x ./code -L add_with_sleep

  # Show probe-able function lines in binary
  perf probe -x ./code -L add_with_sleep:2

  # Show available variables at some point
  perf probe -x ./code -V add_with_sleep:2

  # Add a probe
  perf probe -x ./code --add='add_with_sleep:0 sleep_us'
  perf probe -x ./code --add='add_with_sleep%return'

  perf record -e probe_code:add_with_sleep -e probe_code:add_with_sleep__return ./code

  # This will generate a python script called perf-script.py
  # Modify its entry and exit functions to print deltas between
  # Entry and Exit timesteps
  perf script -g python

  perf script -s perf-script.py | less

  ## Cleanup ##

  # Should show two events
  perf probe -l
  perf probe -d 'add_with_sleep'
  perf probe -d 'add_with_sleep%return'
  perf probe -d 'add_with_sleep__return'
  # Should show zero events
  perf probe -l

  PTHREADS=/usr/lib/x86_64-linux-gnu/libpthread.so.0
  perf probe -x $PTHREADS -F | grep spin

  PSM=/users/ankushj/repos/parthenon-vibe/amr-install/lib/libpsm_infinipath.so.1.16
  perf probe -x $PSM -F | grep amsh


}

run
