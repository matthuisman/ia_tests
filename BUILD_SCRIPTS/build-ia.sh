#!/bin/bash
#Ubuntu 16.04 LTS
IA_HOME="$(dirname "$(dirname "$(readlink "$0" || readlink -f "$0")")")"
ADDON_ID="inputstream.adaptive"
KODI_GIT="$HOME/kodi"
ANDROID_ROOT=$HOME/kodi-android-tools
CONFIGURE_EXTRA_OPTIONS=""
CMAKE_GENERATOR=""
CMAKE_TOOLSET=""

if [[ $# -eq 0 ]]; then
    echo "$0: usage: build-ia.sh [--android] --arch <arch> --kodiversion <version>"
    exit 4
fi
set -o errexit -o pipefail -o nounset
! getopt --test > /dev/null 
if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
    echo 'I’m sorry, `getopt --test` failed in this environment.'
    exit 1
fi

OPTIONS=ph:k:cnbr
LONGOPTS=platform:,arch:,kodiversion:,clean-deps,no-apt-install,clean-build,rebuild
! PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@")
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    exit 2
fi

eval set -- "$PARSED"
ARCH="" KODI_VERSION="" PLATFORM="" CLEAN_DEPS=""
NO_APT_INSTALL="" CLEAN_BUILD="" REBUILD=""
while true; do
    case "$1" in
        -p|--platform)
            PLATFORM="$2"
            shift 2
            ;;
        -h|--arch)
            ARCH="$2"
            shift 2
            ;;
        -k|--kodiversion)
            KODI_VERSION="$2"
            shift 2
            ;;
        -c|--clean-deps)
            CLEAN_DEPS=yes
            shift
            ;;
        -n|--no-apt-install)
            NO_APT_INSTALL=yes
            shift
            ;;
        -b|--clean-build)
            CLEAN_BUILD=yes
            shift
            ;;
        -r|--rebuild)
            REBUILD=yes
            shift
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Programming error"
            exit 3
            ;;
    esac
done

declare -A ARCHS=( ["linux-armv7"]="arm-linux-gnueabihf" \
                   ["linux-aarch64"]="aarch64-linux-gnu" \
                   ["linux-x86_64"]="x86_64-linux" \
                   ["android-armv7"]="arm-linux-androideabi" \
                   ["android-aarch64"]="aarch64-linux-android" \
                   ["darwin-x86_64"]="x86_64-apple-darwin" )

if [[ $KODI_VERSION == "leia" ]]; then
    KODI_BRANCH="Leia"
    NDK_VER="r18b"
elif [[ $KODI_VERSION == "matrix" ]]; then
    KODI_BRANCH="Matrix"
    NDK_VER="r20b"
else
    echo "Version required (leia or matrix)"
    exit 1
fi

case $ARCH in
    x86_64|x86|aarch64|armv7)
        ;;
    *)
        echo "arch not valid, must be one of [x86_64,aarch64,armv7,x86] (x86 windows only)"
        exit 3
        ;;
esac

case $PLATFORM in
    android|darwin|linux|windows)
        ;;
    *)
        echo "platform not valid, must be one of [android,darwin,linux,windows]"
        exit 3
        ;;
esac

ZIP_NAME=$PLATFORM-$ARCH-$KODI_VERSION-$(git -C $IA_HOME describe --always).zip

