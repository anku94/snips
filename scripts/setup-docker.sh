#!/usr/bin/env bash

install-docker() {
  sudo apt-get remove -y docker docker-engine docker.io containerd runc
  sudo apt-get update
  sudo apt-get install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  sudo apt-get update
  sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin
}

setup-user() {
  sudo groupadd docker
  sudo usermod -aG docker $USER
  newgrp docker
}

setup-config() {
  (
  cat << EOF
{
  "proxies":
    {
          "default":
              {
                      "httpProxy": "http://proxy.pdl.cmu.edu:3128",
      "httpsProxy": "http://proxy.pdl.cmu.edu:3128"
    }
  }
}
EOF
  ) | tee ~/.docker/config.json

  sudo mkdir -p /etc/systemd/system/docker.service.d
  (
    cat << EOF
[Service]
Environment="HTTP_PROXY=http://proxy.pdl.cmu.edu:3128"
Environment="HTTPS_PROXY=http://proxy.pdl.cmu.edu:3128"
EOF
  ) | sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf
  sudo systemctl daemon-reload
  sudo systemctl restart docker
}

# install-docker
# setup-user
setup-config
