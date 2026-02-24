#!/usr/bin/env bash
#
# startup.bash: starts a k-node Logos Node network running the storage node.
# By default, k = 2. It illustrates:
#
#  1. how to start and preconfigure a Logos node with storage on;
#  2. how to bootstrap storage nodes from each other;
#  3. how to pre-populate a storage node with files.
#
set -e -o pipefail

LIB_SRC=${LIB_SRC:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}

# shellcheck source=./utils.bash
source "${LIB_SRC}/utils.bash"

k=2 # Want more nodes? Increase this number.
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
    echo "" >> "${config_file}"
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
    if [ -z "$file_path" ]; then
      continue
    fi
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
  grep "udp" "${log}/storage-${node_id}.log" | grep -e 'spr:[a-zA-Z0-9_-]\+' -o | head -n 1
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

spr=""

echoerr "Starting a ${k}-node network."

for ((i=1; i<=k; i++)); do
  generate_config_file $i "$spr"
  start_node $i "${import_folder}"

  if [ $i -eq 1 ]; then
    echoerr "Wait for bootstrap SPR."
    spr=$(await 10 get_spr $i)
    echoerr "SPR is: ${spr}"
  fi

  if [ -n "${import_folder}" ]; then
    echoerr "Populate node $i with files from ${import_folder}."
    #shellcheck disable=SC2012
    await 10 cid_count_ge $i "$(ls -1 "${import_folder}" 2> /dev/null | wc -l)"

    echoerr "CIDs for node $i:"
    get_cids $i
  else
    echoerr "No import folder specified, so no files will be imported for node ${i}."
  fi

done
