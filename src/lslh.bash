#!/usr/bin/env bash
#
# lsnlh - Logos Storage Node Local Harness
#
LIB_SRC=${LIB_SRC:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}

if [ ! -f "$LIB_SRC/../env.sh" ]; then
  echo "Error: $LIB_SRC/../env.sh not found. Run build.bash first."
  exit 1
fi

# shellcheck source=../env.sh
source "$LIB_SRC/../env.sh"

RUNTIME_OUTPUTS=$(realpath "${LIB_SRC}/../runtime")
echo "Build outputs: $BUILD_OUTPUTS"
echo "Runtime outputs: $RUNTIME_OUTPUTS"
echo "Logos modules: $LOGOS_MODULES"

# shellcheck source=./storage.bash
source "$LIB_SRC/storage.bash"

if [[ $- =~ i ]]; then
  echo "You are sourcing this from a shell. Setting set +e."
  set +e
fi

reload() {
  echo "Reloading..."
  source "$LIB_SRC/lslh.bash"
}
