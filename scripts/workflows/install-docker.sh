#!/usr/bin/env bash

setup_repo() {
  # Add Docker's official GPG key:
  sudo apt-get update
  sudo apt-get install ca-certificates curl
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc

  # Add the repository to Apt sources:
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" |
    sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt-get update
}

change_docker_root() {
  DOCKER_ROOT=/l0/docker-root
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

run() {
  setup_repo
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  sudo apt install -y pv
  sudo docker run hello-world
  env | grep -i PROXY
}

load_docker_image() {
  IMAGE_PATH=/mnt/ltio/images/pytorch-v2.7.0-cu121.tar.zst.v2
  pv $IMAGE_PATH | zstd -d -c | sudo docker load

}

load_docker_image
