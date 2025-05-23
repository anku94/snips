##!/usr/bin/env bash

#set -eu

# Build tree:
# $ORCA_ROOT
# |- mon-umbrella
#    |- build
#    |- install
# |- orca
#    |- build
#    |- install

bash

ORCA_ROOT=/l0/orcahome/orca-test
mkdir -p $ORCA_ROOT
cd $ORCA_ROOT

MON_UMB_REPO="https://github.com/pdlfs/orca-umbrella.git"
MON_UMB_TAG="main"

ORCA_REPO="https://github.com/anku94/mon.git"
ORCA_TAG="e2e"

ORCA_DEPS_INSTDIR=/users/ankushj/repos/orca-workspace/orca-umb-install
ORCA_INSTDIR=/users/ankushj/repos/orca-workspace/orca-install

MPI_HOME=/users/ankushj/amr-workspace/mvapich-install-ub22
export PATH=$MPI_HOME/bin:$PATH

message() {
  echo "-INFO- $1"
}

umbrella_disable_mon() {
  pushd $umb_srcdir
  cat CMakeLists.txt | sed 's/\(include (umbrella\/mon)\)/# \1/' >CMakeLists.txt.tmp
  mv CMakeLists.txt.tmp CMakeLists.txt
  popd
}

umbrella_build() {
  local umb_srcdir="$ORCA_ROOT/mon-umbrella"
  local umb_builddir="$umb_srcdir/build"
  # umb_instdir="$umb_srcdir/install"
  local umb_instdir="$ORCA_DEPS_INSTDIR"

  message "Building umbrella in $umb_srcdir"

  cd /

  # git clone https://github.com/anku94/mon-umbrella.git $umb_srcdir
  git clone $MON_UMB_REPO $umb_srcdir
  cd $umb_srcdir
  git checkout $MON_UMB_TAG

  # disable mon, just use umbrella for deps
  umbrella_disable_mon

  cd $umb_srcdir

  message "mon should be commented out: "
  tail -2 CMakeLists.txt

  mkdir -p $umb_builddir
  cd $umb_builddir
  cmake -DCMAKE_INSTALL_PREFIX=$umb_instdir ..

  make -j16
}

orca_build() {
  message "Building orca using mon-umbrella at $umb_srcdir"

  local orca_srcdir="$ORCA_ROOT/orca"
  local orca_builddir="$orca_srcdir/build"
  # orca_instdir="$orca_srcdir/install"
  local orca_instdir="$ORCA_INSTDIR"

  message "orca builddir: $orca_builddir"
  message "orca instdir: $orca_instdir"

  git clone $ORCA_REPO $orca_srcdir
  cd $orca_srcdir
  git checkout $ORCA_TAG

  mkdir -p $orca_builddir $orca_instdir
  cd $orca_builddir

  cmake \
    -DCMAKE_PREFIX_PATH=$ORCA_DEPS_INSTDIR \
    -DCMAKE_INSTALL_PREFIX=$orca_instdir ..
  make -j16
}

#
# setup_grafana: download and set up grafana + fsql plugin
#
setup_grafana() {
  if [ -z "$GRF_ROOT" ] || [ ! -d $GRF_ROOT ]; then
    message "No/invalid grafana root specified"
    return 1
  fi

  if [ -d $GRF_DIR ]; then
    message "Grafana dir already exists: $GRF_DIR"
    rm -i $GRF_DIR
  fi

  pushd $GRF_ROOT
  message "Downloading Grafana in $GRF_ROOT"

  local grfver=11.6.2
  local grfurlbase=https://dl.grafana.com/enterprise/release
  local grfurl_ver=$grfurlbase/grafana-enterprise-$grfver.linux-amd64.tar.gz

  local grftar=$(basename $grfurl_ver)
  local grfdir=$GRF_ROOT/grafana-v$grfver

  # if exists, delete it
  if [ -f $grftar ]; then
    message "Grafana tarball already exists: $grftar"
    rm -i $grftar
  fi

  if [ -d $grfdir ]; then
    message "Grafana dir already exists: $grfdir"
    rm -i $grfdir
  fi

  wget $grfurl_ver
  if [ ! -f $grftar ]; then
    message "Grafana tarball not found: $grftarname"
    return 1
  fi
  message "Grafana tarball: $grftar downloaded"

  tar -xf $grftar
  message "Grafana version: $grfver extracted"

  popd
}

