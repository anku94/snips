#!/usr/bin/env bash
cd /Users/schwifty/Repos/rust-exps/interop-2/build

# /Library/Developer/CommandLineTools/usr/bin/c++  \
# 	-I/Users/schwifty/Repos/rust-exps/interop-2/include \
# 	-I/Users/schwifty/Repos/rust-exps/interop-2/rust_lib \
# 	-isystem /Users/schwifty/Repos/rust-exps/interop-2/build/rust_lib \
# 	-std=gnu++14 \
# 	-arch arm64 \
# 	-isysroot /Library/Developer/CommandLineTools/SDKs/MacOSX14.4.sdk \
# 	-MD \
# 	-MT CMakeFiles/main.dir/src/main.cpp.o \
# 	-MF CMakeFiles/main.dir/src/main.cpp.o.d \
# 	-o CMakeFiles/main.dir/src/main.cpp.o \
# 	-c /Users/schwifty/Repos/rust-exps/interop-2/src/main.cpp

# /Library/Developer/CommandLineTools/usr/bin/c++  \
  /usr/bin/g++  -E -dD \
	-I/Users/schwifty/Repos/rust-exps/interop-2/include \
 	-isysroot /Library/Developer/CommandLineTools/SDKs/MacOSX14.4.sdk \
	-I/Users/schwifty/Repos/rust-exps/interop-2/rust_lib \
	-I/Users/schwifty/Repos/rust-exps/interop-2/build/rust_lib \
  -o /tmp/abc.o \
	-c /Users/schwifty/Repos/rust-exps/interop-2/src/main.cpp
