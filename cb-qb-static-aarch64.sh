#! /usr/bin/env bash
set -e

apk add bash bash-completion build-base curl pkgconf autoconf automake libtool git perl python3 python3-dev py3-numpy linux-headers

OPENSSL_TAG=OpenSSL_1_1_1h
[ -n "$1" ] && QBITTORRENT_TAG="$1" || QBITTORRENT_TAG=v4_3_x
LIBTORRENT_TAG=v1.2.11
QT5_TAG=v5.15.1
BOOST_VER=1.74.0
BOOST_BUILD_TAG=boost-$BOOST_VER
PATH=/usr/lib/ccache:$PATH

[ -n "$2" -a "$2" = "reset" ] && {
rm -rf work
mkdir work
cd work
mkdir aarch64
} || {
[ -e work ] && cd work || echo "No work base, exit...";exit
rm -rf qBittorrent/
[ -e aarch64 ] || echo "No aarch64 base, exit...";exit
}

install_dir=`pwd`/aarch64
include_dir="${install_dir}/include"
lib_dir="${install_dir}/lib"

PATH="${install_dir}/bin:${HOME}/bin${PATH:+:${PATH}}"
LD_LIBRARY_PATH="-L${lib_dir}"
PKG_CONFIG_PATH="-L${lib_dir}/pkgconfig"
local_boost="--with-boost=${install_dir}"
local_openssl="--with-openssl=${install_dir}"

custom_flags_set() {
	CXXFLAGS="-std=c++14"
	CPPFLAGS="--static -static -I${include_dir}"
	LDFLAGS="--static -static -Wl,--no-as-needed -L${lib_dir} -lpthread -pthread"
}

custom_flags_reset() {
	CXXFLAGS="-std=c++14"
	CPPFLAGS=""
	LDFLAGS=""
}

custom_flags_reset

