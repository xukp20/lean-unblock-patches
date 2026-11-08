#!/usr/bin/env bash
# Build and install Linux x86-64 with Lean's release recipe inside the oldGlibc shell.
set -euo pipefail

if [[ $# != 4 ]]; then
    echo "Usage: $0 CHECKOUT LLVM_ARCHIVE INSTALL_PREFIX JOBS" >&2
    exit 2
fi
script_dir=$(cd -- "$(dirname -- "$0")" && pwd)
source_tree=$(realpath -- "$1")
archive=$(realpath -- "$2")
prefix=$(realpath -m -- "$3")
jobs=$4
[[ $(uname -s)/$(uname -m) == Linux/x86_64 && $jobs =~ ^[1-9][0-9]*$ ]]
if [[ -e "$prefix" || -L "$prefix" ]]; then
    echo "Choose a new install prefix: $prefix" >&2
    exit 2
fi
for dependency in GLIBC GLIBC_DEV GCC_LIB ZLIB GMP LIBUV OPENSSL; do
    if [[ ! -d ${!dependency:-} ]]; then
        echo "Missing $dependency; run inside the Lean checkout's oldGlibc Nix shell." >&2
        exit 2
    fi
done

python3 "$script_dir/apply.py" --verify v4.35.0 "$source_tree"
printf '434d69269e7542c508df882fd9083a40814ef75a1ad2762e2a2e9139ff0f85dc  %s\n' "$archive" | sha256sum --check
cmp "$source_tree/src/stdlib_flags.h" "$source_tree/stage0/src/stdlib_flags.h"
build="$source_tree/build/release"
mkdir -p -- "$source_tree/build"
mkdir -- "$build"
cd -- "$build"
# The pinned upstream script emits shell-quoted CMake arguments, as consumed in CI.
prepare=$("$source_tree/script/prepare-llvm-linux.sh" "$archive")
cp -r stage1 stage2
cp -r stage1 stage3
options=()
eval "options+=($prepare)"
cmake --preset release -S "$source_tree" -B "$build" -DLEAN_EXTRA_CXX_FLAGS=-Werror \
    -DWFAIL=ON -DLEAN_HEADER_SNAPSHOTS=ON -DCHECK_OLEAN_VERSION=ON "${options[@]}"
cmake --build "$build" --target stage1 --parallel "$jobs"
cmake --install "$build/stage1" --prefix "$prefix"
[[ $("$prefix/bin/lean" --githash) == "$(git -C "$source_tree" rev-parse HEAD)" ]]
"$prefix/bin/lake" --version
