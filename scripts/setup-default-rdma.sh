export DEBIAN_FRONTEND=noninteractive

export HTTP_PROXY="http://ops:8888"
export HTTPS_PROXY="http://ops:8888"

# sudo apt install -y librdmacm-dev libibverbs-dev libmlx4-1 ibverbs-utils infiniband-diags ibutils rdmacm-utils perftest silversearcher-ag

# sudo modprobe mlx4_ib # low level ahrdware
# sudo modprobe ib_uverbs # verbs API
# sudo modprobe rdma_ucm # ib_ucm also?
# sudo modprobe ib_umad # needed for ibstat

sudo add-apt-repository -y ppa:ubuntu-toolchain-r/test
sudo apt update
sudo apt install -y infiniband-diags
sudo apt install -y libgflags-dev libgtest-dev libblkid-dev linux-modules-extra-`uname -r`
cd /usr/src/gtest && sudo cmake . && sudo make && sudo mv libg* /usr/lib/
sudo apt install -y libsnmp30 libsnmp-dev socat pkg-config fio
sudo apt install -y libpmem-dev libpapi-dev
sudo apt install -y numactl
sudo apt install -y g++-9
sudo apt remove -y clang-format
sudo apt-get install -y clang-format-10 htop tree
sudo ln -s /usr/bin/clang-format-10 /usr/bin/clang-format

sudo dpkg -i ~/downloads/fd_7.3.0_amd64.deb
sudo dpkg -i ~/downloads/bat_0.10.0_amd64.deb
sudo apt install -y silversearcher-ag sysstat

sudo apt install -y ctags

sudo apt remove -y openmpi-bin libopenmpi-dev
# sudo apt install -y mpich

sudo apt install -y linux-tools-common linux-tools-`uname -r` linux-cloud-tools-`uname -r`

sudo /share/testbed/bin/localize-resolv

# Disabled because of parallel-ssh issues
#rm -rf ~/.pyenv
#curl https://pyenv.run | bash
echo 0 | sudo dd of=/proc/sys/kernel/yama/ptrace_scope

curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | sudo bash

sudo apt-get install git-lfs
git lfs install --skip-repo


# kitware/cmake 3.16

sudo apt purge --auto-remove cmake
wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | gpg --dearmor - | sudo tee /etc/apt/trusted.gpg.d/kitware.gpg >/dev/null
sudo apt-add-repository 'deb https://apt.kitware.com/ubuntu/ bionic main'
sudo apt update
sudo apt install -y cmake cmake-curses-gui
