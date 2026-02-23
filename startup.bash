#!/usr/bin/env bash
set -e -o pipefail

LIB_SRC=${LIB_SRC:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}

# shellcheck source=./utils.bash
source "${LIB_SRC}/utils.bash"

import_folder=$1

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
  \"log-level\": \"DEBUG\",
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

get_spr() {
  local node_id=$1
  grep -e 'spr:[a-zA-Z0-9_-]\+' -o "${log}/storage-${node_id}.log"
}

get_cids() {
  local node_id=$1
  grep -o 'cid= \\"[a-zA-Z0-9_-]\+' "${log}/storage-${node_id}.log" | cut -d '"' -f2
}

cid_count_ge() {
  local node_id=$1
  local expected=$2
  local current
  echoerr "Expecting at least $expected CIDs for node $node_id"
  current=$(get_cids "$node_id" | wc -l)
  echoerr "Found $current CIDs for node $node_id"
  [ "$current" -ge "$expected" ]
}

init_folders

generate_config_file 1
start_node 1 "${import_folder}"

spr=$(await 10 get_spr 1)
get_spr 1 | head -n 1

generate_config_file 2 "$spr"
start_node 2 "${import_folder}"

#shellcheck disable=SC2012
await 10 cid_count_ge 2 "$(ls -1 "${import_folder}" | wc -l)"
get_cids 2
