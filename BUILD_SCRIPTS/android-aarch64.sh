#!/bin/bash
#Ubuntu 16.04 LTS

version=${1,,}

if [[ $version == "leia" ]]; then
    kodi_branch="Leia"
    ndk_ver="r18b"
elif [[ $version == "matrix" ]]; then
    kodi_branch="Matrix"
    ndk_ver="r20b"
elif [[ $version == "nexus" ]]; then
    kodi_branch="Nexus"
    ndk_ver="r20b"
else
    echo "Version required (leia, matrix, nexus)"
    exit
fi

zip_name=android-aarch64-$version.zip

cd $HOME

rm -rf kodi
rm -rf tools
rm -rf .android
rm -rf inputstream.adaptive
rm -r $zip_name

apt-get update && apt-get -y update
apt install -y --no-install-recommends build-essential git cmake unzip aria2 default-jdk python3
rm -r /usr/bin/python
ln -s /usr/bin/python3 /usr/bin/python

### ANDROID TOOLS ###
aria2c -x 4 -s 4 https://dl.google.com/android/repository/android-ndk-$ndk_ver-linux-x86_64.zip
aria2c -x 4 -s 4 https://dl.google.com/android/repository/commandlinetools-linux-6609375_latest.zip

mkdir -p $HOME/tools/android-sdk
unzip commandlinetools-linux*.zip -d $HOME/tools/android-sdk && rm $HOME/commandlinetools-linux*.zip
unzip android-ndk-*.zip -d $HOME/tools && mv $HOME/tools/android-ndk-* $HOME/tools/android-ndk && rm android-ndk-*.zip

cd $HOME/tools/android-sdk/tools/bin
touch ../android
yes | ./sdkmanager --sdk_root=$HOME/tools/android-sdk platform-tools
yes | ./sdkmanager --sdk_root=$HOME/tools/android-sdk "platforms;android-28"
yes | ./sdkmanager --sdk_root=$HOME/tools/android-sdk "build-tools;28.0.3"

cd $HOME/tools/android-ndk/build/tools
./make-standalone-toolchain.sh --verbose --force --install-dir=$HOME/tools/toolchain --platform=android-21 --toolchain=aarch64-linux-android
toolchain=$HOME/tools/toolchain

### CONFIRE KODI BUILD TOOLS ###
git clone https://github.com/xbmc/xbmc --branch $kodi_branch --depth 1 $HOME/kodi
cd $HOME/kodi/tools/depends
./bootstrap
./configure --host=aarch64-linux-android --with-ndk-api=21 --with-sdk-path=$HOME/tools/android-sdk --with-ndk-path=$HOME/tools/android-ndk --with-toolchain=$toolchain --disable-debug --prefix=$HOME/tools/xbmc-depends

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
