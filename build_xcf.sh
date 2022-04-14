#!/bin/bash

#set -x

rm -rf frameworks/*.xcframework

# Download names and shas to download bottles from homebrew
libs=("libplist" "libusbmuxd" "libimobiledevice")
shas_x86_64=("02291f2f28099a73de8fa37b49962fe575a434be63af356cceff9200c6d73f37" "67c3d43cb2a1ebfd68fba1c9b51b419288fedefc93f101adeea1b5f6bdf1ad77" "072d224a0fa2a77bccde27eee39b65300a387613b41f07fc677108a7812ec003")
shas_arm64=("ed9c2d665d5700c91f099bd433a38ba904b63eef4d3cdc47bd0f6b0229ac689a" "9cd9d1df802799e026f09775bbde2c4bf0557fb3e1f5919f14a5b0def0b0255e" "41a64c9856f7845bb4c21bba4f42eb55c640301b59c032eb4db416db19ecf97d")

processLibrary() {
    lib=$1
    arch=$2
    sha=$3
    echo "Download..."
    curl -s -L -H "Authorization: Bearer QQ==" -o ${lib}.tar.gz https://ghcr.io/v2/homebrew/core/${lib}/blobs/sha256:${sha}
    echo "Extract library..."
    tar -xf ${lib}.tar.gz
    file=$(find ./${lib} -name "${lib}-*.a")
    echo "Move library..."
    mkdir -p "lib"
    cp ${file} lib/${lib}-${arch}".a"
    echo "Cleanup..."
    rm -rf ${lib}
    rm -rf ${lib}.tar.gz
}

for i in "${!libs[@]}"; do
    lib=${libs[i]}

    echo "Process x86_64 bottle:" ${lib}
    processLibrary $lib "x86_64" ${shas_x86_64[i]}
    echo "Process arm64 bottle:" ${lib}
    processLibrary $lib "arm64" ${shas_arm64[i]}

    echo "Create fat binary..."
    lipo ./lib/${lib}-x86_64.a ./lib/${lib}-arm64.a -create -output /tmp/${lib}.a
    echo "Create xcframework..."
    name=$(echo $lib | sed 's/lib//')
    xcodebuild -create-xcframework -library /tmp/${lib}.a -headers include/${lib} -output frameworks/${name}.xcframework
done

echo "Cleanup..."
rm -rf lib
