#!/usr/bin/env bash
#
set -e -o pipefail

LIB_SRC=${LIB_SRC:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}

# shellcheck source=./utils.bash
source "${LIB_SRC}/utils.bash"

if [ -z "${LOGOS_MODULES}" ]; then
  echo "Error: LOGOS_MODULES not set."
  exit 1
fi

logos_modules="${LOGOS_MODULES}"
logos_core=$(find_binary logoscore)

logos_cli() {
  local node_id=$1
  echo "${logos_core} --config-dir=${config}/logoscore-${node_id}"
}

logos_start_node() {
  local node_id=$1
  local spawn_terminal=$2

  local logos_cmd
  logos_cmd=$(logos_cli "$node_id")

  echoerr "Starting logoscore node ${node_id}"

  ${logos_cmd} -D -m "$logos_modules" &> "${log}/logos-daemon-${node_id}.log" &
  echo $! > "${pids}/logos-daemon-${node_id}.pid"

  if [ "$spawn_terminal" = true ]; then
    util_spawn_terminal "Node ${node_id}" tail -f "${log}/logos-daemon-${node_id}.log"
  fi
}

logos_stop_node() {
  local node_id=$1
  local pid_file="${pids}/logos-daemon-${node_id}.pid"

  if [ -f "$pid_file" ]; then
    local pid
    pid=$(cat "$pid_file")

    echoerr "Stopping logoscore node ${node_id} (PID: $pid)"
    $(logos_cli "$node_id") stop

    if await 10 is_dead "$pid"; then
      echoerr "Node ${node_id} stopped successfully"
    else
      echoerr "Node ${node_id} did not stop in time. Killing"
      kill -9 "$pid"
    fi
    rm -f "$pid_file"
  else
    echoerr "No PID file found for node ${node_id}"
  fi
}

init_folders
