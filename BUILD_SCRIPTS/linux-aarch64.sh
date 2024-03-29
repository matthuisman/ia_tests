#!/bin/bash
#Ubuntu 16.04 LTS

version=${1,,}

if [[ $version == "leia" ]]; then
    kodi_branch="Leia"
elif [[ $version == "matrix" ]]; then
    kodi_branch="Matrix"
elif [[ $version == "nexus" ]]; then
    kodi_branch="Nexus"
else
    echo "Version required (leia, matrix, nexus)"
    exit
fi

zip_name=linux-aarch64-$version.zip

cd $HOME

rm -rf kodi
rm -rf tools
rm -rf inputstream.adaptive
rm -r $zip_name

apt-get update && apt-get -y update
apt install -y --no-install-recommends build-essential git cmake crossbuild-essential-arm64

### CONFIRE KODI BUILD TOOLS ###
git clone https://github.com/xbmc/xbmc --branch $kodi_branch --depth 1 $HOME/kodi
cd $HOME/kodi/tools/depends
./bootstrap
./configure --host=aarch64-linux-gnu --disable-debug --prefix=$HOME/tools/kodi-depends

### ADD-ON SOURCE ###
git clone https://github.com/xbmc/inputstream.adaptive --branch $kodi_branch --depth 1 $HOME/inputstream.adaptive

### Clean ###
cd $HOME/kodi/cmake/addons && (git clean -xfd || rm -rf CMakeCache.txt CMakeFiles cmake_install.cmake build/*)

### CONFIGURE & BUILD ###
mkdir -p $HOME/kodi/cmake/addons/inputstream.adaptive/build/depends/share
cp -f $HOME/kodi/tools/depends/target/config-binaddons.site $HOME/kodi/cmake/addons/inputstream.adaptive/build/depends/share/config.site
sed "s|@CMAKE_FIND_ROOT_PATH@|$HOME/kodi/cmake/addons/inputstream.adaptive/build/depends|g" $HOME/kodi/tools/depends/target/Toolchain_binaddons.cmake > $HOME/kodi/cmake/addons/inputstream.adaptive/build/depends/share/Toolchain_binaddons.cmake

cd $HOME/kodi/cmake/addons/inputstream.adaptive

cmake -DCMAKE_BUILD_TYPE=Release -DOVERRIDE_PATHS=ON -DCMAKE_TOOLCHAIN_FILE=$HOME/kodi/cmake/addons/inputstream.adaptive/build/depends/share/Toolchain_binaddons.cmake -DADDONS_TO_BUILD=inputstream.adaptive -DADDON_SRC_PREFIX=$HOME -DADDONS_DEFINITION_DIR=$HOME/kodi/tools/depends/target/binary-addons/addons -DPACKAGE_ZIP=1 $HOME/kodi/cmake/addons
make package-inputstream.adaptive

### COPY ZIP ###
mv $HOME/kodi/cmake/addons/inputstream.adaptive/inputstream.adaptive-prefix/src/inputstream.adaptive-build/addon-inputstream.adaptive*.zip $HOME/$zip_name && cd $HOME && ls $zip_name
