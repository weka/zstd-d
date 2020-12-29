#!/bin/bash
zstd_h_path="$1"
zstd_d_path=$(dirname $0)/source/zstd/c/zstd.d
echo "Translating ${zstd_h_path} => ${zstd_d_path} with DStep"
dstep --package zstd.c -DZSTD_STATIC_LINKING_ONLY=1 --skip ZSTDLIB_API --skip ZSTD_LIB_VERSION --skip ZSTD_VERSION_STRING --global-attribute @trusted --global-attribute @nogc --global-attribute nothrow "${zstd_h_path}" -o "${zstd_d_path}"

# Convert `ULL` unsigned long long constants to D's `UL`
# perl as a platform-neutral sed (e.g GNU sed vs MacOS's BSD SED)
perl -pi -e 's/([0-9])ULL\b/$1UL/g' "${zstd_d_path}"
