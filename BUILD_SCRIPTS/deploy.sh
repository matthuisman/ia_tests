#!/bin/bash
while getopts ":k:r:" opt; do
  case $opt in
    k) KODI_VERSION="$OPTARG"
    ;;
    r) REPO="$OPTARG"
    ;;
    \?) echo "Invalid option -$OPTARG" >&2
    ;;
  esac
done

cd $HOME/.deploy
git checkout travis-build-$TRAVIS_BUILD_NUMBER 2>/dev/null || git checkout -b travis-build-$TRAVIS_BUILD_NUMBER
mkdir -p $HOME/.deploy/$REPO/$KODI_VERSION
cd $HOME/.deploy/$REPO/$KODI_VERSION
for f in $(find $HOME/zips -name '*.zip'); do
    mkdir -p $TRAVIS_BUILD_DIR/.build/$REPO/$KODI_VERSION/$(basename "$f" .zip)
    unzip $f -d $TRAVIS_BUILD_DIR/.build/$REPO/$KODI_VERSION/$(basename "$f" .zip)
    python3 $TRAVIS_BUILD_DIR/manage_repo.py $TRAVIS_BUILD_DIR -b $TRAVIS_BUILD_DIR/.build/$REPO/$KODI_VERSION/$(basename "$f" .zip)/${APP_ID}
    ret=$?
    if [ $ret -ne 0 ]; then
      exit $ret
    fi
done

cd $HOME/.deploy/
git config --global user.email "travis@travis-ci.org"
git config --global user.name "Travis CI"
git config credential.helper "store --file=.git/credentials"
echo "https://${GH_TOKEN}:@github.com" > .git/credentials
git add .
git commit --allow-empty -m "Update $(basename `git -C $TRAVIS_BUILD_DIR rev-parse --show-toplevel`) to $TRAVIS_TAG"
git push --set-upstream origin travis-build-$TRAVIS_BUILD_NUMBER
