#!/usr/bin/env bash
set -e -o pipefail

LIB_SRC=${LIB_SRC:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}

# shellcheck source=./utils.bash
source "${LIB_SRC}/utils.bash"

file_list=("$@")

generate_config_file() {
  local node_id=$1
  local listen_port=$((node_id + 8080))
  local disc_port=$((node_id + 9090))
  local spr=$2
  local config_file="${config}/storage-config-${node_id}.json"

  echo -n "{
  \"log-level\": \"DEBUG\",
  \"data-dir\": \"${data}/storage-${node_id}\",
  \"disc-port\": $disc_port,
  \"nat\": \"none\",
  \"listen-addrs\": [\"/ip4/0.0.0.0/tcp/$listen_port\"]" > "${config_file}"

  if [ -n "$spr" ]; then
    echo -n ",\"bootstrap-node\": [\"$spr\"]" >> "${config_file}"
  fi

  echo -e "\n}" >> "${config_file}"
}

start_node() {
  local node_id=$1
  local config_file="${config}/storage-config-${node_id}.json"
  local commands=()
  shift

  echoerr "Starting node ${node_id}"

  commands+=("-c")
  commands+=("storage_module.init(@${config_file})")
  commands+=("-c")
  commands+=('storage_module.start()')

  for file_path in "$@"; do
    commands+=("-c")
    commands+=("storage_module.importFiles(${file_path})")
  done

  ./logos/bin/logoscore\
    -m ./modules\
    --load-modules storage_module\
    "${commands[@]}" &> "${log}/storage-${node_id}.log" &

  echo $! > "${pids}/storage-${node_id}.pid"
}

get_spr() {
  local node_id=$1
  local timeout=${2:-10}
  local interval=${3:-1}
  local start_time=$SECONDS
  local spr

  while (( SECONDS - start_time < timeout )); do
    spr=$(grep -e 'spr:[a-zA-Z0-9_-]\+' -o "${log}/storage-${node_id}.log" 2>/dev/null | head -n 1)
    if [ -n "$spr" ]; then
      echo "$spr"
      echoerr "Bootstrap SPR is: ${spr}"
      return 0
    fi
    sleep "$interval"
  done

  echoerr "Timed out waiting for SPR on node ${node_id}"

  return 1
}

init_folders

generate_config_file 1
start_node 1 "${file_list[@]}"

spr=$(get_spr 1) || exit 1

generate_config_file 2 "$spr"
start_node 2 "${file_list[@]}"
