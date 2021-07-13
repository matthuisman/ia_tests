git clone https://github.com/xbmc/xbmc -b Leia --depth=1 kodi
git clone https://github.com/xbmc/inputstream.adaptive -b Leia --depth=1 inputstream.adaptive

mkdir inputstream.adaptive\build
cd inputstream.adaptive\build

cmake -T host=x64 -G "Visual Studio 15 2017 Win64" -DADDONS_TO_BUILD=inputstream.adaptive -DCMAKE_BUILD_TYPE=Release -DADDON_SRC_PREFIX=../.. -DPACKAGE_ZIP=1 ../../kodi/cmake/addons
cmake --build . --config Release --target package-inputstream.adaptive
move %temp%\addon-inputstream.adaptive*.zip ../..

cd ../..
