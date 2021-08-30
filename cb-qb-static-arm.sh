#! /usr/bin/env bash

#libtorrent是qBittorrent必要的后端程序，对软件性能有直接影响。

#libtorrent 1.0.11: 非常稳定，适合长时间使用，但已经很旧了，不建议使用。
#libtorrent 1.1.14: 性能更好，对高速种子比较友好，非常稳定，适合长时间使用，建议使用。
#libtorrent 1.2.10: 没用过，但是小问题应该也修得差不多了，是qBittorrent4.3.0的默认版本
#libtorrent 2.0   : 没用过，应该不稳定，不建议使用

#libtorrent 1.0.11: 适用于qBittorrent3.3.11-4.1.3
#libtorrent 1.1.14: 适用于qBittorrent4.0.0或更新版本
#libtorrent 1.2.10 : 适用于qBittorrent4.2.0或更新版本

#qBittorrent 4.1.4或更新版本: 要求libtorrent ≥ 1.1.10
#qBittorrent 4.3.0或更新版本: 要求libtorrent ≥ 1.2.0

#下面请根据qBittorrent版本安装所需的libtorrent，如果看不懂的话：
#如果你想安装qBittorrent4.0.0-4.2.5，请安装libtorrent 1.1.14
#如果你想安装qBittorrent4.3.0或更新版本，请安装libtorrent 1.2.11
#如果你想安装qBittorrent4.3.3或更新版本，请安装libtorrent 1.2.12

# 4.3.3 以上需要 C++17，其它 C++14

set -e

apk add bash bash-completion build-base curl pkgconf autoconf automake libtool git perl python2 python2-dev python3 python3-dev py3-numpy linux-headers

OPENSSL_TAG=OpenSSL_1_1_1l
[ -n "$1" ] && QBITTORRENT_TAG="$1" || QBITTORRENT_TAG=4.3.8
IS_PT_VER=$(awk 'BEGIN{ print "'$QBITTORRENT_TAG'"<"'4.2'" }')
HIGH_PT_VER=$(awk 'BEGIN{ print "'$QBITTORRENT_TAG'"<"'4.3.4'" }')
[ "$IS_PT_VER" -eq 1 ] && LIBTORRENT_TAG=libtorrent-1_1_14 || LIBTORRENT_TAG=v1.2.13
[ "$HIGH_PT_VER" -eq 0 ] && LIBTORRENT_STATIC_FILE="libtorrent-rasterbar.a" || LIBTORRENT_STATIC_FILE="libtorrent.a"
QT5_TAG=v5.15.2
BOOST_VER=1.77.0
BOOST_BUILD_TAG=boost-$BOOST_VER
STANDARD="c++17"
PATH=/usr/lib/ccache:$PATH

result_dir="$(printf "%s" "$(pwd <(dirname "${0}"))")"

[ -n "$2" -a "$2" = "reset" ] && {
    rm -rf work
    mkdir work
    cd work
    mkdir arm
} || {
    [ -e work ] && {
        cd work
    } || {
        echo "No work base, exit..."
        exit
    }
    rm -rf qBittorrent/
    rm -rf libtorrent/
    [ -e arm ] || {
        echo "No arm base, exit..."
        exit
    }
}

install_dir="`pwd`/arm"
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
rm -rf openssl/ > /dev/null 2>&1
git clone https://github.com/openssl/openssl.git --branch $OPENSSL_TAG --single-branch --depth 1
cd openssl
custom_flags_set
./Configure linux-armv4 --cross-compile-prefix=arm-linux-musleabi- --prefix="${install_dir}" threads no-shared no-dso no-comp CXXFLAGS="${CXXFLAGS}" CPPFLAGS="${CPPFLAGS}" LDFLAGS="${LDFLAGS}"
make -j${nproc}
make install_sw install_ssldirs
cd ..

#zlib
rm -rf zlib/ > /dev/null 2>&1
git clone https://github.com/madler/zlib.git
cd zlib
custom_flags_set
CC=arm-linux-musleabi-gcc ./configure --prefix="${install_dir}" --static
make -j"$(nproc)" CXXFLAGS="${CXXFLAGS}" CPPFLAGS="${CPPFLAGS}" LDFLAGS="${LDFLAGS}"
make install
cd ..