#
# setup_grafana_fsql: download and set up grafana flightsql plugin
#
setup_grafana_fsql() {
  if [ -z "$GRF_ROOT" ] || [ ! -d $GRF_ROOT ]; then
    message "No/invalid grafana root specified"
    return 1
  fi

  pushd $GRF_ROOT

  local fsql_ver=1.1.1
  local fsql_repo=https://github.com/influxdata/grafana-flightsql-datasource
  local fsql_reldir=$fsql_repo/releases/download
  local fsql_url=$fsql_reldir/v$fsql_ver/influxdata-flightsql-datasource-$fsql_ver.zip
  local fsql_zip=$(basename $fsql_url)

  if [ -f $fsql_zip ]; then
    message "Grafana Flightsql plugin already exists: $fsql_zip"
    rm -i $fsql_zip
  fi

  wget $fsql_url
  if [ ! -f $fsql_zip ]; then
    message "Grafana Flightsql plugin not found: $fsql_zip"
    return 1
  fi

  unzip influxdata-flightsql-datasource-1.1.1.zip

  mkdir -p $GRF_DIR/data/plugins
  mv influxdata-flightsql-datasource $grfdir/data/plugins

  message "Grafana Flightsql plugin set up"
  popd
}

#
# setup_gfgrr: download and set up grizzly in $GRF_ROOT
# alias grr is exported for grizzly
#
setup_grizzly() {
  if [ -z "$GRF_ROOT" ] || [ ! -d $GRF_ROOT ]; then
    message "No/invalid destination specified for grizzly"
    return 1
  fi

  pushd $GRF_ROOT

  local gr_urlbase="https://github.com/grafana/grizzly/releases"
  local gr_ver="v0.7.1"
  local gr_url="$gr_urlbase/download/$gr_ver/grr-linux-amd64"

  local gr_fname=$(basename $gr_url)
  local gr_fpath="$GRF_ROOT/$gr_fname"
  message "Downloading grizzly to path: $gr_fpath"

  # if exists, delete it
  if [ -f $gr_fname ]; then
    message "Grizzly file already exists: $gr_fname"
    rm -i $gr_fname
  fi

  wget $gr_url
  # if wget failed, return
  if [ $? -ne 0 ] || [ ! -f $gr_fname ]; then
    message "Failed to download grizzly"
    return 1
  fi

  chmod +x $gr_fname
  alias grr="$gr_fpath"

  message "Grizzly available as alias: grr"
}

#
# setup_gfdash: set up grafana dashboards
# (most be running first)
#
setup_gfdash() {
  if [ -z "$GRF_DIR" ] || [ ! -d "$GRF_DIR" ]; then
    message "No/invalid destination specified for grizzly"
    return 1
  fi

  if [ -z "$ORCAUTILS_DIR" ] || [ ! -d "$ORCAUTILS_DIR" ]; then
    message "No/invalid orca-utils dir specified"
    return 1
  fi

  json_dir=$ORCAUTILS_DIR/grafana-dashboard
  datasource_yaml=$json_dir/datasources/fsql.yml

  message "Installing datasource yaml: $datasource_yaml"
  if [ ! -f $datasource_yaml ]; then
    message "Datasource yaml not found: $datasource_yaml"
    return 1
  fi

  grr config set grafana.url http://localhost:3000
  grr config set grafana.user admin
  grr config set grafana.token admin
  grr apply $datasource_yaml

  grr apply $json_dir/dashboards -J $json_dir/lib
  # grr watch $json_dir/dashboards $json_dir/dashboards -J $json_dir/lib
}

#
# grafana_main: all grafana setup
#
grafana_main() {
  GRF_ROOT=/l0/grafana
  GRF_VER=11.6.2
  GRF_DIR=$GRF_ROOT/grafana-v$GRF_VER
  ORCAUTILS_DIR=$GRF_ROOT/orca-utils

  local orcautils_repo="https://github.com/pdlfs/orca-utils.git"

  mkdir -p $GRF_ROOT

  setup_grafana
  setup_grafana_fsql
  setup_grizzly # defines alias grr

  git clone $orcautils_repo $ORCAUTILS_DIR
  # Need to run grafana before the next step
  # setup_gfdash
}

umbrella_clean() {
  cd /
  local umb_srcdir="$ORCA_ROOT/mon-umbrella"
  rm -rf $umb_srcdir
}

umbrella_main() {
  umbrella_build
  orca_build

  sudo apt install -y lld

  #umbrella_clean
}
