echoerr() { echo "$@" >&2; }

LIB_SRC=${LIB_SRC:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}

export root="${LIB_SRC}/nodes"
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