#boost
rm -rf boost/ > /dev/null 2>&1
rm -rf "${install_dir}/boost/" > /dev/null 2>&1
git clone --recursive --single-branch --branch boost-$BOOST_VER --depth=1 -j$(nproc) --shallow-submodules https://github.com/boostorg/boost.git
mv -f boost/ "${install_dir}/boost"
#tar xvf "${result_dir}"/boost_1_77_0.tar.gz
#mv -f boost_1_77_0/ "${install_dir}/boost"
cd "${install_dir}/boost"
echo "using gcc : arm : /opt/cross/bin/arm-linux-musleabi-g++ ;" > ~/user-config.jam
custom_flags_set
./bootstrap.sh
./b2 --without-atomic --without-math --without-context --without-coroutine --without-fiber --without-python --without-graph_parallel --without-mpi toolset=gcc-arm -j"$(nproc)" variant=release threading=multi link=static cxxflags="${CXXFLAGS}" cflags="${CPPFLAGS}" linkflags="${LDFLAGS}" install --prefix="${install_dir}"
cd ../..


#qtbase
rm -rf qtbase/ > /dev/null 2>&1
git clone https://github.com/qt/qtbase.git --branch $QT5_TAG --single-branch --depth 1
cd qtbase
sed -i 's/arm-linux-gnu/arm-linux-musleabi/g' ./mkspecs/linux-arm-gnueabi-g++/qmake.conf
[ -f config.cache ] && rm config.cache
custom_flags_set
./configure -xplatform linux-arm-gnueabi-g++ -prefix "${install_dir}" -opensource -confirm-license -release -openssl-linked -static -c++std c++14 -no-feature-c++17 -qt-pcre -no-iconv -no-feature-glib -no-feature-opengl -no-feature-dbus -no-feature-gui -no-feature-widgets -no-feature-testlib -no-compile-examples -I "$include_dir" -L "$lib_dir" QMAKE_LFLAGS="$LDFLAGS"
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
rm -rf libtorrent > /dev/null 2>&1
git clone https://github.com/arvidn/libtorrent.git --branch $LIBTORRENT_TAG --single-branch --depth 1
cd libtorrent
echo "using gcc : arm : /opt/cross/bin/arm-linux-musleabi-g++ ;" > ~/user-config.jam
#edit Jamfile ---> 	local boost-include-path =
custom_flags_set
BOOST_ROOT="${install_dir}/boost" BOOST_INCLUDEDIR="${install_dir}/boost" BOOST_BUILD_PATH="${install_dir}/boost" "${install_dir}/boost/b2" -j"$(nproc)" toolset=gcc-arm dht=on encryption=on crypto=openssl i2p=on extensions=on variant=release threading=multi link=static boost-link=static runtime-link=static cxxflags="${CXXFLAGS}" cflags="${CPPFLAGS}" linkflags="${LDFLAGS}" install --prefix="${install_dir}"
cd ..

}

#echo "Done!" && exit

#qbittorrent
rm -rf qBittorrent > /dev/null 2>&1
git clone https://github.com/qbittorrent/qBittorrent.git --branch release-$QBITTORRENT_TAG --single-branch --depth 1
cd qBittorrent
custom_flags_set
./bootstrap.sh
./configure --prefix="${install_dir}" "${local_boost}" --disable-gui --disable-qt-dbus --host=arm-linux-musleabi CXXFLAGS="${CXXFLAGS}" CPPFLAGS="${CPPFLAGS}" LDFLAGS="${LDFLAGS} -l:libboost_system.a" openssl_CFLAGS="-I${include_dir}" openssl_LIBS="-L${lib_dir} -l:libcrypto.a -l:libssl.a" libtorrent_CFLAGS="-I${include_dir}" libtorrent_LIBS="-L${lib_dir} -l:${LIBTORRENT_STATIC_FILE}" zlib_CFLAGS="-I${include_dir}" zlib_LIBS="-L${lib_dir} -l:libz.a" QT_QMAKE="${install_dir}/bin"
sed -i 's/-lboost_system//; s/-lcrypto//; s/-lssl//' conf.pri
make -j$(nproc) VERBOSE=1 all
cp src/qbittorrent-nox "${result_dir}/arm-qbittorrent-nox-${QBITTORRENT_TAG}"
arm-linux-musleabi-strip "${result_dir}/arm-qbittorrent-nox-${QBITTORRENT_TAG}"
file "${result_dir}/arm-qbittorrent-nox-${QBITTORRENT_TAG}"
tar czvf ${result_dir}/arm-qbittorrent-nox-${QBITTORRENT_TAG}.tar.gz
echo "Copy ${result_dir}/arm-qbittorrent-nox-${QBITTORRENT_TAG} to you arm device and test it."
