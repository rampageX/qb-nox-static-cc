#! /usr/bin/env bash

#libtorrent是qBittorrent必要的後端程序，對軟件性能有直接影響。

#libtorrent 1.0.11: 非常穩定，適合長時間使用，但已經很舊了，不建議使用。
#libtorrent 1.1.14: 性能更好，對高速種子比較友好，非常穩定，適合長時間使用，建議使用。
#libtorrent 1.2.10: 沒用過，但是小問題應該也修得差不多了，是qBittorrent4.3.0的默認版本
#libtorrent 2.0   : 沒用過，應該不穩定，不建議使用

#libtorrent 1.0.11: 適用於qBittorrent3.3.11-4.1.3
#libtorrent 1.1.14: 適用於qBittorrent4.0.0或更新版本
#libtorrent 1.2.10 : 適用於qBittorrent4.2.0或更新版本

#qBittorrent 4.1.4或更新版本: 要求libtorrent ≥ 1.1.10
#qBittorrent 4.3.0或更新版本: 要求libtorrent ≥ 1.2.0

#下面請根據qBittorrent版本安裝所需的libtorrent，如果看不懂的話：
#如果你想安裝qBittorrent4.0.0-4.2.5，請安裝libtorrent 1.1.14
#如果你想安裝qBittorrent4.3.0或更新版本，請安裝libtorrent 1.2.11
#如果你想安裝qBittorrent4.3.3或更新版本，請安裝libtorrent 1.2.12

# 4.3.3 以上需要 C++17，其它 C++14

set -e

apk add bash bash-completion build-base curl pkgconf autoconf automake libtool git perl python2 python2-dev python3 python3-dev py3-numpy linux-headers

OPENSSL_TAG=OpenSSL_1_1_1k
[ -n "$1" ] && QBITTORRENT_TAG="$1" || QBITTORRENT_TAG=4.3.5
IS_PT_VER=$(awk 'BEGIN{ print "'$QBITTORRENT_TAG'"<"'4.2'" }')
HIGH_PT_VER=$(awk 'BEGIN{ print "'$QBITTORRENT_TAG'"<"'4.3.4'" }')
[ "$IS_PT_VER" -eq 1 ] && LIBTORRENT_TAG=libtorrent-1_1_14 || LIBTORRENT_TAG=v1.2.13
[ "$HIGH_PT_VER" -eq 0 ] && LIBTORRENT_STATIC_FILE="libtorrent-rasterbar.a" || LIBTORRENT_STATIC_FILE="libtorrent.a"
QT5_TAG=v5.15.2
BOOST_VER=1.76.0
BOOST_BUILD_TAG=boost-$BOOST_VER
STANDARD="c++17"
PATH=/usr/lib/ccache:$PATH

result_dir="$(printf "%s" "$(pwd <(dirname "${0}"))")"

[ -n "$2" -a "$2" = "reset" ] && {
    rm -rf work
    mkdir work
    cd work
    mkdir aarch64
} || {
    [ -e work ] && {
        cd work
    } || {
        echo "No work base, exit..."
        exit
    }
    rm -rf qBittorrent/
    rm -rf libtorrent/
    [ -e aarch64 ] || {
        echo "No aarch64 base, exit..."
        exit
    }
}

install_dir="`pwd`/aarch64"
include_dir="${install_dir}/include"
lib_dir="${install_dir}/lib"

PATH="${install_dir}/bin:${HOME}/bin${PATH:+:${PATH}}"
LD_LIBRARY_PATH="-L${lib_dir}"
PKG_CONFIG_PATH="-L${lib_dir}/pkgconfig"
local_boost="--with-boost=${install_dir}"
local_openssl="--with-openssl=${install_dir}"

custom_flags_set() {
    CXXFLAGS="-std=${STANDARD}"
    CPPFLAGS="--static -static -I${include_dir}"
    LDFLAGS="--static -static -Wl,--no-as-needed -L${lib_dir} -lpthread -pthread"
}

custom_flags_reset() {
    CXXFLAGS="-std=${STANDARD}"
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
echo "using gcc : aarch64 : /opt/cross/bin/aarch64-linux-musl-g++ ;" > ~/user-config.jam
custom_flags_set
./bootstrap.sh
./b2 toolset=gcc-aarch64 -j"$(nproc)" variant=release threading=multi link=static cxxflags=-std=c++14 cxxflags="${CXXFLAGS}" cflags="${CPPFLAGS}" linkflags="${LDFLAGS}" install --prefix="${install_dir}"
cd ../..

#qtbase
git clone https://github.com/qt/qtbase.git --branch $QT5_TAG --single-branch --depth 1
cd qtbase
sed -i 's/aarch64-linux-gnu/aarch64-linux-musl/g' ./mkspecs/linux-aarch64-gnu-g++/qmake.conf
[ -f config.cache ] && rm config.cache
custom_flags_set
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
}

#libtorrent
rm -rf libtorrent
git clone https://github.com/arvidn/libtorrent.git --branch $LIBTORRENT_TAG --single-branch --depth 1
cd libtorrent
echo "using gcc : aarch64 : /opt/cross/bin/aarch64-linux-musl-g++ ;" > ~/user-config.jam
#edit Jamfile ---> 	local boost-include-path =
custom_flags_set
BOOST_ROOT="${install_dir}/boost" BOOST_INCLUDEDIR="${install_dir}/boost" BOOST_BUILD_PATH="${install_dir}/boost" "${install_dir}/boost/b2" -j"$(nproc)" toolset=gcc-aarch64 dht=on encryption=on crypto=openssl i2p=on extensions=on variant=release threading=multi link=static boost-link=static runtime-link=static cxxflags="${CXXFLAGS}" cflags="${CPPFLAGS}" linkflags="${LDFLAGS}" install --prefix="${install_dir}"
cd ..

#echo "Done!" && exit


#qbittorrent
#rm -rf qBittorrent
git clone https://github.com/qbittorrent/qBittorrent.git --branch release-$QBITTORRENT_TAG --single-branch --depth 1
cd qBittorrent
custom_flags_set
./bootstrap.sh
./configure --prefix="${install_dir}" "${local_boost}" --disable-gui --disable-qt-dbus --host=aarch64-linux-musl CXXFLAGS="${CXXFLAGS}" CPPFLAGS="${CPPFLAGS}" LDFLAGS="${LDFLAGS} -l:libboost_system.a" openssl_CFLAGS="-I${include_dir}" openssl_LIBS="-L${lib_dir} -l:libcrypto.a -l:libssl.a" libtorrent_CFLAGS="-I${include_dir}" libtorrent_LIBS="-L${lib_dir} -l:${LIBTORRENT_STATIC_FILE}" zlib_CFLAGS="-I${include_dir}" zlib_LIBS="-L${lib_dir} -l:libz.a" QT_QMAKE="${install_dir}/bin"
sed -i 's/-lboost_system//; s/-lcrypto//; s/-lssl//' conf.pri
make -j$(nproc) VERBOSE=1 all
cp src/qbittorrent-nox "${result_dir}/aarch64-qbittorrent-nox-${QBITTORRENT_TAG}"
aarch64-linux-musl-strip "${result_dir}/aarch64-qbittorrent-nox-${QBITTORRENT_TAG}"
file "${result_dir}/aarch64-qbittorrent-nox-${QBITTORRENT_TAG}"
echo "Copy ${result_dir}/aarch64-qbittorrent-nox-${QBITTORRENT_TAG} to you aarch64 device and test it."
