#!/usr/bin/env bash
# Build json-c with AFL++ + ASan instrumentation and compile the harness.
# Run from the repo root:  ./build.sh
# Assumes AFL++ (afl-clang-fast) is already installed. See README for that step.
set -euo pipefail

JSONC_REPO="https://github.com/json-c/json-c"
JSONC_COMMIT=""                          # pin the commit you used, e.g. "abc1234"
SRC_DIR="$HOME/json-c"
PREFIX="$HOME/jsonc-asan"
JOBS="${JOBS:-1}"                        # -j1 is deliberate: 4 GB RAM froze at -j2
REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"

command -v afl-clang-fast >/dev/null || { echo "afl-clang-fast not found. Install AFL++ first."; exit 1; }

# 1. Fetch json-c
if [ ! -d "$SRC_DIR" ]; then
  git clone "$JSONC_REPO" "$SRC_DIR"
fi
if [ -n "$JSONC_COMMIT" ]; then
  git -C "$SRC_DIR" checkout "$JSONC_COMMIT"
fi

# 2. Configure + build json-c as a static ASan-instrumented library
rm -rf "$SRC_DIR/build"
mkdir -p "$SRC_DIR/build"
cd "$SRC_DIR/build"
AFL_USE_ASAN=1 CC=afl-clang-fast cmake .. \
  -DCMAKE_BUILD_TYPE=Debug \
  -DBUILD_SHARED_LIBS=OFF -DBUILD_STATIC_LIBS=ON \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_INSTALL_LIBDIR=lib
AFL_USE_ASAN=1 make -j"$JOBS"
make install        

# 3. Compile the harness
cd "$REPO_ROOT"
AFL_USE_ASAN=1 afl-clang-fast -O1 -g harness/jc_harness.c \
  -I"$PREFIX/include" -o jc_harness "$PREFIX/lib/libjson-c.a"

# 4. Smoke test (expect exit code 0)
echo '{"a":[1,2]}' | ./jc_harness
echo "Harness smoke test exit code: $?"

echo
echo "Build done. To fuzz:"
echo "  sudo afl-system-config"
echo "  afl-fuzz -m none -x ~/AFLplusplus/dictionaries/json.dict -i seeds -o out_jc -- ./jc_harness"
