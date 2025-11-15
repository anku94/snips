#!/bin/bash

sudo rpm -i 'centos-gpg-keys-8-3.el8.noarch.rpm'
sudo dnf --disablerepo '*' --enablerepo=extras swap centos-linux-repos centos-stream-repos
sudo yum install -y tmux zsh vim tree
sudo cp /users/ankushj/downloads/fd-v8.2.1-x86_64-unknown-linux-musl/fd /usr/local/bin
