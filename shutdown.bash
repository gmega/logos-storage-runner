#!/usr/bin/env bash
set -e -o pipefail

LIB_SRC=${LIB_SRC:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}

# shellcheck source=./utils.bash
source "${LIB_SRC}/utils.bash"

for i in "${pids}"/*; do
  echo "Stopping node $(basename "$i")"
  kill "$(cat "$i")" || true
  rm -rf "$i"
done

if [ "$1" != "nocleanup" ]; then
  echo "Cleaning up folders."
  cleanup_folders
fi