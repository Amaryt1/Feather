#!/usr/bin/env bash
set -eu
work=$1
cp -R Zsign/Upstream "$work/native-signer"
cp Zsign/bundle.cpp "$work/native-signer/src/"
make -C "$work/native-signer/build/linux" -j2
src="$work/native-signer/src"
obj="$work/native-signer/build/linux/.build"
g++ -std=c++17 -I"$src" -I"$src/common" Tests/StoreActions/clone-identity-check.cpp Zsign/CloneIdentity.cpp \
    "$obj/openssl.o" "$obj/common/"{base64,fs,json,log,sha,util}.o -lssl -lcrypto -o "$work/check-identity"
python3 Tests/StoreActions/sign-clone-fixture.py "$work/native-signer/bin/zsign" "$work/check-identity"
