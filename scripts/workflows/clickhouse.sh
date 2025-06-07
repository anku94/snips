#!/usr/bin/env bash

# complete config:
# https://raw.githubusercontent.com/ClickHouse/ClickHouse/master/programs/server/config.xml

run() {
  curl https://clickhouse.com/ | sh
  ./clickhouse --help
  # --path: storage path?
  ./clickhouse
  timedatectl
  # set timezone to fix clickhouse error
  sudo dpkg-reconfigure tzdata
  ls
  # local 
  ch_store="/mnt/ltio/chdb.data"
  sudo timedatectl set-timezone America/New_York
  ./clickhouse server --path $ch_store
  ./clickhouse server -C ./chconfig.xml
  # rm -rf $ch_store
}
