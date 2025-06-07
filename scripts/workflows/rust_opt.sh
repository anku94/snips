#!/usr/bin/env bash


init() {
  # Add to your shell configuration
  export CARGO_HOME=/l0/rust/.cargo
  export RUSTUP_HOME=/l0/rust/.rustup

  # Then create the config file in your local mount
  mkdir -p /l0/rust/.cargo
  mkdir -p /l0/rust/.rustup
}

setup_lld() {
  sudo apt install -y lld clang

  # return if exists
  if [ -f /l0/rust/.cargo/config.toml ]; then
    echo "Config file already exists, skipping initialization."
    return
  fi

  cat > /l0/rust/.cargo/config.toml << EOF
  [target.x86_64-unknown-linux-gnu]
  linker = "clang"
  rustflags = ["-C", "link-arg=-fuse-ld=lld", "-C", "target-cpu=sandybridge"]

  [build]
  target-dir = '/l0/rust/target/${CARGO_PKG_NAME}'
EOF
}

setup_mold() {
  # return if exists
  if [ -f /l0/rust/.cargo/config.toml ]; then
    echo "Config file already exists, skipping initialization."
    return
  fi

  cat > /l0/rust/.cargo/config.toml << EOF
  [target.x86_64-unknown-linux-gnu]
  linker = "clang"
  rustflags = ["-C", "link-arg=-fuse-ld=mold", "-C", "target-cpu=sandybridge"]

  [build]
  target-dir = "/l0/rust/target"
EOF
}

build_mold() {
  git clone --branch stable https://github.com/rui314/mold.git
  cd mold
  ./install-build-deps.sh
  cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_COMPILER=c++ -B build
  cmake --build build -j$(nproc)
  sudo cmake --build build --target install
}

init
# setup_lld