if [[ $REBUILD = yes ]]; then
    if [[ $CLEAN_BUILD = yes ]]; then
        cd $KODI_GIT/cmake/addons && (git clean -xfd || rm -rf CMakeCache.txt CMakeFiles cmake_install.cmake build/*)
    fi
    cd $KODI_GIT/cmake/addons/$ADDON_ID
    make package-$ADDON_ID
    mv $KODI_GIT/cmake/addons/$ADDON_ID/$ADDON_ID-prefix/src/$ADDON_ID-build/addon-$ADDON_ID*.zip $HOME/$ZIP_NAME && cd $HOME && ls $ZIP_NAME
    exit 0
fi

cd $HOME

if [[ $CLEAN_DEPS = yes ]]; then
    sudo rm -rf $KODI_GIT
    sudo rm -rf $ANDROID_ROOT
fi

rm -f $HOME/$ZIP_NAME

if [[ ! $NO_APT_INSTALL = yes ]]; then
    sudo apt-get update && sudo apt-get -y update
    sudo apt install -y --no-install-recommends build-essential git cmake
    if [[ $PLATFORM = android ]]; then
        sudo apt install -y --no-install-recommends unzip aria2 default-jdk python3
    elif [[ $ARCH = aarch64 ]] && [[ $PLATFORM = linux ]]; then
        sudo apt install -y --no-install-recommends crossbuild-essential-arm64
    elif [[ $ARCH = armv7 ]] && [[ $PLATFORM = linux ]]; then
        sudo apt install -y --no-install-recommends crossbuild-essential-armhf
    fi
fi

### ANDROID TOOLS ###
if [[ $PLATFORM = android ]]; then
    NDK_ZIP=android-ndk-$NDK_VER-linux-x86_64.zip
    SDK_ZIP=commandlinetools-linux-6609375_latest.zip
    aria2c -x 4 -s 4 https://dl.google.com/android/repository/$NDK_ZIP
    aria2c -x 4 -s 4 https://dl.google.com/android/repository/$SDK_ZIP

    mkdir -p $ANDROID_ROOT/android-sdk
    unzip -q $SDK_ZIP -d $ANDROID_ROOT/android-sdk && rm $HOME/$SDK_ZIP
    unzip -q $NDK_ZIP -d $ANDROID_ROOT && rm $NDK_ZIP

    cd $ANDROID_ROOT/android-sdk/tools/bin
    touch ../android
    echo yes | ./sdkmanager --sdk_root=$ANDROID_ROOT/android-sdk platform-tools
    echo yes | ./sdkmanager --sdk_root=$ANDROID_ROOT/android-sdk "platforms;android-28"
    echo yes | ./sdkmanager --sdk_root=$ANDROID_ROOT/android-sdk "build-tools;28.0.3"

    cd $ANDROID_ROOT/android-ndk-$NDK_VER/build/tools
    ./make-standalone-toolchain.sh --verbose --force --install-dir=$ANDROID_ROOT/toolchain --platform=android-21 --toolchain=${ARCHS[$PLATFORM-$ARCH]}
    TOOLCHAIN=$ANDROID_ROOT/toolchain
    CONFIGURE_EXTRA_OPTIONS="--with-ndk-api=21 --with-sdk-path=$ANDROID_ROOT/android-sdk --with-ndk-path=$ANDROID_ROOT/android-ndk-$NDK_VER  --with-toolchain=$TOOLCHAIN"
fi

### CONFIRE KODI BUILD TOOLS ###
if  [[ ! -d $KODI_GIT ]]; then
    git clone https://github.com/xbmc/xbmc --branch $KODI_BRANCH --depth 1 $KODI_GIT
else
    cd $KODI_GIT
    if (git rev-parse --verify $KODI_BRANCH); then
        git checkout $KODI_BRANCH
    else
        git remote set-branches --add origin $KODI_BRANCH
        git fetch --depth 1 origin $KODI_BRANCH
        git checkout $KODI_BRANCH
    fi
fi

if [[ $PLATFORM = darwin ]]; then
    CONFIGURE_EXTRA_OPTIONS="--with-sdk=10.15 --with-platform=macos"
    if [[ $KODI_VERSION = leia ]]; then
        gsed -i '/10\.14);;/a\          10\.15);;' $KODI_GIT/tools/depends/configure.ac
        CONFIGURE_EXTRA_OPTIONS="--with-sdk=10.15"
    else
        CONFIGURE_EXTRA_OPTIONS="--with-sdk=10.15 --with-platform=macos"
    fi
fi

if [[ $PLATFORM != windows ]]; then
    cd $KODI_GIT/tools/depends
    ./bootstrap
    ./configure --host=${ARCHS[$PLATFORM-$ARCH]} --disable-debug --prefix=$HOME/xbmc-depends $CONFIGURE_EXTRA_OPTIONS
    CMAKE_GENERATOR="Unix Makefiles"
else
    case $ARCH in
        x86_64)
            HOST="x64"
            CMAKE_GENERATOR="Visual Studio 15 2017 Win64"
            ;;
        x86)
            HOST="x86"
            CMAKE_GENERATOR="Visual Studio 15 2017"
            ;;
        *)
            echo "arch not valid for windows, must be one of [x86_64,x86]"
            exit 3
            ;;
    esac
    CMAKE_TOOLSET="-T host=$HOST"
fi

### ADD-ON SOURCE ###
cd $IA_HOME
git checkout "${KODI_VERSION^}" || git branch "${KODI_VERSION^}" # if tag is checked out
    
### Clean ###
if [[ $CLEAN_BUILD = yes ]]; then
    cd $KODI_GIT/cmake/addons && (git clean -xfd || rm -rf CMakeCache.txt CMakeFiles cmake_install.cmake build/*)
fi
### CONFIGURE & BUILD ###

mkdir -p $KODI_GIT/tools/depends/target/binary-addons/addons2/$ADDON_ID && cd "$_"
echo "all" > platforms.txt
echo "$ADDON_ID https://github.com/xbmc/$ADDON_ID $KODI_BRANCH" > $ADDON_ID.txt


TOOLCHAIN_OPTION=""
if [[ $PLATFORM != windows ]]; then
    TOOLCHAIN_OPTION="-DCMAKE_TOOLCHAIN_FILE=$KODI_GIT/cmake/addons/$ADDON_ID/build/depends/share/Toolchain_binaddons.cmake"
    mkdir -p $KODI_GIT/cmake/addons/$ADDON_ID/build/depends/share
    cp -f $KODI_GIT/tools/depends/target/config-binaddons.site $KODI_GIT/cmake/addons/$ADDON_ID/build/depends/share/config.site
    sed "s|@CMAKE_FIND_ROOT_PATH@|$KODI_GIT/cmake/addons/$ADDON_ID/build/depends|g" $KODI_GIT/tools/depends/target/Toolchain_binaddons.cmake > $KODI_GIT/cmake/addons/$ADDON_ID/build/depends/share/Toolchain_binaddons.cmake
    cd $KODI_GIT/cmake/addons/$ADDON_ID
    
else
    mkdir -p $IA_HOME/build && cd "$_"
fi

cmake -G "$CMAKE_GENERATOR" $CMAKE_TOOLSET -DCMAKE_BUILD_TYPE=Release -DOVERRIDE_PATHS=ON $TOOLCHAIN_OPTION -DADDONS_TO_BUILD=$ADDON_ID -DADDON_SRC_PREFIX="$(dirname "$IA_HOME")" -DADDONS_DEFINITION_DIR=$KODI_GIT/tools/depends/target/binary-addons/addons2 -DPACKAGE_ZIP=1 $KODI_GIT/cmake/addons
if [[ $PLATFORM != windows ]]; then
    make package-$ADDON_ID
    mv $KODI_GIT/cmake/addons/$ADDON_ID/$ADDON_ID-prefix/src/$ADDON_ID-build/addon-$ADDON_ID*.zip $HOME/$ZIP_NAME && cd $HOME && ls $ZIP_NAME
else
    cmake --build . --config Release --target package-$ADDON_ID
    mv $HOME/AppData/Local/Temp/addon-$ADDON_ID*.zip $HOME/$ZIP_NAME && cd $HOME && ls $ZIP_NAME
fi
