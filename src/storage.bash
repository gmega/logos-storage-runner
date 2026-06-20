set -e -o pipefail

LIB_SRC=${LIB_SRC:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}
# shellcheck source=./utils.bash
source "${LIB_SRC}/utils.bash"
# shellcheck source=./logos.bash
source "${LIB_SRC}/logos.bash"

BASE_DISC_PORT=9090
BASE_LISTEN_PORT=8080

DEFAULT_BUFFER_SIZE=65536

active_mix=0
active_storage=0

_sto_data_dir() {
  local node_id=$1
  echo "${data}/storage-${node_id}"
}

# Generates a storage node configuration file.
# Arguments:
#   $1: node_id - The node ID
#   $2: spr - The SPR (optional)
sto_generate_config() {
  local node_id=$1
  local listen_port=$((node_id + BASE_LISTEN_PORT))
  local disc_port=$((node_id + BASE_DISC_PORT))
  local spr=$2
  local config_file="${config}/storage-config-${node_id}.json"

  echo "{
  \"log-level\": \"DEBUG\",
  \"data-dir\": \"$(_sto_data_dir "$node_id")\",
  \"disc-port\": $disc_port,
  \"nat\": \"none\",
  \"mix-enabled\": true,
  \"listen-port\": $listen_port," > "${config_file}"

  if [ -n "$spr" ]; then
    echo -n "\"bootstrap-node\": [\"$spr\"]" >> "${config_file}"
  else
    echo -n "\"no-bootstrap-node\": true" >> "${config_file}"
  fi

  if [[ -f "${config}/mix-pool.json" ]]; then
    echo "," >> "${config_file}"
    echo "\"mix-pool\": \"${config}/mix-pool.json\"" >> "${config_file}"
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

# Starts a storage node within an existing logos node. All nodes
# are started with mix support. Nodes tagged as relays end up in
# the mix pool.
# Arguments:
#   $1: node_id - The node ID
#   $2: is_relay - Whether the node is a relay (true) or not (false)
sto_start_node() {
  local node_id=$1
  local is_relay=$2
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

  await 10 sto_node_ready "$node_id"

  if [[ "$is_relay" == "true" ]]; then
    echoerr "Export mix info for node ${node_id}"
    "$MIX_TOOLS/mix_pool" export\
      --pool="${config}/mix-pool.json"\
      --data-dir="$(_sto_data_dir "$node_id")"\
      --listen-ip="127.0.0.1"\
      --listen-port=$((node_id + BASE_LISTEN_PORT))
  fi
}

# Stops a storage node within a logos node. Unloads the module.
# Arguments:
#   $1: node_id - The node ID
sto_stop_node() {
  local node_id=$1
  local logos_cmd
  logos_cmd=$(logos_cli "$node_id")

  echoerr "Stopping node ${node_id}"

  ${logos_cmd} unload-module storage_module
}

# Starts a network of storage nodes. Handles launching of logos nodes,
# configuration generation, and storage/mix node startup.
# Arguments:
#   $1: storage - The number of storage nodes
#   $2: mix - The number of mix nodes
#   $3: follow_terminal - Whether to spawn a terminal containing the logs
#                         for each node or not
sto_start_network() {
  local storage=$1
  local mix=$2
  local follow_terminal=$3
  local k=$((storage + mix))

  init_folders

  for ((i=1; i<=k; i++)); do
    logos_start_node $i "$follow_terminal"
    sleep 1
    if [[ $i -eq 1 ]]; then
      spr=$(sto_get_spr $i)
      echoerr "Bootstrap SPR is ${spr}"
    fi

    sto_generate_config $i "$spr"
    # First nodes are mix/dht relay nodes.
    if [[ $i -le $mix ]]; then
      sto_start_node $i true "$follow_terminal"
    else
      sto_start_node $i false "$follow_terminal"
    fi
  done

  echoerr "Started network: "
  echoerr "* Nodes (0-${mix}): mix nodes"
  echoerr "* Nodes (${mix + 1}-${k}): storage nodes"

  active_mix=$mix
  active_storage=$storage
}

# Tears down the network of storage nodes that was started last. Stops all storage nodes,
# mix nodes, logos nodes and cleans up directories.
# Arguments:
#   None
sto_teardown_network() {
  local k=$((active_mix + active_storage))
  if [ "$k" -eq 0 ]; then
    echoerr "No active network to teardown"
    return 1
  fi

  echoerr "Tearing down network with ${active_mix} mix nodes and ${active_storage} storage nodes"

  for ((i=1; i<=k; i++)); do
    sto_stop_node $i
    logos_stop_node $i
  done

  cleanup_folders

  active_mix=0
  active_storage=0
}

# Uploads all files in a given folder to a storage node.
# Arguments:
#   $1: node_id - The node ID
#   $2: folder_path - The path to the folder to upload
sto_import_files() {
  local node_id=$1
  local folder_path=$2

  echoerr "Importing files to node ${node_id}: ${folder_path}"
  sto_call "$node_id" importFiles "${folder_path}"
}

# Gets the SPR (Service Provider Record) for a storage node.
# Arguments:
#   $1: node_id - The node ID
sto_get_spr() {
  local node_id=$1
  sto_call "$node_id" spr | jq --raw-output .result.value
}

# Gets debug information for a storage node.
# Arguments:
#   $1: node_id - The node ID
sto_debug() {
  local node_id=$1

  sto_call "$node_id" debug
}

# Uploads a file to a storage node.
# Arguments:
#   $1: node_id - The node ID
#   $2: file_path - The path to the file to upload
sto_upload() {
  local node_id=$1
  local file_path=$2

  if ! _sto_is_storage "$node_id"; then
    echoerr "Node $node_id is not a storage node"
    return 1
  fi

  sto_call "$node_id" uploadUrl "$file_path" "$DEFAULT_BUFFER_SIZE"
}

# Downloads a file from a storage node.
# Arguments:
#   $1: node_id - The node ID
#   $2: cid - The CID of the file to download
#   $3: output_path - The path to save the downloaded file
#   $4: local_download - Whether to download locally or not (default: false)
sto_download() {
  local node_id=$1
  local cid=$2
  local output_path=$3
  local local_download=${4:false}

  if ! _sto_is_storage "$node_id"; then
    echoerr "Node $node_id is not a storage node"
    return 1
  fi

  sto_call "$node_id" downloadToUrl "$cid" "$output_path" "$local_download" "$DEFAULT_BUFFER_SIZE"
}

# Gets the CIDs of all files in a storage node.
# Arguments:
#   $1: node_id - The node ID
sto_cids() {
  local node_id=$1
  sto_call "$node_id" manifests | jq --raw-output '.result.value[].cid'
}

# Checks if a storage node is ready.
# Arguments:
#   $1: node_id - The node ID
sto_node_ready() {
  local node_id=$1 spr
  spr=$(sto_call "$node_id" spr)
  [[ -n "$spr" ]]
}

_sto_is_storage() {
  local node_id=$1
  local first_index=$((active_mix + 1))
  [[ $node_id -ge $first_index ]]
}
