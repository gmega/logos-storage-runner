set -e -o pipefail

LIB_SRC=${LIB_SRC:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}
# shellcheck source=./utils.bash
source "${LIB_SRC}/utils.bash"
# shellcheck source=./logos.bash
source "${LIB_SRC}/logos.bash"

BASE_DISC_PORT=9090
BASE_LISTEN_PORT=8080

DEFAULT_BUFFER_SIZE=65536

active_network=""

sto_generate_config() {
  local node_id=$1
  local listen_port=$((node_id + BASE_LISTEN_PORT))
  local disc_port=$((node_id + BASE_DISC_PORT))
  local spr=$2
  local config_file="${config}/storage-config-${node_id}.json"

  echo -n "{
  \"log-level\": \"DEBUG\",
  \"data-dir\": \"${data}/storage-${node_id}\",
  \"disc-port\": $disc_port,
  \"nat\": \"none\",
  \"listen-port\": $listen_port" > "${config_file}"

  if [ -n "$spr" ]; then
    echo "," >> "${config_file}"
    echo -n "\"bootstrap-node\": [\"$spr\"]" >> "${config_file}"
  else
    echo "," >> "${config_file}"
    echo -n "\"no-bootstrap-node\": true" >> "${config_file}"
  fi

  echo -e "\n}" >> "${config_file}"
}

sto_call() {
  local node_id=$1
  local logos_cmd
  logos_cmd=$(logos_cli "$node_id")
  shift

  ${logos_cmd} call storage_module "$@"
}

sto_start_node() {
  local node_id=$1
  local config_file="${config}/storage-config-${node_id}.json"
  local logos_cmd
  logos_cmd=$(logos_cli "$node_id")

  echoerr "Starting storage node ${node_id}"
  if [[ ! -f "$config_file" ]]; then
    echoerr "Config file $config_file not found. You must invoke sto_generate_config ${node_id} ... first"
    return 1
  fi

  ${logos_cmd} load-module storage_module
  sto_call "$node_id" init "@${config_file}"
  sto_call "$node_id" start
}

sto_stop_node() {
  local node_id=$1
  local logos_cmd
  logos_cmd=$(logos_cli "$node_id")

  echoerr "Stopping node ${node_id}"

  ${logos_cmd} unload-module storage_module
}

sto_start_network() {
  local k=$1
  local follow_terminal=$2
  local spr

  init_folders

  for ((i=1; i<=k; i++)); do
    logos_start_node $i "$follow_terminal"
    sleep 1
    sto_generate_config $i "$spr"
    sto_start_node $i
    if [[ $i -eq 1 ]]; then
      spr=$(sto_get_spr $i)
      echoerr "Bootstrap SPR is ${spr}"
    fi
  done

  active_network="$k"
}

sto_teardown_network() {
  if [ -z "$active_network" ]; then
    echoerr "No active network to teardown"
    return 1
  fi
  echoerr "Tearing down network with ${active_network} nodes"

  local k=$active_network
  for ((i=1; i<=k; i++)); do
    sto_stop_node $i
    logos_stop_node $i
  done

  cleanup_folders

  active_network=""
}

sto_import_files() {
  local node_id=$1
  local file_path=$2

  echoerr "Importing files to node ${node_id}: ${file_path}"
  sto_call "$node_id" importFiles "${file_path}"
}

sto_get_spr() {
  local node_id=$1
  sto_call "$node_id" spr | jq --raw-output .result.value
}

sto_debug() {
  local node_id=$1

  sto_call "$node_id" debug
}

sto_upload() {
  local node_id=$1
  local file_path=$2

  sto_call "$node_id" uploadUrl "$file_path" "$DEFAULT_BUFFER_SIZE"
}

sto_download() {
  local node_id=$1
  local cid=$2
  local output_path=$3
  local local_download=${4:false}

  sto_call "$node_id" downloadToUrl "$cid" "$output_path" "$local_download" "$DEFAULT_BUFFER_SIZE"
}

sto_cids() {
  local node_id=$1
  sto_call "$node_id" manifests | jq --raw-output '.result.value[].cid'
}
