#!/usr/bin/env bash
LIB_SRC=${LIB_SRC:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}

if [ -z "${RUNTIME_OUTPUTS}" ]; then
  root=$(realpath "${LIB_SRC}/../nodes")
else
  root="${RUNTIME_OUTPUTS}"
fi

export log="${root}/log"
export config="${root}/config"
export data="${root}/data"
export pids="${root}/pids"

echoerr() { echo "$@" >&2; }

init_folders() {
  mkdir -p "${config}" "${log}" "${data}" "${pids}"
}

cleanup_folders() {
  rm -rf "${config}" "${log}" "${data}" "${pids}"
}

util_spawn_terminal() {
  local title=$1
  shift
  # TODO: Use another terminal in OSX
  gnome-terminal --title="$title" -- "$@" &
  local pid=$!
  echo $pid > "${pids}/terminal-${pid}.pid"
}

find_binary() {
  local path
  echoerr "Finding binary ${1}."
  path=$(find -L ~+ -iname "${1}")
  if [ -z "$path" ]; then
    echoerr "Binary ${1} not found. Have you built the project?"
    exit 1
  fi
  echoerr "Found binary ${1} at ${path}."
  echo "$path"
}

killtree() {
  local pid=$1
  for child in $(ps -o pid= --ppid "$pid" 2>/dev/null); do
    echoerr "Killing $child"
    killtree "$child"
  done
  echoerr "Killing $pid"
  kill "$pid" 2>/dev/null
}

kill_all() {
  for i in "${pids}"/*; do
    echoerr "Stopping node $(basename "$i")"
    killtree "$(cat "$i")" || true
    rm -rf "$i"
  done

  if [ "$1" != "nocleanup" ]; then
    echoerr "Cleaning up folders."
    cleanup_folders
  fi
}

is_dead() {
  local pid=$1
  kill -0 "$pid" 2>/dev/null
}

await() {
  local timeout=$1
  shift 1

  local start_time=$SECONDS
  while (( SECONDS - start_time < timeout )); do
    if "$@"; then
      return 0
    fi
    sleep 1
  done

  echoerr "Timed out waiting for [${*}]"

  return 1
}

file_lock_acquire() {
  local lock_file="${1}.lock"
  if [ -f "$lock_file" ]; then
    # Acquire failed, returns.
    return 1
  fi
  touch "$lock_file"
  return 0
}

file_lock_release() {
  local lock_file="${1}.lock"
  rm "$lock_file"
}
