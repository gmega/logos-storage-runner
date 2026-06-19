#!/usr/bin/env bash
#
set -e -o pipefail

LIB_SRC=${LIB_SRC:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}
# shellcheck source=./utils.bash
source "${LIB_SRC}/utils.bash"

logos_core=$(find_binary logoscore)

logos_cli() {
  local node_id=$1
  echo "${logos_core} --config-dir=${config}/logoscore-${node_id}"
}

logos_start_node() {
  local node_id=$1
  local follow_terminal=$2

  local logos_cmd
  logos_cmd=$(logos_cli "$node_id")

  echoerr "Starting logoscore node ${node_id}"

  ${logos_cmd} -D -m ./modules &> "${log}/logos-daemon-${node_id}.log" &
  echo $! > "${pids}/logos-daemon-${node_id}.pid"

  if [ "$follow_terminal" = true ]; then
    launch_terminal "Node ${node_id}" tail -f "${log}/logos-daemon-${node_id}.log"
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
