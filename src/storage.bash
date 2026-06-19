set -e -o pipefail

LIB_SRC=${LIB_SRC:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}
# shellcheck source=./utils.bash
source "${LIB_SRC}/utils.bash"
# shellcheck source=./logos.bash
source "${LIB_SRC}/logos.bash"

BASE_DISC_PORT=9090
BASE_LISTEN_PORT=8080

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
  sto_call "$node_id" uploadUrl "$file_path"
}

sto_download() {
  local node_id=$1
  local cid=$2
  local output_path=$3
  sto_call "$node_id" downloadToUrl "$cid" "$output_path" "false"
}

sto_cids() {
  sto_call "$node_id" manifests | jq --raw-output 'result.value[].cid'
}

sto_cid_count_ge() {
  local node_id=$1
  local expected=$2
  local current
  echoerr "Expecting at least $expected CIDs for node $node_id"
  current=$(sto_get_cids "$node_id" | wc -l)
  echoerr "Found $current CIDs for node $node_id"
  [ "$current" -ge "$expected" ]
}
