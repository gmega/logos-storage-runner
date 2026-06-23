#!/usr/bin/bash

N_MIX=${1:-5}
N_STORAGE=${2:-10}
N_EXPERIMENTS=${3:-1}

source "./src/lslh.bash"

sto_start_network $N_MIX $N_STORAGE false

EXPERIMENT_DIR="${RUNTIME_OUTPUTS}/experiments/$(date +%Y%m%d-%H%M%S)"

mkdir -p "$EXPERIMENT_DIR"

for i in $(seq 1 $N_EXPERIMENTS); do
  echo "Run experiment ${i}."
  filepath=$(genfile 50)

  seeder=$(randint $((N_MIX + 1)) $((N_STORAGE + N_MIX)))
  mapfile -t leechers < <(seq $((N_MIX + 1)) $((N_STORAGE + N_MIX)))
  unset 'leechers[seeder - 1]'

  echo "Seeder is ${seeder}, leechers are ${leechers[*]}"
  echo "Generated file: $filepath"
  cid=$(sto_upload "$seeder" "$filepath")

  outfile=$(basename "$filepath")
  for leecher in "${leechers[@]}"; do
    mkdir -p "$EXPERIMENT_DIR/leecher-$leecher"
    sto_enable_mix "$leecher" "true"
    sto_download "$leecher" "$cid" "$EXPERIMENT_DIR/leecher-$leecher/$outfile"
  done

  for leecher in "${leechers[@]}"; do
    await 50 sto_await_download "$leecher" "$cid" "$EXPERIMENT_DIR/leecher-$leecher/$outfile"
    sha1_equals "$filepath" "$EXPERIMENT_DIR/leecher-$leecher/$outfile"
  done
  echo "Done running experiment ${i}."
done

sto_teardown_network

echoerr "Success."