[ -n "$2" -a "$2" = "reset" ] && {

#openssl
git clone https://github.com/openssl/openssl.git --branch $OPENSSL_TAG --single-branch --depth 1
cd openssl
custom_flags_set
./Configure linux-aarch64 --cross-compile-prefix=aarch64-linux-musl- --prefix="${install_dir}" threads no-shared no-dso no-comp CXXFLAGS="${CXXFLAGS}" CPPFLAGS="${CPPFLAGS}" LDFLAGS="${LDFLAGS}"
make -j${nproc}
make install_sw install_ssldirs
cd ..

#zlib
git clone https://github.com/madler/zlib.git
cd zlib
custom_flags_set
CC=aarch64-linux-musl-gcc ./configure --prefix="${install_dir}" --static
make -j"$(nproc)" CXXFLAGS="${CXXFLAGS}" CPPFLAGS="${CPPFLAGS}" LDFLAGS="${LDFLAGS}"
make install
cd ..

#boost
git clone --recursive --single-branch --branch boost-$BOOST_VER --depth=1 -j$(nproc) --shallow-submodules https://github.com/boostorg/boost.git
mv boost/ "${install_dir}/boost"
cd "${install_dir}/boost"
echo "using gcc : arm : /opt/cross/bin/aarch64-linux-musl-g++ ;" > ~/user-config.jam
custom_flags_set
./bootstrap.sh
./b2 toolset=gcc-arm -j"$(nproc)" variant=release threading=multi link=static cxxflags=-std=c++14 cxxflags="${CXXFLAGS}" cflags="${CPPFLAGS}" linkflags="${LDFLAGS}" install --prefix="${install_dir}"
cd ../..

#qtbase
git clone https://github.com/qt/qtbase.git --branch $QT5_TAG --single-branch --depth 1
cd qtbase
sed -i 's/aarch64-linux-gnu/aarch64-linux-musl/g' ./mkspecs/linux-aarch64-gnu-g++/qmake.conf
[ -f config.cache ] && rm config.cache
custom_flags_set
./configure -xplatform linux-aarch64-gnu-g++ -prefix "${install_dir}" "${icu}" -opensource -confirm-license -release -openssl-linked -static -c++std c++14 -no-feature-c++17 -qt-pcre -no-iconv -no-feature-glib -no-feature-opengl -no-feature-dbus -no-feature-gui -no-feature-widgets -no-feature-testlib -no-compile-examples -I "$include_dir" -L "$lib_dir" QMAKE_LFLAGS="$LDFLAGS"
./configure -xplatform linux-aarch64-gnu-g++ -prefix "${install_dir}" -opensource -confirm-license -release -openssl-linked -static -c++std c++14 -no-feature-c++17 -qt-pcre -no-iconv -no-feature-glib -no-feature-opengl -no-feature-dbus -no-feature-gui -no-feature-widgets -no-feature-testlib -no-compile-examples -I "$include_dir" -L "$lib_dir" QMAKE_LFLAGS="$LDFLAGS"
make -j$(nproc) VERBOSE=1 all
make install
cd ..

#qttools
git clone https://github.com/qt/qttools.git --branch $QT5_TAG --single-branch --depth 1
cd qttools
custom_flags_set
BOOST_ROOT="${install_dir}/boost"
"${install_dir}/bin/qmake" -set prefix "${install_dir}"
"${install_dir}/bin/qmake" QMAKE_CXXFLAGS="-static" QMAKE_LFLAGS="-static"
make -j$(nproc) VERBOSE=1 all
make install
cd ..

#libtorrent
rm -rf libtorrent
git clone https://github.com/arvidn/libtorrent.git --branch $LIBTORRENT_TAG --single-branch --depth 1
cd libtorrent
echo "using gcc : arm : /opt/cross/bin/aarch64-linux-musl-g++ ;" > ~/user-config.jam
#edit Jamfile ---> 	local boost-include-path =
custom_flags_set
BOOST_ROOT="${install_dir}/boost" BOOST_INCLUDEDIR="${install_dir}/boost" BOOST_BUILD_PATH="${install_dir}/boost" "${install_dir}/boost/b2" -j"$(nproc)" toolset=gcc-arm dht=on encryption=on crypto=openssl i2p=on extensions=on variant=release threading=multi link=static boost-link=static runtime-link=static cxxflags="${CXXFLAGS}" cflags="${CPPFLAGS}" linkflags="${LDFLAGS}" install --prefix="${install_dir}"
cd ..

#echo "Done!" && exit
}

#qbittorrent
git clone https://github.com/qbittorrent/qBittorrent.git --branch $QBITTORRENT_TAG --single-branch --depth 1
cd qBittorrent
custom_flags_set
./bootstrap.sh
./configure --prefix="${install_dir}" "${local_boost}" --disable-gui --disable-qt-dbus --host=aarch64-linux-musl CXXFLAGS="${CXXFLAGS}" CPPFLAGS="${CPPFLAGS}" LDFLAGS="${LDFLAGS} -l:libboost_system.a" openssl_CFLAGS="-I${include_dir}" openssl_LIBS="-L${lib_dir} -l:libcrypto.a -l:libssl.a" libtorrent_CFLAGS="-I${include_dir}" libtorrent_LIBS="-L${lib_dir} -l:libtorrent.a" zlib_CFLAGS="-I${include_dir}" zlib_LIBS="-L${lib_dir} -l:libz.a" QT_QMAKE="${install_dir}/bin"
#    ./configure --disable-gui --disable-qt-dbus --host=aarch64-linux-musl --with-boost-libdir=`pwd`/../arm/lib
#sed -i 's/-lboost_system//; s/-lcrypto//; s/-lssl//; s/libssl.so/libssl.a/; s/libcrypto.so/libcrypto.a -ldl -lz' conf.pri
sed -i 's/-lboost_system//; s/-lcrypto//; s/-lssl//' conf.pri
make -j$(nproc) VERBOSE=1 all
aarch64-linux-musl-strip src/qbittorrent-nox
file src/qbittorrent-nox
src/qbittorrent-nox -v

