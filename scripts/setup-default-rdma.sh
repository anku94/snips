export HTTP_PROXY="http://ops:8888"
export HTTPS_PROXY="http://ops:8888"

# sudo apt install -y librdmacm-dev libibverbs-dev libmlx4-1 ibverbs-utils infiniband-diags ibutils rdmacm-utils perftest silversearcher-ag

# sudo modprobe mlx4_ib # low level ahrdware
# sudo modprobe ib_uverbs # verbs API
# sudo modprobe rdma_ucm # ib_ucm also?
# sudo modprobe ib_umad # needed for ibstat

# for erpc
sudo apt install -y libgflags-dev libgtest-dev
cd /usr/src/gtest && sudo cmake . && sudo make && sudo mv libg* /usr/lib/
sudo apt install -y libpmem-dev libpapi-dev
sudo apt install -y numactl
sudo apt-get install -y clang-format htop tree
sudo apt-get update

sudo dpkg -i ~/downloads/fd_7.3.0_amd64.deb
sudo dpkg -i ~/downloads/bat_0.10.0_amd64.deb
sudo apt install -y silversearcher-ag sysstat

sudo apt install -y ctags

sudo apt remove -y openmpi-bin libopenmpi-dev
sudo apt install -y mpich

sudo /share/testbed/bin/localize-resolv

# Disabled because of parallel-ssh issues
#rm -rf ~/.pyenv
#curl https://pyenv.run | bash
echo 0 | sudo dd of=/proc/sys/kernel/yama/ptrace_scope

curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | sudo bash

sudo apt-get install git-lfs
git lfs install --skip-repo

