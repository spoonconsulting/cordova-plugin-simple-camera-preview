#!/bin/bash
set -o nounset
set -o errexit

npm install -g cordova npx forever
npm install

# lint
npm run lint

# run tests 
if [[ "$TRAVIS_OS_NAME" == "osx" ]]; then
    gem install cocoapods
    pod repo update
    npm install -g ios-sim ios-deploy
    npm run test:ios
fi
if [[ "$TRAVIS_OS_NAME" == "linux" ]]; then
    echo no | android create avd --force -n test -t android-22 --abi armeabi-v7a
    emulator -avd test -no-audio -no-window &
    android-wait-for-emulator
    npm run test:android
fi