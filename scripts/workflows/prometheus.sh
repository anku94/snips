#!/usr/bin/env bash

dothings() {
  cd /l0
  wget https://github.com/prometheus/prometheus/releases/download/v3.2.1/prometheus-3.2.1.linux-amd64.tar.gz
  cd prometheus-3.2.1.linux-amd64
  PROM=prometheus-3.2.1.linux-amd64
  tar -xf $PROM.tar.gz
  cd $PROM
  ls

  NODEXP_URL=https://github.com/prometheus/node_exporter/releases/download/v1.9.0/node_exporter-1.9.0.linux-amd64.tar.gz
  NODEXP=node_exporter-1.9.0.linux-amd64

  wget $NODEXP_URL
  tar -xf $NODEXP.tar.gz

  wget https://dl.grafana.com/enterprise/release/grafana-enterprise-11.5.2.linux-amd64.tar.gz
tar -zxvf grafana-enterprise-11.5.2.linux-amd64.tar.gz



}

