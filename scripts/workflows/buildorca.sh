#!/usr/bin/env bash

set -eu

# Build tree:
# $ORCA_ROOT
# |- mon-umbrella
#    |- build
#    |- install
# |- orca
#    |- build
#    |- install

#bash

ORCA_ROOT=/l0/orcaroot
mkdir -p $ORCA_ROOT
cd $ORCA_ROOT

MON_UMB_REPO="https://github.com/pdlfs/orca-umbrella.git"
MON_UMB_TAG="main"

ORCA_REPO="https://github.com/anku94/mon.git"
ORCA_TAG="e2e"

ORCA_DEPS_INSTDIR=/users/ankushj/repos/orca-workspace/orca-umb-install
#ORCA_DEPS_INSTDIR=/proj/TableFS/orca-hgdbg/orca-umbrella-install
ORCA_INSTDIR=/users/ankushj/repos/orca-workspace/orca-install
#ORCA_INSTDIR=/proj/TableFS/orca-hgdbg/orca-install

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

#
# umbrella_build: build mon-umbrella with bmi and sm
#
umbrella_build() {
  local umb_srcdir="$ORCA_ROOT/orca-umbrella"
  local umb_builddir="$umb_srcdir/build"
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
  cmake \
    -DMERCURY_NA_INITIALLY_ON="bmi;sm;ofi" \
    -DCMAKE_INSTALL_PREFIX=$umb_instdir \
    ..

  make -j14
}

#
# orca_build: build orca using mon-umbrella
#
orca_build() {
  message "Building orca using mon-umbrella at $ORCA_DEPS_INSTDIR"

  local orca_srcdir="$ORCA_ROOT/orca"
  local orca_builddir="$orca_srcdir/build"
  # orca_instdir="$orca_srcdir/install"
  local orca_instdir="$ORCA_INSTDIR"

  message "orca builddir: $orca_builddir"
  message "orca instdir: $orca_instdir"

  # if orca_srcdir does not exist
  if [ ! -d $orca_srcdir ]; then
    message "Cloning ORCA at $orca_srcdir"
    git clone $ORCA_REPO $orca_srcdir
    cd $orca_srcdir
    git checkout $ORCA_TAG
  else
    message "ORCA dir already exists: $orca_srcdir. Reusing it."
    message "Delete it to reclone."
  fi

  mkdir -p $orca_builddir $orca_instdir
  cd $orca_builddir

  cmake \
    -DCMAKE_PREFIX_PATH=$ORCA_DEPS_INSTDIR \
    -DCMAKE_INSTALL_PREFIX=$orca_instdir \
    -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_CXX_FLAGS="-fuse-ld=lld" \
    ..
  make -j16
}

orca_buildtmp() {
  message "Building orca using mon-umbrella at $umb_srcdir"

  orca_srcdir="$ORCA_ROOT/orca"
  orca_builddir="$orca_srcdir/build2"
  # orca_instdir="$orca_srcdir/install"
  orca_instdir="$ORCA_INSTDIR"

  cd ..
  rm -rf $orca_builddir
  cargo clean

  message "orca builddir: $orca_builddir"
  message "orca instdir: $orca_instdir"

  mkdir -p $orca_builddir $orca_instdir
  cd $orca_builddir

  cmake \
    -DCMAKE_PREFIX_PATH=$ORCA_DEPS_INSTDIR \
    -DCMAKE_INSTALL_PREFIX=$orca_instdir \
    -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_CXX_FLAGS="-fuse-ld=lld" \
    ..
  make -j16
  make VERBOSE=1 2>&1 | tee build.log
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

  local grfurlbase=https://dl.grafana.com/enterprise/release
  local grfurl_ver=$grfurlbase/grafana-enterprise-${GRF_VER}.linux-amd64.tar.gz

  local grftar=$(basename $grfurl_ver)
  local grfdir=$GRF_ROOT/grafana-v$GRF_VER

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
  message "Grafana version: $GRF_VER extracted"

  popd
}

#
# config_gf12: set up grafana config for version 12
#
config_gf12() {
  message "Configuring Grafana v12 in $GRF_DIR"

  # See: https://github.com/grafana/grafana/issues/105129
  # gf12 has a bug where it needs dashboardScene to enable new schemas

  cat <<EOF > $GRF_DIR/conf/custom.ini
# Grafana config for version 12
[feature_toggles]
enable = kubernetesDashboard,dashboardNewLayouts,dashboardScene
EOF
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
  mv influxdata-flightsql-datasource $GRF_DIR/data/plugins

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

  alias grr="$GRF_ROOT/grr-linux-amd64"

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
  GRF_VER=11.5.2
  GRF_VER=11.6.1
  GRF_VER=12.0.1
  GRF_DIR=$GRF_ROOT/grafana-v$GRF_VER
  ORCAUTILS_DIR=$GRF_ROOT/orca-utils

  local
  orcautils_repo="https://github.com/pdlfs/orca-utils.git"

  mkdir -p $GRF_ROOT

  setup_grafana
  setup_grafana_fsql
  # setup_grizzly # defines alias grr

  git clone $orcautils_repo $ORCAUTILS_DIR
  cd $ORCAUTILS_DIR
  git checkout grfexp
  cd $GRF_ROOT
  # Need to run grafana before the next step
  alias grr=$GRF_ROOT/grr-linux-amd64
  setup_gfdash

  setopt clobber
  config_gf12
}

umbrella_clean() {
  cd /
  local umb_srcdir="$ORCA_ROOT/mon-umbrella"
  rm -rf $umb_srcdir
}

umbrella_main() {
  umbrella_build
  # sudo apt install -y lld
  # orca_build

  #umbrella_clean
}

umbrella_main
