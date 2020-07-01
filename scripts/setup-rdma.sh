export http_proxy=http://ops:8888
export https_proxy=http://ops:8888

sudo apt-get update
sudo apt-get install -y vim

sudo apt-get remove ibverbs-providers:amd64 libfabric1 openmpi-bin openmpi-common librdmacm1:amd64 libibverbs-dev:amd64 libopenmpi2 libopenmpi2:amd64 libopenmpi-dev
#sudo apt-get install -y librdmacm-dev libibverbs-dev libmlx4-1 ibverbs-utils infiniband-diags ibutils rdmacm-utils perftest
sudo apt-get install libgflags-dev libmemcached-dev numactl

sudo bash -c "echo 8192 > /sys/devices/system/node/node0/hugepages/hugepages-2048kB/nr_hugepages"
sudo bash -c "echo kernel.shmmax = 9223372036854775807 >> /etc/sysctl.conf"
sudo bash -c "echo kernel.shmall = 1152921504606846720 >> /etc/sysctl.conf"
sudo sysctl -p /etc/sysctl.conf

# sudo modprobe mlx4_ib
# sudo modprobe ib_uverbs
# sudo modprobe rdma_ucm
# sudo modprobe ib_ipoib
# sudo modprobe ib_ucm
# sudo modprobe ib_umad

# sudo apt-get install -y libibcm1 ibsim-utils libcxgb3-1 libmthca1 libnes1 mstflint opensm srptools
