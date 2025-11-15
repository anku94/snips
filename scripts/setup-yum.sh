export HTTP_PROXY="http://ops:8888"
export HTTPS_PROXY="http://ops:8888"

function additional() {
  sudo yum install -y tmux systemd-devel valgrind-devel libnl3-devel tcl-devel numactl-devel
}

# sudo yum update

# Install rpm fusion
# sudo yum localinstall --nogpgcheck https://download1.rpmfusion.org/free/el/rpmfusion-free-release-7.noarch.rpm https://download1.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-7.noarch.rpm

# sudo yum install -y gflags-devel gtest-devel libpmem-devel papi-devel numa-ctl htop tree centos-release-scl

# might need to rm rm /etc/yum.repos.d/CentOS-SCL.repo
# sudo yum update

# sudo yum install -y llvm-toolset-7

sudo yum install -y the_silver_searcher sysstat ctags-etags mpich perf

# /opt/rh/llvm-toolset-7/root/bin/clang-format

# sudo apt-get install -y clang-format
# sudo apt-get update

# sudo dpkg -i ~/downloads/fd_7.3.0_amd64.deb
# sudo dpkg -i ~/downloads/bat_0.10.0_amd64.deb

# sudo apt remove -y openmpi-bin libopenmpi-dev
# sudo apt install -y mpich

# sudo apt install -y linux-tools-common linux-tools-`uname -r` linux-cloud-tools-`uname -r`

sudo /share/testbed/bin/localize-resolv

# # Disabled because of parallel-ssh issues
# #rm -rf ~/.pyenv
# #curl https://pyenv.run | bash
echo 0 | sudo dd of=/proc/sys/kernel/yama/ptrace_scope


sudo rpm -Uvh http://mirror.ghettoforge.org/distributions/gf/gf-release-latest.gf.el7.noarch.rpm
sudo rpm --import http://mirror.ghettoforge.org/distributions/gf/RPM-GPG-KEY-gf.el7

# WARNING: removing  vim-minimal uninstalls `sudo` if you skip the second step
#          make sure to at least run `yum install sudo`
sudo yum -y remove vim-minimal vim-common vim-enhanced
sudo yum -y --enablerepo=gf-plus install vim-enhanced sudo


# curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | sudo bash

# sudo apt-get install git-lfs
# git lfs install --skip-repo
