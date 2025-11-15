#!/bin/bash

set -eu

#
# Script installs kdump-tools and configures it to capture kernel crash dumps.
#

echo "kdump-tools kdump-tools/use_kdump boolean true" | sudo debconf-set-selections
echo "kdump-tools kdump-tools/should_handler_reboot boolean true" | sudo debconf-set-selections

sudo DEBIAN_FRONTEND=noninteractive apt-get install -y kdump-tools

echo "Verifying kdump configuration..."
if grep -q "USE_KDUMP=1" /etc/default/kdump-tools; then
  echo "kdump-tools successfully configured."
else
  echo "Error: kdump-tools configuration failed." >&2
  exit 1
fi

# Set kernel to panic on certain conditions
sudo tee /etc/sysctl.d/98-debugging.conf > /dev/null <<EOF
# Panic if a task is stuck in an uninterruptible state for more than 120 seconds.
# This is a great way to catch tasks hung on broken storage or drivers.
kernel.hung_task_panic = 1
kernel.hung_task_timeout_secs = 120

# Panic on an Out-Of-Memory (OOM) condition. Instead of just killing a process
# and potentially leaving the system unstable, this will give you a full dump
# of the memory state at the moment it ran out.
vm.panic_on_oom = 1

# Panic if the kernel detects a "soft lockup" (CPU stuck in kernel mode for
# too long but still responsive to some interrupts).
kernel.softlockup_panic = 1
EOF

# Apply the 98-debugging.conf settings
sudo sysctl --system

echo ""
echo "************************************************************************"
echo "  kdump is installed. A REBOOT IS REQUIRED to activate the crashkernel."
echo "************************************************************************"
