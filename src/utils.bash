echoerr() { echo "$@" >&2; }

LIB_SRC=${LIB_SRC:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}

root=$(realpath "${LIB_SRC}/../nodes")
export root
export log="${root}/log"
export config="${root}/config"
export data="${root}/data"
export pids="${root}/pids"

init_folders() {
  mkdir -p "${config}" "${log}" "${data}" "${pids}"
}

cleanup_folders() {
  rm -rf "${config}" "${log}" "${data}" "${pids}"
}

launch_terminal() {
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
