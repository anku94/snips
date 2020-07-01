export http_proxy=http://ops:8888
export https_proxy=http://ops:8888

sudo apt-get update
sudo apt-get install -y vim

sudo apt-get install -y librdmacm-dev libibverbs-dev libmlx4-1 ibverbs-utils infiniband-diags ibutils rdmacm-utils perftest

sudo modprobe mlx4_ib
sudo modprobe ib_uverbs
sudo modprobe rdma_ucm
sudo modprobe ib_ipoib
sudo modprobe ib_ucm
sudo modprobe ib_umad

sudo apt-get install -y libibcm1 ibsim-utils libcxgb3-1 libmthca1 libnes1 mstflint opensm srptools
