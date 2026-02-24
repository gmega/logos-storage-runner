#!/usr/bin/env bash
set -e -o pipefail

LIB_SRC=${LIB_SRC:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}

# shellcheck source=./utils.bash
source "${LIB_SRC}/utils.bash"

for i in "${pids}"/*; do
  echoerr "Stopping node $(basename "$i")"
  killtree "$(cat "$i")" || true
  rm -rf "$i"
done

if [ "$1" != "nocleanup" ]; then
  echoerr "Cleaning up folders."
  cleanup_folders
fi