run() {
  TORCH_ROOT=/l0/pytorch-root
  TORCH_REPO_URL=https://github.com/pytorch/pytorch
  TORCH_REPO=$TORCH_ROOT/pytorch

  mkdir $TORCH_ROOT
  cd $TORCH_ROOT

  git clone $TORCH_REPO_URL $TORCH_REPO
  cd $TORCH_REPO

  git checkout v2.7.0

  ls

  docker build --target build -t pytorch-builder .
}

build_cmd() {
  # edit Dockerfile and add MAX_JOBS=6 before `python setup.py install`
  # MAX_JOBS=8 may also work (bottleneck is memory, around 40GB for flash-attention @ 6 jobs)
  # can also prune TORCH_CUDA_ARCH_LIST to just the needed architectures
  BUILD_TYPE=build \
    BUILD_PROGRESS=plain \
    DOCKER_FULL_NAME=pytorch-builder \
    sudo -E make -f docker.Makefile devel-image
}

mod_docker() {
  DOCKER_ROOT=/l0/docker-root
  DOCKER_ROOT=/mnt/ltio/docker-root
  sudo mkdir -p $DOCKER_ROOT
  sudo chown root:docker $DOCKER_ROOT
  # edit /etc/docker/daemon.json to add the root directory
  echo "{
    \"data-root\": \"$DOCKER_ROOT\"
  }" | sudo tee /etc/docker/daemon.json
  cat /etc/docker/daemon.json

  # restart docker
  sudo systemctl restart docker

  sudo ls /var/lib/docker
  sudo systemctl status docker

  # This will show the new Docker root directory
  sudo docker info --format '{{.DockerRootDir}}'
}
